import Foundation

/// One skill box on the sheet, for a value in `thiefSkills`.
public struct SkillBox: Sendable, Equatable, Identifiable {
    /// The key in `thiefSkills`, e.g. `moveSilently`.
    public let key: String
    /// Short, for the box ("Move").
    public let label: String
    /// In full, for help and lists ("Move silently").
    public let name: String
    public let kind: ClassRules.Skill.Kind

    public var id: String { key }
    public var path: NodePath { ["thiefSkills", .key(key)] }

    /// "%", "in 6", or nothing for a modifier.
    public var suffix: String {
        switch kind {
        case .percent: "%"
        case .inSix: "in 6"
        case .modifier: ""
        }
    }

    /// The value as shown on paper: "35%", "2 in 6", "−2".
    public func text(_ value: Int) -> String {
        switch kind {
        case .percent: "\(value)%"
        case .inSix: "\(value) in 6"
        case .modifier: value < 0 ? "−\(-value)" : "\(value)"
        }
    }

    /// Box labels for the known keys; anything else uses its name.
    private static let labels = [
        "climb": "Climb", "traps": "Traps", "hearNoise": "Hear", "hide": "Hide", "moveSilently": "Move",
        "openLocks": "Locks", "pickPockets": "Pockets", "falling": "Falling", "tightrope": "Tightrope",
        "assassination": "Assassinate", "tracking": "Tracking",
    ]

    init(_ skill: ClassRules.Skill) {
        key = skill.key
        name = skill.name
        kind = skill.kind
        label = Self.labels[skill.key] ?? skill.name
    }

    /// The thief's skills, for a file that has skill values but no class
    /// that lists its own.
    static let thief: [SkillBox] = OSERuleset.classic.classRules(named: "thief")?.skills?.map(SkillBox.init) ?? []
}

extension RulesAnalysis {
    /// The boxes the Skills section shows: the class's skills, then any
    /// other skill the file has a value for. Empty when there's nothing to
    /// show.
    public func skillBoxes(for file: CharacterFile) -> [SkillBox] {
        var boxes = classRules?.skills?.map(SkillBox.init) ?? []
        let inFile = file.keys(["thiefSkills"])
        if boxes.isEmpty, !inFile.isEmpty { boxes = SkillBox.thief }
        let shown = Set(boxes.map(\.key))
        for key in inFile where !shown.contains(key) {
            boxes.append(SkillBox.thief.first { $0.key == key }
                ?? SkillBox(ClassRules.Skill(key: key, name: key, kind: .percent)))
        }
        return boxes
    }

    /// "Acrobat Skills", or "Skills" without a class that has its own.
    public var skillsTitle: String {
        guard let classRules, classRules.skills != nil else { return "Skills" }
        return "\(classRules.name) Skills"
    }
}
