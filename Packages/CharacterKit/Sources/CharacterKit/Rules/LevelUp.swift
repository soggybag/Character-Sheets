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
    /// XP the new level starts at, when the character has less (a level
    /// awarded by the referee, or a sheet that never tracked XP).
    public let xpShortfall: (needed: Int, have: Int)?

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
        let (changes, kept) = ruleChanges(for: file, toLevel: level + 1, rules: rules)

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
        let have = file.int(["xp"]) ?? 0
        let shortfall = classRules.row(level: level + 1).flatMap { $0.xp > have ? ($0.xp, have) : nil }
        return LevelUpPlan(fromLevel: level, toLevel: level + 1, changes: changes, keptOverrides: kept,
                           hitPoints: hitPoints, xpShortfall: shortfall)
    }
}

/// What changes when a character loses a level (energy drain, a curse).
/// Like a level-up, only automatic values change.
public struct LevelDownPlan: Sendable {
    public let fromLevel: Int
    public let toLevel: Int
    public let changes: [LevelUpPlan.Change]
    public let keptOverrides: [NodePath]
    /// XP the lower level starts at, when the character has more XP than
    /// that level allows.
    public let xpReset: (to: Int, have: Int)?
    /// Hit points the lost level gave, when the sheet knows: the last
    /// recorded roll plus CON, or the table's fixed gain at high levels.
    public let suggestedHitPointLoss: Int?
}

extension RulesAnalysis {
    /// The plan for losing a level, or nil at 1st level or when the class or
    /// level is unknown.
    public func levelDownPlan(for file: CharacterFile, rules: OSERuleset = .classic) -> LevelDownPlan? {
        guard let classRules, let level, level > 1 else { return nil }
        let (changes, kept) = ruleChanges(for: file, toLevel: level - 1, rules: rules)
        let fromRow = classRules.row(level: level)
        let toRow = classRules.row(level: level - 1)

        let have = file.int(["xp"]) ?? 0
        let reset: (Int, Int)? = if let fromRow, let toRow, have >= fromRow.xp { (toRow.xp, have) } else { nil }

        let loss: Int?
        if let fromRow, let toRow, fromRow.conModifier == false {
            loss = fromRow.hitPointBonus - toRow.hitPointBonus
        } else if file.count(["hp", "rolls"]) >= level, let last = file.int(["hp", "rolls", .index(level - 1)]) {
            loss = max(1, last + (abilities["con"].flatMap { Int($0.headline) } ?? 0))
        } else {
            loss = nil
        }
        return LevelDownPlan(fromLevel: level, toLevel: level - 1, changes: changes, keptOverrides: kept,
                             xpReset: reset, suggestedHitPointLoss: loss)
    }

    /// Rules values that change when the level changes. Automatic values
    /// (matching or missing) change; overrides are listed and kept.
    fileprivate func ruleChanges(for file: CharacterFile, toLevel: Int,
                                 rules: OSERuleset) -> ([LevelUpPlan.Change], [NodePath]) {
        var next = file
        next.setInt(toLevel, at: ["level"])
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
        return (changes, kept)
    }
}

extension RulesAnalysis {
    /// The hit dice at the current level as dice to roll, e.g. 3d4 or 9d8+2.
    public var hitDiceToRoll: Dice? { hitDice.flatMap { Dice($0) } }

    /// Max HP from rolling every hit die at the current level: each die adds
    /// the CON modifier and gives at least 1; the table's fixed bonus (the
    /// +2 in 9d8+2, gained when CON no longer counts) is added once.
    public func hitPoints(fromDice results: [Int]) -> Int? {
        guard let dice = hitDiceToRoll else { return nil }
        let con = abilities["con"].flatMap { Int($0.headline) } ?? 0
        return results.reduce(0) { $0 + max(1, $1 + con) } + dice.modifier
    }
}

extension CharacterFile {
    /// Applies a level-up. `hitPointRoll` is the die result (before CON) for
    /// rolled gains; pass nil to leave hit points alone. `raiseXP` sets XP to
    /// the new level's minimum when it's short.
    public mutating func apply(_ plan: LevelUpPlan, hitPointRoll: Int?, raiseXP: Bool = false) {
        setInt(plan.toLevel, at: ["level"])
        if raiseXP, let shortfall = plan.xpShortfall {
            setInt(shortfall.needed, at: ["xp"])
        }
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
    /// Applies a lost level. `hitPointLoss` comes off max HP (leaving at
    /// least 1), and current HP drops only if it's above the new max.
    /// `resetXP` sets XP to the start of the lower level.
    public mutating func apply(_ plan: LevelDownPlan, hitPointLoss: Int?, resetXP: Bool) {
        setInt(plan.toLevel, at: ["level"])
        for change in plan.changes {
            setRulesValue(change.to, at: change.path)
        }
        if resetXP, let reset = plan.xpReset {
            setInt(reset.to, at: ["xp"])
        }
        if let hitPointLoss, let max = int(["hp", "max"]) {
            let newMax = Swift.max(1, max - hitPointLoss)
            setInt(newMax, at: ["hp", "max"])
            if let current = int(["hp", "current"]), current > newMax {
                setInt(newMax, at: ["hp", "current"])
            }
            if count(["hp", "rolls"]) > plan.toLevel {
                removeItem(at: ["hp", "rolls", .index(count(["hp", "rolls"]) - 1)])
            }
        }
    }

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

    /// Basic encumbrance: whether the character carries a lot of treasure.
    /// A movement rate that followed the rules follows them to the new rate;
    /// one set by hand is kept.
    public mutating func setCarryingTreasure(_ carrying: Bool, rules: OSERuleset = .classic) {
        let followed = RulesAnalysis(self, rules: rules).status(of: ["movement"], in: self) == .matches
        setBool(carrying ? true : nil, at: ["carryingTreasure"])
        if followed, let rate = RulesAnalysis(self, rules: rules).suggestions[["movement"]] {
            setRulesValue(rate, at: ["movement"])
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
