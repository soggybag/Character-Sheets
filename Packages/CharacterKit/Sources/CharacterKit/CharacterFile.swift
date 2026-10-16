import Foundation
import Yams

/// A character file: a YAML front matter header (the sheet) followed by a
/// Markdown body (notes). See docs/FILE-FORMAT.md.
///
/// The header is kept as a YAML node tree rather than decoded into a struct,
/// so key order, flow/block style, quoting and unknown keys all survive a
/// load/save cycle.
public struct CharacterFile {
    /// The front matter. Always a mapping.
    public var header: Node
    /// Everything after the closing `---` line, unchanged.
    public var body: String
    /// Line ending of the original file, re-applied when saving.
    public var lineEnding: LineEnding
    /// Whether the original file started with a UTF-8 byte order mark.
    public var hasByteOrderMark: Bool

    public enum LineEnding: String, Sendable {
        case lf = "\n"
        case crlf = "\r\n"
    }

    public init(header: Node = Node([(Node, Node)]()),
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

        let node: Node?
        do {
            node = try Yams.compose(yaml: headerText)
        } catch let error as YamlError {
            throw Self.describe(error)
        }
        switch node {
        case nil:
            header = Node([(Node, Node)]())
        case let .some(node) where node.mapping != nil:
            header = Self.restoringCollectionStyles(node, source: headerText.unicodeScalars.split(
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

    /// Yams 6.2 reads a collection's style from its *end* event, so parsed
    /// maps and lists come back with style `.any`. Recover it from the
    /// source instead: a flow collection starts with `{` or `[` at its mark.
    static func restoringCollectionStyles(_ node: Node, source lines: [[Unicode.Scalar]]) -> Node {
        func startsWithBracket(_ mark: Mark?, _ bracket: Unicode.Scalar) -> Bool? {
            guard let mark, lines.indices.contains(mark.line - 1) else { return nil }
            let line = lines[mark.line - 1]
            guard line.indices.contains(mark.column - 1) else { return nil }
            return line[mark.column - 1] == bracket
        }
        switch node {
        case var .mapping(mapping):
            if let isFlow = startsWithBracket(mapping.mark, "{") { mapping.style = isFlow ? .flow : .block }
            for key in mapping.keys {
                mapping[key] = mapping[key].map { restoringCollectionStyles($0, source: lines) }
            }
            return .mapping(mapping)
        case var .sequence(sequence):
            if let isFlow = startsWithBracket(sequence.mark, "[") { sequence.style = isFlow ? .flow : .block }
            for index in sequence.indices {
                sequence[index] = restoringCollectionStyles(sequence[index], source: lines)
            }
            return .sequence(sequence)
        case .scalar, .alias:
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
}
