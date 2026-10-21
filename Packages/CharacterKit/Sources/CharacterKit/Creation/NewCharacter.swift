/// A character being rolled up: scores in order, a class, adjustments, hit
/// points and gold. Every value can be rolled here or typed in from real
/// dice. Rules are checked and explained, never enforced.
public struct NewCharacter: Sendable {
    public static let abilityOrder = ["str", "int", "wis", "dex", "con", "cha"]

    public let rules: OSERuleset
    /// How scores are rolled.
    public var method: RollMethod = .rules
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
    /// Equipment bought (or given) at creation, in order.
    public var purchases: [Purchase] = []

    public struct Purchase: Equatable, Sendable {
        public let item: ShopItem
        public var count: Int
        /// Paid for from the starting gold; false for gear that was given.
        public var paid: Bool

        public init(item: ShopItem, count: Int = 1, paid: Bool = true) {
            self.item = item
            self.count = count
            self.paid = paid
        }

        /// In copper; 0 when given.
        public var price: Int { paid ? item.price * count : 0 }
    }

    /// The rules' roll, or a common house rule.
    public enum RollMethod: String, CaseIterable, Sendable {
        /// 3d6 for each score.
        case rules
        /// 4d6 for each score, dropping the lowest die.
        case fourDropLowest
    }

    public init(rules: OSERuleset = .classic) {
        self.rules = rules
    }

    // MARK: Rolling

    public var abilityDice: Dice {
        let dice = Dice(rules.creation.abilityRoll) ?? Dice(count: 3, sides: 6)
        switch method {
        case .rules: return dice
        case .fourDropLowest:
            return Dice(count: dice.count + 1, sides: dice.sides, modifier: dice.modifier, keepHighest: dice.count)
        }
    }
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

    /// House rule: swaps two scores (and their dice). Adjustments made for
    /// the old order are cleared.
    public mutating func swapScores(_ first: String, _ second: String) {
        guard first != second else { return }
        rolledScores.swapAt(first, second)
        scoreRolls.swapAt(first, second)
        adjustments = [:]
    }

    /// Scores poor enough that the referee may allow a new character
    /// (optional rule): every score below 9, or two or more below 7.
    public var isSubPar: Bool {
        guard hasAllScores else { return false }
        let scores = Self.abilityOrder.compactMap { rolledScores[$0] }
        return scores.allSatisfy { $0 < 9 } || scores.filter { $0 < 7 }.count >= 2
    }
    /// Sets a score typed in from real dice.
    public mutating func setRolledScore(_ score: Int?, for ability: String) {
        rolledScores[ability] = score
        scoreRolls[ability] = nil
    }

    public mutating func rollGold() {
        var generator = SystemRandomNumberGenerator()
        rollGold(using: &generator)
    }

    public mutating func rollGold<G: RandomNumberGenerator>(using generator: inout G) {
        let roll = goldDice.roll(using: &generator)
        goldRoll = roll
        gold = roll.total
    }

    /// The class's hit die, e.g. `1d8`.
    public var hitDie: Dice? {
        classRules.flatMap { Dice($0.hitDie) }
    }

    public mutating func rollHitPoints() {
        var generator = SystemRandomNumberGenerator()
        rollHitPoints(using: &generator)
    }

    public mutating func rollHitPoints<G: RandomNumberGenerator>(using generator: inout G) {
        hitPointRoll = hitDie.map { Int.random(in: 1...$0.sides, using: &generator) }
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
        let classCannotLower = Set(classRules?.creation?.cannotLower ?? [])
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
                } else if let classRules, classCannotLower.contains(ability) {
                    notes.append("\(classRules.plural) can't normally lower \(name).")
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

    // MARK: Shopping

    /// Money left after the purchases that fit, with change in gold,
    /// silver and copper.
    public var moneyLeft: Purse? {
        guard let gold else { return nil }
        return Purse(copper: gold * 100 - purchases.filter { !unaffordable.contains($0) }.reduce(0) { $0 + $1.price })
    }

    /// Paid purchases the gold doesn't stretch to (after a lower gold roll),
    /// in order. They're left out of the character.
    public var unaffordable: [Purchase] {
        var left = (gold ?? 0) * 100
        var over: [Purchase] = []
        for purchase in purchases {
            if purchase.price > left { over.append(purchase) } else { left -= purchase.price }
        }
        return over
    }

    /// Buys an item, or more of one already bought the same way.
    public mutating func buy(_ item: ShopItem, count: Int = 1, paid: Bool = true) {
        if let index = purchases.firstIndex(where: { $0.item.id == item.id && $0.paid == paid }) {
            purchases[index].count += count
        } else {
            purchases.append(Purchase(item: item, count: count, paid: paid))
        }
    }

    // MARK: The file

    /// The new character's file. Values that don't depend on equipment
    /// (saves, attacks, skills, spell slots) are filled from the rules.
    /// AC and movement are filled too once gear is bought; without gear
    /// they're left for the rules to suggest later.
    public func makeFile() -> CharacterFile {
        var file = baseFile()
        let analysis = RulesAnalysis(file, rules: rules)
        let gearDependent: Set<NodePath> = file.count(["equipment"]) > 0 ? [] : [["combat", "ac"], ["movement"]]
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
        if let left = moneyLeft {
            // Gold is written even at 0; silver and copper only if there are some.
            file.setInt(left.gp, at: ["money", "gp"])
            file.setPurse(left)
        }
        let over = unaffordable
        for purchase in purchases where !over.contains(purchase) {
            file.addEquipment(purchase.item, count: purchase.count)
        }
        return file
    }
}
