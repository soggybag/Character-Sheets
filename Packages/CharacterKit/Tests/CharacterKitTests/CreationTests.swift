import Foundation
import Testing
@testable import CharacterKit

/// A repeatable random number generator (SplitMix64).
struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

@Suite("Dice")
struct DiceTests {
    @Test func parsesNotation() {
        #expect(Dice("3d6") == Dice(count: 3, sides: 6))
        #expect(Dice("1d8+1") == Dice(count: 1, sides: 8, modifier: 1))
        #expect(Dice("3d6*10") == Dice(count: 3, sides: 6, multiplier: 10))
        #expect(Dice("d4") == Dice(count: 1, sides: 4))
        #expect(Dice("2D6 - 1") == Dice(count: 2, sides: 6, modifier: -1))
        #expect(Dice("abc") == nil)
        #expect(Dice("0d6") == nil)
        #expect(Dice("3d0") == nil)
    }

    @Test func describesDiceAndRange() {
        #expect(Dice("3d6*10")!.description == "3d6×10")
        #expect(Dice("1d8+1")!.description == "1d8+1")
        #expect(Dice("3d6")!.range == 3...18)
        #expect(Dice("3d6*10")!.range == 30...180)
    }

    @Test func showsEachDie() {
        #expect(DiceRoll(dice: Dice("3d6")!, results: [4, 3, 6]).description == "4 + 3 + 6 = 13")
        #expect(DiceRoll(dice: Dice("3d6*10")!, results: [2, 5, 1]).description == "(2 + 5 + 1) × 10 = 80")
        #expect(DiceRoll(dice: Dice("1d8")!, results: [6]).description == "6")
        #expect(DiceRoll(dice: Dice("1d8-1")!, results: [6]).description == "6 − 1 = 5")
    }

    @Test func rollsWithinRange() {
        var generator = SeededGenerator(state: 7)
        for _ in 0..<500 {
            let roll = Dice("3d6")!.roll(using: &generator)
            #expect(roll.results.count == 3)
            #expect(roll.results.allSatisfy { (1...6).contains($0) })
            #expect((3...18).contains(roll.total))
        }
    }
}

@Suite("New characters")
struct CreationTests {
    private func character(_ scores: [Int], class name: String, alignment: String = "Neutral") -> NewCharacter {
        var character = NewCharacter()
        for (ability, score) in zip(NewCharacter.abilityOrder, scores) {
            character.setRolledScore(score, for: ability)
        }
        character.className = name
        character.alignment = alignment
        return character
    }

    @Test func rollsScoresInOrderAndKeepsTheDice() {
        var new = NewCharacter()
        new.adjustments = ["str": -2]
        var generator = SeededGenerator(state: 42)
        new.rollScores(using: &generator)
        #expect(new.hasAllScores)
        #expect(new.adjustments.isEmpty)
        for ability in NewCharacter.abilityOrder {
            #expect(new.scoreRolls[ability]?.total == new.rolledScores[ability])
        }
        new.setRolledScore(12, for: "str")
        #expect(new.scoreRolls["str"] == nil)
    }

    @Test func ronkComesOutLikeHisSheet() throws {
        var ronk = character([13, 11, 13, 11, 11, 16], class: "fighter")
        ronk.name = "Ronk"
        ronk.hitPointRoll = 4
        ronk.gold = 90
        let file = ronk.makeFile()

        #expect(file.string(["name"]) == "Ronk")
        #expect(file.string(["class"]) == "Fighter")
        #expect(file.int(["level"]) == 1)
        #expect(file.int(["xp"]) == 0)
        #expect(file.int(["hp", "max"]) == 4)
        #expect(file.int(["hp", "current"]) == 4)
        #expect(file.int(["combat", "thac0"]) == 19)
        #expect(file.strings(["languages"]) == ["Neutral", "Common"])
        #expect(file.int(["money", "gp"]) == 90)
        // Gear decides these, so the rules suggest them later.
        #expect(file.int(["combat", "ac"]) == nil)
        #expect(file.int(["movement"]) == nil)

        let example = try CharacterFile(text: String(contentsOf: URL(filePath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "examples/Ronk the Fighter.md"), encoding: .utf8))
        #expect(file[["saves"]] == example[["saves"]])
        #expect(file[["abilityScores"]] == example[["abilityScores"]])
        #expect(try CharacterFile(text: file.text()).text() == file.text())
    }

    @Test func classDetails() {
        let elf = character([10, 13, 10, 17, 15, 10], class: "Elf", alignment: "Chaotic").makeFile()
        #expect(elf.strings(["languages"]) == ["Chaotic", "Common", "Elvish", "Gnoll", "Hobgoblin", "Orcish"])
        #expect(elf.count(["spells", "slots"]) == 1)

        let thief = character([6, 10, 10, 17, 13, 11], class: "Thief").makeFile()
        #expect(thief.int(["thiefSkills", "climb"]) == 87)

        var ascending = character([13, 11, 13, 11, 11, 16], class: "Fighter")
        ascending.ascendingAC = true
        #expect(ascending.makeFile().int(["combat", "attackBonus"]) == 0)
    }

