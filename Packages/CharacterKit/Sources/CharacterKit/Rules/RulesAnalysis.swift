import Foundation

/// A value the rules give for a stored field.
public enum RulesValue: Equatable, Sendable, CustomStringConvertible {
    case int(Int)
    case ints([Int])

    public var description: String {
        switch self {
        case let .int(value): String(value)
        case let .ints(values): values.map(String.init).joined(separator: ", ")
        }
    }
}

/// How a stored field compares with the rules.
public enum FieldStatus: Equatable, Sendable {
    /// The rules have nothing to say about this field.
    case noRule
    /// Stored value matches the rules: it's automatic.
    case matches
    /// Stored value differs: a house rule, magic item or ruling. Kept as is.
    case overridden(rules: RulesValue)
    /// Nothing stored; the sheet shows the rules value.
    case missing(rules: RulesValue)
}

public struct RuleNote: Equatable, Sendable, Identifiable {
    public enum Kind: Sendable { case info, warning }
    public let kind: Kind
    public let message: String
    /// The field the note is about, if any.
    public let path: NodePath?
    public var id: String { message + "|" + (path?.dotted ?? "") }
}

/// One ability score and what it affects.
public struct AbilityEffects: Sendable {
    public let score: Int
    /// The main modifier to show beside the score, e.g. "+1".
    public let headline: String
    /// Everything the score affects, e.g. ("Melee", "+1").
    public let effects: [(label: String, value: String)]
}

/// To-hit and damage for one way of using a weapon.
public struct Attack: Equatable, Sendable {
    /// Descending: roll needed to hit AC 0.
    public let thac0: Int
    /// Ascending: bonus added to the d20 roll. Always `19 - thac0`.
    public var bonus: Int { 19 - thac0 }
    public let damage: String

    /// The book's notation, e.g. "18 [+1]".
    public var notation: String { "\(thac0) [\(signed(bonus))]" }
}

public struct WeaponLine: Sendable {
    /// Index of the item in `equipment`.
    public let itemIndex: Int
    public let name: String
    public let melee: Attack?
    public let missile: Attack?
    public let range: WeaponData.Range?
}

public struct XPInfo: Equatable, Sendable {
    /// Prime requisite bonus (or penalty), in percent.
    public let bonusPercent: Int
    /// XP needed for the next level; nil at the class's maximum.
    public let nextLevel: Int?
    public let readyToLevelUp: Bool
}

/// What the rules say about a character: suggestions for stored fields,
/// modifiers and other values to show, and notes. Never changes the file.
public struct RulesAnalysis: Sendable {
    public let classRules: ClassRules?
    public let level: Int?
    public let abilities: [String: AbilityEffects]
    public let suggestions: [NodePath: RulesValue]
    public let xp: XPInfo?
    public let weapons: [WeaponLine]
    public let notes: [RuleNote]
    /// Hit dice at this level, e.g. "2d6".
    public let hitDice: String?
    /// The die rolled for hit points each level, with the CON modifier, e.g. "1d4+2".
    public let hitPointRoll: String?

    public init(_ file: CharacterFile, rules: OSERuleset = .classic) {
        var builder = Builder(file: file, rules: rules)
        builder.run()
        classRules = builder.classRules
        level = builder.level
        abilities = builder.abilities
        suggestions = builder.suggestions
        xp = builder.xp
        weapons = builder.weapons
        notes = builder.notes
        hitDice = builder.row?.hd
        hitPointRoll = builder.hitPointRoll
    }

    /// How the stored value at `path` compares with the rules.
    public func status(of path: NodePath, in file: CharacterFile) -> FieldStatus {
        guard let rules = suggestions[path] else { return .noRule }
        let stored: RulesValue? = switch rules {
        case .int: file.int(path).map(RulesValue.int)
        case .ints: file.count(path) > 0 ? .ints((0..<file.count(path)).map { file.int(path + [.index($0)]) ?? 0 }) : nil
        }
        guard let stored else { return .missing(rules: rules) }
        return stored == rules ? .matches : .overridden(rules: rules)
    }

