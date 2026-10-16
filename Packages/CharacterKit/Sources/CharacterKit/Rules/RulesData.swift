import Foundation

// Decoded forms of the bundled rules data in Resources/ose.
// See Resources/ose/README.md for the conventions.

public struct ClassRules: Decodable, Sendable {
    public let id: String
    public let name: String
    public let race: String
    public let requirements: [String: Int]
    public let primeRequisites: [String]
    public let xpModifier: XPModifier
    public let hitDie: String
    public let maxLevel: Int
    public let armour: ArmourRule
    public let weapons: WeaponRule
    public let languages: [String]
    public let spellcasting: Spellcasting?
    public let exploration: [String: Int]?
    public let infravision: Int?
    public let features: [Feature]
    public let levels: [LevelRow]

    public func row(level: Int) -> LevelRow? {
        levels.first { $0.level == level }
    }

    /// "Elves", "Thieves", "Fighters".
    public var plural: String {
        switch name {
        case "Elf": "Elves"
        case "Dwarf": "Dwarves"
        case "Thief": "Thieves"
        default: name + "s"
        }
    }

    public func hasFeature(_ id: String) -> Bool {
        features.contains { $0.id == id }
    }

    public enum XPModifier: Decodable, Sendable {
        /// Uses the prime requisite table in abilities.json.
        case standard
        /// First matching rule wins.
        case rules([XPRule])

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let name = try? container.decode(String.self), name == "standard" {
                self = .standard
            } else {
                self = .rules(try container.decode([XPRule].self))
            }
        }
    }

    public struct XPRule: Decodable, Sendable {
        /// Every score must be at least this.
        public let all: [String: Int]?
        /// At least one score must be at least this.
        public let any: [String: Int]?
        public let percent: Int
    }

    public struct ArmourRule: Decodable, Sendable {
        public let allowed: [String]
        public let shields: Bool
    }

    public struct WeaponRule: Decodable, Sendable {
        public let text: String
        public let allowed: [String]?
        public let forbidden: [String]?
    }

    public struct Spellcasting: Decodable, Sendable {
        /// `arcane` or `divine`.
        public let type: String
        public let fromLevel: Int
    }

    public struct Feature: Decodable, Sendable {
        public let id: String
        public let name: String
        public let summary: String
        public let minLevel: Int?
    }

    public struct LevelRow: Decodable, Sendable {
        public let level: Int
        public let xp: Int
        /// As printed, e.g. `9d8+2`.
        public let hd: String
        /// False from the level where CON stops adding hit points.
        public let conModifier: Bool?
        public let thac0: Int
        public let saves: [String: Int]
        public let spells: [Int]?
        public let thiefSkills: [String: Int]?

        /// The fixed hit point bonus in `hd` (the `+2` in `9d8+2`).
        var hitPointBonus: Int {
            hd.split(separator: "+").dropFirst().first.flatMap { Int($0) } ?? 0
        }
    }
}

struct AbilityTables: Decodable, Sendable {
    let ranges: [[Int]]
    let str: Strength
    let int: Intelligence
    let wis: Wisdom
    let dex: Dexterity
    let con: Constitution
    let cha: Charisma
    let primeRequisite: PrimeRequisite

    struct Strength: Decodable, Sendable { let melee, openDoors: [Int] }
    struct Intelligence: Decodable, Sendable { let extraLanguages: [Int]; let literacy: [String] }
    struct Wisdom: Decodable, Sendable { let magicSaves: [Int] }
    struct Dexterity: Decodable, Sendable { let ac, missile, initiative: [Int] }
    struct Constitution: Decodable, Sendable { let hitPoints: [Int] }
    struct Charisma: Decodable, Sendable { let reactions, maxRetainers, retainerLoyalty: [Int] }
    struct PrimeRequisite: Decodable, Sendable { let ranges: [[Int]]; let xpPercent: [Int] }

    /// Index into a table for a score. Scores past either end use the end row.
    static func band(_ score: Int, in ranges: [[Int]]) -> Int {
        if let index = ranges.firstIndex(where: { $0[0] <= score && score <= $0[1] }) { return index }
        return score < ranges[0][0] ? 0 : ranges.count - 1
    }
}

public struct WeaponData: Decodable, Sendable {
    public let id: String
    public let name: String
    public let cost: Int
    public let weight: Int?
    public let damage: String
    public let qualities: [String]
    public let range: Range?

    public var isMelee: Bool { qualities.contains("melee") }
    public var isMissile: Bool { qualities.contains("missile") }

    public struct Range: Decodable, Sendable, Equatable {
        public let short, medium, long: Int
    }
}

public struct ArmourData: Decodable, Sendable {
    public let id: String
    public let name: String
    public let ac: Int?
    public let acBonus: Int?
    public let weight: Int
    /// `light` or `heavy`; nil for shields.
    public let encumbrance: String?
}

struct EquipmentTables: Decodable, Sendable {
    let weapons: [WeaponData]
    let armour: [ArmourData]
    let encumbrance: Encumbrance

    struct Encumbrance: Decodable, Sendable {
        let maxLoad: Int
        let basic: Basic
        let detailed: Detailed

        struct Basic: Decodable, Sendable {
            let movement: [String: Rates]
            struct Rates: Decodable, Sendable { let normal, treasure: Int }
        }

        struct Detailed: Decodable, Sendable {
            let miscGear: Int
            let movement: [Step]
            struct Step: Decodable, Sendable { let upTo, rate: Int }
        }
    }
}

struct RulesetInfo: Decodable, Sendable {
    let alignments: [String]
    let combat: Combat
    let exploration: Exploration

    struct Combat: Decodable, Sendable { let unarmouredAC: Int }
    struct Exploration: Decodable, Sendable { let defaults: [String: Int] }
}

struct ClassesFile: Decodable {
    let classes: [ClassRules]
}
