import Testing
@testable import CharacterKit

@Suite("Finding a file's rules")
struct RulesetLookupTests {
    private func file(_ rules: String, _ more: String = "") throws -> CharacterFile {
        try CharacterFile(text: "---\nformatVersion: 1\nrules: \(rules)\n\(more)---\n")
    }

    @Test func builtInRules() {
        #expect(OSERuleset.classic.system == "ose" && OSERuleset.classic.variant == "classic")
        #expect(OSERuleset.classic.displayName == "Old-School Essentials Classic Fantasy")
        for (system, variant) in [("ose", nil), ("ose", "classic"), ("OSE", "Classic"), ("ose", "")] as [(String, String?)] {
            #expect(OSERuleset.named(system: system, variant: variant)?.variant == "classic", "\(system) \(variant ?? "-")")
        }
        #expect(OSERuleset.named(system: "ose", variant: "advanced") == nil)
        #expect(OSERuleset.named(system: "bfrpg", variant: nil) == nil)
        #expect(OSERuleset.named(system: nil, variant: "classic") == nil)
    }

    @Test func aFileUsesTheRulesItNames() throws {
        let classic = try file("{ system: ose, variant: classic }", "class: Thief\n")
        #expect(classic.namedRuleset?.variant == "classic")
        let analysis = RulesAnalysis(classic)
        #expect(analysis.rules.variant == "classic")
        #expect(!analysis.notes.contains { $0.message.hasPrefix("The app doesn't have the rules") })
    }

    @Test func rulesTheAppDoesntHaveFallBackWithANote() throws {
        let advanced = try file("{ system: ose, variant: advanced }", "class: Fighter\nlevel: 1\n")
        #expect(advanced.namedRuleset == nil && advanced.ruleset.variant == "classic")
        let analysis = RulesAnalysis(advanced)
        #expect(analysis.notes.map(\.message).contains(
            "The app doesn't have the rules for “ose advanced”, so Old-School Essentials Classic Fantasy is used where they match."))
        // Classic Fantasy still fills in what matches.
        #expect(analysis.suggestions[["saves", "death"]] == .int(12))
    }

    @Test func classAbilitiesComeFromTheRulesNotTheName() throws {
        let rules = OSERuleset.classic
        for name in ["Thief", "thief", "THIEF"] {
            #expect(rules.classRules(named: name)?.hasFeature("thief-skills") == true, "\(name)")
        }
        #expect(rules.classRules(named: "dwarf")?.exploration?["constructionTricks"] != nil)
        #expect(rules.classRules(named: "Fighter")?.hasFeature("thief-skills") == false)
        #expect(rules.classRules(named: "magic user")?.spellcasting != nil)
        #expect(rules.classRules(named: "Fighter")?.spellcasting == nil)
        // The sheet's suggestions come from the rules data.
        #expect(rules.classes.map(\.name) == ["Cleric", "Dwarf", "Elf", "Fighter", "Halfling", "Magic-User", "Thief"])
        #expect(rules.alignments == ["Lawful", "Neutral", "Chaotic"])
    }

    @Test func newCharactersRecordTheirRules() {
        var character = NewCharacter()
        character.className = "Fighter"
        let made = character.makeFile()
        #expect(made.system == "ose" && made.variant == "classic")
    }
}
