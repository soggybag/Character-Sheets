import CharacterKit
import SwiftUI

struct CombatSection: View {
    @Binding var file: CharacterFile
    let analysis: RulesAnalysis

    private func warning(at path: NodePath) -> String? {
        analysis.notes.first { $0.kind == .warning && $0.path == path }?.message
    }

    var body: some View {
        SheetSection(title: "Combat") {
            FlowLayout(alignment: .top) {
                StatBox(label: "HP", value: $file.int(["hp", "current"]), help: "Current hit points",
                        warning: warning(at: ["hp", "current"]))
                HitPointAdjuster(file: $file)
                MaxHitPointsBox(file: $file, analysis: analysis, warning: warning(at: ["hp", "max"]))
                RuledStatBox(label: "AC", path: ["combat", "ac"], file: $file, analysis: analysis,
                             help: file.usesAscendingAC ? "Armour class (ascending)" : "Armour class")
                if file.usesAscendingAC {
                    RuledStatBox(label: "Attack", path: ["combat", "attackBonus"], file: $file, analysis: analysis,
                                 width: 72, help: "Attack bonus")
                } else {
                    RuledStatBox(label: "THAC0", path: ["combat", "thac0"], file: $file, analysis: analysis,
                                 help: "To hit AC 0")
                }
                let movement = MovementSummary(file: file, analysis: analysis)
                ValueBox(label: "Move", value: movement.encounterRate, suffix: "'",
                         help: "Encounter movement: a third of the rate per turn. Change the rate under Exploration.",
                         caption: movement.isEncumbered ? "encumbered" : "per round",
                         captionHelp: movement.isEncumbered ? movement.explanation : "Feet per round",
                         highlighted: movement.isEncumbered)
            }
        }
    }
}

/// Max HP, with a way to roll it when it's empty: every hit die at the
/// current level, each shown, or a total typed in from real dice.
struct MaxHitPointsBox: View {
    @Binding var file: CharacterFile
    let analysis: RulesAnalysis
    let warning: String?
    @State private var isRolling = false

    var body: some View {
        let isEmpty = file.int(["hp", "max"]) == nil
        let dice = analysis.hitDiceToRoll
        VStack(spacing: 4) {
            // Lowering max brings current HP down with it (one undo step).
            StatBox(label: "Max HP", value: Binding(
                        get: { file.int(["hp", "max"]) },
                        set: { if $0 != file.int(["hp", "max"]) { file.setMaxHitPoints($0) } }),
                    help: "Maximum hit points. They're rolled, so the rules can't fill them in"
                        + (analysis.hitPointRoll.map { ": \($0) per level (at least 1)" } ?? ""),
                    caption: isEmpty && dice != nil ? nil : analysis.hitDice.map { "HD \($0)" },
                    captionHelp: analysis.hitPointRoll.map { "Roll \($0) per level (at least 1)" },
                    emptyPrompt: "roll",
                    warning: warning)
            if isEmpty, let dice {
                Button("Roll \(dice.description)…") { isRolling = true }
                    .buttonStyle(.link)
                    .zoomFont(.caption)
                    .help("Roll hit points for this level, or type in your own roll")
                    .popover(isPresented: $isRolling, arrowEdge: .bottom) {
                        RollHitPointsView(file: $file, analysis: analysis, dice: dice) { isRolling = false }
                    }
            }
        }
    }
}

