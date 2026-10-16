import Foundation

/// What changes when a character gains a level. Only automatic values change
/// (those that matched the rules, or were missing); overrides are kept.
public struct LevelUpPlan: Sendable {
    public struct Change: Sendable {
        public let path: NodePath
        public let from: RulesValue?
        public let to: RulesValue
    }

    public enum HitPoints: Equatable, Sendable {
        /// Roll `1d<sides>` and add the CON modifier (at least 1 in total).
        case roll(sides: Int, conModifier: Int)
        /// A fixed gain from the table (high levels, where CON no longer counts).
        case fixed(Int)
    }

    public let fromLevel: Int
    public let toLevel: Int
    public let changes: [Change]
    /// Fields that differ from the rules and are left alone.
    public let keptOverrides: [NodePath]
    public let hitPoints: HitPoints?

    /// Hit points gained for a given die roll (ignored for fixed gains).
    public func hitPointGain(roll: Int) -> Int? {
        switch hitPoints {
        case let .roll(_, conModifier): max(1, roll + conModifier)
        case let .fixed(gain): gain
        case nil: nil
        }
    }
}

extension RulesAnalysis {
    /// The plan for going up one level, or nil if the class or level is
    /// unknown. Going past the class maximum is allowed (rules notes say so).
    public func levelUpPlan(for file: CharacterFile, rules: OSERuleset = .classic) -> LevelUpPlan? {
        guard let classRules, let level else { return nil }
        var next = file
        next.setInt(level + 1, at: ["level"])
        let after = RulesAnalysis(next, rules: rules)

        var changes: [LevelUpPlan.Change] = []
        var kept: [NodePath] = []
        for (path, newValue) in after.suggestions.sorted(by: { $0.key.dotted < $1.key.dotted }) {
            switch status(of: path, in: file) {
            case .matches, .noRule:
                if suggestions[path] != newValue {
                    changes.append(.init(path: path, from: suggestions[path], to: newValue))
                }
            case .missing:
                changes.append(.init(path: path, from: nil, to: newValue))
            case .overridden:
                if suggestions[path] != newValue { kept.append(path) }
            }
        }

        let hitPoints: LevelUpPlan.HitPoints?
        if let oldRow = classRules.row(level: level), let newRow = classRules.row(level: level + 1) {
            if newRow.conModifier == false {
                hitPoints = .fixed(newRow.hitPointBonus - oldRow.hitPointBonus)
            } else {
                let sides = Int(classRules.hitDie.dropFirst()) ?? 6
                hitPoints = .roll(sides: sides, conModifier: abilities["con"].flatMap { Int($0.headline) } ?? 0)
            }
        } else {
            hitPoints = nil
        }
        return LevelUpPlan(fromLevel: level, toLevel: level + 1, changes: changes, keptOverrides: kept,
                           hitPoints: hitPoints)
    }
}

extension CharacterFile {
    /// Applies a level-up. `hitPointRoll` is the die result (before CON) for
    /// rolled gains; pass nil to leave hit points alone.
    public mutating func apply(_ plan: LevelUpPlan, hitPointRoll: Int?) {
        setInt(plan.toLevel, at: ["level"])
        for change in plan.changes {
            setRulesValue(change.to, at: change.path)
        }
        let roll: Int? = if case .fixed = plan.hitPoints { 0 } else { hitPointRoll }
        if let roll, let gain = plan.hitPointGain(roll: roll), let max = int(["hp", "max"]) {
            setInt(max + gain, at: ["hp", "max"])
            setInt((int(["hp", "current"]) ?? max) + gain, at: ["hp", "current"])
            if case .roll = plan.hitPoints, count(["hp", "rolls"]) > 0 {
                appendInt(roll, to: ["hp", "rolls"])
            }
        }
    }
}

extension CharacterFile {
    /// Writes a value from the rules.
    public mutating func setRulesValue(_ value: RulesValue, at path: NodePath) {
        switch value {
        case let .int(number):
            setInt(number, at: path)
        case let .ints(numbers):
            self[path] = nil
            for number in numbers { appendInt(number, to: path) }
        }
    }

    /// Writes the rules value into every field that's empty. Returns how many
    /// fields were filled.
    @discardableResult
    public mutating func fillMissingValues(from analysis: RulesAnalysis) -> Int {
        var filled = 0
        for (path, value) in analysis.suggestions.sorted(by: { $0.key.dotted < $1.key.dotted })
        where analysis.status(of: path, in: self) == .missing(rules: value) {
            setRulesValue(value, at: path)
            filled += 1
        }
        return filled
    }
}

extension NodePath {
    /// `saves.death`, `equipment.2.name`
    public var dotted: String { map(\.description).joined(separator: ".") }
}