    /// Calculated values by name, for future custom layouts, e.g.
    /// `str.melee`, `xp.next`, `weapons.0.melee`, `rules.saves.death`.
    public var namedValues: [String: String] {
        var values: [String: String] = [:]
        for (key, ability) in abilities {
            values["\(key).score"] = String(ability.score)
            values["\(key).mod"] = ability.headline
        }
        if let xp {
            values["xp.bonus"] = signed(xp.bonusPercent) + "%"
            values["xp.next"] = xp.nextLevel.map(String.init)
        }
        values["hitDice"] = hitDice
        values["hitPointRoll"] = hitPointRoll
        for (path, value) in suggestions {
            values["rules." + path.dotted] = value.description
        }
        for (index, weapon) in weapons.enumerated() {
            values["weapons.\(index).name"] = weapon.name
            values["weapons.\(index).melee"] = weapon.melee.map { "\($0.notation) \($0.damage)" }
            values["weapons.\(index).missile"] = weapon.missile.map { "\($0.notation) \($0.damage)" }
        }
        return values
    }
}

func signed(_ value: Int) -> String {
    value >= 0 ? "+\(value)" : "\(value)"
}

// MARK: - Working it out

private struct Builder {
    let file: CharacterFile
    let rules: OSERuleset

    var classRules: ClassRules?
    var level: Int?
    var row: ClassRules.LevelRow?
    var abilities: [String: AbilityEffects] = [:]
    var suggestions: [NodePath: RulesValue] = [:]
    var xp: XPInfo?
    var weapons: [WeaponLine] = []
    var notes: [RuleNote] = []
    var hitPointRoll: String?

    init(file: CharacterFile, rules: OSERuleset) {
        self.file = file
        self.rules = rules
    }

    private var className: String { file.string(["class"])?.trimmingCharacters(in: .whitespaces) ?? "" }
    private var ascending: Bool { file.usesAscendingAC }

    private func score(_ key: String) -> Int? { file.int(["abilityScores", .key(key)]) }

    private func band(_ key: String) -> Int? {
        score(key).map { AbilityTables.band($0, in: rules.abilities.ranges) }
    }

    /// A modifier from an ability table, 0 if the score is missing.
    private func mod(_ key: String, _ table: (AbilityTables) -> [Int]) -> Int {
        band(key).map { table(rules.abilities)[$0] } ?? 0
    }

    private mutating func note(_ kind: RuleNote.Kind, _ message: String, _ path: NodePath? = nil) {
        notes.append(RuleNote(kind: kind, message: message, path: path))
    }

    mutating func run() {
        classRules = rules.classRules(named: className)
        level = file.int(["level"])
        if let classRules, let level { row = classRules.row(level: min(level, classRules.maxLevel)) }

        abilityEffects()
        classNotes()
        combat()
        savesAndSkills()
        experience()
        weaponLines()
        otherNotes()
    }

    // MARK: Abilities

    private mutating func abilityEffects() {
        let t = rules.abilities
        func add(_ key: String, headline: (Int) -> String, effects: (Int) -> [(String, String)]) {
            guard let score = score(key), let band = band(key) else { return }
            abilities[key] = AbilityEffects(score: score, headline: headline(band),
                                            effects: effects(band).map { (label: $0.0, value: $0.1) })
        }
        add("str", headline: { signed(t.str.melee[$0]) }) {
            [("Melee to-hit and damage", signed(t.str.melee[$0])), ("Open doors", "\(t.str.openDoors[$0])-in-6")]
        }
        add("int", headline: { t.int.extraLanguages[$0] > 0 ? "+\(t.int.extraLanguages[$0]) lang" : "" }) {
            [("Extra languages", String(t.int.extraLanguages[$0])), ("Literacy", t.int.literacy[$0].capitalized)]
        }
        add("wis", headline: { signed(t.wis.magicSaves[$0]) }) {
            [("Saves against magic", signed(t.wis.magicSaves[$0]))]
        }
        add("dex", headline: { signed(t.dex.ac[$0]) }) {
            [("Armour class", signed(t.dex.ac[$0])), ("Missile to-hit", signed(t.dex.missile[$0])),
             ("Initiative (optional)", signed(t.dex.initiative[$0]))]
        }
        add("con", headline: { signed(t.con.hitPoints[$0]) }) {
            [("Hit points per Hit Die", signed(t.con.hitPoints[$0]))]
        }
        add("cha", headline: { signed(t.cha.reactions[$0]) }) {
            [("NPC reactions", signed(t.cha.reactions[$0])), ("Max retainers", String(t.cha.maxRetainers[$0])),
             ("Retainer loyalty", String(t.cha.retainerLoyalty[$0]))]
        }
    }

    // MARK: Class

