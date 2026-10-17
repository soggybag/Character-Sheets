import Foundation

/// One spell on the sheet: a spell book entry and the copies of it memorized
/// today. A memorized spell that isn't in the book (a cleric's prayer, a
/// hand-edited file) gets a row of its own.
///
/// The file keeps the two lists (`spells.spellbook` and `spells.memorized`,
/// one entry per memorized copy), matched by name ignoring case.
public struct SpellRow: Equatable, Sendable {
    public let name: String
    /// Index in `spells.spellbook`, or nil when the spell isn't in the book.
    public let bookIndex: Int?
    public let level: Int?
    /// Indices in `spells.memorized` of this spell's copies, in order.
    public let memorized: [Int]
}

extension CharacterFile {
    private static let book: NodePath = ["spells", "spellbook"]
    private static let memorizedList: NodePath = ["spells", "memorized"]

    private static func spellKey(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespaces).lowercased()
    }

    /// Spell book entries in book order, then memorized spells that aren't
    /// in the book, in the order first memorized.
    public var spellRows: [SpellRow] {
        var copies: [String: [Int]] = [:]
        var extraOrder: [String] = []
        for index in 0..<count(Self.memorizedList) {
            let key = Self.spellKey(string(Self.memorizedList + [.index(index), "name"]) ?? "")
            if copies[key] == nil { extraOrder.append(key) }
            copies[key, default: []].append(index)
        }
        var rows: [SpellRow] = []
        var claimed = Set<String>()
        for index in 0..<count(Self.book) {
            let path = Self.book + [.index(index)]
            let name = string(path + ["name"]) ?? ""
            let key = Self.spellKey(name)
            // A blank or repeated book entry gets no copies of its own.
            let memorized = key.isEmpty || claimed.contains(key) ? [] : copies[key] ?? []
            if !key.isEmpty { claimed.insert(key) }
            rows.append(SpellRow(name: name, bookIndex: index, level: int(path + ["level"]), memorized: memorized))
        }
        for key in extraOrder where !claimed.contains(key) {
            let indices = copies[key] ?? []
            let first = Self.memorizedList + [.index(indices[0])]
            rows.append(SpellRow(name: string(first + ["name"]) ?? "", bookIndex: nil,
                                 level: int(first + ["level"]), memorized: indices))
        }
        return rows
    }

    /// How many spells of a level (1 = 1st) are memorized.
    public func memorizedCount(level: Int) -> Int {
        spellRows.filter { $0.level == level }.reduce(0) { $0 + $1.memorized.count }
    }

    /// Memorizes one more copy of a spell.
    public mutating func memorize(_ row: SpellRow) {
        guard !Self.spellKey(row.name).isEmpty else { return }
        let index = appendItem(to: Self.memorizedList)
        setString(row.name, at: Self.memorizedList + [.index(index), "name"])
        if row.bookIndex == nil, let level = row.level {
            setInt(level, at: Self.memorizedList + [.index(index), "level"])
        }
    }

    /// Forgets one memorized copy of a spell, an uncast one if there is one.
    public mutating func forgetOne(_ row: SpellRow) {
        let uncast = row.memorized.last { bool(Self.memorizedList + [.index($0), "cast"]) != true }
        guard let index = uncast ?? row.memorized.last else { return }
        removeItem(at: Self.memorizedList + [.index(index)])
    }

    /// Renames a spell in the book and every memorized copy. A blank name is
    /// ignored, so the copies aren't orphaned.
    public mutating func renameSpell(_ row: SpellRow, to name: String) {
        let name = name.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, name != row.name else { return }
        if let book = row.bookIndex {
            setString(name, at: Self.book + [.index(book), "name"])
        }
        for index in row.memorized {
            setString(name, at: Self.memorizedList + [.index(index), "name"])
        }
    }

    /// Sets a spell's level. A memorized spell that isn't in the book is
    /// added to it.
    public mutating func setSpellLevel(_ row: SpellRow, to level: Int?) {
        if let book = row.bookIndex {
            setInt(level, at: Self.book + [.index(book), "level"])
            return
        }
        guard let level else { return }
        let book = appendItem(to: Self.book)
        setString(row.name, at: Self.book + [.index(book), "name"])
        setInt(level, at: Self.book + [.index(book), "level"])
        for index in row.memorized {
            setInt(nil, at: Self.memorizedList + [.index(index), "level"])
        }
    }

    /// Removes a spell from the book along with its memorized copies.
    public mutating func removeSpell(_ row: SpellRow) {
        for index in row.memorized.sorted(by: >) {
            removeItem(at: Self.memorizedList + [.index(index)])
        }
        if let book = row.bookIndex {
            removeItem(at: Self.book + [.index(book)])
        }
    }

    /// Adds a blank 1st-level spell to the book.
    public mutating func addSpell() {
        let index = appendItem(to: Self.book)
        setInt(1, at: Self.book + [.index(index), "level"])
    }

    /// Whether a memorized copy has been cast today.
    public func isCast(memorized index: Int) -> Bool {
        bool(Self.memorizedList + [.index(index), "cast"]) ?? false
    }

    /// Marks a memorized copy cast, or not. Not cast removes the key.
    public mutating func setCast(_ cast: Bool, memorized index: Int) {
        setBool(cast ? true : nil, at: Self.memorizedList + [.index(index), "cast"])
    }
}