    @Test func requirementsAreReportedNotEnforced() {
        let rules = OSERuleset.classic
        let weak = character([10, 8, 10, 8, 8, 10], class: "Elf")
        #expect(weak.unmetRequirements(for: rules.classRules(named: "Elf")!) == ["INT 9"])
        #expect(weak.unmetRequirements(for: rules.classRules(named: "Halfling")!) == ["CON 9", "DEX 9"])
        #expect(weak.unmetRequirements(for: rules.classRules(named: "Fighter")!).isEmpty)
        #expect(weak.makeFile().string(["class"]) == "Elf")
    }

    @Test func xpBonusForEachClass() {
        let rules = OSERuleset.classic
        let new = character([16, 6, 10, 13, 10, 10], class: "Fighter")
        #expect(new.xpBonus(for: rules.classRules(named: "Fighter")!) == 10)
        #expect(new.xpBonus(for: rules.classRules(named: "Magic-User")!) == -10)
        #expect(new.xpBonus(for: rules.classRules(named: "Thief")!) == 5)
    }

    @Test func hitPointsUseConAndAreAtLeastOne() {
        var sickly = character([10, 10, 10, 10, 3, 10], class: "Magic-User")
        sickly.hitPointRoll = 2
        #expect(sickly.conModifier == -3)
        #expect(sickly.hitPoints == 1)
        var hardy = character([10, 10, 10, 10, 16, 10], class: "Fighter")
        hardy.hitPointRoll = 5
        #expect(hardy.hitPoints == 7)
        #expect(hardy.hitDie == Dice("1d8"))
    }

    @Test func adjustmentsFollowingTheRulesHaveNoNotes() {
        var fighter = character([13, 12, 11, 10, 10, 10], class: "Fighter")
        fighter.adjustments = ["int": -2, "str": 1]
        #expect(fighter.adjustmentNotes.isEmpty)
        #expect(fighter.scores["str"] == 14)
        #expect(fighter.makeFile().int(["abilityScores", "int"]) == 10)
    }

    @Test func adjustmentsAgainstTheRulesAreExplained() {
        var fighter = character([13, 10, 11, 12, 10, 10], class: "Fighter")
        fighter.adjustments = ["dex": -2, "wis": 1, "int": -2]
        #expect(fighter.adjustmentNotes == [
            "INT is lowered below 9.",
            "WIS isn't a prime requisite for fighters, so it can't normally be raised.",
            "DEX can't normally be lowered (only STR, INT, WIS).",
            "Lower 2 points for each point raised (lowered 4, raised 1).",
        ])
        fighter.adjustments = ["int": -1, "str": 1]
        #expect(fighter.adjustmentNotes == ["Lower 2 points for each point raised (lowered 1, raised 1)."])
    }
}

@Suite("Shopping for a new character")
struct NewCharacterShoppingTests {
    private func item(_ id: String) throws -> ShopItem {
        try #require(OSERuleset.classic.shopItems.first { $0.id == id })
    }

    @Test func spendingStartingGold() throws {
        var character = NewCharacter()
        character.className = "Fighter"
        for ability in NewCharacter.abilityOrder { character.setRolledScore(12, for: ability) }
        character.gold = 100
        character.buy(try item("chainmail"))
        character.buy(try item("shield"))
        character.buy(try item("sword"))
        character.buy(try item("torches"), count: 2)
        character.buy(try item("holy-symbol"), paid: false)
        #expect(character.goldLeft == 100 - 40 - 10 - 10 - 2)
        let file = character.makeFile()
        #expect(file.int(["money", "gp"]) == 38)
        #expect((0..<file.count(["equipment"])).compactMap { file.string(["equipment", .index($0), "name"]) }
                == ["Chainmail", "Shield", "Sword", "Torches", "Holy symbol"])
        #expect(file.int(["equipment", 3, "qty"]) == 12)
        // With armour bought, AC is filled in: chainmail 5, shield −1.
        #expect(file.int(["combat", "ac"]) == 4)
        #expect(file.int(["movement"]) != nil)
    }

    @Test func aLowerGoldRollLeavesOutWhatDoesntFit() throws {
        var character = NewCharacter()
        character.gold = 100
        character.buy(try item("plate"))       // 60
        character.buy(try item("long-bow"))    // 40
        character.gold = 70
        #expect(character.unaffordable.map(\.item.id) == ["long-bow"])
        #expect(character.goldLeft == 10)
        let file = character.makeFile()
        #expect(file.count(["equipment"]) == 1)
        #expect(file.int(["money", "gp"]) == 10)
    }

    @Test func noGearLeavesACForLater() {
        var character = NewCharacter()
        character.className = "Fighter"
        character.gold = 50
        let file = character.makeFile()
        #expect(file.int(["combat", "ac"]) == nil)
        #expect(file.int(["money", "gp"]) == 50)
    }
}
