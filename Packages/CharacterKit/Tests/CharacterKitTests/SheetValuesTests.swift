import Testing
@testable import CharacterKit

/// Values the sheet shows that are worked out here, not in the app.
@Suite("Sheet values")
struct SheetValuesTests {
    private func file(_ header: String) throws -> CharacterFile {
        try CharacterFile(text: "---\nformatVersion: 1\nrules: { system: ose }\nclass: Fighter\nlevel: 1\n\(header)\n---\n")
    }

    @Test func signedText() {
        #expect(1.signedText == "+1" && 0.signedText == "+0" && (-2).signedText == "-2")
    }

    @Test func storedOrRulesValue() throws {
        let stored = try file("abilityScores: { dex: 10 }\ncombat: { ac: 4 }")
        #expect(RulesAnalysis(stored).value(at: ["combat", "ac"], in: stored) == 4)
        let missing = try file("abilityScores: { dex: 10 }")
        #expect(RulesAnalysis(missing).value(at: ["combat", "ac"], in: missing) == 9)
        #expect(RulesAnalysis(missing).value(at: ["hp", "max"], in: missing) == nil)
    }

    @Test func conModifier() throws {
        #expect(RulesAnalysis(try file("abilityScores: { con: 16 }")).conModifier == 2)
        #expect(RulesAnalysis(try file("abilityScores: { con: 5 }")).conModifier == -2)
        #expect(RulesAnalysis(try file("")).conModifier == 0)
    }

    // MARK: Movement

    @Test func movementFollowsTheStoredRate() throws {
        let file = try file("movement: 90\nequipment: [{ name: Leather armour }]")
        let movement = MovementSummary(file: file, analysis: RulesAnalysis(file))
        #expect(movement.rate == 90 && movement.encounterRate == 30 && movement.travelRate == 18)
        // Leather is light armour: 90' is its unencumbered rate.
        #expect(!movement.isEncumbered)
        #expect(movement.explanation == "Unencumbered: 90' per turn, 30' per round.")
    }

    @Test func encumberedMovement() throws {
        let laden = try file("carryingTreasure: true")
        let movement = MovementSummary(file: laden, analysis: RulesAnalysis(laden))
        #expect(movement.rate == 90 && movement.isEncumbered)
        #expect(movement.explanation == "Carrying treasure. Unencumbered: 120' per turn, 40' per round.")

        let heavy = try CharacterFile(text: """
            ---
            formatVersion: 1
            rules: { system: ose, options: { encumbrance: detailed } }
            class: Fighter
            equipment: [{ name: Chainmail }]
            money: { gp: 150 }
            ---
            """)
        let detailed = MovementSummary(file: heavy, analysis: RulesAnalysis(heavy))
        #expect(detailed.isEncumbered && detailed.explanation.hasPrefix("Carrying 550 coins of weight."))
    }

    @Test func untrackedMovementIsNeverEncumbered() throws {
        let file = try CharacterFile(text: "---\nformatVersion: 1\nrules: { system: ose, options: { encumbrance: none } }\nmovement: 30\n---\n")
        let movement = MovementSummary(file: file, analysis: RulesAnalysis(file))
        #expect(!movement.isEncumbered && movement.explanation == "")
    }

    // MARK: Edit as Text status

    @Test func textStatus() {
        #expect(TextFileStatus(text: "---\nformatVersion: 1\nrules: { system: ose }\nname: Ronk\nclass: Fighter\nlevel: 2\n---\n",
                               fileName: "x") == .character(summary: "Ronk · Fighter · level 2"))
        #expect(TextFileStatus(text: "---\nformatVersion: 1\nrules: { system: ose }\n---\n", fileName: "Ronk")
                == .character(summary: "Ronk"))
        #expect(TextFileStatus(text: "# Just notes", fileName: nil) == .notACharacter)
        #expect(TextFileStatus(text: "---\ntitle: A blog post\n---\n", fileName: nil) == .notACharacter)
        #expect(TextFileStatus(text: "---\nname: [oops\n---\n", fileName: nil) != .notACharacter)
        #expect(TextFileStatus(text: EquipmentList.template(name: "Market"), fileName: nil)
                == .equipmentList(summary: "Equipment list: Market · No changes yet", problems: []))
    }
}
