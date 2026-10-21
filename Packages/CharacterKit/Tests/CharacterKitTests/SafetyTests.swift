import Foundation
import Testing
@testable import CharacterKit

/// Hand-edited files with values of the wrong kind. The app must neither
/// crash on them nor lose them when something else is edited.
@Suite("Data safety")
struct SafetyTests {
    static let oddHeaders: [String] = [
        "xp: \"1,200\"\nlevel: 3rd\nhp: lots",
        "level: 0\nclass: Fighter\nabilityScores: { str: 0, int: 99, wis: -4, dex: 3, con: 18, cha: 25 }",
        "level: -1\nclass: Elf",
        "level: 999\nclass: Thief\nxp: 99999999999999999999",
        "level: 2147483647\nclass: Cleric\nxp: 9223372036854775807",
        "class: [Fighter, Thief]\nlevel: { a: 1 }",
        "abilityScores: [13, 12, 11]\nsaves: 12\ncombat: fast",
        "languages: Common and Elvish\nequipment: a sword\nspells: 5",
        "equipment:\n  - Sword\n  - 12\n  - [a, b]\n  - { name: 7, qty: many, equipped: maybe }",
        "spells:\n  slots: [one, 2]\n  spellbook: { name: Sleep }\n  memorized: [Sleep]",
        "hp:\n  max: 7.5\n  current: ~\n  rolls: four\ncombat: { ac: \"3 [16]\", thac0: nineteen }",
        "class: Magic-User\nlevel: 14\nxp: 1000000",
        "class: Dwarf\nlevel: 12\nabilityScores: { con: 3 }",
        "rules:\n  system: ose\n  options: [ascendingAC]",
        "name: \"\"\nclass: \"\"\nlevel: \"\"",
    ]

    private func file(_ header: String) throws -> CharacterFile {
        let rules = header.contains("rules:") ? "" : "rules: { system: ose, variant: classic }\n"
        return try CharacterFile(text: "---\nformatVersion: 1\n\(rules)\(header)\n---\n\n# Notes\n\nKeep me.\n")
    }

    @Test(arguments: oddHeaders.indices)
    func rulesNeverCrashOnOddValues(_ index: Int) throws {
        var character = try file(Self.oddHeaders[index])
        let analysis = RulesAnalysis(character)
        for path in analysis.suggestions.keys { _ = analysis.status(of: path, in: character) }
        if let plan = analysis.levelUpPlan(for: character) {
            var levelled = character
            levelled.apply(plan, hitPointRoll: 3)
            #expect(levelled.body == character.body)
        }
        character.fillMissingValues(from: analysis)
        #expect(character.body.contains("Keep me."))
        #expect(try CharacterFile(text: character.text()).text() == character.text())
    }

    @Test(arguments: oddHeaders.indices)
    func oddValuesSurviveUnrelatedEdits(_ index: Int) throws {
        let original = try file(Self.oddHeaders[index])
        var edited = original
        edited.setString("Someone Else", at: ["player"])
        edited.setString(nil, at: ["player"])
        #expect(edited.text() == original.text())
    }

    @Test func settingTheSameValueChangesNothing() throws {
        for url in try FileManager.default.contentsOfDirectory(
            at: URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
                .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
                .appending(path: "examples"), includingPropertiesForKeys: nil) where url.pathExtension == "md" {
            let original = try CharacterFile(text: String(contentsOf: url, encoding: .utf8))
            var edited = original
            for path: NodePath in [["xp"], ["level"], ["hp", "current"], ["combat", "ac"], ["money", "gp"]] {
                edited.setInt(edited.int(path), at: path)
            }
            edited.setString(edited.string(["name"]), at: ["name"])
            #expect(edited.text() == original.text(), "\(url.lastPathComponent)")
        }
    }

    @Test func unusualTextRoundTripsAfterEdits() throws {
        var character = try file("name: Ronk")
        let names = ["Ælfwine “the Bold”", "O'Brien: the #1 fan", "yes", "null", "- dash", "  padded  ",
                     "Line one\nLine two", "🐉 Dragon", "@at", "key: value", "123", "1e5", "~"]
        for name in names {
            character.setString(name, at: ["name"])
            let reloaded = try CharacterFile(text: character.text())
            #expect(reloaded.string(["name"]) == name, "\(name)")
            #expect(reloaded.text() == character.text())
        }
    }
}
