import Testing
@testable import CharacterKit

@Suite("The sheet using the race")
struct SheetRaceTests {
    private func analysis(_ more: String) throws -> RulesAnalysis {
        try RulesAnalysis(CharacterFile(text: "---\nformatVersion: 1\nrules: { system: ose, variant: advanced }\n\(more)---\n"))
    }

    private func messages(_ analysis: RulesAnalysis) -> [String] { analysis.notes.map(\.message) }

    @Test func raceAbilities() throws {
        let a = try analysis("race: Dwarf\nclass: Fighter\nlevel: 1\n")
        #expect(a.raceRules?.name == "Dwarf")
        #expect(a.raceAbilities.map(\.id).contains("infravision") && a.raceAbilities.map(\.id).contains("resilience"))
        // The Dwarf class already has infravision: not listed twice.
        let dwarf = try analysis("race: Dwarf\nclass: Dwarf\nlevel: 1\n")
        #expect(!dwarf.raceAbilities.contains { $0.id == "infravision" })
        // Drow innate magic comes at 2nd level.
        let drow = try analysis("race: Drow\nclass: Fighter\nlevel: 1\n")
        #expect(drow.laterAbilities.contains { $0.id == "innate-magic" })
        #expect(try analysis("race: Drow\nclass: Fighter\nlevel: 2\n").raceAbilities.contains { $0.id == "innate-magic" })
    }

    @Test func explorationTakesTheBetterChance() throws {
        let a = try analysis("race: Dwarf\nclass: Fighter\nlevel: 1\n")
        #expect(a.suggestions[["exploration", "listen"]] == .int(2))
        #expect(a.suggestions[["exploration", "findTraps"]] == .int(2))
        #expect(a.suggestions[["exploration", "constructionTricks"]] == .int(2))
        let human = try analysis("race: Human\nclass: Fighter\nlevel: 1\n")
        #expect(human.suggestions[["exploration", "listen"]] == .int(1))
    }

    @Test func classAndLevelLimits() throws {
        #expect(messages(try analysis("race: Dwarf\nclass: Magic-User\nlevel: 1\n"))
            .contains("Dwarves can't normally be magic-users."))
        let high = try analysis("race: Dwarf\nclass: Fighter\nlevel: 11\n")
        #expect(messages(high).contains("Dwarves can't normally go past level 10 as fighters."))
        // At the race's limit, there's no next level.
        let top = try analysis("race: Dwarf\nclass: Fighter\nlevel: 10\nxp: 999999\n")
        #expect(top.xp?.nextLevel == nil && top.xp?.readyToLevelUp == false)
        #expect(try analysis("race: Dwarf\nclass: Fighter\nlevel: 9\n").xp?.nextLevel == 360_000)
        // Humans have no limit.
        #expect(!messages(try analysis("race: Human\nclass: Fighter\nlevel: 14\n")).contains { $0.contains("go past") })
        #expect(messages(try analysis("race: Hobbit\nclass: Fighter\nlevel: 1\n"))
            .contains("No Old-School Essentials Advanced Fantasy rules for the race “Hobbit”."))
    }

    @Test func raceWeaponLimits() throws {
        let a = try analysis("""
            race: Halfling
            class: Fighter
            level: 1
            equipment:
              - { name: Long bow }

            """)
        #expect(messages(a).contains { $0.contains("Halflings can't normally use a long bow") })
    }

    @Test func halflingMissileBonusFromTheRace() throws {
        let scores = "abilityScores: { str: 10, int: 10, wis: 10, dex: 10, con: 10, cha: 10 }\n"
        let fighter = try analysis("class: Fighter\nlevel: 1\n" + scores + "equipment:\n  - { name: Sling }\n")
        let halfling = try analysis("race: Halfling\nclass: Fighter\nlevel: 1\n" + scores + "equipment:\n  - { name: Sling }\n")
        let human = try #require(fighter.weapons.first?.missile?.thac0)
        #expect(halfling.weapons.first?.missile?.thac0 == human - 1)
    }

    @Test func raceLanguagesCountAsNative() throws {
        let a = try analysis("""
            race: Dwarf
            class: Fighter
            level: 1
            alignment: Lawful
            abilityScores: { str: 10, int: 10, wis: 10, dex: 10, con: 10, cha: 10 }
            languages: [Lawful, Common, Dwarvish, Gnomish, Goblin, Kobold]

            """)
        #expect(!messages(a).contains { $0.contains("more language") })
    }
}
