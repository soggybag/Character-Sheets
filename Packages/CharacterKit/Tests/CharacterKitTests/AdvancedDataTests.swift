import Foundation
import Testing
@testable import CharacterKit

@Suite("Advanced Fantasy data")
struct AdvancedDataTests {
    let rules = OSERuleset.advanced

    @Test func loadsAndSharesTheClassicTables() {
        #expect(rules.system == "ose" && rules.variant == "advanced")
        #expect(rules.displayName == "Old-School Essentials Advanced Fantasy")
        #expect(rules.weapons.map(\.id) == OSERuleset.classic.weapons.map(\.id))
        #expect(rules.armour.map(\.id) == OSERuleset.classic.armour.map(\.id))
    }

    @Test func notOfferedUntilItHasClassesOfItsOwn() {
        let ownClasses = rules.classes.count > OSERuleset.classic.classes.count
        #expect(ownClasses == OSERuleset.all.contains { $0.variant == "advanced" })
    }

    @Test func includesTheClassicClasses() {
        #expect(Array(rules.classes.map(\.id).prefix(7)) == OSERuleset.classic.classes.map(\.id))
    }

    @Test func classicHasNoRaces() {
        #expect(OSERuleset.classic.races.isEmpty)
    }

    @Test(arguments: [OSERuleset.classic, OSERuleset.advanced])
    func everyClassHasARowPerLevel(rules: OSERuleset) {
        for classRules in rules.classes {
            #expect(classRules.levels.map(\.level) == Array(1...classRules.maxLevel), "\(classRules.name)")
            #expect(classRules.levels.map(\.xp) == classRules.levels.map(\.xp).sorted(), "\(classRules.name)")
        }
    }

    @Test func racesNameRealClassesAndLevels() {
        for race in rules.races {
            for (classID, maxLevel) in race.classes {
                let classRules = rules.classes.first { $0.id == classID }
                #expect(classRules != nil, "\(race.name): no class \(classID)")
                if let classRules { #expect((1...classRules.maxLevel).contains(maxLevel), "\(race.name) \(classID)") }
            }
        }
    }

    @Test func raceFormat() throws {
        let json = """
            {"id": "half-elf", "name": "Half-Elf", "plural": "Half-Elves",
             "requirements": {"con": 9, "int": 9}, "maximums": {}, "abilityModifiers": {},
             "languages": ["Alignment", "Common", "Elvish"], "infravision": 30,
             "features": [{"id": "x", "name": "X", "summary": "Y"}],
             "classes": {"fighter": 12}}
            """
        let race = try JSONDecoder().decode(RaceRules.self, from: Data(json.utf8))
        #expect(race.plural == "Half-Elves")
        #expect(race.maxLevel(classID: "fighter") == 12 && race.maxLevel(classID: "cleric") == nil)
        #expect(race.exploration == nil)

        let gnome = try JSONDecoder().decode(RaceRules.self, from: Data(
            json.replacingOccurrences(of: #""name": "Half-Elf", "plural": "Half-Elves","#, with: #""name": "Gnome","#).utf8))
        #expect(gnome.plural == "Gnomes")
    }
}

@Suite("Advanced Fantasy classes")
struct AdvancedClassTests {
    let rules = OSERuleset.advanced

    /// Spot checks against the book's Druid Level Progression table.
    @Test func druid() throws {
        let druid = try #require(rules.classRules(named: "druid"))
        #expect(druid.maxLevel == 14 && druid.hitDie == "d6" && druid.primeRequisites == ["wis"])
        #expect(druid.alignments == ["Neutral"])
        #expect(druid.armour.allowed == ["leather"] && druid.armour.shields)
        #expect(druid.spellcasting?.type == "divine" && druid.spellcasting?.fromLevel == 1)
        let first = try #require(druid.row(level: 1))
        #expect(first.xp == 0 && first.thac0 == 19 && first.spells == [1])
        #expect(first.saves == ["death": 11, "wands": 12, "paralysis": 14, "breath": 16, "spells": 15])
        let fifth = try #require(druid.row(level: 5))
        #expect(fifth.xp == 12500 && fifth.thac0 == 17 && fifth.spells == [2, 2, 1, 1])
        let tenth = try #require(druid.row(level: 10))
        #expect(tenth.hd == "9d6+1" && tenth.conModifier == false && tenth.xp == 125000)
        let last = try #require(druid.row(level: 14))
        #expect(last.xp == 1_500_000 && last.thac0 == 12 && last.spells == [6, 6, 5, 5, 5])
        #expect(last.saves == ["death": 3, "wands": 5, "paralysis": 7, "breath": 8, "spells": 7])
    }

    @Test func druidsMustBeNeutral() throws {
        func notes(_ alignment: String) throws -> [String] {
            let file = try CharacterFile(text: """
                ---
                formatVersion: 1
                rules: { system: ose, variant: advanced }
                class: Druid
                level: 1
                alignment: \(alignment)
                ---

                """)
            return RulesAnalysis(file, rules: rules).notes.map(\.message)
        }
        #expect(try notes("Lawful").contains("Druids must be Neutral (this one is Lawful)."))
        #expect(try !notes("neutral").contains { $0.hasPrefix("Druids must be") })
    }
}
