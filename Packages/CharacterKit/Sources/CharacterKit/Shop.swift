import Foundation

/// Something on the ruleset's equipment lists that can be bought.
public struct ShopItem: Identifiable, Equatable, Sendable {
    public enum Category: String, CaseIterable, Sendable {
        case weapons = "Weapons"
        case armour = "Armour and shields"
        case ammunition = "Ammunition"
        case gear = "Adventuring gear"
    }

    public let id: String
    public let category: Category
    /// As listed, e.g. `Arrows (quiver of 20)`.
    public let name: String
    /// As written on a sheet, e.g. `Arrows`.
    public let itemName: String
    /// In gold pieces, for `quantity` items.
    public let cost: Int
    /// How many come for the cost; nil for a single item.
    public let quantity: Int?
    /// A short description: damage and qualities, AC, or notes.
    public let details: String
    /// In coins, when the rules give one.
    public let weight: Int?
}

extension OSERuleset {
    /// Everything that can be bought, by category, then name.
    public var shopItems: [ShopItem] {
        var items: [ShopItem] = []
        for weapon in weapons where weapon.soldAs == nil {
            let qualities = weapon.qualities.filter { $0 != "melee" && $0 != "missile" }
            let kind = [weapon.isMelee ? "melee" : nil, weapon.isMissile ? "missile" : nil].compactMap { $0 }
            items.append(ShopItem(id: weapon.id, category: .weapons, name: weapon.name, itemName: weapon.name,
                                  cost: weapon.cost, quantity: nil,
                                  details: ([weapon.damage, kind.joined(separator: " and ")] + qualities)
                                      .joined(separator: ", "),
                                  weight: weapon.weight))
        }
        for armour in armour {
            let isShield = armour.acBonus != nil
            // "Leather" alone reads oddly on a sheet; "Chainmail" and "Plate mail" don't.
            let itemName = isShield || armour.name.lowercased().contains("mail") ? armour.name : armour.name + " armour"
            let details = armour.ac.map { "AC \($0) [\(19 - $0)]" } ?? armour.acBonus.map { "+\($0) AC" } ?? ""
            items.append(ShopItem(id: armour.id, category: .armour, name: armour.name, itemName: itemName,
                                  cost: armour.cost, quantity: nil,
                                  details: details + (armour.encumbrance.map { ", \($0)" } ?? ""),
                                  weight: armour.weight))
        }
        for ammo in ammunition {
            items.append(ShopItem(id: ammo.id, category: .ammunition, name: ammo.name,
                                  itemName: ammo.itemName ?? ammo.name, cost: ammo.cost, quantity: ammo.quantity,
                                  details: ammo.cost == 0 ? "Free" : "", weight: nil))
        }
        for gear in gear {
            let weapon = weapons.first { $0.soldAs == gear.id }
            let details = [weapon.map { "\($0.damage) thrown" }, gear.notes].compactMap { $0 }.joined(separator: ". ")
            items.append(ShopItem(id: gear.id, category: .gear, name: gear.name, itemName: gear.itemName ?? gear.name,
                                  cost: gear.cost, quantity: gear.quantity, details: details, weight: nil))
        }
        let order = ShopItem.Category.allCases
        return items.sorted {
            ($0.category == $1.category)
                ? $0.name.localizedStandardCompare($1.name) == .orderedAscending
                : order.firstIndex(of: $0.category)! < order.firstIndex(of: $1.category)!
        }
    }

    /// Why a class wouldn't normally use an item, or nil if it can.
    public func restriction(of item: ShopItem, for classRules: ClassRules?) -> String? {
        guard let classRules else { return nil }
        switch item.category {
        case .weapons:
            if let allowed = classRules.weapons.allowed, !allowed.contains(item.id) {
                return "\(classRules.plural) normally use: \(classRules.weapons.text.lowercased())."
            }
            if classRules.weapons.forbidden?.contains(item.id) == true {
                return "\(classRules.plural) can't normally use this."
            }
        case .armour:
            if item.id == "shield" {
                if !classRules.armour.shields { return "\(classRules.plural) can't normally use a shield." }
            } else if !classRules.armour.allowed.contains(item.id) {
                return classRules.armour.allowed.isEmpty
                    ? "\(classRules.plural) can't wear armour."
                    : "\(classRules.plural) can't normally wear this."
            }
        case .ammunition, .gear:
            break
        }
        return nil
    }
}

