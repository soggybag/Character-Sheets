import Foundation
import Yams

/// A custom equipment list: a group's changes to the rules' equipment
/// (prices, items not sold, house items). See docs/EQUIPMENT-FORMAT.md.
///
/// Reading never fails over a bad entry: it's skipped and described in
/// `problems`, and the rest of the list still applies.
public struct EquipmentList: Sendable {
    /// Shown in the shop and in Settings. Nil means use the file name.
    public var name: String?
    /// Rules items the market doesn't sell, as written in the file.
    public var removals: [String] = []
    public var changes: [Change] = []
    public var additions: [HouseItem] = []
    /// Rules prices as a percentage (150 for a boomtown). Items with their
    /// own `change` price, and house items, aren't scaled.
    public var priceScale = 100
    /// Entries that were skipped or partly read, in file order.
    public var problems: [String] = []
    /// The Markdown body: the group's notes. Not interpreted.
    public var body = ""

    /// New details for a rules item. Nil fields are unchanged.
    public struct Change: Equatable, Sendable {
        /// The rules item, as written in the file.
        public var item: String
        /// In copper pieces.
        public var price: Int?
        public var quantity: Int?
        public var weight: Int?
        public var notes: String?
    }

    /// An item the rules don't have.
    public struct HouseItem: Equatable, Sendable {
        public var name: String
        public var category: ShopItem.Category
        /// In copper pieces.
        public var price: Int
        public var quantity: Int?
        public var weight: Int?
        public var notes: String?
        // Weapons
        public var damage: String?
        public var qualities: [String] = []
        public var range: WeaponData.Range?
        // Armour
        public var ac: Int?
        public var acBonus: Int?
        public var encumbrance: String?
        /// Classes that can normally use it. Empty: no class warning.
        public var usableBy: [String] = []
    }
}

public enum EquipmentListError: Error, Equatable, CustomStringConvertible {
    /// The header doesn't have `formatVersion` and `kind: equipment`.
    case notAnEquipmentList
    /// The header couldn't be read at all.
    case unreadable(CharacterFileError)

    public var description: String {
        switch self {
        case .notAnEquipmentList: "Not an equipment list. The header needs formatVersion and kind: equipment."
        case let .unreadable(error): error.description
        }
    }
}

// MARK: - Reading

extension EquipmentList {
    /// Recognised weapon qualities (see the rules' `weaponQualities`).
    static let qualities: Set<String> = ["blunt", "brace", "charge", "melee", "missile", "reload", "slow",
                                         "splash", "two-handed"]

    /// A short starting file: one commented-out example of each section.
    public static func template(name: String) -> String {
        """
        ---
        formatVersion: 1
        kind: equipment
        system: ose
        name: \(YAMLWriter().scalarText(.text(name), inFlow: false))
        # Remove the # from a line to use it. Costs are gold pieces (15),
        # or coins in quotes ("5 sp"). See Help for every field.

        # Every rules price, scaled:
        # prices: 150%

        # Rules items this market doesn't sell:
        remove:
        # - Garlic

        # New prices and details for rules items:
        change:
        # - { item: Sword, cost: 15 }
        # - { item: Arrows, cost: "3 gp 5 sp", notes: Fletched locally. }

        # House items:
        add:
        # - { name: Mule, category: gear, cost: 30, notes: "Carries 2,000 coins." }
        # - { name: Hand crossbow, category: weapons, cost: 40, damage: 1d4, qualities: [missile, reload] }
        ---

        # \(name)

        Notes for the group: where the market is, who runs it, haggling.

        """
    }

    /// One line: what the list changes. "Changes 4 prices, adds 5 items".
    public var summary: String {
        var parts: [String] = []
        if priceScale != 100 { parts.append("rules prices at \(priceScale)%") }
        if !removals.isEmpty { parts.append("removes \(removals.count)") }
        if !changes.isEmpty { parts.append("changes \(changes.count)") }
        if !additions.isEmpty { parts.append("adds \(additions.count)") }
        guard let first = parts.first else { return "No changes yet" }
        return ([first.prefix(1).uppercased() + first.dropFirst()] + parts.dropFirst()).joined(separator: ", ")
    }

    /// The house item an equipment line refers to, if any.
    public func houseItem(named name: String) -> HouseItem? {
        let key = OSERuleset.matchKey(name)
        guard !key.isEmpty else { return nil }
        return additions.first { OSERuleset.matchKey($0.name) == key }
    }

    /// Whether the text is an equipment list, without reading the entries.
    public static func isEquipmentList(_ text: String) -> Bool {
        guard let file = try? CharacterFile(text: text) else { return false }
        return file.formatVersion != nil && file.header["kind"]?.string == "equipment"
    }