    private mutating func classNotes() {
        guard let classRules else {
            if className.isEmpty {
                note(.info, "Choose a class to see what the rules suggest.", ["class"])
            } else {
                note(.info, "No Classic Fantasy rules for “\(className)”, so saves, attacks and class abilities aren't suggested.", ["class"])
            }
            return
        }
        for (key, minimum) in classRules.requirements.sorted(by: { $0.key < $1.key }) {
            if let score = score(key), score < minimum {
                note(.warning, "\(classRules.plural) need \(key.uppercased()) \(minimum) or more (it's \(score)).",
                     ["abilityScores", .key(key)])
            }
        }
        if let level, level > classRules.maxLevel {
            note(.warning, "\(classRules.plural) can't normally go past level \(classRules.maxLevel).", ["level"])
        }
    }

    // MARK: Combat

    /// Armour and shield from equipment. Items marked `equipped` count; if no
    /// item is marked at all, every armour item listed counts.
    private func wornArmour() -> (armour: ArmourData?, shield: Bool) {
        let count = file.count(["equipment"])
        let anyMarked = (0..<count).contains { file.bool(["equipment", .index($0), "equipped"]) != nil }
        var best: ArmourData?
        var shield = false
        for index in 0..<count {
            let path: NodePath = ["equipment", .index(index)]
            guard !anyMarked || file.bool(path + ["equipped"]) == true,
                  let name = file.string(path + ["name"]),
                  let armour = rules.armour(named: name) else { continue }
            if armour.acBonus != nil {
                shield = true
            } else if let ac = armour.ac, ac < (best?.ac ?? .max) {
                best = armour
            }
        }
        return (best, shield)
    }

    private mutating func combat() {
        let (armour, shield) = wornArmour()
        let descending = (armour?.ac ?? rules.info.combat.unarmouredAC) - (shield ? 1 : 0)
            - mod("dex") { $0.dex.ac }
        if score("dex") != nil {
            suggestions[["combat", "ac"]] = .int(ascending ? 19 - descending : descending)
        }

        if let row {
            if ascending {
                suggestions[["combat", "attackBonus"]] = .int(19 - row.thac0)
            } else {
                suggestions[["combat", "thac0"]] = .int(row.thac0)
            }
        }

        if let movement = movementRate(armour: armour) {
            suggestions[["movement"]] = .int(movement)
        }

        guard let classRules else { return }
        if let armour, !classRules.armour.allowed.contains(armour.id) {
            note(.warning, classRules.armour.allowed.isEmpty
                 ? "\(classRules.plural) can't normally wear armour."
                 : "\(classRules.plural) can't normally wear \(armour.name.lowercased()).", ["equipment"])
        }
        if shield, !classRules.armour.shields {
            note(.warning, "\(classRules.plural) can't normally use a shield.", ["equipment"])
        }
    }

    private func movementRate(armour: ArmourData?) -> Int? {
        switch file.string(["rules", "options", "encumbrance"]) ?? "basic" {
        case "none":
            return 120
        case "detailed":
            var weight = 0
            var hasGear = false
            for index in 0..<file.count(["equipment"]) {
                let path: NodePath = ["equipment", .index(index)]
                let name = file.string(path + ["name"]) ?? ""
                let quantity = file.int(path + ["qty"]) ?? 1
                if let stated = file.int(path + ["weight"]) {
                    weight += stated * quantity
                } else if let armour = rules.armour(named: name) {
                    weight += armour.weight
                } else if let weapon = rules.weapon(named: name) {
                    weight += (weapon.weight ?? 0) * quantity
                } else {
                    hasGear = true
                }
            }
            if hasGear { weight += rules.encumbrance.detailed.miscGear }
            weight += ["pp", "gp", "ep", "sp", "cp"].reduce(0) { $0 + (file.int(["money", .key($1)]) ?? 0) }
            return rules.encumbrance.detailed.movement.first { weight <= $0.upTo }?.rate ?? 0
        default:
            let kind = armour?.encumbrance ?? "none"
            return rules.encumbrance.basic.movement[kind]?.normal
        }
    }

    // MARK: Saves, exploration, skills, spells

    private mutating func savesAndSkills() {
        var exploration = rules.info.exploration.defaults
        exploration.merge(classRules?.exploration ?? [:]) { $1 }
        if let band = band("str") { exploration["openDoors"] = rules.abilities.str.openDoors[band] }
        if classRules != nil {
            for (key, value) in exploration { suggestions[["exploration", .key(key)]] = .int(value) }
        }

        guard let row else { return }
        for (key, value) in row.saves { suggestions[["saves", .key(key)]] = .int(value) }
        for (key, value) in row.thiefSkills ?? [:] { suggestions[["thiefSkills", .key(key)]] = .int(value) }
        if classRules?.spellcasting != nil, let spells = row.spells {
            suggestions[["spells", "slots"]] = .ints(spells)
        }
        if let classRules {
            let con = mod("con") { $0.con.hitPoints }
            hitPointRoll = "1\(classRules.hitDie)" + (con == 0 ? "" : signed(con))
        }
    }

