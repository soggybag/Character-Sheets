/// A character's movement as the sheet shows it: the stored rate (or the
/// rules' rate when nothing is stored), and whether what they carry slows
/// them.
public struct MovementSummary: Equatable, Sendable {
    /// Feet per turn.
    public let rate: Int?
    public let info: MovementInfo?

    public init(file: CharacterFile, analysis: RulesAnalysis) {
        rate = analysis.value(at: ["movement"], in: file)
        info = analysis.movement
    }

    /// Feet per round in an encounter.
    public var encounterRate: Int? { rate.map(MovementInfo.encounter) }
    /// Miles a day overland.
    public var travelRate: Int? { rate.map(MovementInfo.travel) }

    /// Slower than the unencumbered rate because of what's carried. Not when
    /// encumbrance isn't tracked.
    public var isEncumbered: Bool {
        guard let rate, let info, info.load != .untracked else { return false }
        return rate < info.unencumbered
    }

    /// Why the rate is what it is, for a tooltip. Empty when encumbrance
    /// isn't tracked.
    public var explanation: String {
        guard let info else { return "" }
        let unburdened = "Unencumbered: \(info.unencumbered)' per turn, "
            + "\(MovementInfo.encounter(info.unencumbered))' per round."
        switch info.load {
        case .untracked: return ""
        case let .basic(treasure):
            return (treasure ? "Carrying treasure. " : "") + unburdened
        case let .detailed(coins):
            return "Carrying \(coins.formatted()) coins of weight. " + unburdened
        }
    }
}
