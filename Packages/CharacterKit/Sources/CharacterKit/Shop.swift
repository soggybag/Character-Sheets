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
    /// In copper pieces, for `quantity` items.
    public var price: Int
    /// How many come for the price; nil for a single item.
    public var quantity: Int?
    /// A short description: damage and qualities, AC, or notes.
    public var details: String
    /// In coins, when the rules give one.
    public var weight: Int?
    public var origin: Origin = .rules
    /// House items only: classes that can normally use it. Empty: anyone.
    public var usableBy: [String] = []

    /// Where an item's price and details come from.
    public enum Origin: Equatable, Sendable {
        case rules
        /// A rules item a custom list changes; `rulesPrice` is in copper.
        case changed(rulesPrice: Int)
        /// An item only the custom list has.
        case house
    }

    public init(id: String, category: Category, name: String, itemName: String, price: Int, quantity: Int?,
                details: String, weight: Int?) {
        self.id = id
        self.category = category
        self.name = name
        self.itemName = itemName
        self.price = price
        self.quantity = quantity
        self.details = details
        self.weight = weight
    }
}

extension OSERuleset {
    /// Everything that can be bought, by category, then name.
    public var shopItems: [ShopItem] {
        var items: [ShopItem] = []
        for weapon in weapons where weapon.soldAs == nil {
            let qualities = weapon.qualities.filter { $0 != "melee" && $0 != "missile" }
            let kind = [weapon.isMelee ? "melee" : nil, weapon.isMissile ? "missile" : nil].compactMap { $0 }
            items.append(ShopItem(id: weapon.id, category: .weapons, name: weapon.name, itemName: weapon.name,
                                  price: weapon.cost * 100, quantity: nil,
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
                                  price: armour.cost * 100, quantity: nil,
                                  details: details + (armour.encumbrance.map { ", \($0)" } ?? ""),
                                  weight: armour.weight))
        }
        for ammo in ammunition {
            items.append(ShopItem(id: ammo.id, category: .ammunition, name: ammo.name,
                                  itemName: ammo.itemName ?? ammo.name, price: ammo.cost * 100, quantity: ammo.quantity,
                                  details: ammo.cost == 0 ? "Free" : "", weight: nil))
        }
        for gear in gear {
            let weapon = weapons.first { $0.soldAs == gear.id }
            let details = [weapon.map { "\($0.damage) thrown" }, gear.notes].compactMap { $0 }.joined(separator: ". ")
            items.append(ShopItem(id: gear.id, category: .gear, name: gear.name, itemName: gear.itemName ?? gear.name,
                                  price: gear.cost * 100, quantity: gear.quantity, details: details, weight: nil))
        }
        return Self.sorted(items)
    }

    /// The rules items with a custom list's changes, or the rules items
    /// alone when there's no list.
    public func shopItems(with list: EquipmentList?) -> [ShopItem] {
        guard let list else { return shopItems }
        let rulesItems = shopItems
        let houseKeys = Set(list.additions.map { Self.matchKey($0.name) })
        let removed = Set(list.removals.compactMap { EquipmentList.rulesItem(named: $0, in: rulesItems)?.id })
        var items: [ShopItem] = []
        for var item in rulesItems where !removed.contains(item.id) {
            // A house item by the same name replaces it.
            guard !houseKeys.contains(Self.matchKey(item.name)), !houseKeys.contains(Self.matchKey(item.itemName))
            else { continue }
            let rulesPrice = item.price
            let change = list.changes.last { EquipmentList.rulesItem(named: $0.item, in: [item]) != nil }
            item.price = change?.price ?? (rulesPrice * list.priceScale + 50) / 100
            if let quantity = change?.quantity { item.quantity = quantity }
            if let weight = change?.weight { item.weight = weight }
            if let notes = change?.notes {
                // Notes replace the rules' notes; weapon and armour stats stay.
                let ruleNotes = gear.first { $0.id == item.id }?.notes
                let stats = ruleNotes.map { item.details.replacingOccurrences(of: $0, with: "") } ?? item.details
                let trimmed = stats.trimmingCharacters(in: CharacterSet(charactersIn: ". "))
                item.details = trimmed.isEmpty ? notes : "\(trimmed). \(notes)"
            }
            if item.price != rulesPrice || change?.quantity != nil { item.origin = .changed(rulesPrice: rulesPrice) }
            items.append(item)
        }
        for house in list.additions {
            var item = ShopItem(id: "house:" + Self.matchKey(house.name), category: house.category, name: house.name,
                                itemName: house.name, price: house.price, quantity: house.quantity,
                                details: Self.details(of: house), weight: house.weight)
            item.origin = .house
            item.usableBy = house.usableBy
            items.removeAll { $0.id == item.id }
            items.append(item)
        }
        return Self.sorted(items)
    }

