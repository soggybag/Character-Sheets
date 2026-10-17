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
