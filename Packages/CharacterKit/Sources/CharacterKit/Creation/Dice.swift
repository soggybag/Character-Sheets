/// Dice notation: `3d6`, `1d8+1`, `3d6*10`.
public struct Dice: Equatable, Sendable, CustomStringConvertible {
    public let count: Int
    public let sides: Int
    public let modifier: Int
    public let multiplier: Int

    public init(count: Int, sides: Int, modifier: Int = 0, multiplier: Int = 1) {
        self.count = count
        self.sides = sides
        self.modifier = modifier
        self.multiplier = multiplier
    }

    public init?(_ notation: String) {
        let text = notation.lowercased().filter { !$0.isWhitespace }.replacing("×", with: "*")
        guard let match = text.wholeMatch(of: /(\d*)d(\d+)([+-]\d+)?(?:\*(\d+))?/),
              let sides = Int(match.output.2), sides > 0 else { return nil }
        let count = match.output.1.isEmpty ? 1 : Int(match.output.1) ?? 0
        guard count > 0 else { return nil }
        self.init(count: count, sides: sides,
                  modifier: match.output.3.flatMap { Int($0) } ?? 0,
                  multiplier: match.output.4.flatMap { Int($0) } ?? 1)
    }

    public var description: String {
        var text = "\(count)d\(sides)"
        if modifier != 0 { text += signed(modifier) }
        if multiplier != 1 { text += "×\(multiplier)" }
        return text
    }

    /// The lowest and highest possible totals.
    public var range: ClosedRange<Int> {
        ((count + modifier) * multiplier)...((count * sides + modifier) * multiplier)
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

    public var total: Int { (results.reduce(0, +) + dice.modifier) * dice.multiplier }

    /// `4 + 3 + 6 = 13`, `(2 + 5 + 1) × 10 = 80`, `6`.
    public var description: String {
        var sum = results.map(String.init).joined(separator: " + ")
        if dice.modifier != 0 { sum += (dice.modifier > 0 ? " + " : " − ") + String(abs(dice.modifier)) }
        if dice.multiplier != 1 {
            sum = (results.count > 1 || dice.modifier != 0 ? "(\(sum))" : sum) + " × \(dice.multiplier)"
        }
        return results.count == 1 && dice.modifier == 0 && dice.multiplier == 1 ? sum : "\(sum) = \(total)"
    }
}
