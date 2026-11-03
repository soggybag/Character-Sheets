import Testing
@testable import CharacterKit

@Suite("Skill boxes")
struct SkillBoxTests {
    private func boxes(_ header: String) throws -> (keys: [String], title: String, boxes: [SkillBox]) {
        let file = try CharacterFile(text: "---\nformatVersion: 1\n\(header)---\n")
        let analysis = RulesAnalysis(file)
        let boxes = analysis.skillBoxes(for: file)
        return (boxes.map(\.key), analysis.skillsTitle, boxes)
    }

    @Test func thief() throws {
        let thief = try boxes("rules: { system: ose, variant: classic }\nclass: Thief\nlevel: 1\n")
        #expect(thief.keys == ["climb", "traps", "hearNoise", "hide", "moveSilently", "openLocks", "pickPockets"])
        #expect(thief.title == "Thief Skills")
        #expect(thief.boxes.map(\.label) == ["Climb", "Traps", "Hear", "Hide", "Move", "Locks", "Pockets"])
    }

    @Test func advancedClassesShowTheirOwn() throws {
        let acrobat = try boxes("rules: { system: ose, variant: advanced }\nclass: Acrobat\nlevel: 1\n")
        #expect(acrobat.keys == ["climb", "falling", "hide", "moveSilently", "tightrope"])
        #expect(acrobat.title == "Acrobat Skills")
        let ranger = try boxes("rules: { system: ose, variant: advanced }\nclass: Ranger\nlevel: 1\n")
        #expect(ranger.keys == ["tracking"])
        let assassin = try boxes("rules: { system: ose, variant: advanced }\nclass: Assassin\nlevel: 1\n")
        let assassination = try #require(assassin.boxes.first)
        #expect(assassination.kind == .modifier && assassination.text(-2) == "−2" && assassination.suffix == "")
        #expect(assassin.boxes[2].text(3) == "3 in 6")
    }

    @Test func noneForClassesWithout() throws {
        #expect(try boxes("rules: { system: ose, variant: classic }\nclass: Fighter\nlevel: 1\n").keys.isEmpty)
        #expect(try boxes("rules: { system: ose, variant: classic }\n").keys.isEmpty)
    }

    @Test func valuesInTheFileAreAlwaysShown() throws {
        // No class with skills: the thief's boxes.
        let typed = try boxes("rules: { system: ose, variant: classic }\nclass: Fighter\nthiefSkills: { climb: 90 }\n")
        #expect(typed.keys.count == 7 && typed.title == "Skills")
        // A skill the class doesn't have is added after the class's.
        let extra = try boxes("rules: { system: ose, variant: advanced }\nclass: Ranger\nthiefSkills: { openLocks: 15, juggling: 40 }\n")
        #expect(extra.keys == ["tracking", "openLocks", "juggling"])
        #expect(extra.boxes.last?.label == "juggling")
    }
}
