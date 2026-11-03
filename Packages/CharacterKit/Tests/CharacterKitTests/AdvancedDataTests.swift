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

    @Test func notOfferedUntilItHasClasses() {
        #expect(rules.classes.isEmpty == !OSERuleset.all.contains { $0.variant == "advanced" })
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
