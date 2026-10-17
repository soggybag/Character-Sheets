import CharacterKit
import SwiftUI

extension LevelUpPlan: @retroactive Identifiable {
    public var id: Int { toLevel }
}

/// Shows what a level-up changes, rolls hit points, then applies it.
struct LevelUpSheet: View {
    let plan: LevelUpPlan
    @Binding var file: CharacterFile
    @Environment(\.dismiss) private var dismiss

    @State private var roll: Int?
    /// Max HP before this level, when the sheet doesn't have it.
    @State private var startingMax: Int?
    /// Set XP to the new level's minimum, when it's short.
    @State private var raiseXP = true

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Level \(plan.fromLevel) → \(plan.toLevel)")
                .font(.title2.weight(.semibold))

            if let shortfall = plan.xpShortfall {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Level \(plan.toLevel) starts at \(shortfall.needed.formatted()) XP; this character has \(shortfall.have.formatted()).",
                          systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Toggle("Set XP to \(shortfall.needed.formatted())", isOn: $raiseXP)
                        .help("For a level awarded without the XP, or a sheet that doesn't track XP")
                }
            }

            if plan.changes.isEmpty {
                Text("No saves, attack values or class abilities change at this level.")
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Updated from the rules").font(.headline)
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
                        ForEach(plan.changes, id: \.path) { change in
                            GridRow {
                                Text(FieldNames.name(for: change.path))
                                Text(change.from?.description ?? "–").foregroundStyle(.secondary)
                                Image(systemName: "arrow.right").foregroundStyle(.tertiary)
                                Text(change.to.description).fontWeight(.medium)
                            }
                            .monospacedDigit()
                        }
                    }
                }
            }

            if !plan.keptOverrides.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Kept as you have them").font(.headline)
                    Text(plan.keptOverrides.map(FieldNames.name).joined(separator: ", "))
                        .foregroundStyle(.secondary)
                    Text("These differ from the rules, so they aren't changed.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            hitPoints

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Level Up") {
                    if file.int(["hp", "max"]) == nil, let startingMax {
                        file.setInt(startingMax, at: ["hp", "max"])
                        if file.int(["hp", "current"]) == nil { file.setInt(startingMax, at: ["hp", "current"]) }
                    }
                    file.apply(plan, hitPointRoll: roll, raiseXP: raiseXP)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 440)
    }

    @ViewBuilder private var hitPoints: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Hit points").font(.headline)
            if file.int(["hp", "max"]) == nil, plan.hitPoints != nil {
                startingMaxRow
            }
            switch plan.hitPoints {
            case let .roll(sides, conModifier):
                HStack {
                    Button("Roll 1d\(sides)") { roll = Int.random(in: 1...sides) }
                    TextField("Roll", value: $roll, format: .number, prompt: Text("roll"))
                        .frame(width: 50)
                        .help("Or type the roll you made")
                    if let roll, let gain = plan.hitPointGain(roll: min(max(roll, 1), sides)) {
                        Text("\(conModifier == 0 ? "" : "\(roll) \(conModifier > 0 ? "+" : "−") \(abs(conModifier)) CON = ")+\(gain) HP")
                            .monospacedDigit()
                    }
                }
                if file.int(["hp", "max"]) == nil, startingMax == nil {
                    Text("Max HP is empty. Enter it above, or hit points won't be changed.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else if roll == nil {
                    Text("Leave empty to change hit points yourself later.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            case let .fixed(gain):
                Text("+\(gain) HP (fixed at this level; CON no longer adds hit points)")
            case nil:
                Text("Unknown for this level.").foregroundStyle(.secondary)
            }
        }
    }
}

extension LevelUpSheet {
    /// Asks for max HP at the current level when the sheet is missing it,
    /// so the new level's roll has something to add to.
    @ViewBuilder fileprivate var startingMaxRow: some View {
        let analysis = RulesAnalysis(file)
        HStack {
            Text("Max HP now, at level \(plan.fromLevel)")
            TextField("Max HP", value: $startingMax, format: .number, prompt: Text("HP"))
                .frame(width: 50)
                .help("Your hit points before this level")
            if let dice = analysis.hitDiceToRoll {
                Button("Roll \(dice.description) (HD at level \(plan.fromLevel))") {
                    startingMax = analysis.hitPoints(fromDice: dice.roll().results)
                }
                .help("Roll every hit die for level \(plan.fromLevel), if you never rolled them. "
                      + "Each die adds CON and gives at least 1.")
            }
        }
    }
}