    // MARK: Experience

    private mutating func experience() {
        guard let classRules, let level else { return }
        let percent: Int
        switch classRules.xpModifier {
        case .standard:
            let table = rules.abilities.primeRequisite
            percent = classRules.primeRequisites.first
                .flatMap(score)
                .map { table.xpPercent[AbilityTables.band($0, in: table.ranges)] } ?? 0
        case let .rules(list):
            percent = list.first { rule in
                let all = rule.all?.allSatisfy { (score($0.key) ?? 0) >= $0.value } ?? true
                let any = rule.any?.contains { (score($0.key) ?? 0) >= $0.value } ?? true
                return all && any
            }?.percent ?? 0
        }
        let next = classRules.row(level: level + 1)?.xp
        let ready = next.map { (file.int(["xp"]) ?? 0) >= $0 } ?? false
        xp = XPInfo(bonusPercent: percent, nextLevel: next, readyToLevelUp: ready)
        if ready {
            note(.info, "Enough XP for level \(level + 1).", ["xp"])
        }
    }

    // MARK: Weapons

    private mutating func weaponLines() {
        let thac0: Int? = ascending
            ? (file.int(["combat", "attackBonus"]) ?? row.map { 19 - $0.thac0 }).map { 19 - $0 }
            : file.int(["combat", "thac0"]) ?? row?.thac0
        let variableDamage = file.bool(["rules", "options", "variableWeaponDamage"]) ?? false
        let melee = mod("str") { $0.str.melee }
        let missile = mod("dex") { $0.dex.missile } + (classRules?.hasFeature("missile-bonus") == true ? 1 : 0)

        for index in 0..<file.count(["equipment"]) {
            let path: NodePath = ["equipment", .index(index)]
            let name = file.string(path + ["name"]) ?? ""
            let data = rules.weapon(named: name)
            let customDamage = file.string(path + ["damage"])
            guard data != nil || customDamage != nil, let thac0 else { continue }

            let die = variableDamage ? (customDamage ?? data?.damage ?? "1d6") : "1d6"
            let isMelee = data?.isMelee ?? true
            let isMissile = data?.isMissile ?? false
            weapons.append(WeaponLine(
                itemIndex: index,
                name: name,
                melee: isMelee ? Attack(thac0: thac0 - melee, damage: die + (melee == 0 ? "" : signed(melee))) : nil,
                missile: isMissile ? Attack(thac0: thac0 - missile, damage: die) : nil,
                range: data?.range))

            if let data, let classRules {
                if let allowed = classRules.weapons.allowed, !allowed.contains(data.id) {
                    note(.warning, "\(classRules.plural) normally use: \(classRules.weapons.text.lowercased()). \(data.name) isn't one.", path)
                }
                if classRules.weapons.forbidden?.contains(data.id) == true {
                    note(.warning, "\(classRules.plural) can't normally use a \(data.name.lowercased()).", path)
                }
            }
        }
    }

    // MARK: Everything else

    private mutating func otherNotes() {
        guard let classRules else { return }
        if file.int(["hp", "max"]) == nil, let hitPointRoll {
            note(.info, "Roll hit points: \(hitPointRoll) per level (at least 1).", ["hp", "max"])
        }
        if (file.string(["alignment"]) ?? "").isEmpty {
            note(.info, "No alignment chosen.", ["alignment"])
        }
        if classRules.spellcasting?.type == "divine" {
            let names = (0..<file.count(["equipment"])).compactMap { file.string(["equipment", .index($0), "name"]) }
            if !names.contains(where: { $0.lowercased().contains("holy symbol") }) {
                note(.info, "\(classRules.plural) need a holy symbol to cast spells.", ["equipment"])
            }
        }
        if let band = band("int") {
            let allowed = rules.abilities.int.extraLanguages[band]
            let native = Set((classRules.languages + rules.alignments).map { $0.lowercased() })
            let extra = file.strings(["languages"]).filter { !native.contains($0.lowercased()) }.count
            if extra < allowed {
                let more = allowed - extra
                note(.info, "INT \(score("int")!) allows \(more) more language\(more == 1 ? "" : "s").", ["languages"])
            }
        }
    }
}