    public init(text: String) throws {
        let file: CharacterFile
        do {
            file = try CharacterFile(text: text)
        } catch let error as CharacterFileError {
            throw EquipmentListError.unreadable(error)
        }
        guard file.formatVersion != nil, file.header["kind"]?.string == "equipment" else {
            throw EquipmentListError.notAnEquipmentList
        }
        let header = file.header
        body = file.body
        name = header["name"]?.string.flatMap { $0.trimmingCharacters(in: .whitespaces).isEmpty ? nil : $0 }

        if let system = header["system"]?.string, system != "ose" {
            problems.append("This list is for the “\(system)” rules; only OSE is supported.")
        }
        if let prices = header["prices"] {
            if let scale = Self.percentage(prices) {
                priceScale = scale
            } else {
                problems.append("prices: “\(prices.string ?? "")” isn't a percentage. Write it like 150%.")
            }
        }

        for (index, node) in Self.entries(header["remove"], key: "remove", problems: &problems).enumerated() {
            guard let item = node.string, !item.isEmpty, node.scalar != nil else {
                problems.append("remove, entry \(index + 1): give the item's name.")
                continue
            }
            removals.append(item)
        }
        for (index, node) in Self.entries(header["change"], key: "change", problems: &problems).enumerated() {
            if let change = readChange(node, number: index + 1) { changes.append(change) }
        }
        for (index, node) in Self.entries(header["add"], key: "add", problems: &problems).enumerated() {
            if let item = readHouseItem(node, number: index + 1) { additions.append(item) }
        }
    }

    /// The items of a list, or nothing (with a problem) if it isn't one.
    private static func entries(_ node: Node?, key: String, problems: inout [String]) -> [Node] {
        // `change:` with nothing after it (the starting file) is no changes.
        guard let node, !["", "~", "null"].contains(node.scalar?.string.lowercased() ?? "-") else { return [] }
        guard case let .sequence(sequence) = node else {
            problems.append("\(key) should be a list (one entry per line starting with -).")
            return []
        }
        return Array(sequence)
    }

    private mutating func readChange(_ node: Node, number: Int) -> Change? {
        guard node.mapping != nil else {
            problems.append("change, entry \(number): write it as { item: Sword, cost: 15 }.")
            return nil
        }
        guard let item = node["item"]?.string, !item.isEmpty else {
            problems.append("change, entry \(number): give the rules item's name as item.")
            return nil
        }
        var change = Change(item: item)
        change.price = price(node["cost"], of: item)
        change.quantity = wholeNumber(node["quantity"], "quantity", of: item)
        change.weight = wholeNumber(node["weight"], "weight", of: item)
        change.notes = node["notes"]?.string
        return change
    }

    private mutating func readHouseItem(_ node: Node, number: Int) -> HouseItem? {
        guard node.mapping != nil else {
            problems.append("add, entry \(number): write it as { name: Mule, category: gear, cost: 30 }.")
            return nil
        }
        guard let name = node["name"]?.string, !name.isEmpty else {
            problems.append("add, entry \(number): give the item a name.")
            return nil
        }
        guard let categoryText = node["category"]?.string else {
            problems.append("\(name): give a category (weapons, armour, ammunition or gear). Skipped.")
            return nil
        }
        guard let category = Self.category(categoryText) else {
            problems.append("\(name): “\(categoryText)” isn't a category. Use weapons, armour, ammunition or gear. Skipped.")
            return nil
        }
        guard node["cost"] != nil else {
            problems.append("\(name): give a cost. Skipped.")
            return nil
        }
        guard let price = price(node["cost"], of: name) else { return nil }

        var item = HouseItem(name: name, category: category, price: price)
        item.quantity = wholeNumber(node["quantity"], "quantity", of: name)
        item.weight = wholeNumber(node["weight"], "weight", of: name)
        item.notes = node["notes"]?.string
        item.damage = node["damage"]?.string
        item.ac = wholeNumber(node["ac"], "ac", of: name)
        item.acBonus = wholeNumber(node["acBonus"], "acBonus", of: name)
        item.encumbrance = node["encumbrance"]?.string
        if let encumbrance = item.encumbrance, !["light", "heavy"].contains(encumbrance) {
            problems.append("\(name): encumbrance is light or heavy, not “\(encumbrance)”.")
            item.encumbrance = nil
        }
        for quality in strings(node["qualities"], "qualities", of: name) {
            if Self.qualities.contains(quality.lowercased()) {
                item.qualities.append(quality.lowercased())
            } else {
                problems.append("\(name): “\(quality)” isn't a weapon quality.")
            }
        }
        if let range = node["range"] {
            if let short = range["short"]?.int, let medium = range["medium"]?.int, let long = range["long"]?.int {
                item.range = WeaponData.Range(short: short, medium: medium, long: long)
            } else {
                problems.append("\(name): write range as { short: 30, medium: 60, long: 90 }.")
            }
        }
        item.usableBy = strings(node["usableBy"], "usableBy", of: name)
        return item
    }

