import Testing
@testable import CharacterKit

@Suite("At the table")
struct TableActionTests {
    private func file(_ header: String) throws -> CharacterFile {
        try CharacterFile(text: "---\nformatVersion: 1\nrules: { system: ose, variant: classic }\n\(header)\n---\n")
    }

    @Test func damageAndHealing() throws {
        var ronk = try file("class: Fighter\nhp:\n  max: 8\n  current: 6")
        #expect(ronk.adjustHitPoints(by: -4) == 2)
        #expect(ronk.adjustHitPoints(by: 10) == 8)
        #expect(ronk.adjustHitPoints(by: -11) == -3)
        #expect(RulesAnalysis(ronk).notes.contains { $0.message == "At 0 hit points or fewer, a character is dead." })
    }

    @Test func healingKeepsHitPointsAboveMax() throws {
        var blessed = try file("hp:\n  max: 8\n  current: 10")
        #expect(blessed.adjustHitPoints(by: 3) == 10)
        #expect(blessed.adjustHitPoints(by: -1) == 9)
    }

    @Test func missingCurrentStartsFromMax() throws {
        var fresh = try file("hp:\n  max: 5")
        #expect(fresh.adjustHitPoints(by: -2) == 3)
        #expect(fresh.int(["hp", "current"]) == 3)
        var none = try file("name: Ghost")
        #expect(none.adjustHitPoints(by: -2) == nil)
        #expect(none.int(["hp", "current"]) == nil)
    }

    @Test func usingItems() throws {
        var thief = try file("equipment:\n  - { name: Torches, qty: 2 }\n  - { name: Rope }")
        thief.useOne(ofItemAt: 0)
        thief.useOne(ofItemAt: 0)
        thief.useOne(ofItemAt: 0)
        #expect(thief.int(["equipment", 0, "qty"]) == 0)
        thief.useOne(ofItemAt: 1)
        #expect(thief.int(["equipment", 1, "qty"]) == 0)
        thief.useOne(ofItemAt: 7)
        #expect(thief.count(["equipment"]) == 2)
    }

    @Test func restingClearsCastSpells() throws {
        var elf = try file("spells:\n  memorized:\n    - { name: Sleep, cast: true }\n    - { name: Light }")
        #expect(elf.castSpellCount == 1)
        elf.resetCastSpells()
        #expect(elf.castSpellCount == 0)
        #expect(elf.text().contains("- { name: Sleep }"))
    }
}

@Suite("Rolling missing hit points")
struct MissingHitPointTests {
    private func analysis(_ header: String) throws -> RulesAnalysis {
        RulesAnalysis(try CharacterFile(text: "---\nformatVersion: 1\nrules: { system: ose, variant: classic }\n\(header)\n---\n"))
    }

    @Test func diceFollowTheLevel() throws {
        let marlek = try analysis("class: Magic-User\nlevel: 3\nabilityScores: { con: 16 }")
        #expect(marlek.hitDiceToRoll == Dice(count: 3, sides: 4))
        // 1 + 2 = 3, 4 + 2 = 6, 2 + 2 = 4
        #expect(marlek.hitPoints(fromDice: [1, 4, 2]) == 13)
    }

    @Test func eachDieGivesAtLeastOne() throws {
        let frail = try analysis("class: Magic-User\nlevel: 2\nabilityScores: { con: 3 }")
        #expect(frail.hitPoints(fromDice: [1, 3]) == 2)
    }

    @Test func fixedBonusAtHighLevels() throws {
        let fighter = try analysis("class: Fighter\nlevel: 10\nabilityScores: { con: 13 }")
        #expect(fighter.hitDiceToRoll == Dice(count: 9, sides: 8, modifier: 2))
        #expect(fighter.hitPoints(fromDice: Array(repeating: 4, count: 9)) == 9 * 5 + 2)
    }
}

@Suite("Level and XP")
struct LevelAndXPTests {
    private func file(_ header: String) throws -> CharacterFile {
        try CharacterFile(text: "---\nformatVersion: 1\nrules: { system: ose, variant: classic }\nclass: Magic-User\nabilityScores: { int: 13 }\n\(header)\n---\n")
    }

    private func warnings(_ file: CharacterFile) -> [String] {
        RulesAnalysis(file).notes.filter { $0.kind == .warning }.map(\.message)
    }

    @Test func warnsWhenXPIsBelowTheLevel() throws {
        let marlek = try file("level: 4\nxp: 2500")
        #expect(warnings(marlek) == ["Level 4 starts at \(10000.formatted()) XP; this character has \(2500.formatted())."])
        #expect(warnings(try file("level: 2\nxp: 2500")).isEmpty)
        #expect(warnings(try file("level: 4")).isEmpty)
    }

