/// Dice notation: `3d6`, `1d8+1`, `3d6*10`, `4d6kh3` (keep the highest 3).
public struct Dice: Equatable, Sendable, CustomStringConvertible {
    public let count: Int
    public let sides: Int
    public let modifier: Int
    public let multiplier: Int
    /// How many of the highest dice count; nil for all of them.
    public let keepHighest: Int?

    public init(count: Int, sides: Int, modifier: Int = 0, multiplier: Int = 1, keepHighest: Int? = nil) {
        self.count = count
        self.sides = sides
        self.modifier = modifier
        self.multiplier = multiplier
        self.keepHighest = keepHighest.map { min(max($0, 1), count) }
    }

    public init?(_ notation: String) {
        let text = notation.lowercased().filter { !$0.isWhitespace }.replacing("×", with: "*")
        guard let match = text.wholeMatch(of: /(\d*)d(\d+)(?:kh(\d+))?([+-]\d+)?(?:\*(\d+))?/),
              let sides = Int(match.output.2), sides > 0 else { return nil }
        let count = match.output.1.isEmpty ? 1 : Int(match.output.1) ?? 0
        guard count > 0 else { return nil }
        self.init(count: count, sides: sides,
                  modifier: match.output.4.flatMap { Int($0) } ?? 0,
                  multiplier: match.output.5.flatMap { Int($0) } ?? 1,
                  keepHighest: match.output.3.flatMap { Int($0) })
    }

    /// Dice that count toward the total.
    var keptCount: Int { keepHighest ?? count }

    /// `3d6`, `1d8+1`, `4d6 drop lowest`, `5d6kh3`.
    public var description: String {
        var text = "\(count)d\(sides)"
        if let keepHighest, keepHighest < count {
            text += keepHighest == count - 1 ? " drop lowest" : "kh\(keepHighest)"
        }
        if modifier != 0 { text += signed(modifier) }
        if multiplier != 1 { text += "×\(multiplier)" }
        return text
    }

    /// The lowest and highest possible totals.
    public var range: ClosedRange<Int> {
        ((keptCount + modifier) * multiplier)...((keptCount * sides + modifier) * multiplier)
    }

    public func roll() -> DiceRoll {
        var generator = SystemRandomNumberGenerator()
        return roll(using: &generator)
    }

    public func roll<G: RandomNumberGenerator>(using generator: inout G) -> DiceRoll {
        DiceRoll(dice: self, results: (0..<count).map { _ in Int.random(in: 1...sides, using: &generator) })
    }
}

/// One roll, keeping each die so it can be shown.
public struct DiceRoll: Equatable, Sendable, CustomStringConvertible {
    public let dice: Dice
    public let results: [Int]

    public init(dice: Dice, results: [Int]) {
        self.dice = dice
        self.results = results
    }

    /// Positions of the dice that don't count: the lowest ones, when only
    /// the highest are kept.
    public var dropped: Set<Int> {
        let drop = results.count - min(dice.keptCount, results.count)
        guard drop > 0 else { return [] }
        let lowest = results.indices.sorted { results[$0] != results[$1] ? results[$0] < results[$1] : $0 < $1 }
        return Set(lowest.prefix(drop))
    }

    public var total: Int {
        let dropped = dropped
        let sum = results.indices.filter { !dropped.contains($0) }.reduce(0) { $0 + results[$1] }
        return (sum + dice.modifier) * dice.multiplier
    }

    /// `4 + 3 + 6 = 13`, `(2 + 5 + 1) × 10 = 80`, `6`, `4 + 3 + 6 = 13 (dropped 2)`.
    public var description: String {
        let dropped = dropped
        let counted = results.indices.filter { !dropped.contains($0) }.map { results[$0] }
        var sum = counted.map(String.init).joined(separator: " + ")
        if dice.modifier != 0 { sum += (dice.modifier > 0 ? " + " : " − ") + String(abs(dice.modifier)) }
        if dice.multiplier != 1 {
            sum = (counted.count > 1 || dice.modifier != 0 ? "(\(sum))" : sum) + " × \(dice.multiplier)"
        }
        let text = counted.count == 1 && dice.modifier == 0 && dice.multiplier == 1 ? sum : "\(sum) = \(total)"
        guard !dropped.isEmpty else { return text }
        return text + " (dropped " + dropped.sorted().map { String(results[$0]) }.joined(separator: ", ") + ")"
    }
}
