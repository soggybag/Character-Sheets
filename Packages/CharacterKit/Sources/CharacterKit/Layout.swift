import Yams

/// House style for values the app creates: where new keys go and whether new
/// maps and lists are written on one line (flow) or several (block).
/// Matches docs/FILE-FORMAT.md and the example files.
enum Layout {
    /// Paths are matched with list indices replaced by `*`.
    private static func pattern(_ path: NodePath) -> String {
        path.map { component in
            switch component {
            case let .key(key): key
            case .index: "*"
            }
        }.joined(separator: ".")
    }

    private static let keyOrders: [String: [String]] = [
        "": ["formatVersion", "rules", "name", "player", "title", "portrait", "class", "race", "level",
             "alignment", "xp", "abilityScores", "hp", "combat", "saves", "movement", "exploration",
             "thiefSkills", "languages", "spells", "equipment", "money"],
        "rules": ["system", "variant", "options"],
        "rules.options": ["ascendingAC", "encumbrance", "variableWeaponDamage"],
        "abilityScores": ["str", "int", "wis", "dex", "con", "cha"],
        "hp": ["max", "current", "rolls"],
        "combat": ["ac", "thac0", "attackBonus"],
        "saves": ["death", "wands", "paralysis", "breath", "spells"],
        "exploration": ["listen", "secretDoors", "openDoors", "findTraps", "constructionTricks"],
        "thiefSkills": ["climb", "traps", "hearNoise", "hide", "moveSilently", "openLocks", "pickPockets"],
        "spells": ["slots", "spellbook", "memorized"],
        "spells.spellbook.*": ["name", "level"],
        "spells.memorized.*": ["name", "cast"],
        "equipment.*": ["name", "qty", "weight", "equipped", "damage", "notes"],
        "money": ["pp", "gp", "ep", "sp", "cp"],
    ]

    private static let blockMaps: Set<String> = ["", "rules", "rules.options", "hp", "combat", "spells"]
    private static let flowMaps: Set<String> = ["abilityScores", "saves", "exploration", "thiefSkills", "money",
                                                "spells.spellbook.*", "spells.memorized.*", "equipment.*"]
    private static let blockLists: Set<String> = ["spells.spellbook", "spells.memorized", "equipment"]
    private static let flowLists: Set<String> = ["hp.rolls", "languages", "spells.slots"]

    static func keyOrder(at path: NodePath) -> [String] {
        keyOrders[pattern(path)] ?? []
    }

    static func mappingStyle(at path: NodePath) -> Node.Mapping.Style {
        let key = pattern(path)
        if blockMaps.contains(key) { return .block }
        if flowMaps.contains(key) { return .flow }
        return .any
    }

    static func sequenceStyle(at path: NodePath) -> Node.Sequence.Style {
        let key = pattern(path)
        if blockLists.contains(key) { return .block }
        if flowLists.contains(key) { return .flow }
        return .any
    }
}
