import Foundation

/// Turns the form fields of a filled-in PDF character sheet into a character
/// file. See docs/PDF-IMPORT.md for the sheets and the mapping.
///
/// Import never fails on odd values: whatever maps is imported, and fields
/// that had a value but weren't used are listed in `skipped`.
public struct SheetImport: Sendable {
    public enum Layout: String, Sendable {
        /// Character Record Sheet with THAC0 boxes.
        case descending
        /// Character Record Sheet with field names ending in " 2".
        case ascending
        /// The one-page illustrated sheet.
        case illustrated
        /// Not one we know, but it had some fields we recognised.
        case unknown
    }

    public let layout: Layout
    public let file: CharacterFile
    /// Names of fields that had a value but weren't imported.
    public let skipped: [String]

    public init(fields: [String: String], rules: OSERuleset = .classic) throws {
        var reader = FieldReader(fields)
        guard reader.hasValues else { throw SheetImportError.noFormFields }
        layout = reader.layout
        file = try Self.build(&reader, rules: rules)
        skipped = reader.unusedNames
    }

    private static func build(_ fields: inout FieldReader, rules: OSERuleset) throws -> CharacterFile {
        // Ascending sheets have an attack bonus box; descending ones have THAC0.
        let ascending = fields.has("Attack Bonus") && !fields.has("THAC0")
        var file = try CharacterFile(text: """
            ---
            formatVersion: 1
            rules:
              system: ose
              variant: classic
              options:
                ascendingAC: \(ascending)
                encumbrance: basic
            ---

            """)

        for (key, field) in [("name", "Name"), ("title", "Title"), ("class", "Character Class"), ("alignment", "Alignment")] {
            file.setString(fields.text(field), at: [.key(key)])
        }
        let level = fields.number("Level")
        file.setInt(level, at: ["level"])
        file.setInt(fields.number("XP") ?? 0, at: ["xp"])

        for ability in ["str", "int", "wis", "dex", "con", "cha"] {
            file.setInt(fields.number(ability.uppercased()), at: ["abilityScores", .key(ability)])
        }

        // HP may be "6/3" (max/current).
        let hpParts = (fields.text("Current HP") ?? fields.text("HP"))?
            .split(separator: "/").map { Self.firstNumber(in: String($0)) } ?? []
        let maxHP = fields.number("Max HP") ?? (hpParts.count > 1 ? hpParts[0] : nil)
        file.setInt(maxHP, at: ["hp", "max"])
        file.setInt(hpParts.last ?? nil, at: ["hp", "current"])

        file.setInt(fields.number("AC"), at: ["combat", "ac"])
        if ascending {
            file.setInt(fields.number("Attack Bonus"), at: ["combat", "attackBonus"])
        } else {
            file.setInt(fields.number("THAC0"), at: ["combat", "thac0"])
        }

        for (key, field) in [("death", "Death Save"), ("wands", "Wands Save"), ("paralysis", "Paralysis Save"),
                             ("breath", "Breath Save"), ("spells", "Spells Save")] {
            file.setInt(fields.number(field), at: ["saves", .key(key)])
        }
        file.setInt(fields.number("Exporation Movement", "Exploration Movement", "Movement", "Move"), at: ["movement"])
        for (key, field) in [("listen", "Listen at Door"), ("secretDoors", "Find Secret Door"),
                             ("openDoors", "Open Stuck Door"), ("findTraps", "Find Room Trap")] {
            file.setInt(fields.number(field), at: ["exploration", .key(key)])
        }

        // Languages: "Alignment" means the alignment language, which is listed by name.
        var languages: [String] = []
        for language in Self.items(in: fields.text("Languages") ?? "")
        where language.lowercased() != "alignment" && !languages.contains(language) {
            languages.append(language)
        }
        file.setStrings(languages, at: ["languages"])

        // Equipment. The "Abilities" boxes repeat the weapons and list class
        // features (which the rules supply); only their spells are used.
        let gear = Self.sections(in: fields.text("Weapons and Armour") ?? "")
        let abilities = Self.sections(in: fields.text("Abilities, Skills, Weapons", "Abilities") ?? "")
        for entry in Self.items(in: gear["weapons"] ?? abilities["weapons"] ?? "") {
            let item = Self.item(entry)
            add(item, equipped: !rules.isAmmunition(item.name), to: &file)
        }
        for entry in Self.items(in: gear["armour"] ?? "") {
            guard let name = Self.armourName(entry, rules: rules) else { continue }
            add((name, nil), equipped: true, to: &file)
        }
        for field in ["Equipment", "Magic Items", "Treasure"] {
            for entry in Self.items(in: fields.text(field) ?? "") {
                add(Self.item(entry), equipped: false, to: &file)
            }
        }

        for (key, field) in [("pp", "PP"), ("gp", "GP"), ("ep", "EP"), ("sp", "SP"), ("cp", "CP")] {
            file.setInt(fields.number(field), at: ["money", .key(key)])
        }

        // Spells are listed in the abilities box or on a "Spells:" line in the notes.
        var noteLines: [String] = []
        var spells = Self.items(in: abilities["spells"] ?? "")
        for line in (fields.text("Notes") ?? "").components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.lowercased().hasPrefix("spells:") {
                spells += Self.items(in: String(trimmed.dropFirst("spells:".count)))
            } else {
                noteLines.append(trimmed)
            }
        }
        for spell in spells {
            let book = file.appendItem(to: ["spells", "spellbook"])
            file.setString(spell, at: ["spells", "spellbook", .index(book), "name"])
            // At 1st level every spell is 1st level; otherwise the sheet doesn't say.
            if level == 1 { file.setInt(1, at: ["spells", "spellbook", .index(book), "level"]) }
            let memorized = file.appendItem(to: ["spells", "memorized"])
            file.setString(spell, at: ["spells", "memorized", .index(memorized), "name"])
        }