    private static func details(of house: EquipmentList.HouseItem) -> String {
        var parts: [String] = []
        switch house.category {
        case .weapons:
            let qualities = house.qualities.filter { $0 != "melee" && $0 != "missile" }
            let kind = ["melee", "missile"].filter(house.qualities.contains).joined(separator: " and ")
            parts = ([house.damage, kind.isEmpty ? nil : kind].compactMap { $0 } + qualities)
        case .armour:
            parts = [house.ac.map { "AC \($0) [\(19 - $0)]" } ?? house.acBonus.map { "+\($0) AC" }, house.encumbrance]
                .compactMap { $0 }
        case .ammunition, .gear:
            break
        }
        let stats = parts.joined(separator: ", ")
        return [stats.isEmpty ? nil : stats, house.notes].compactMap { $0 }.joined(separator: ". ")
    }

    private static func sorted(_ items: [ShopItem]) -> [ShopItem] {
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
        if item.origin == .house {
            return Self.houseRestriction(usableBy: item.usableBy, name: item.name, for: classRules, in: self)
        }
        switch item.category {
        case .weapons:
            return Self.weaponRestriction(id: item.id, name: item.name, for: classRules)
        case .armour:
            return Self.armourRestriction(id: item.id, name: item.name, isShield: item.id == "shield", for: classRules)
        case .ammunition, .gear:
            return nil
        }
    }

    // MARK: Class restrictions
    // One wording for the shop and the sheet's rules notes.

    /// Why a class wouldn't normally use a rules weapon, or nil.
    static func weaponRestriction(id: String, name: String, for classRules: ClassRules) -> String? {
        if let allowed = classRules.weapons.allowed, !allowed.contains(id) {
            return "\(classRules.plural) normally use \(classRules.weapons.text.lowercased()), not \(withArticle(name))."
        }
        if classRules.weapons.forbidden?.contains(id) == true {
            return "\(classRules.plural) can't normally use \(withArticle(name))."
        }
        return nil
    }

    /// Why a class wouldn't normally wear rules armour or use a shield, or nil.
    static func armourRestriction(id: String, name: String, isShield: Bool, for classRules: ClassRules) -> String? {
        if isShield {
            return classRules.armour.shields ? nil : "\(classRules.plural) can't normally use a shield."
        }
        guard !classRules.armour.allowed.contains(id) else { return nil }
        return classRules.armour.allowed.isEmpty
            ? "\(classRules.plural) can't wear armour."
            : "\(classRules.plural) can't normally wear \(name.lowercased())."
    }

    /// Why a class wouldn't normally use a house item: it isn't in the
    /// item's `usableBy`. No `usableBy` means no restriction.
    static func houseRestriction(usableBy: [String], name: String, for classRules: ClassRules,
                                 in rules: OSERuleset) -> String? {
        guard !usableBy.isEmpty,
              !usableBy.contains(where: { rules.classRules(named: $0)?.id == classRules.id }) else { return nil }
        return "\(classRules.plural) don't normally use \(withArticle(name))."
    }

    /// "a sword", "an axe".
    private static func withArticle(_ name: String) -> String {
        let lower = name.lowercased()
        return (lower.first.map { "aeiou".contains($0) } == true ? "an " : "a ") + lower
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

    /// An amount in copper as coins: gold, silver and copper.
    public init(copper: Int) {
        self.init(gp: copper / 100, sp: copper % 100 / 10, cp: copper % 10)
    }

    /// A price for showing: "2 gp, 5 sp", or "free".
    public static func priceText(_ copper: Int) -> String {
        copper == 0 ? "free" : Purse(copper: copper).description
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
            guard let purse = Purse(self).paying(item.price * count) else { return false }
            setPurse(purse)
        }
        addEquipment(item, count: count)
        return true
    }
}