    private mutating func wholeNumber(_ node: Node?, _ key: String, of item: String) -> Int? {
        guard let node else { return nil }
        guard let value = node.int else {
            problems.append("\(item): \(key) should be a whole number, not “\(node.string ?? "")”.")
            return nil
        }
        return value
    }

    private mutating func strings(_ node: Node?, _ key: String, of item: String) -> [String] {
        switch node {
        case nil:
            return []
        case let .sequence(sequence)?:
            return sequence.compactMap(\.string)
        case let .scalar(scalar)?:
            return [scalar.string]
        default:
            problems.append("\(item): \(key) should be a list, like [Fighter, Thief].")
            return []
        }
    }

    private mutating func price(_ node: Node?, of item: String) -> Int? {
        guard let node else { return nil }
        guard let price = Self.price(node) else {
            problems.append("\(item): “\(node.string ?? "")” isn't a cost. Write gold pieces (15) or coins (\"5 sp\").")
            return nil
        }
        return price
    }

    /// A cost in copper: `15` and `2.5` are gold pieces; `"5 sp"` and
    /// `"2 gp 5 sp"` name the coins.
    static func price(_ node: Node) -> Int? {
        guard let text = node.string?.trimmingCharacters(in: .whitespaces), node.scalar != nil else { return nil }
        if let gold = Double(text), gold >= 0 {
            return Int((gold * 100).rounded())
        }
        let values = Dictionary(uniqueKeysWithValues: Purse.values.map { ($0.key, $0.cp) })
        let parts = text.lowercased().split(whereSeparator: { $0 == " " || $0 == "," }).map(String.init)
        var total = 0
        var index = 0
        while index < parts.count {
            // "5 sp" or "5sp"
            var number = parts[index]
            var coin = index + 1 < parts.count ? parts[index + 1] : ""
            if let split = number.firstIndex(where: \.isLetter) {
                coin = String(number[split...])
                number = String(number[..<split])
                index += 1
            } else {
                index += 2
            }
            guard let count = Int(number), count >= 0, let value = values[coin] else { return nil }
            total += count * value
        }
        return parts.isEmpty ? nil : total
    }

    /// `150%`, or a plain `150`.
    static func percentage(_ node: Node) -> Int? {
        guard var text = node.string?.trimmingCharacters(in: .whitespaces) else { return nil }
        if text.hasSuffix("%") { text.removeLast() }
        guard let value = Double(text.trimmingCharacters(in: .whitespaces)), value > 0 else { return nil }
        return Int(value.rounded())
    }

    static func category(_ text: String) -> ShopItem.Category? {
        switch OSERuleset.matchKey(text) {
        case "weapon", "weapons": .weapons
        case "armour", "armor", "shield", "shields": .armour
        case "ammunition", "ammo": .ammunition
        case "gear", "adventuringgear", "item", "items": .gear
        default: nil
        }
    }
}

// MARK: - Checking against the rules

extension EquipmentList {
    /// The rules item a name in the file refers to: by its name in the
    /// shop, as written on a sheet, or by id, ignoring case and punctuation.
    public static func rulesItem(named name: String, in items: [ShopItem]) -> ShopItem? {
        let key = OSERuleset.matchKey(name)
        guard !key.isEmpty else { return nil }
        return items.first {
            OSERuleset.matchKey($0.name) == key || OSERuleset.matchKey($0.itemName) == key
                || OSERuleset.matchKey($0.id) == key
        }
    }

    /// Problems that need the rules to find: items the rules don't have,
    /// and classes that don't exist. Reading problems come first.
    public func allProblems(rules: OSERuleset = .classic) -> [String] {
        let items = rules.shopItems
        var problems = problems
        for name in removals where Self.rulesItem(named: name, in: items) == nil {
            problems.append("remove: the rules have no “\(name)”.")
        }
        for change in changes where Self.rulesItem(named: change.item, in: items) == nil {
            problems.append("change: the rules have no “\(change.item)”. To sell it, add it as a house item.")
        }
        for item in additions {
            for name in item.usableBy where rules.classRules(named: name) == nil {
                problems.append("\(item.name): usableBy has “\(name)”, which isn't a class.")
            }
        }
        return problems
    }
}
