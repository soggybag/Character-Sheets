import Testing
@testable import CharacterKit

@Suite("Movement")
struct MovementTests {
    private func file(_ body: String, encumbrance: String = "basic") throws -> CharacterFile {
        try CharacterFile(text: """
            ---
            formatVersion: 1
            rules: { system: ose, options: { encumbrance: \(encumbrance) } }
            class: Fighter
            level: 1
            \(body)
            ---

            """)
    }

    @Test func encounterAndTravelRates() {
        #expect(MovementInfo.encounter(120) == 40 && MovementInfo.travel(120) == 24)
        #expect(MovementInfo.encounter(90) == 30 && MovementInfo.travel(90) == 18)
        #expect(MovementInfo.encounter(30) == 10 && MovementInfo.travel(30) == 6)
    }

    @Test func basicEncumbranceFromArmourAndTreasure() throws {
        let chain = try file("equipment: [{ name: Chainmail }]")
        #expect(RulesAnalysis(chain).movement == MovementInfo(load: .basic(carryingTreasure: false),
                                                              unencumbered: 60, rate: 60))
        let laden = try file("carryingTreasure: true\nequipment: [{ name: Leather armour }]")
        let movement = try #require(RulesAnalysis(laden).movement)
        #expect(movement.load == .basic(carryingTreasure: true))
        #expect(movement.unencumbered == 90 && movement.rate == 60)
        #expect(RulesAnalysis(laden).suggestions[["movement"]] == .int(60))
    }

    @Test func detailedEncumbranceCountsCoins() throws {
        let file = try file("equipment: [{ name: Chainmail }, { name: Rope }]\nmoney: { gp: 150 }", encumbrance: "detailed")
        // 400 chainmail + 80 gear + 150 coins = 630: the 601–800 band.
        #expect(RulesAnalysis(file).movement == MovementInfo(load: .detailed(coins: 630), unencumbered: 120, rate: 60))
    }

    @Test func untracked() throws {
        let file = try file("carryingTreasure: true\nequipment: [{ name: Plate mail }]", encumbrance: "none")
        #expect(RulesAnalysis(file).movement == MovementInfo(load: .untracked, unencumbered: 120, rate: 120))
    }

    @Test func twoSuitsOfArmourUseTheBestUnlessOneIsEquipped() throws {
        let both = try file("equipment: [{ name: Leather armour }, { name: Chainmail }]")
        let analysis = RulesAnalysis(both)
        #expect(analysis.movement?.rate == 60 && analysis.suggestions[["combat", "ac"]] == nil)
        #expect(analysis.notes.contains { $0.message.hasPrefix("More than one suit of armour (leather, chainmail)") })

        let worn = try file("abilityScores: { dex: 10 }\nequipment: [{ name: Leather armour, equipped: true }, { name: Chainmail }]")
        let wornAnalysis = RulesAnalysis(worn)
        #expect(wornAnalysis.movement?.rate == 90 && wornAnalysis.suggestions[["combat", "ac"]] == .int(7))
        #expect(!wornAnalysis.notes.contains { $0.message.hasPrefix("More than one suit") })
    }

    @Test func carryingTreasureMovesARateThatFollowedTheRules() throws {
        var file = try file("movement: 120")
        file.setCarryingTreasure(true)
        #expect(file.bool(["carryingTreasure"]) == true && file.int(["movement"]) == 90)
        #expect(file.text().contains("movement: 90\ncarryingTreasure: true\n"))
        file.setCarryingTreasure(false)
        #expect(file.bool(["carryingTreasure"]) == nil && file.int(["movement"]) == 120)

        // Boots of speed: set by hand, so kept.
        var fast = try self.file("movement: 240")
        fast.setCarryingTreasure(true)
        #expect(fast.int(["movement"]) == 240)
    }
}
