import Testing
@testable import CharacterKit

@Suite("Rolling methods and random characters")
struct RandomCharacterTests {
    private func character(_ scores: [Int], class name: String? = nil) -> NewCharacter {
        var character = NewCharacter()
        for (ability, score) in zip(NewCharacter.abilityOrder, scores) {
            character.setRolledScore(score, for: ability)
        }
        character.className = name
        return character
    }

    // MARK: 4d6, drop lowest

    @Test func fourDropLowestRollsFourDice() {
        var new = NewCharacter()
        new.method = .fourDropLowest
        #expect(new.abilityDice.description == "4d6 drop lowest")
        var generator = SeededGenerator(state: 3)
        new.rollScores(using: &generator)
        for ability in NewCharacter.abilityOrder {
            let roll = new.scoreRolls[ability]!
            #expect(roll.results.count == 4 && roll.dropped.count == 1)
            #expect(new.rolledScores[ability] == roll.results.sorted().dropFirst().reduce(0, +))
        }
        #expect(NewCharacter().abilityDice.description == "3d6")
    }

    // MARK: Swapping and sub-par characters

    @Test func swappingMovesScoresAndDice() {
        var new = NewCharacter()
        var generator = SeededGenerator(state: 9)
        new.rollScores(using: &generator)
        let (str, dex) = (new.scoreRolls["str"], new.scoreRolls["dex"])
        new.adjustments = ["str": 1, "int": -2]
        new.swapScores("str", "dex")
        #expect(new.scoreRolls["str"] == dex && new.scoreRolls["dex"] == str)
        #expect(new.rolledScores["str"] == dex?.total && new.adjustments.isEmpty)
    }

    @Test func subParScores() {
        #expect(character([8, 8, 8, 8, 8, 8]).isSubPar)                 // all below 9
        #expect(character([6, 7, 6, 8, 12, 14]).isSubPar)               // two below 7
        #expect(!character([6, 7, 7, 8, 12, 14]).isSubPar)             // only one below 7
        #expect(!character([9, 8, 8, 8, 8, 8]).isSubPar)
        #expect(!character([8, 8, 8]).isSubPar)                         // not all rolled yet
    }

    @Test func thievesCantLowerStrength() {
        var thief = character([12, 10, 10, 12, 10, 10], class: "Thief")
        thief.adjustments = ["str": -2, "dex": 1]
        #expect(thief.adjustmentNotes == ["Thieves can't normally lower STR."])
    }

    // MARK: Random characters

    @Test func theBestClassForTheScores() {
        var generator = SeededGenerator(state: 1)
        #expect(character([8, 17, 8, 9, 9, 9]).bestClass(using: &generator)?.name == "Magic-User")
        #expect(character([9, 9, 9, 16, 9, 9]).bestClass(using: &generator)?.name == "Thief")
        // CON 8 rules out the dwarf and halfling.
        let fighters = character([16, 9, 9, 16, 8, 9])
        for _ in 0..<10 {
            #expect(fighters.bestClass(using: &generator)?.name != "Dwarf")
        }
    }

    @Test func adjustingReachesTheNextXPBonus() {
        // STR 15 → 16 for +10%, paid for with INT 12 → 10; WIS 13 would lose its modifier.
        var fighter = character([15, 12, 13, 10, 10, 10], class: "Fighter")
        fighter.adjustForXP()
        #expect(fighter.adjustments == ["str": 1, "int": -2])
        #expect(fighter.adjustmentNotes.isEmpty)

        // Nothing spare to lower: no change.
        var tight = character([15, 9, 14, 10, 10, 10], class: "Fighter")
        tight.adjustForXP()
        #expect(tight.adjustments.isEmpty)

        // Thieves don't lower STR.
        var thief = character([12, 9, 9, 12, 10, 10], class: "Thief")
        thief.adjustForXP()
        #expect(thief.adjustments.isEmpty)
    }

    @Test func randomCharactersAreComplete() {
        let items = OSERuleset.classic.shopItems
        for seed in 1...200 {
            var new = NewCharacter()
            new.name = "Kept"
            new.method = seed.isMultiple(of: 2) ? .fourDropLowest : .rules
            var generator = SeededGenerator(state: UInt64(seed))
            new.rollRandom(items: items, using: &generator)
            #expect(new.name == "Kept" && new.hasAllScores && !new.isSubPar, "seed \(seed)")
            let classRules = try! #require(new.classRules)
            #expect(new.unmetRequirements(for: classRules).isEmpty, "seed \(seed)")
            #expect(new.adjustmentNotes.isEmpty, "seed \(seed): \(new.adjustmentNotes)")
            #expect(new.alignment != nil && new.hitPoints != nil && new.gold != nil)
            #expect(![1, 2].contains(new.hitPointRoll ?? 0), "seed \(seed)")
            #expect(new.unaffordable.isEmpty && new.moneyLeft!.totalCP >= 0)
            for purchase in new.purchases {
                #expect(OSERuleset.classic.restriction(of: purchase.item, for: classRules) == nil,
                        "seed \(seed): \(classRules.name) with \(purchase.item.name)")
            }
            let file = new.makeFile()
            #expect(file.string(["class"]) == classRules.name)
        }
    }

    @Test func aKitForEachClass() throws {
        let items = OSERuleset.classic.shopItems
        func kit(_ className: String, gold: Int) -> [String] {
            var new = character([10, 10, 10, 10, 10, 10], class: className)
            new.gold = gold
            new.buyStartingKit(from: items)
            return new.purchases.map(\.item.id)
        }
        #expect(kit("Fighter", gold: 180) == [
            "sword", "plate", "backpack", "rations-iron-7-days", "torches", "tinder-box-flint-steel", "waterskin",
            "shield", "short-bow", "arrows", "rope-50",
        ])
        #expect(kit("Cleric", gold: 100).prefix(3) == ["holy-symbol", "mace", "chainmail"])
        #expect(kit("Thief", gold: 100).prefix(3) == ["thieves-tools", "sword", "leather"])
        let magicUser = kit("Magic-User", gold: 100)
        #expect(magicUser.first == "dagger" && !magicUser.contains { ["leather", "shield", "sling"].contains($0) })
        // Poor: a weapon and what's left.
        #expect(kit("Fighter", gold: 30).first == "sword")
        #expect(kit("Fighter", gold: 0).isEmpty)
    }

    @Test func aKitFromACustomList() throws {
        let list = try EquipmentList(text: "---\nformatVersion: 1\nkind: equipment\nsystem: ose\nremove: [Sword]\n---\n")
        var new = character([10, 10, 10, 10, 10, 10], class: "Fighter")
        new.gold = 100
        new.buyStartingKit(from: OSERuleset.classic.shopItems(with: list))
        #expect(new.purchases.first?.item.id == "mace")
    }
}
