/// A character being rolled up: scores in order, a class, adjustments, hit
/// points and gold. Every value can be rolled here or typed in from real
/// dice. Rules are checked and explained, never enforced.
public struct NewCharacter: Sendable {
    public static let abilityOrder = ["str", "int", "wis", "dex", "con", "cha"]

    public let rules: OSERuleset
    /// Scores as rolled (before adjustments).
    public var rolledScores: [String: Int] = [:]
    /// The dice behind each rolled score, when the app rolled them.
    public var scoreRolls: [String: DiceRoll] = [:]
    /// Change to each score: negative when lowered, positive when raised.
    public var adjustments: [String: Int] = [:]
    public var className: String?
    public var alignment: String?
    public var name = ""
    public var ascendingAC = false
    /// The hit die result, before the CON modifier.
    public var hitPointRoll: Int?
    public var goldRoll: DiceRoll?
    /// Starting gold, rolled or typed.
    public var gold: Int?

    public init(rules: OSERuleset = .classic) {
        self.rules = rules
    }

    // MARK: Rolling

    public var abilityDice: Dice { Dice(rules.creation.abilityRoll) ?? Dice(count: 3, sides: 6) }
    public var goldDice: Dice { Dice(rules.creation.startingGold) ?? Dice(count: 3, sides: 6, multiplier: 10) }

    /// Rolls every score in order and clears adjustments made for the old scores.
    public mutating func rollScores<G: RandomNumberGenerator>(using generator: inout G) {
        for ability in Self.abilityOrder {
            let roll = abilityDice.roll(using: &generator)
            scoreRolls[ability] = roll
            rolledScores[ability] = roll.total
        }
        adjustments = [:]
    }

    public mutating func rollScores() {
        var generator = SystemRandomNumberGenerator()
        rollScores(using: &generator)
    }

    /// Sets a score typed in from real dice.
    public mutating func setRolledScore(_ score: Int?, for ability: String) {
        rolledScores[ability] = score
        scoreRolls[ability] = nil
    }

    public mutating func rollGold() {
        let roll = goldDice.roll()
        goldRoll = roll
        gold = roll.total
    }

    /// The class's hit die, e.g. `1d8`.
    public var hitDie: Dice? {
        classRules.flatMap { Dice($0.hitDie) }
    }

    public mutating func rollHitPoints() {
        hitPointRoll = hitDie.map { Int.random(in: 1...$0.sides) }
    }

    // MARK: Derived values

    public var classRules: ClassRules? { className.flatMap(rules.classRules(named:)) }

    /// Scores after adjustments.
    public var scores: [String: Int] {
        rolledScores.reduce(into: [:]) { result, entry in
            result[entry.key] = entry.value + (adjustments[entry.key] ?? 0)
        }
    }

    public var hasAllScores: Bool { Self.abilityOrder.allSatisfy { rolledScores[$0] != nil } }

    public var conModifier: Int {
        guard let con = scores["con"] else { return 0 }
        return rules.abilities.con.hitPoints[AbilityTables.band(con, in: rules.abilities.ranges)]
    }

    /// Hit points at 1st level: the die plus CON, at least 1.
    public var hitPoints: Int? {
        hitPointRoll.map { max(1, $0 + conModifier) }
    }

    /// Requirements the scores don't meet, e.g. `CON 9`.
    public func unmetRequirements(for classRules: ClassRules) -> [String] {
        classRules.requirements.sorted { $0.key < $1.key }.compactMap { ability, minimum in
            (scores[ability] ?? 0) < minimum ? "\(ability.uppercased()) \(minimum)" : nil
        }
    }

    /// The XP bonus (or penalty) the scores give the class.
    public func xpBonus(for classRules: ClassRules) -> Int {
        var draft = self
        draft.className = classRules.name
        return RulesAnalysis(draft.baseFile(), rules: rules).xp?.bonusPercent ?? 0
    }

    /// Notes on adjustments that don't follow the rules. Not enforced.
    public var adjustmentNotes: [String] {
        let rule = rules.creation.abilityAdjustment
        let primes = Set(classRules?.primeRequisites ?? [])
        var notes: [String] = []
        var lowered = 0
        var raised = 0
        for ability in Self.abilityOrder {
            guard let change = adjustments[ability], change != 0 else { continue }
            let name = ability.uppercased()
            if change < 0 {
                lowered -= change
                if !rule.canLower.contains(ability) {
                    notes.append("\(name) can't normally be lowered (only \(rule.canLower.map { $0.uppercased() }.joined(separator: ", "))).")
                }
                if let score = scores[ability], score < rule.minimum {
                    notes.append("\(name) is lowered below \(rule.minimum).")
                }
                if primes.contains(ability) {
                    notes.append("\(name) is a prime requisite, so lowering it costs XP.")
                }
            } else {
                raised += change
                if !primes.contains(ability) {
                    notes.append("\(name) isn't a prime requisite\(classRules.map { " for \($0.plural.lowercased())" } ?? ""), so it can't normally be raised.")
                }
            }
        }
        if raised * rule.cost != lowered, lowered + raised > 0 {
            notes.append("Lower \(rule.cost) points for each point raised (lowered \(lowered), raised \(raised)).")
        }
        return notes
    }

    /// The rules' view of the character so far (modifiers, XP bonus, notes).
    public var analysis: RulesAnalysis { RulesAnalysis(baseFile(), rules: rules) }

    // MARK: The file

    /// The new character's file. Values that don't depend on equipment
    /// (saves, attacks, skills, spell slots) are filled from the rules;
    /// AC and movement are left for the rules to suggest once gear is bought.
    public func makeFile() -> CharacterFile {
        var file = baseFile()
        let analysis = RulesAnalysis(file, rules: rules)
        let gearDependent: Set<NodePath> = [["combat", "ac"], ["movement"]]
        for (path, value) in analysis.suggestions.sorted(by: { $0.key.dotted < $1.key.dotted })
        where !gearDependent.contains(path) && analysis.status(of: path, in: file) == .missing(rules: value) {
            file.setRulesValue(value, at: path)
        }
        return file
    }

    private func baseFile() -> CharacterFile {
        // The template is covered by the tests.
        var file = try! CharacterFile(text: CharacterFile.newCharacterTemplate)
        file.setAscendingAC(ascendingAC)
        file.setString(name.trimmingCharacters(in: .whitespaces), at: ["name"])
        file.setString(classRules?.name ?? className, at: ["class"])
        file.setString(alignment, at: ["alignment"])
        for ability in Self.abilityOrder {
            file.setInt(scores[ability], at: ["abilityScores", .key(ability)])
        }
        file.setInt(hitPoints, at: ["hp", "max"])
        file.setInt(hitPoints, at: ["hp", "current"])
        // "Alignment" in the class list means the alignment language.
        var languages: [String] = []
        for language in classRules?.languages ?? ["Alignment", "Common"] {
            let actual = language == "Alignment" ? alignment : language
            if let actual, !languages.contains(actual) { languages.append(actual) }
        }
        file.setStrings(languages, at: ["languages"])
        file.setInt(gold, at: ["money", "gp"])
        return file
    }
}
