import Testing
@testable import CharacterKit

@Suite("Spells")
struct SpellTests {
    private func file(_ spells: String) throws -> CharacterFile {
        try CharacterFile(text: "---\nformatVersion: 1\nrules: { system: ose, variant: classic }\nclass: Magic-User\nlevel: 3\nspells:\n\(spells)\n---\n")
    }

    private let elowen = """
          slots: [2, 1]
          spellbook:
            - { name: Sleep, level: 1 }
            - { name: Magic Missile, level: 1 }
            - { name: Web, level: 2 }
          memorized:
            - { name: Sleep, cast: true }
            - { name: sleep }
            - { name: Cure Light Wounds, level: 1 }
        """

    @Test func rowsJoinTheBookAndMemorized() throws {
        let rows = try file(elowen).spellRows
        #expect(rows.map(\.name) == ["Sleep", "Magic Missile", "Web", "Cure Light Wounds"])
        #expect(rows.map(\.memorized) == [[0, 1], [], [], [2]])
        #expect(rows[3].bookIndex == nil && rows[3].level == 1)
        #expect(try file(elowen).memorizedCount(level: 1) == 3)
        #expect(try file(elowen).memorizedCount(level: 2) == 0)
    }

    @Test func memorizeAndForget() throws {
        var character = try file(elowen)
        character.memorize(character.spellRows[2])
        #expect(character.spellRows[2].memorized == [3])
        #expect(character.string(["spells", "memorized", 3, "name"]) == "Web")
        #expect(character.int(["spells", "memorized", 3, "level"]) == nil)
        // The uncast copy goes first.
        character.forgetOne(character.spellRows[0])
        #expect(character.spellRows[0].memorized == [0])
        #expect(character.isCast(memorized: 0))
        character.forgetOne(character.spellRows[0])
        #expect(character.spellRows[0].memorized.isEmpty)
        character.forgetOne(character.spellRows[0])
        #expect(character.spellRows.count == 4)
    }

    @Test func castAndRest() throws {
        var character = try file(elowen)
        character.setCast(true, memorized: 1)
        #expect(character.castSpellCount == 2)
        character.setCast(false, memorized: 1)
        #expect(character.string(["spells", "memorized", 1, "cast"]) == nil)
        character.resetCastSpells()
        #expect(character.castSpellCount == 0)
    }

    @Test func renameFollowsTheCopies() throws {
        var character = try file(elowen)
        character.renameSpell(character.spellRows[0], to: "Sleep (reversed)")
        #expect(character.spellRows[0].memorized == [0, 1])
        #expect(character.string(["spells", "memorized", 1, "name"]) == "Sleep (reversed)")
        let before = character.text()
        character.renameSpell(character.spellRows[0], to: "  ")
        #expect(character.text() == before)
    }

    @Test func levelPutsAMemorizedSpellInTheBook() throws {
        var character = try file(elowen)
        character.setSpellLevel(character.spellRows[3], to: 1)
        let rows = character.spellRows
        #expect(rows.count == 4)
        #expect(rows[3].bookIndex == 3 && rows[3].memorized == [2])
        #expect(character.int(["spells", "memorized", 2, "level"]) == nil)
    }

    @Test func removeTakesTheCopiesToo() throws {
        var character = try file(elowen)
        character.removeSpell(character.spellRows[0])
        #expect(character.spellRows.map(\.name) == ["Magic Missile", "Web", "Cure Light Wounds"])
        #expect(character.spellRows[2].memorized == [0])
    }

    @Test func blankAndRepeatedEntries() throws {
        var character = try file("""
              spellbook:
                - { name: Sleep, level: 1 }
                - { name: SLEEP, level: 1 }
              memorized:
                - { name: Sleep }
            """)
        #expect(character.spellRows.map(\.memorized) == [[0], []])
        character.addSpell()
        let blank = character.spellRows[2]
        #expect(blank.name == "" && blank.level == 1)
        character.memorize(blank)
        #expect(character.count(["spells", "memorized"]) == 1)
    }
}