        // Body: description as a bold-labelled list, then notes.
        var description = (fields.text("Description") ?? "").components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map(Self.descriptionLine)
        if let portrait = fields.text("Portrait"), !description.contains(where: { $0.contains(portrait) }) {
            description.append("- **Portrait:** \(portrait)")
        }
        let notes = noteLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        var body = ""
        if !description.isEmpty {
            body += "\n# Description\n\n" + description.joined(separator: "\n") + "\n"
        }
        body += "\n# Notes\n" + (notes.isEmpty ? "" : "\n" + notes + "\n")
        file.body = body

        guard fields.usedAny else { throw SheetImportError.nothingRecognised }
        // Read, but deliberately not imported: the rules recalculate these.
        fields.markIgnored()
        return file
    }

    private static func add(_ item: (name: String, qty: Int?), equipped: Bool, to file: inout CharacterFile) {
        let index = file.appendItem(to: ["equipment"])
        file.setString(item.name, at: ["equipment", .index(index), "name"])
        file.setInt(item.qty, at: ["equipment", .index(index), "qty"])
        if equipped { file.setBool(true, at: ["equipment", .index(index), "equipped"]) }
    }

    // MARK: - Parsing free text

    /// The first whole number in the text: `"3 [16]"` → 3, `"+2"` → 2, `"-1"` → -1.
    static func firstNumber(in text: String) -> Int? {
        text.firstMatch(of: /[-+−]?\d+/).flatMap { Int($0.output.replacing("−", with: "-")) }
    }

    /// Comma-separated entries, ignoring commas inside parentheses and
    /// line breaks anywhere ("Arrows\n(16)").
    static func items(in text: String) -> [String] {
        var items: [String] = []
        var current = ""
        var depth = 0
        for character in collapsed(text) {
            switch character {
            case "(": depth += 1
            case ")": depth = max(depth - 1, 0)
            case "," where depth == 0:
                items.append(current)
                current = ""
                continue
            default: break
            }
            current.append(character)
        }
        items.append(current)
        return items.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    /// A trailing plain-number `(N)` is a quantity: `Torches (6)` → Torches × 6.
    /// Other parentheses stay in the name.
    static func item(_ entry: String) -> (name: String, qty: Int?) {
        guard let match = entry.wholeMatch(of: /(.+?)\s*\((\d+)\)/), let qty = Int(match.output.2) else {
            return (entry, nil)
        }
        return (String(match.output.1), qty)
    }

    /// Splits "Weapons: … Armour: … Abilities: … Spells: …" into its parts,
    /// keyed `weapons`, `armour`, `abilities`, `spells`.
    static func sections(in text: String) -> [String: String] {
        let text = collapsed(text)
        let labels = text.matches(of: /(?i)\b(weapons|armou?r|abilities|spells)\s*:/)
        var sections: [String: String] = [:]
        for (index, label) in labels.enumerated() {
            let end = index + 1 < labels.count ? labels[index + 1].range.lowerBound : text.endIndex
            var key = label.output.1.lowercased()
            if key == "armor" { key = "armour" }
            sections[key] = text[label.range.upperBound..<end].trimmingCharacters(in: .whitespaces)
        }
        return sections
    }

    /// The armour an entry names. "Unarmoured" is none. An entry that is only
    /// numbers ("3 [16] 60 500": AC, cost, weight) is matched against the
    /// armour table.
    static func armourName(_ entry: String, rules: OSERuleset) -> String? {
        let key = entry.lowercased()
        if key.hasPrefix("unarmo") || key == "none" { return nil }
        guard entry.allSatisfy({ $0.isNumber || " []+-".contains($0) }) else { return entry }
        let numbers = entry.matches(of: /\d+/).compactMap { Int($0.output) }
        guard let ac = numbers.first else { return nil }
        let rest = Set(numbers.dropFirst())
        let matches = rules.armour.filter { $0.ac == ac || $0.ac.map { 19 - $0 } == ac }
        return (matches.first { rest.contains($0.weight) || rest.contains($0.cost) } ?? matches.first)?.name ?? entry
    }

    /// "Appearance: shadowy" → "- **Appearance:** shadowy".
    static func descriptionLine(_ line: String) -> String {
        guard let match = line.wholeMatch(of: /([A-Za-z][A-Za-z ]{0,30}):\s*(.*)/) else { return line }
        return "- **\(match.output.1):** \(match.output.2)"
    }

    /// Runs of whitespace (including line breaks) become one space.
    static func collapsed(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}

public enum SheetImportError: Error, LocalizedError, Equatable {
    case unreadable
    case noFormFields
    case nothingRecognised

    public var errorDescription: String? {
        switch self {
        case .unreadable: "The file couldn't be opened as a PDF."
        case .noFormFields: "This PDF has no filled-in form fields."
        case .nothingRecognised: "None of this PDF's form fields look like a character sheet."
        }
    }
}

// MARK: - Field access

/// Looks up form fields by name, accepting the ascending sheet's " 2"
/// suffix, and remembers which ones were used.
private struct FieldReader {
    private let values: [String: String]
    private var used: Set<String> = []

    init(_ fields: [String: String]) {
        values = fields.mapValues { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    var hasValues: Bool { values.values.contains { !$0.isEmpty } }

    var layout: SheetImport.Layout {
        if has("Current HP") || has("Portrait") { return .illustrated }
        if values["Name 2"] != nil || values["STR 2"] != nil { return .ascending }
        if has("THAC0") { return .descending }
        return .unknown
    }

    /// Whether the sheet has the field, filled in or not.
    func has(_ name: String) -> Bool {
        values[name] != nil || values[name + " 2"] != nil
    }

    /// The first non-empty value among the names.
    mutating func text(_ names: String...) -> String? {
        for name in names {
            for candidate in [name, name + " 2"] {
                guard let value = values[candidate], !value.isEmpty else { continue }
                used.insert(candidate)
                return value
            }
        }
        return nil
    }

    mutating func number(_ names: String...) -> Int? {
        for name in names {
            if let value = text(name), let number = SheetImport.firstNumber(in: value) { return number }
        }
        return nil
    }

    /// Values the rules recalculate, so they're dropped without comment.
    mutating func markIgnored() {
        let derived = ["str melee mod", "dex missile mod", "dex ac mod", "con hp mod", "magic save mod",
                       "reactions cha mod", "unarmoured ac", "encounter movement", "overland movement", "xp for next level", "pr xp bonus", "literacy"]
        for name in values.keys {
            let key = name.lowercased().replacing(/\s2$/, with: "")
            if derived.contains(key) || key.wholeMatch(of: /thac[1-9]/) != nil || key.contains("encumbrance") {
                used.insert(name)
            }
        }
    }

    var usedAny: Bool { !used.isEmpty }

    var unusedNames: [String] {
        values.filter { !$0.value.isEmpty && !used.contains($0.key) }.keys.sorted()
    }
}
