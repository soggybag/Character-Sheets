import Foundation
import Testing
@testable import CharacterKit

@Suite("Party")
struct PartyTests {
    private let examples = URL(filePath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
        .appending(path: "examples")

    @Test func loadsEveryExample() throws {
        let party = PartyMember.load(folder: examples)
        let files = try FileManager.default.contentsOfDirectory(at: examples, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "md" }
        #expect(party.count == files.count)
        #expect(party.map(\.name) == party.map(\.name).sorted { $0.localizedStandardCompare($1) == .orderedAscending })
        let ronk = try #require(party.first { $0.name == "Ronk" })
        #expect(ronk.className == "Fighter")
        #expect(ronk.level == 1)
        #expect(ronk.currentHP == 4 && ronk.maxHP == 4)
        #expect(ronk.ac == 2 && ronk.attack == 19 && !ronk.ascendingAC)
        #expect(ronk.saves == ["death": 12, "wands": 13, "paralysis": 14, "breath": 15, "spells": 16])
    }

    @Test func missingValuesComeFromTheRules() throws {
        let file = try CharacterFile(text: """
            ---
            formatVersion: 1
            rules: { system: ose, variant: classic, options: { ascendingAC: true } }
            class: Cleric
            level: 1
            ---
            """)
        let member = PartyMember(file: file, url: URL(filePath: "/party/Brother Anselm.md"))
        #expect(member.name == "Brother Anselm")
        #expect(member.attack == 0)
        #expect(member.saves["death"] == 11)
        #expect(member.currentHP == nil)
    }

    @Test func skipsFilesThatArentCharacters() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try "# Session notes\n".write(to: folder.appending(path: "Notes.md"), atomically: true, encoding: .utf8)
        try "---\nformatVersion: 1\nrules: { system: ose }\nname: Ronk\n---\n"
            .write(to: folder.appending(path: "Ronk.md"), atomically: true, encoding: .utf8)
        try "not: [valid".write(to: folder.appending(path: "Broken.md"), atomically: true, encoding: .utf8)
        try "---\nformatVersion: 1\nrules: { system: ose }\n---\n"
            .write(to: folder.appending(path: "Hidden.txt"), atomically: true, encoding: .utf8)
        #expect(PartyMember.load(folder: folder).map(\.name) == ["Ronk"])
    }
}
