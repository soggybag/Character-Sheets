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

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Level \(plan.fromLevel) → \(plan.toLevel)")
                .font(.title2.weight(.semibold))

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
                    file.apply(plan, hitPointRoll: roll)
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
                if file.int(["hp", "max"]) == nil {
                    Text("Max HP is empty, so hit points won't be changed.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