extension LevelDownPlan: @retroactive Identifiable {
    public var id: Int { toLevel }
}

/// Shows what losing a level changes (energy drain), then applies it.
struct LevelDownSheet: View {
    let plan: LevelDownPlan
    @Binding var file: CharacterFile
    @Environment(\.dismiss) private var dismiss

    @State private var loss: Int?
    @State private var resetXP = true

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Level \(plan.fromLevel) → \(plan.toLevel)")
                .font(.title2.weight(.semibold))

            if !plan.changes.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Updated from the rules").font(.headline)
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
                        ForEach(plan.changes, id: \.path) { change in
                            GridRow {
                                Text(FieldNames.name(for: change.path))
                                Text(change.from?.description ?? "–").foregroundStyle(.secondary)
                                Image(systemName: "arrow.right").foregroundStyle(.tertiary)
                                Text(change.to.description).fontWeight(.medium)
                            }
                            .monospacedDigit()
                        }
                    }
                }
            }

            if !plan.keptOverrides.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Kept as you have them").font(.headline)
                    Text(plan.keptOverrides.map(FieldNames.name).joined(separator: ", "))
                        .foregroundStyle(.secondary)
                }
            }

            if let reset = plan.xpReset {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Experience").font(.headline)
                    Toggle("Set XP to \(reset.to.formatted()), the start of level \(plan.toLevel)", isOn: $resetXP)
                    Text("This character has \(reset.have.formatted()) XP. Your referee may rule otherwise.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Hit points").font(.headline)
                HStack {
                    Text("Lose")
                    TextField("HP lost", value: $loss, format: .number, prompt: Text("HP"))
                        .frame(width: 50)
                    Text("from max HP")
                    if let dice = lostDie {
                        Button("Roll \(dice.description)") { loss = max(1, dice.roll().total) }
                            .help("Roll the hit die for level \(plan.fromLevel), with CON (at least 1)")
                    }
                    if let max = file.int(["hp", "max"]), let loss {
                        Text("(\(max) → \(Swift.max(1, max - loss)))")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                Text(lossHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Level Down") {
                    file.apply(plan, hitPointLoss: loss, resetXP: resetXP)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 440)
        .onAppear { loss = plan.suggestedHitPointLoss }
    }

    /// The die level `fromLevel` rolled, with CON, e.g. 1d4+2. None at high
    /// levels, where hit points are a fixed gain.
    private var lostDie: Dice? {
        guard rollable else { return nil }
        return RulesAnalysis(file).hitPointRoll.flatMap { Dice($0) }
    }

    private var rollable: Bool {
        RulesAnalysis(file).classRules?.row(level: plan.fromLevel)?.conModifier != false
    }

    private var lossHint: String {
        if file.int(["hp", "max"]) == nil { return "Max HP is empty, so hit points won't be changed." }
        if plan.suggestedHitPointLoss != nil { return "What level \(plan.fromLevel) gave. Current HP drops only if it's above the new max." }
        return "The sheet doesn't record level \(plan.fromLevel)'s roll. Leave empty to change hit points yourself."
    }
}

/// Readable names for fields, used when listing changes.
enum FieldNames {
    private static let names: [String: String] = [
        "combat.ac": "AC", "combat.thac0": "THAC0", "combat.attackBonus": "Attack bonus",
        "movement": "Movement", "spells.slots": "Spells per day",
        "saves.death": "Death save", "saves.wands": "Wands save", "saves.paralysis": "Paralysis save",
        "saves.breath": "Breath save", "saves.spells": "Spells save",
        "exploration.listen": "Listen", "exploration.secretDoors": "Secret doors",
        "exploration.openDoors": "Open doors", "exploration.findTraps": "Room traps",
        "exploration.constructionTricks": "Construction tricks",
        "thiefSkills.climb": "Climb", "thiefSkills.traps": "Treasure traps", "thiefSkills.hearNoise": "Hear noise",
        "thiefSkills.hide": "Hide", "thiefSkills.moveSilently": "Move silently",
        "thiefSkills.openLocks": "Open locks", "thiefSkills.pickPockets": "Pick pockets",
    ]

    static func name(for path: NodePath) -> String {
        names[path.dotted] ?? path.dotted
    }
}
