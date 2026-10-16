import Foundation
import Yams

/// A character file: a YAML front matter header (the sheet) followed by a
/// Markdown body (notes). See docs/FILE-FORMAT.md.
///
/// The header is kept as a YAML node tree rather than decoded into a struct,
/// so key order, flow/block style, quoting and unknown keys all survive a
/// load/save cycle.
///
/// Sendable: Yams nodes share `Tag` objects that Yams mutates when it first
/// works out an untagged value's type. Every node in a `CharacterFile` has an
/// explicit tag (set when loading, and by every setter), so the tags are
/// never mutated and copies can be read safely from any thread.
public struct CharacterFile: @unchecked Sendable {
    /// The front matter. Always a mapping.
    public var header: Node
    /// Everything after the closing `---` line, unchanged.
    public var body: String
    /// Line ending of the original file, re-applied when saving.
    public var lineEnding: LineEnding
    /// Whether the original file started with a UTF-8 byte order mark.
    public var hasByteOrderMark: Bool
    /// The header had full-line `#` comments. They are not kept when the file
    /// is saved, so the app warns about it.
    public private(set) var headerHadComments = false

    public enum LineEnding: String, Sendable {
        case lf = "\n"
        case crlf = "\r\n"
    }

    public init(header: Node = .mapping(.init([], Tag(.map), .block)),
                body: String = "",
                lineEnding: LineEnding = .lf,
                hasByteOrderMark: Bool = false) {
        self.header = header
        self.body = body
        self.lineEnding = lineEnding
        self.hasByteOrderMark = hasByteOrderMark
    }
}

// MARK: - Reading

public enum CharacterFileError: Error, Equatable, CustomStringConvertible {
    /// The file doesn't start with a `---` line.
    case noFrontMatter
    /// There's an opening `---` but no closing one.
    case unterminatedFrontMatter
    /// The header isn't valid YAML. `line` is the line in the whole file.
    case invalidYAML(problem: String, line: Int?)
    /// The header is valid YAML but not a mapping (e.g. a bare list).
    case headerNotMapping

    public var description: String {
        switch self {
        case .noFrontMatter:
            return "The file doesn't start with a --- header."
        case .unterminatedFrontMatter:
            return "The header has no closing --- line."
        case let .invalidYAML(problem, line):
            return line.map { "Line \($0): \(problem)" } ?? problem
        case .headerNotMapping:
            return "The header must be a list of key: value pairs."
        }
    }
}

extension CharacterFile {
    /// Parses the text of a character file.
    public init(text: String) throws {
        var text = text
        hasByteOrderMark = text.hasPrefix("\u{FEFF}")
        if hasByteOrderMark { text.removeFirst() }
        lineEnding = text.contains("\r\n") ? .crlf : .lf
        if lineEnding == .crlf { text = text.replacingOccurrences(of: "\r\n", with: "\n") }

        let (headerText, body) = try Self.split(text)
        self.body = body
        headerHadComments = headerText.split(separator: "\n").contains {
            $0.drop { $0 == " " }.hasPrefix("#")
        }

        let node: Node?
        do {
            node = try Yams.compose(yaml: headerText)
        } catch let error as YamlError {
            throw Self.describe(error)
        }
        switch node {
        case nil:
            header = .mapping(.init([], Tag(.map), .block))
        case let .some(node) where node.mapping != nil:
            header = Self.normalized(node, source: headerText.unicodeScalars.split(
                separator: "\n", omittingEmptySubsequences: false).map(Array.init))
        default:
            throw CharacterFileError.headerNotMapping
        }
    }

    /// Splits text into the header YAML and the body.
    static func split(_ text: String) throws -> (header: String, body: String) {
        guard text.hasPrefix("---\n") || text == "---" else {
            throw CharacterFileError.noFrontMatter
        }
        var headerLines: [Substring] = []
        var rest = text.dropFirst(4)
        while !rest.isEmpty {
            let lineEnd = rest.firstIndex(of: "\n")
            let line = rest[..<(lineEnd ?? rest.endIndex)]
            let afterLine = lineEnd.map { rest.index(after: $0) } ?? rest.endIndex
            if line == "---" || line == "..." {
                let header = headerLines.map { $0 + "\n" }.joined()
                return (header, String(rest[afterLine...]))
            }
            headerLines.append(line)
            rest = rest[afterLine...]
        }
        throw CharacterFileError.unterminatedFrontMatter
    }