/// The coins a character carries.
public struct Purse: Equatable, Sendable, CustomStringConvertible {
    public var pp = 0, gp = 0, ep = 0, sp = 0, cp = 0

    /// Coin values in copper, largest first.
    static let values: [(key: String, cp: Int)] = [("pp", 500), ("gp", 100), ("ep", 50), ("sp", 10), ("cp", 1)]

    public init(pp: Int = 0, gp: Int = 0, ep: Int = 0, sp: Int = 0, cp: Int = 0) {
        (self.pp, self.gp, self.ep, self.sp, self.cp) = (pp, gp, ep, sp, cp)
    }

    public init(_ file: CharacterFile) {
        self.init()
        for (key, _) in Self.values { self[key] = max(0, file.int(["money", .key(key)]) ?? 0) }
    }

    subscript(key: String) -> Int {
        get { [pp, gp, ep, sp, cp][Self.values.firstIndex { $0.key == key }!] }
        set {
            switch key {
            case "pp": pp = newValue
            case "gp": gp = newValue
            case "ep": ep = newValue
            case "sp": sp = newValue
            default: cp = newValue
            }
        }
    }

    /// Everything, in copper pieces.
    public var totalCP: Int { Self.values.reduce(0) { $0 + self[$1.key] * $1.cp } }

    /// The purse after paying `cost` copper pieces, or nil if it's not enough.
    /// Pays in gold, silver and copper first, then electrum and platinum,
    /// using as many of each as fit. Then it breaks the smallest coin that
    /// covers the rest and takes change in gold, silver and copper.
    public func paying(_ cost: Int) -> Purse? {
        guard cost <= totalCP else { return nil }
        var purse = self
        var owed = cost
        for key in ["gp", "sp", "cp", "ep", "pp"] {
            let value = Self.values.first { $0.key == key }!.cp
            let used = min(purse[key], owed / value)
            purse[key] -= used
            owed -= used * value
        }
        guard owed > 0 else { return purse }
        // Every coin left is worth more than what's owed: a coin type with
        // some left over would otherwise have paid more.
        guard let (key, value) = Self.values.reversed().first(where: { purse[$0.key] > 0 }) else { return nil }
        purse[key] -= 1
        var change = value - owed
        for (changeKey, changeValue) in Self.values where ["gp", "sp", "cp"].contains(changeKey) {
            purse[changeKey] += change / changeValue
            change %= changeValue
        }
        return purse
    }

    /// "37 gp, 12 sp", or "no money".
    public var description: String {
        let parts = Self.values.filter { self[$0.key] > 0 }.map { "\(self[$0.key].formatted()) \($0.key)" }
        return parts.isEmpty ? "no money" : parts.joined(separator: ", ")
    }
}

extension CharacterFile {
    /// Writes the coins back. Denominations already in the file are kept
    /// (even at 0); others are added only when there are some.
    public mutating func setPurse(_ purse: Purse) {
        for (key, _) in Purse.values {
            let path: NodePath = ["money", .key(key)]
            if int(path) != nil || purse[key] > 0 { setInt(purse[key], at: path) }
        }
    }

    /// Adds `count` of an item to the equipment list. An item already there
    /// by the same name gets more of it instead of a second line.
    public mutating func addEquipment(_ item: ShopItem, count: Int = 1) {
        let amount = (item.quantity ?? 1) * count
        let key = OSERuleset.matchKey(item.itemName)
        if let index = (0..<self.count(["equipment"])).first(where: {
            OSERuleset.matchKey(string(["equipment", .index($0), "name"]) ?? "") == key
        }) {
            let path: NodePath = ["equipment", .index(index), "qty"]
            setInt((int(path) ?? 1) + amount, at: path)
            return
        }
        let index = appendItem(to: ["equipment"])
        setString(item.itemName, at: ["equipment", .index(index), "name"])
        if item.quantity != nil || amount > 1 {
            setInt(amount, at: ["equipment", .index(index), "qty"])
        }
    }

    /// Buys `count` of an item: adds it, and if `pay` is set, takes the cost
    /// from the character's money. Returns false (and changes nothing) when
    /// the character can't afford it.
    @discardableResult
    public mutating func buy(_ item: ShopItem, count: Int = 1, pay: Bool) -> Bool {
        if pay {
            guard let purse = Purse(self).paying(item.cost * count * 100) else { return false }
            setPurse(purse)
        }
        addEquipment(item, count: count)
        return true
    }
}
