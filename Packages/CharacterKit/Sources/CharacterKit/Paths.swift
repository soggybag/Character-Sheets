import Yams

/// One step into the header: a map key or a list index.
public enum PathComponent: Hashable, Sendable, ExpressibleByStringLiteral, ExpressibleByIntegerLiteral,
    CustomStringConvertible {
    case key(String)
    case index(Int)

    public init(stringLiteral value: String) { self = .key(value) }
    public init(integerLiteral value: Int) { self = .index(value) }

    public var description: String {
        switch self {
        case let .key(key): key
        case let .index(index): String(index)
        }
    }
}

/// A location in the header, e.g. `["equipment", 2, "name"]`.
public typealias NodePath = [PathComponent]

// MARK: - Reading and writing values

extension CharacterFile {
    /// The node at `path`, or nil if any step is missing. Setting nil removes
    /// the value, and also removes any map or list left empty by that.
    public subscript(path: NodePath) -> Node? {
        get { header.value(at: path[...]) }
        set { header.setValue(newValue, at: path[...], prefix: []) }
    }

    public func string(_ path: NodePath) -> String? { self[path]?.string }
    public func int(_ path: NodePath) -> Int? { self[path]?.int }
    public func bool(_ path: NodePath) -> Bool? { self[path]?.bool }

    /// Number of items in the list at `path` (0 if there's no list).
    public func count(_ path: NodePath) -> Int {
        switch self[path] {
        case let .sequence(sequence): sequence.count
        case let .mapping(mapping): mapping.count
        default: 0
        }
    }

    /// Sets a text value. Nil or empty removes the key.
    public mutating func setString(_ value: String?, at path: NodePath) {
        self[path] = value.flatMap { $0.isEmpty ? nil : .text($0) }
    }

    /// Sets a whole number. Nil removes the key.
    public mutating func setInt(_ value: Int?, at path: NodePath) {
        self[path] = value.map(Node.integer)
    }

    /// Sets a true/false value. Nil removes the key.
    public mutating func setBool(_ value: Bool?, at path: NodePath) {
        self[path] = value.map(Node.boolean)
    }

    /// Sets a list of text values. Empty removes the key.
    public mutating func setStrings(_ values: [String], at path: NodePath) {
        self[path] = values.isEmpty ? nil : .sequence(.init(values.map(Node.text), Tag(.seq), Layout.sequenceStyle(at: path)))
    }

    /// Text values of the list at `path`.
    public func strings(_ path: NodePath) -> [String] {
        guard case let .sequence(sequence)? = self[path] else { return [] }
        return sequence.compactMap(\.string)
    }

    /// Appends a number to the list at `path`, creating the list if needed.
    public mutating func appendInt(_ value: Int, to path: NodePath) {
        append(.integer(value), to: path)
    }

    /// Appends an empty item (a map) to the list at `path` and returns its
    /// index, so its fields can be set.
    @discardableResult
    public mutating func appendItem(to path: NodePath) -> Int {
        append(.mapping(.init([], Tag(.map), Layout.mappingStyle(at: path + [.index(0)]))), to: path)
        return count(path) - 1
    }

    /// Appends to the list at `path`, creating the list if needed.
    mutating func append(_ value: Node, to path: NodePath) {
        var sequence = self[path]?.sequence ?? Node.Sequence([], Tag(.seq), Layout.sequenceStyle(at: path))
        sequence.append(value)
        self[path] = .sequence(sequence)
    }

    /// Removes the list item at `path` (whose last component is an index).
    public mutating func removeItem(at path: NodePath) {
        guard case let .index(index)? = path.last else { return }
        let listPath = Array(path.dropLast())
        guard var sequence = self[listPath]?.sequence, sequence.indices.contains(index) else { return }
        sequence.remove(at: index)
        self[listPath] = sequence.isEmpty ? nil : .sequence(sequence)
    }

    /// Moves the list item at `from` to `to` within the list at `path`.
    public mutating func moveItem(in path: NodePath, from: Int, to: Int) {
        guard var sequence = self[path]?.sequence, sequence.indices.contains(from) else { return }
        let item = sequence.remove(at: from)
        sequence.insert(item, at: min(max(to, 0), sequence.count))
        self[path] = .sequence(sequence)
    }

    /// Top-level keys the app doesn't know about. They're kept as they are.
    public var unknownTopLevelKeys: [String] {
        guard let mapping = header.mapping else { return [] }
        let known = Set(Layout.keyOrder(at: []))
        return mapping.keys.compactMap(\.string).filter { !known.contains($0) }
    }
}

// MARK: - Tree walking

extension Node {
    func value(at path: ArraySlice<PathComponent>) -> Node? {
        guard let first = path.first else { return self }
        switch (first, self) {
        case let (.key(key), .mapping(mapping)):
            return mapping[key]?.value(at: path.dropFirst())
        case let (.index(index), .sequence(sequence)):
            return sequence.indices.contains(index) ? sequence[index].value(at: path.dropFirst()) : nil
        default:
            return nil
        }
    }

    mutating func setValue(_ value: Node?, at path: ArraySlice<PathComponent>, prefix: NodePath) {
        guard let first = path.first else {
            if let value { self = value }
            return
        }
        let rest = path.dropFirst()
        let here = prefix + [first]

        switch first {
        case let .key(key):
            var mapping = self.mapping ?? Node.Mapping([], Tag(.map), Layout.mappingStyle(at: prefix))
            if rest.isEmpty {
                if let value {
                    mapping.setValue(value, forKey: key, order: Layout.keyOrder(at: prefix))
                } else {
                    mapping[key] = nil
                }
            } else {
                guard value != nil || mapping[key] != nil else { return }
                var child = mapping[key] ?? Self.emptyContainer(for: rest.first!, at: here)
                child.setValue(value, at: rest, prefix: here)
                if value == nil, child.isEmptyCollection {
                    mapping[key] = nil
                } else {
                    mapping.setValue(child, forKey: key, order: Layout.keyOrder(at: prefix))
                }
            }
            self = .mapping(mapping)

        case let .index(index):
            guard var sequence = self.sequence, sequence.indices.contains(index) else { return }
            if rest.isEmpty {
                if let value { sequence[index] = value } else { sequence.remove(at: index) }
            } else {
                sequence[index].setValue(value, at: rest, prefix: here)
            }
            self = .sequence(sequence)
        }
    }

    private static func emptyContainer(for next: PathComponent, at path: NodePath) -> Node {
        switch next {
        case .key: .mapping(.init([], Tag(.map), Layout.mappingStyle(at: path)))
        case .index: .sequence(.init([], Tag(.seq), Layout.sequenceStyle(at: path)))
        }
    }

    var isEmptyCollection: Bool {
        switch self {
        case let .mapping(mapping): mapping.isEmpty
        case let .sequence(sequence): sequence.isEmpty
        default: false
        }
    }
}

extension Node.Mapping {
    /// Replaces the value in place, or inserts a new key at its standard
    /// position: before the first existing key that comes after it in `order`.
    mutating func setValue(_ value: Node, forKey key: String, order: [String]) {
        if self[key] != nil {
            self[key] = value
            return
        }
        var pairs = map { ($0.key, $0.value) }
        let newRank = order.firstIndex(of: key)
        let position = newRank.flatMap { newRank in
            pairs.firstIndex { pair in
                guard let name = pair.0.string, let rank = order.firstIndex(of: name) else { return false }
                return rank > newRank
            }
        } ?? pairs.endIndex
        pairs.insert((.text(key), value), at: position)
        self = Node.Mapping(pairs, tag, style, mark)
    }
}
