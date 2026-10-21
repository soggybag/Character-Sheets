import Testing
@testable import CharacterKit

@Suite("Class abilities")
struct ClassAbilityTests {
    private func analysis(_ className: String, level: Int?) throws -> RulesAnalysis {
        let levelLine = level.map { "level: \($0)\n" } ?? ""
        return RulesAnalysis(try CharacterFile(
            text: "---\nformatVersion: 1\nrules: { system: ose }\nclass: \(className)\n\(levelLine)---\n"))
    }

    @Test func abilitiesArriveByLevel() throws {
        let first = try analysis("Thief", level: 1)
        #expect(first.classAbilities.map(\.id) == ["back-stab", "thief-skills"])
        // Soonest first, whatever order the rules list them in.
        #expect(first.laterAbilities.map(\.id) == ["read-languages", "hideout", "scroll-use"])
        #expect(first.laterAbilities.map(\.minLevel) == [4, 9, 10])

        let fourth = try analysis("Thief", level: 4)
        #expect(fourth.classAbilities.map(\.id) == ["back-stab", "thief-skills", "read-languages"])
        #expect(try analysis("thief", level: 14).laterAbilities.isEmpty)
    }

    @Test func everyClassHasAbilitiesAtFirstLevel() throws {
        for classRules in OSERuleset.classic.classes {
            let abilities = try analysis(classRules.name, level: 1).classAbilities
            #expect(!abilities.isEmpty, "\(classRules.name)")
            #expect(abilities.allSatisfy { !$0.summary.isEmpty && !$0.name.isEmpty }, "\(classRules.name)")
        }
        #expect(try analysis("Dwarf", level: 1).classAbilities.contains { $0.summary == "Sees heat in the dark to 60'." })
    }

    @Test func noLevelMeansFirstLevel() throws {
        #expect(try analysis("Cleric", level: nil).classAbilities.map(\.id) == ["divine-magic", "turn-undead"])
    }

    @Test func noClassNoAbilities() throws {
        let unknown = try analysis("Barbarian", level: 3)
        #expect(unknown.classAbilities.isEmpty && unknown.laterAbilities.isEmpty)
    }
}
