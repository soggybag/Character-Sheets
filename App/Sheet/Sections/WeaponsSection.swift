import CharacterKit
import SwiftUI

struct WeaponsSection: View {
    let file: CharacterFile
    let analysis: RulesAnalysis

    var body: some View {
        SheetSection(title: "Weapons") {
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
                GridRow {
                    Text("Weapon")
                    Text("Melee")
                    Text("Missile")
                    Text("Range")
                }
                .zoomFont(.caption)
                .foregroundStyle(.secondary)
                ForEach(analysis.weapons, id: \.itemIndex) { weapon in
                    GridRow {
                        Text(weapon.name)
                        attack(weapon.melee)
                        attack(weapon.missile)
                        Text(weapon.range.map { "\($0.short) / \($0.medium) / \($0.long)'" } ?? "")
                            .monospacedDigit()
                            .help("Short (+1 to hit) / medium / long (−1 to hit)")
                    }
                }
            }
            Text(footnote)
                .zoomFont(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func attack(_ attack: Attack?) -> some View {
        Group {
            if let attack {
                Text("\(attack.notation)  \(attack.damage)")
                    .monospacedDigit()
                    .help("THAC0 \(attack.thac0) (attack bonus \(attack.bonus.signedText)), damage \(attack.damage)")
            } else {
                Text("—").foregroundStyle(.tertiary)
            }
        }
    }

    private var footnote: String {
        let variable = file.bool(["rules", "options", "variableWeaponDamage"]) ?? false
        return "THAC0 [attack bonus] and damage, including STR for melee and DEX for missiles."
            + (variable ? "" : " Every weapon does 1d6 (variable weapon damage is off).")
    }
}
