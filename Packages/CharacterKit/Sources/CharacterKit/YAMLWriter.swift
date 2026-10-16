import Foundation
import Yams

/// Writes the header in the house style described in docs/FILE-FORMAT.md:
/// 2-space indents, `{ key: value }` flow maps with inner spaces, `[a, b]`
/// flow lists, and block lists indented under their key.
///
/// Nodes that came from a file keep their original block/flow style and
/// quoting, so a file written in the house style is reproduced byte for byte.
/// Nodes created in code (style `.any`) get flow style when they are short
/// and contain only scalars, and are quoted only when they need to be.
struct YAMLWriter {
    var indentWidth = 2
    /// Longest flow collection, in characters, chosen for nodes with style `.any`.
    var maxFlowLength = 80

    // MARK: Block style

    func blockMapping(_ mapping: Node.Mapping, indent: Int) -> String {
        let pad = String(repeating: " ", count: indent)
        var out = ""
        for (key, value) in mapping {
            let keyText = scalarText(key, inFlow: false)
            switch value {
            case let .scalar(scalar) where scalar.style == .literal || scalar.style == .folded:
                out += pad + keyText + ": " + literal(scalar.string, indent: indent + indentWidth)
            case .scalar, .alias:
                out += pad + keyText + ": " + flow(value) + "\n"
            case let .mapping(child):
                if child.isEmpty || usesFlow(value) {
                    out += pad + keyText + ": " + flow(value) + "\n"
                } else {
                    out += pad + keyText + ":\n" + blockMapping(child, indent: indent + indentWidth)
                }
            case let .sequence(child):
                if child.isEmpty || usesFlow(value) {
                    out += pad + keyText + ": " + flow(value) + "\n"
                } else {
                    out += pad + keyText + ":\n" + blockSequence(child, indent: indent + indentWidth)
                }
            }
        }
        return out
    }

    func blockSequence(_ sequence: Node.Sequence, indent: Int) -> String {
        let pad = String(repeating: " ", count: indent)
        var out = ""
        for item in sequence {
            switch item {
            case let .scalar(scalar) where scalar.style == .literal || scalar.style == .folded:
                out += pad + "- " + literal(scalar.string, indent: indent + indentWidth)
            case let .mapping(child) where !child.isEmpty && !usesFlow(item):
                // First pair shares the "- " line; the rest line up under it.
                let nested = blockMapping(child, indent: indent + indentWidth)
                out += pad + "- " + nested.dropFirst(indent + indentWidth)
            case let .sequence(child) where !child.isEmpty && !usesFlow(item):
                out += pad + "-\n" + blockSequence(child, indent: indent + indentWidth)
            default:
                out += pad + "- " + flow(item) + "\n"
            }
        }
        return out
    }

    /// A `|` block scalar. Falls back to a quoted string when the text can't
    /// be represented as one (e.g. it starts with a space).
    func literal(_ string: String, indent: Int) -> String {
        if string.isEmpty || string.first == " " || string.contains("\r") {
            return doubleQuoted(string) + "\n"
        }
        let chomp: String
        if string.hasSuffix("\n\n") { chomp = "+" } else if string.hasSuffix("\n") { chomp = "" } else { chomp = "-" }
        let pad = String(repeating: " ", count: indent)
        var lines = string.components(separatedBy: "\n")
        if string.hasSuffix("\n") { lines.removeLast() }
        return "|" + chomp + "\n" + lines.map { $0.isEmpty ? "\n" : pad + $0 + "\n" }.joined()
    }

    // MARK: Flow style

    func flow(_ node: Node) -> String {
        switch node {
        case .scalar:
            return scalarText(node, inFlow: true)
        case let .mapping(mapping):
            if mapping.isEmpty { return "{}" }
            let pairs = mapping.map { scalarText($0.key, inFlow: true) + ": " + flow($0.value) }
            return "{ " + pairs.joined(separator: ", ") + " }"
        case let .sequence(sequence):
            return "[" + sequence.map(flow).joined(separator: ", ") + "]"
        case let .alias(alias):
            return "*" + alias.anchor.rawValue
        }
    }

    func usesFlow(_ node: Node) -> Bool {
        switch node {
        case let .mapping(mapping):
            switch mapping.style {
            case .flow: return true
            case .block: return false
            case .any: return mapping.values.allSatisfy(\.isScalar) && flow(node).count <= maxFlowLength
            }
        case let .sequence(sequence):
            switch sequence.style {
            case .flow: return true
            case .block: return false
            case .any: return sequence.allSatisfy(\.isScalar) && flow(node).count <= maxFlowLength
            }
        default:
            return true
        }
    }

    // MARK: Scalars

    func scalarText(_ node: Node, inFlow: Bool) -> String {
        guard case let .scalar(scalar) = node else { return flow(node) }
        let string = scalar.string
        let isString = Resolver.default.resolveTag(of: node) == .str

        switch scalar.style {
        case .singleQuoted where !string.contains("\n"):
            return "'" + string.replacingOccurrences(of: "'", with: "''") + "'"
        case .singleQuoted, .doubleQuoted, .literal, .folded:
            return doubleQuoted(string)
        case .plain:
            // Came from a file as plain text, so it's already safe here,
            // unless it was explicitly tagged as a string but looks like a number.
            if !isString || resolvesToString(string) { return string }
            return doubleQuoted(string)
        case .any:
            if !isString { return string }
            return canBePlain(string, inFlow: inFlow) ? string : doubleQuoted(string)
        }
    }

    /// Conservative check for writing a string without quotes.
    func canBePlain(_ string: String, inFlow: Bool) -> Bool {
        guard let first = string.first, let last = string.last else { return false }
        if first.isWhitespace || last.isWhitespace { return false }
        if "-?:,[]{}#&*!|>'\"%@`".contains(first) { return false }
        if string.contains(where: { $0.isNewline || $0 == "\t" }) { return false }
        if string.contains(": ") || string.hasSuffix(":") || string.contains(" #") { return false }
        if inFlow && string.contains(where: { ",[]{}".contains($0) }) { return false }
        return resolvesToString(string)
    }

    /// True if the text, written plain, would read back as a string
    /// (and not, say, `no` → false or `12` → a number).
    func resolvesToString(_ string: String) -> Bool {
        Resolver.default.resolveTag(of: Node(string)) == .str
    }

    func doubleQuoted(_ string: String) -> String {
        var out = "\""
        for scalar in string.unicodeScalars {
            switch scalar {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case "\t": out += "\\t"
            case "\r": out += "\\r"
            case _ where scalar.value < 0x20 || scalar.value == 0x7F:
                out += String(format: "\\u%04X", scalar.value)
            default:
                out.unicodeScalars.append(scalar)
            }
        }
        return out + "\""
    }
}

private extension Node {
    var isScalar: Bool {
        if case .scalar = self { return true }
        return false
    }
}