    @Test func levelUpCanRaiseXP() throws {
        var marlek = try file("level: 1\nxp: 900")
        let plan = try #require(RulesAnalysis(marlek).levelUpPlan(for: marlek))
        #expect(plan.xpShortfall?.needed == 2500 && plan.xpShortfall?.have == 900)
        var kept = marlek
        kept.apply(plan, hitPointRoll: nil)
        #expect(kept.int(["xp"]) == 900)
        #expect(warnings(kept).count == 1)
        marlek.apply(plan, hitPointRoll: nil, raiseXP: true)
        #expect(marlek.int(["xp"]) == 2500)
        #expect(warnings(marlek).isEmpty)
    }

    @Test func noShortfallWithEnoughXP() throws {
        let ready = try file("level: 1\nxp: 2600")
        #expect(RulesAnalysis(ready).levelUpPlan(for: ready)?.xpShortfall == nil)
    }
}

@Suite("Level down")
struct LevelDownTests {
    private func file(_ header: String) throws -> CharacterFile {
        try CharacterFile(text: "---\nformatVersion: 1\nrules: { system: ose, variant: classic }\n\(header)\n---\n")
    }

    @Test func losingALevel() throws {
        // Elowen: Elf 2, rolls 5 and 4, CON 11 (no modifier).
        var elowen = try file("""
            class: Elf
            level: 2
            xp: 4625
            abilityScores: { str: 13, int: 15, wis: 9, dex: 14, con: 11, cha: 10 }
            hp: { max: 9, current: 7, rolls: [5, 4] }
            spells: { slots: [2] }
            """)
        let plan = try #require(RulesAnalysis(elowen).levelDownPlan(for: elowen))
        #expect(plan.toLevel == 1)
        #expect(plan.xpReset?.to == 0 && plan.xpReset?.have == 4625)
        #expect(plan.suggestedHitPointLoss == 4)
        #expect(plan.changes.contains { $0.path.dotted == "spells.slots" && $0.to == .ints([1]) })
        #expect(plan.keptOverrides.isEmpty)
        elowen.apply(plan, hitPointLoss: 4, resetXP: true)
        #expect(elowen.int(["level"]) == 1 && elowen.int(["xp"]) == 0)
        #expect(elowen.int(["hp", "max"]) == 5 && elowen.int(["hp", "current"]) == 5)
        #expect(elowen.count(["hp", "rolls"]) == 1, "\(elowen.text())")
        #expect(elowen.int(["hp", "rolls", 0]) == 5)
        #expect(elowen.int(["spells", "slots", 0]) == 1)
    }

    @Test func keepingXPAndUnknownHitPoints() throws {
        var marlek = try file("class: Magic-User\nlevel: 3\nxp: 4000\nhp: { max: 8, current: 3 }")
        let plan = try #require(RulesAnalysis(marlek).levelDownPlan(for: marlek))
        #expect(plan.xpReset == nil)   // 4,000 is within level 2
        #expect(plan.suggestedHitPointLoss == nil)
        marlek.apply(plan, hitPointLoss: 2, resetXP: true)
        #expect(marlek.int(["xp"]) == 4000)
        #expect(marlek.int(["hp", "max"]) == 6 && marlek.int(["hp", "current"]) == 3)
    }

    @Test func fixedLossAtHighLevels() throws {
        let fighter = try file("class: Fighter\nlevel: 11\nhp: { max: 60 }")
        #expect(RulesAnalysis(fighter).levelDownPlan(for: fighter)?.suggestedHitPointLoss == 2)
    }

    @Test func notBelowFirstLevel() throws {
        let ronk = try file("class: Fighter\nlevel: 1")
        #expect(RulesAnalysis(ronk).levelDownPlan(for: ronk) == nil)
    }

    @Test func maxHitPointsOutsideTheDice() throws {
        func notes(_ header: String) throws -> [String] {
            RulesAnalysis(try file(header)).notes.map(\.message).filter { $0.hasPrefix("Max HP") }
        }
        #expect(try notes("class: Magic-User\nlevel: 1\nabilityScores: { con: 16 }\nhp: { max: 25 }")
                == ["Max HP 25 is more than 1d4 with CON +2 a die can give (at most 6)."])
        #expect(try notes("class: Fighter\nlevel: 2\nhp: { max: 1 }")
                == ["Max HP 1 is less than 2d8 can give (at least 2)."])
        #expect(try notes("class: Fighter\nlevel: 2\nhp: { max: 16 }").isEmpty)
    }
}
