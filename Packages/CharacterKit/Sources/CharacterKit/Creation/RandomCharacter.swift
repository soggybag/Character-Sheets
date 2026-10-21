/// One click: a whole 1st-level character, ready to look over and change.
/// The choices are the ones a player might make in a hurry: the class the
/// scores suit best, adjustments that reach a better XP bonus without losing
/// a modifier, and a starting kit the gold stretches to.
extension NewCharacter {
    /// Rolls everything, keeping the name, AC style and roll method.
    /// `items` is what the shop sells (with any custom list applied).
    public mutating func rollRandom(items: [ShopItem]) {
        var generator = SystemRandomNumberGenerator()
        rollRandom(items: items, using: &generator)
    }

    public mutating func rollRandom<G: RandomNumberGenerator>(items: [ShopItem], using generator: inout G) {
        var fresh = NewCharacter(rules: rules)
        fresh.method = method
        fresh.name = name
        fresh.ascendingAC = ascendingAC

        // Optional rule: a sub-par character may be rolled again.
        for _ in 0..<20 {
            fresh.rollScores(using: &generator)
            if !fresh.isSubPar { break }
        }
        fresh.className = fresh.bestClass(using: &generator)?.name
        fresh.adjustForXP()
        fresh.alignment = rules.alignments.randomElement(using: &generator)

        // Optional rule: 1s and 2s may be rerolled at 1st level.
        let rerolls = rules.creation.hitPoints.optionalRerollAtFirstLevel
        for _ in 0..<20 {
            fresh.rollHitPoints(using: &generator)
            if !rerolls.contains(fresh.hitPointRoll ?? 0) { break }
        }
        fresh.rollGold(using: &generator)
        fresh.buyStartingKit(from: items)
        self = fresh
    }

    // MARK: Class

    /// A class the scores qualify for with the best XP bonus; ties are
    /// broken at random.
    func bestClass<G: RandomNumberGenerator>(using generator: inout G) -> ClassRules? {
        let qualified = rules.classes.filter { unmetRequirements(for: $0).isEmpty }
        let bonuses = qualified.map { xpBonus(for: $0) }
        guard let best = bonuses.max() else { return rules.classes.randomElement(using: &generator) }
        return zip(qualified, bonuses).filter { $0.1 == best }.map(\.0).randomElement(using: &generator)
    }

    // MARK: Adjustments

    /// Scores that can be lowered without changing a modifier: 11 and 12
    /// can drop 2 and stay in the 9–12 band.
    private var spareScores: [String] {
        let rule = rules.creation.abilityAdjustment
        let primes = Set(classRules?.primeRequisites ?? [])
        let classCannotLower = Set(classRules?.creation?.cannotLower ?? [])
        return Self.abilityOrder.filter { ability in
            guard rule.canLower.contains(ability), !primes.contains(ability), !classCannotLower.contains(ability),
                  let score = rolledScores[ability] else { return false }
            return (rule.minimum + rule.cost...12).contains(score)
        }
    }

    /// Raises a prime requisite when that improves the XP bonus, paying
    /// with spare scores. The fewest points that reach the best bonus win.
    mutating func adjustForXP() {
        guard let classRules else { return }
        let cost = rules.creation.abilityAdjustment.cost
        let spare = spareScores
        guard !spare.isEmpty else { return }
        let current = xpBonus(for: classRules)
        var best: (bonus: Int, prime: String, points: Int)?
        for prime in classRules.primeRequisites {
            guard let score = rolledScores[prime] else { continue }
            for points in 1...spare.count where score + points <= 18 {
                var trial = self
                trial.adjustments[prime] = points
                let bonus = trial.xpBonus(for: classRules)
                if bonus > current, bonus > best?.bonus ?? Int.min { best = (bonus, prime, points) }
            }
        }
        guard let best else { return }
        adjustments[best.prime] = best.points
        for ability in spare.prefix(best.points) { adjustments[ability] = -cost }
    }

    // MARK: Starting kit

    /// Weapons tried in order; the first the class can use and afford is bought.
    static let kitWeapons = ["sword", "mace", "war-hammer", "short-sword", "hand-axe", "spear", "dagger", "club", "staff"]
    /// A missile weapon and its ammunition, bought if there's gold left.
    static let kitMissiles = [("short-bow", "arrows"), ("crossbow", "crossbow-bolts"), ("sling", "sling-stones")]
    /// What every adventurer carries.
    static let kitGear = ["backpack", "rations-iron-7-days", "torches", "tinder-box-flint-steel", "waterskin"]

    /// Buys a starting kit with the gold: the class's tools, a weapon, the
    /// basics, the best armour that leaves enough for the basics, a shield,
    /// a missile weapon and rope. Items the shop doesn't sell are skipped.
    public mutating func buyStartingKit(from items: [ShopItem]) {
        guard let classRules, gold != nil else { return }
        let byID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        func usable(_ id: String) -> ShopItem? {
            byID[id].flatMap { rules.restriction(of: $0, for: classRules) == nil ? $0 : nil }
        }
        var left: Int { moneyLeft?.totalCP ?? 0 }
        @discardableResult func tryBuy(_ item: ShopItem?) -> Bool {
            guard let item, item.price <= left else { return false }
            buy(item)
            return true
        }

        if classRules.spellcasting?.type == "divine" { tryBuy(byID["holy-symbol"]) }
        if classRules.hasFeature("thief-skills") { tryBuy(byID["thieves-tools"]) }
        for id in Self.kitWeapons where tryBuy(usable(id)) { break }

        let gear = Self.kitGear.compactMap { byID[$0] }
        let gearCost = gear.reduce(0) { $0 + $1.price }
        let armour = classRules.armour.allowed.compactMap(usable)
            .filter { $0.price <= left - gearCost }
            .min { (armourClass($0) ?? 9) < (armourClass($1) ?? 9) }
        tryBuy(armour)
        for item in gear { tryBuy(item) }
        if classRules.armour.shields { tryBuy(usable("shield")) }

        for (weapon, ammo) in Self.kitMissiles {
            guard let weapon = usable(weapon), let ammo = byID[ammo], weapon.price + ammo.price <= left else { continue }
            buy(weapon)
            buy(ammo)
            break
        }
        tryBuy(byID["rope-50"])
    }

    private func armourClass(_ item: ShopItem) -> Int? {
        rules.armour.first { $0.id == item.id }?.ac
    }
}

extension Dictionary {
    /// Swaps two entries, either of which may be missing.
    mutating func swapAt(_ first: Key, _ second: Key) {
        let value = self[first]
        self[first] = self[second]
        self[second] = value
    }
}
