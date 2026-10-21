import Testing
import Yams
@testable import CharacterKit

private func file(_ header: String, body: String = "") throws -> CharacterFile {
    try CharacterFile(text: "---\n" + header + "---\n" + body)
}

/// The header text of a file with an empty body.
private func header(_ file: CharacterFile) -> String {
    String(file.text().dropFirst("---\n".count).dropLast("---\n".count))
}

@Suite("Editing values")
struct EditingTests {
    @Test func readsNestedValues() throws {
        let f = try file("hp:\n  max: 9\nequipment:\n  - { name: Sword, qty: 1 }\n")
        #expect(f.int(["hp", "max"]) == 9)
        #expect(f.string(["equipment", 0, "name"]) == "Sword")
        #expect(f.string(["equipment", 1, "name"]) == nil)
        #expect(f.int(["missing", "path"]) == nil)
    }

    @Test func replacingAValueKeepsItsPlace() throws {
        var f = try file("name: Ronk\nlevel: 1\nxp: 0\n")
        f.setInt(2, at: ["level"])
        #expect(header(f) == "name: Ronk\nlevel: 2\nxp: 0\n")
    }

    @Test func newKeysGoInTheStandardPosition() throws {
        var f = try file("formatVersion: 1\nname: Ronk\nxp: 0\nmoney: { gp: 9 }\n")
        f.setString("Fighter", at: ["class"])
        f.setInt(1, at: ["level"])
        f.setInt(4, at: ["hp", "max"])
        #expect(header(f) == """
        formatVersion: 1
        name: Ronk
        class: Fighter
        level: 1
        xp: 0
        hp:
          max: 4
        money: { gp: 9 }

        """)
    }

    @Test func newKeysInsideMapsAreOrderedToo() throws {
        var f = try file("saves: { death: 12, spells: 16 }\n")
        f.setInt(15, at: ["saves", "breath"])
        f.setInt(13, at: ["saves", "wands"])
        #expect(header(f) == "saves: { death: 12, wands: 13, breath: 15, spells: 16 }\n")
    }

    @Test func newContainersUseTheHouseStyle() {
        var f = CharacterFile()
        f.setInt(13, at: ["abilityScores", "str"])
        f.setInt(19, at: ["combat", "thac0"])
        f.setInt(37, at: ["money", "gp"])
        f.setStrings(["Common", "Elvish"], at: ["languages"])
        f.append(Node([(Node("name"), .text("Sword")), (Node("equipped"), Node("true"))]), to: ["equipment"])
        #expect(header(f) == """
        abilityScores: { str: 13 }
        combat:
          thac0: 19
        languages: [Common, Elvish]
        equipment:
          - { name: Sword, equipped: true }
        money: { gp: 37 }

        """)
    }

    @Test func clearingRemovesTheKeyAndEmptyParents() throws {
        var f = try file("name: Ronk\nmoney: { gp: 9 }\nhp:\n  max: 4\n  current: 4\n")
        f.setInt(nil, at: ["money", "gp"])
        f.setInt(nil, at: ["hp", "current"])
        f.setString("", at: ["name"])
        #expect(header(f) == "hp:\n  max: 4\n")
    }

    @Test func removingSomethingMissingChangesNothing() throws {
        var f = try file("name: Ronk\n")
        f.setInt(nil, at: ["hp", "max"])
        f.removeItem(at: ["equipment", 3])
        #expect(header(f) == "name: Ronk\n")
    }

    @Test func editingListItems() throws {
        var f = try file("equipment:\n  - { name: Sword }\n  - { name: Torches, qty: 6 }\n  - { name: Rope }\n")
        f.setInt(5, at: ["equipment", 1, "qty"])
        f.setBool(true, at: ["equipment", 0, "equipped"])
        f.removeItem(at: ["equipment", 2])
        #expect(header(f) == "equipment:\n  - { name: Sword, equipped: true }\n  - { name: Torches, qty: 5 }\n")
        f.moveItem(in: ["equipment"], from: 1, to: 0)
        #expect(f.string(["equipment", 0, "name"]) == "Torches")
        f.moveItem(in: ["equipment"], from: 0, to: 1)
        #expect(header(f) == "equipment:\n  - { name: Sword, equipped: true }\n  - { name: Torches, qty: 5 }\n")
        f.moveItem(in: ["equipment"], from: 1, to: 0)
        f.removeItem(at: ["equipment", 0])
        f.removeItem(at: ["equipment", 0])
        #expect(header(f) == "")
    }

    @Test func outOfRangeWritesAreIgnored() throws {
        var f = try file("equipment:\n  - { name: Sword }\n")
        f.setString("Axe", at: ["equipment", 5, "name"])
        #expect(f.count(["equipment"]) == 1)
    }

    @Test func textThatLooksLikeOtherTypesStaysText() throws {
        var f = CharacterFile()
        f.setString("No", at: ["name"])
        f.setStrings(["Yes", "12"], at: ["languages"])
        let reread = try CharacterFile(text: f.text())
        #expect(reread.string(["name"]) == "No")
        #expect(reread.strings(["languages"]) == ["Yes", "12"])
    }

    @Test func unknownKeysAreReported() throws {
        let f = try file("formatVersion: 1\nhomebrew: { sanity: 3 }\nname: Ronk\nnotesFromGM: hi\n")
        #expect(f.unknownTopLevelKeys == ["homebrew", "notesFromGM"])
    }

    @Test func headerCommentsAreDetected() throws {
        #expect(try file("# my notes\nname: Ronk\n").headerHadComments)
        #expect(try !file("name: Ronk\n").headerHadComments)
    }
}

@Suite("Ascending AC")
struct AscendingACTests {
    @Test func switchingConvertsACAndAttack() throws {
        var f = try file("rules:\n  system: ose\ncombat:\n  ac: 5\n  thac0: 19\n")
        f.setAscendingAC(true)
        #expect(f.usesAscendingAC)
        #expect(f.int(["combat", "ac"]) == 14)
        #expect(f.int(["combat", "attackBonus"]) == 0)
        #expect(f.int(["combat", "thac0"]) == nil)
        f.setAscendingAC(false)
        #expect(f.int(["combat", "ac"]) == 5)
        #expect(f.int(["combat", "thac0"]) == 19)
        #expect(header(f) == "rules:\n  system: ose\n  options:\n    ascendingAC: false\ncombat:\n  ac: 5\n  thac0: 19\n")
    }

    @Test func settingTheSameStyleConvertsNothing() throws {
        var f = try file("combat:\n  ac: 5\n")
        f.setAscendingAC(false)
        #expect(f.int(["combat", "ac"]) == 5)
    }
}

@Suite("Thread safety")
struct TagTests {
    /// Tags of every node, without triggering Yams's lazy resolution.
    private func tags(_ node: Node) -> [String] {
        switch node {
        case let .scalar(scalar): [scalar.tag.description]
        case let .mapping(mapping): [mapping.tag.description] + mapping.flatMap { tags($0.key) + tags($0.value) }
        case let .sequence(sequence): [sequence.tag.description] + sequence.flatMap(tags)
        case .alias: []
        }
    }

    @Test func everyNodeHasAnExplicitTagAfterLoadingAndEditing() throws {
        var f = try CharacterFile(text: CharacterFile.newCharacterTemplate)
        f.setString("Ronk", at: ["name"])
        f.setInt(4, at: ["hp", "max"])
        f.setBool(true, at: ["rules", "options", "ascendingAC"])
        f.setStrings(["Common"], at: ["languages"])
        let item = f.appendItem(to: ["equipment"])
        f.setString("Sword", at: ["equipment", .index(item), "name"])
        f.appendInt(2, to: ["spells", "slots"])
        #expect(!tags(f.header).contains(""))
    }

    @Test func newItemsUseFlowStyle() {
        var f = CharacterFile()
        let index = f.appendItem(to: ["spells", "spellbook"])
        f.setInt(1, at: ["spells", "spellbook", .index(index), "level"])
        f.setString("Sleep", at: ["spells", "spellbook", .index(index), "name"])
        #expect(f.text() == "---\nspells:\n  spellbook:\n    - { name: Sleep, level: 1 }\n---\n")
    }
}