/// Rolls every hit die at the current level. Each die shows, and a total
/// rolled with real dice can be typed instead.
struct RollHitPointsView: View {
    @Binding var file: CharacterFile
    let analysis: RulesAnalysis
    let dice: Dice
    let done: () -> Void
    @State private var roll: DiceRoll?
    @State private var total: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Roll Hit Points").font(.headline)
            Text(explanation)
                .zoomFont(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button(roll == nil ? "Roll \(dice.description)" : "Roll Again") {
                    let roll = dice.roll()
                    self.roll = roll
                    total = analysis.hitPoints(fromDice: roll.results)
                }
                if let roll {
                    Text(roll.results.map(String.init).joined(separator: "  "))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .help("Each die")
                }
            }
            HStack {
                Text("Max HP")
                TextField("Max HP", value: Binding(get: { total }, set: { total = $0; roll = nil }),
                          format: .number, prompt: Text("total"))
                    .labelsHidden()
                    .zoomFrame(width: 60)
                    .help("Or type the total you rolled")
            }
            HStack {
                Spacer()
                Button("Cancel", role: .cancel, action: done)
                    .keyboardShortcut(.cancelAction)
                Button("Use \(total.map(String.init) ?? "")") {
                    guard let total, total > 0 else { return }
                    file.setMaxHitPoints(total)
                    if file.int(["hp", "current"]) == nil { file.setInt(total, at: ["hp", "current"]) }
                    done()
                }
                .keyboardShortcut(.defaultAction)
                .disabled((total ?? 0) < 1)
            }
        }
        .padding()
        .zoomFrame(width: 320)
    }

    private var explanation: String {
        let con = analysis.conModifier
        var text = "Hit dice at level \(analysis.level ?? 1): \(dice.description)."
        text += con == 0 ? " Each die gives at least 1." : " Each die adds CON (\(con.signedText)) and gives at least 1."
        if dice.modifier != 0 { text += " The +\(dice.modifier) is added once." }
        return text + " Current HP is set too, if it's empty."
    }
}

/// Applies damage or healing to current hit points. Type an amount and
/// press Return for damage, or use the buttons. No amount means 1.
struct HitPointAdjuster: View {
    @Binding var file: CharacterFile
    @State private var amount = ""
    @State private var last: String?

    var body: some View {
        VStack(spacing: 4) {
            Text("Damage / Heal")
                .zoomFont(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            HStack(spacing: 4) {
                ListButton(title: "Damage", systemImage: "minus.circle") { apply(-1) }
                TextField("Amount", text: $amount, prompt: Text("1"))
                    .labelsHidden()
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.center)
                    .zoomFont(.title3, monospacedDigit: true)
                    .zoomFrame(width: 34)
                    .onSubmit { apply(-1) }
                    .help("Amount. Press Return to take damage.")
                ListButton(title: "Heal", systemImage: "plus.circle") { apply(1) }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 6)
            .background(.quaternary.opacity(0.6), in: .rect(cornerRadius: 8))
            Text(last ?? " ")
                .zoomFont(.caption, monospacedDigit: true)
                .foregroundStyle(.secondary)
        }
        .disabled(file.currentHitPoints == nil)
    }

    private func apply(_ sign: Int) {
        let text = amount.trimmingCharacters(in: .whitespaces).replacing("−", with: "-")
        let size = abs(Int(text.hasPrefix("+") ? String(text.dropFirst()) : text) ?? 1)
        guard size > 0, let before = file.currentHitPoints, let after = file.adjustHitPoints(by: sign * size) else { return }
        last = after == before ? "at max" : "\(sign < 0 ? "−" : "+")\(abs(after - before)) → \(after)"
        amount = ""
    }
}

struct SavesSection: View {
    @Binding var file: CharacterFile
    let analysis: RulesAnalysis

    private let saves = [("Death", "death", "Death / poison"), ("Wands", "wands", "Wands"),
                         ("Paralysis", "paralysis", "Paralysis / petrify"), ("Breath", "breath", "Breath attacks"),
                         ("Spells", "spells", "Spells / rods / staves")]

    var body: some View {
        SheetSection(title: "Saving Throws") {
            FlowLayout {
                ForEach(saves, id: \.1) { label, key, help in
                    RuledStatBox(label: label, path: ["saves", .key(key)], file: $file, analysis: analysis,
                                 width: 72, help: help)
                }
            }
            if let wis = analysis.abilities["wis"]?.headline, wis != "+0" {
                Text("\(wis) to saves against magic (WIS)")
                    .zoomFont(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
