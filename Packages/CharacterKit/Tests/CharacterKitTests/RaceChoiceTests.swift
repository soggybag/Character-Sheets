import Testing
@testable import CharacterKit

@Suite("Choosing a race")
struct RaceChoiceTests {
    private func dwarf(_ scores: [String: Int] = ["str": 13, "int": 10, "wis": 9, "dex": 11, "con": 12, "cha": 10])
        -> NewCharacter {
        var new = NewCharacter(rules: .advanced)
        new.rolledScores = scores
        new.race = "Dwarf"
        return new
    }

    @Test func modifiersChangeTheRolledScores() {
        var new = dwarf()
        #expect(new.scores["con"] == 13 && new.scores["cha"] == 9 && new.scores["str"] == 13)
        new.adjustments = ["str": 1, "int": -2]
        #expect(new.scores["str"] == 14 && new.scores["int"] == 8)
        // A modifier that would pass 18 or go under 3 is ignored.
        let edge = dwarf(["str": 10, "int": 10, "wis": 10, "dex": 10, "con": 18, "cha": 3])
        #expect(edge.scores["con"] == 18 && edge.scores["cha"] == 3)
    }

    @Test func requirementsUseTheRolledScores() {
        #expect(dwarf().unmetRaceRequirements.isEmpty)
        // CON 8 rolled: the +1 would make 9, but the race is chosen first.
        let low = dwarf(["str": 13, "int": 10, "wis": 9, "dex": 11, "con": 8, "cha": 10])
        #expect(low.unmetRaceRequirements == ["CON 9"])
    }

    @Test func classesForTheRace() throws {
        var new = dwarf()
        #expect(!new.classChoices.contains { $0.name == "Elf" || $0.name == "Dwarf" })
        #expect(new.classChoices.contains { $0.name == "Magic-User" })
        #expect(try new.raceAllows(#require(new.rules.classRules(named: "Fighter"))))
        #expect(try !new.raceAllows(#require(new.rules.classRules(named: "Magic-User"))))
        // Choosing a race clears a race-class, but keeps a class it can take.
        new.race = nil
        new.className = "Elf"
        new.race = "Dwarf"
        #expect(new.className == nil)
        new.className = "Thief"
        new.race = "Half-Orc"
        #expect(new.className == "Thief")
        // Without a race, every class is offered.
        new.race = nil
        #expect(new.classChoices.count == new.rules.classes.count)
    }

    @Test func theFileRecordsTheRace() {
        var new = dwarf()
        new.className = "Druid"
        new.alignment = "Neutral"
        let file = new.makeFile()
        #expect(file.string(["race"]) == "Dwarf" && file.string(["class"]) == "Druid")
        #expect(file.strings(["languages"]) == ["Neutral", "Common", "Dwarvish", "Gnomish", "Goblin", "Kobold", "Druidic"])
        #expect(file.int(["abilityScores", "con"]) == 13)
        // The basic method writes no race.
        var basic = NewCharacter(rules: .advanced)
        basic.className = "Elf"
        #expect(basic.makeFile().string(["race"]) == nil)
    }

    @Test func randomCharactersKeepTheRace() throws {
        let items = OSERuleset.advanced.shopItems
        for seed in 1...100 {
            var new = NewCharacter(rules: .advanced)
            new.race = seed.isMultiple(of: 2) ? "Dwarf" : "Halfling"
            var generator = SeededGenerator(state: UInt64(seed))
            new.rollRandom(items: items, using: &generator)
            let race = try #require(new.raceRules)
            let classRules = try #require(new.classRules, "seed \(seed)")
            #expect(race.maxLevel(classID: classRules.id) != nil, "seed \(seed): \(race.name) \(classRules.name)")
            #expect(new.unmetRaceRequirements.isEmpty, "seed \(seed)")
            for purchase in new.purchases {
                #expect(new.rules.restriction(of: purchase.item, for: classRules, race: race) == nil,
                        "seed \(seed): \(race.name) \(classRules.name) with \(purchase.item.name)")
            }
        }
    }

    @Test func raceWeaponLimitsInTheShop() throws {
        let rules = OSERuleset.advanced
        let longBow = try #require(rules.shopItems.first { $0.id == "long-bow" })
        let fighter = try #require(rules.classRules(named: "Fighter"))
        #expect(rules.restriction(of: longBow, for: fighter) == nil)
        #expect(rules.restriction(of: longBow, for: fighter, race: rules.raceRules(named: "Dwarf"))
                == "Dwarves can't normally use a long bow.")
    }

    @Test func bardsAreNotSoldAHolySymbol() throws {
        var new = NewCharacter(rules: .advanced)
        new.rolledScores = ["str": 10, "int": 12, "wis": 10, "dex": 12, "con": 10, "cha": 14]
        new.className = "Bard"
        new.gold = 180
        new.buyStartingKit(from: OSERuleset.advanced.shopItems)
        #expect(!new.purchases.contains { $0.item.id == "holy-symbol" })
        new.purchases = []
        new.className = "Cleric"
        new.buyStartingKit(from: OSERuleset.advanced.shopItems)
        #expect(new.purchases.contains { $0.item.id == "holy-symbol" })
    }
}
