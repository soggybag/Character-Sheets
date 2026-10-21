/// Quick changes made during play.
extension CharacterFile {
    /// Current hit points, or max if current isn't set.
    public var currentHitPoints: Int? { int(["hp", "current"]) ?? int(["hp", "max"]) }

    /// Damage (negative) or healing (positive). Healing stops at max hit
    /// points, but never lowers a current value that's already above max
    /// (a temporary bonus). Damage can go below 0. Returns the new value, or
    /// nil if the character has no hit points to change.
    @discardableResult
    public mutating func adjustHitPoints(by change: Int) -> Int? {
        guard let current = currentHitPoints else { return nil }
        var new = current + change
        if change > 0, let max = int(["hp", "max"]) {
            new = Swift.max(current, Swift.min(new, max))
        }
        setInt(new, at: ["hp", "current"])
        return new
    }

    /// Sets max hit points. Lowering it below current hit points brings
    /// current down to match, unless current was already above the old max
    /// (a temporary bonus, which healing keeps too). Raising it leaves
    /// current alone: the character may be wounded.
    public mutating func setMaxHitPoints(_ value: Int?) {
        let oldMax = int(["hp", "max"])
        setInt(value, at: ["hp", "max"])
        guard let value, let current = int(["hp", "current"]), current > value else { return }
        if let oldMax, current > oldMax { return }
        setInt(value, at: ["hp", "current"])
    }

    /// Uses one of an equipment item (a torch, an arrow). An item with no
    /// quantity counts as one. Stops at 0; the item stays on the list.
    public mutating func useOne(ofItemAt index: Int) {
        let path: NodePath = ["equipment", .index(index), "qty"]
        guard index < count(["equipment"]) else { return }
        let quantity = int(path) ?? 1
        guard quantity > 0 else { return }
        setInt(quantity - 1, at: path)
    }

    /// How many memorized spells are marked cast.
    public var castSpellCount: Int {
        (0..<count(["spells", "memorized"])).filter { bool(["spells", "memorized", .index($0), "cast"]) == true }.count
    }

    /// Clears every "cast" mark, as after a night's rest.
    public mutating func resetCastSpells() {
        for index in 0..<count(["spells", "memorized"]) {
            setBool(nil, at: ["spells", "memorized", .index(index), "cast"])
        }
    }
}