    /// Prepares a parsed tree:
    /// - Gives every node an explicit tag (see the note on `CharacterFile`).
    /// - Restores collection styles. Yams 6.2 reads a collection's style from
    ///   its *end* event, so parsed maps and lists come back with style `.any`.
    ///   A flow collection starts with `{` or `[` at its mark.
    static func normalized(_ node: Node, source lines: [[Unicode.Scalar]]) -> Node {
        func startsWithBracket(_ mark: Mark?, _ bracket: Unicode.Scalar) -> Bool? {
            guard let mark, lines.indices.contains(mark.line - 1) else { return nil }
            let line = lines[mark.line - 1]
            guard line.indices.contains(mark.column - 1) else { return nil }
            return line[mark.column - 1] == bracket
        }
        let tag = Tag(Resolver.default.resolveTag(of: node))
        switch node {
        case let .mapping(mapping):
            let style: Node.Mapping.Style = startsWithBracket(mapping.mark, "{").map { $0 ? .flow : .block } ?? mapping.style
            let pairs = mapping.map { (normalized($0.key, source: lines), normalized($0.value, source: lines)) }
            return .mapping(.init(pairs, tag, style, mapping.mark))
        case let .sequence(sequence):
            let style: Node.Sequence.Style = startsWithBracket(sequence.mark, "[").map { $0 ? .flow : .block } ?? sequence.style
            return .sequence(.init(sequence.map { normalized($0, source: lines) }, tag, style, sequence.mark))
        case var .scalar(scalar):
            scalar.tag = tag
            return .scalar(scalar)
        case .alias:
            return node
        }
    }

    private static func describe(_ error: YamlError) -> CharacterFileError {
        switch error {
        case let .scanner(_, problem, mark, _),
             let .parser(_, problem, mark, _),
             let .composer(_, problem, mark, _):
            // +1 for the opening --- line.
            return .invalidYAML(problem: problem, line: mark.line + 1)
        default:
            return .invalidYAML(problem: String(describing: error), line: nil)
        }
    }
}

// MARK: - Writing

extension CharacterFile {
    /// The file's text, as it should be written to disk.
    public func text() -> String {
        let headerText = header.mapping.map { YAMLWriter().blockMapping($0, indent: 0) } ?? ""
        var text = "---\n" + headerText + "---\n" + body
        if lineEnding == .crlf { text = text.replacingOccurrences(of: "\n", with: "\r\n") }
        if hasByteOrderMark { text = "\u{FEFF}" + text }
        return text
    }
}

// MARK: - Recognising character files

extension CharacterFile {
    /// The format version, if the header has one.
    public var formatVersion: Int? { header["formatVersion"]?.int }

    /// Ruleset id, e.g. `ose`.
    public var system: String? { header["rules"]?["system"]?.string }

    /// True when the header has the keys that mark a character file.
    /// Other Markdown files with front matter are left alone.
    public var isCharacter: Bool { formatVersion != nil && system != nil }

    /// The character's name, or nil if it has none (the app then shows the
    /// file name).
    public var name: String? {
        guard let name = header["name"]?.string?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty else { return nil }
        return name
    }
}

// MARK: - Building values

extension Node {
    /// A string value. Use this rather than `Node(_:)` for text the user
    /// typed: an untagged `Node("No")` would be saved unquoted and read back
    /// as `false`.
    public static func text(_ string: String) -> Node {
        Node(string, Tag(.str))
    }

    static func integer(_ value: Int) -> Node {
        Node(String(value), Tag(.int))
    }

    static func boolean(_ value: Bool) -> Node {
        Node(value ? "true" : "false", Tag(.bool))
    }
}

// MARK: - Options

extension CharacterFile {
    static let ascendingACPath: NodePath = ["rules", "options", "ascendingAC"]

    /// Whether AC is ascending (and attacks use an attack bonus, not THAC0).
    public var usesAscendingAC: Bool { bool(Self.ascendingACPath) ?? false }

    /// Switches AC style, converting AC and THAC0 / attack bonus to match
    /// (ascending = 19 − descending).
    public mutating func setAscendingAC(_ ascending: Bool) {
        let wasAscending = usesAscendingAC
        setBool(ascending, at: Self.ascendingACPath)
        guard ascending != wasAscending else { return }
        if let ac = int(["combat", "ac"]) { setInt(19 - ac, at: ["combat", "ac"]) }
        let (from, to): (NodePath, NodePath) = ascending
            ? (["combat", "thac0"], ["combat", "attackBonus"])
            : (["combat", "attackBonus"], ["combat", "thac0"])
        if let value = int(from) {
            self[from] = nil
            setInt(19 - value, at: to)
        }
    }
}
