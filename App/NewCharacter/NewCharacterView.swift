import CharacterKit
import SwiftUI

/// File → New Character…: rolls up a character.
struct NewCharacterButton: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("New Character…") { openWindow(id: NewCharacterView.windowID) }
            .keyboardShortcut("n", modifiers: .command)
    }
}

/// File → New Blank Sheet: an empty sheet to fill in by hand.
struct NewBlankSheetButton: View {
    @Environment(\.newDocument) private var newDocument

    var body: some View {
        Button("New Blank Sheet") { newDocument(CharacterDocument()) }
            .keyboardShortcut("n", modifiers: [.command, .option])
    }
}

/// Rolls up a 1st-level character: scores in order, class, optional score
/// adjustments, hit points and gold. Every roll shows its dice, and every
/// value can be typed in from real dice instead. Or one click rolls the lot.
struct NewCharacterView: View {
    static let windowID = "new-character"

    @Environment(\.newDocument) private var newDocument
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var character = NewCharacter()
    /// House rules, remembered because a group plays the same way each time.
    @AppStorage("abilityRollMethod") private var method = NewCharacter.RollMethod.rules
    @AppStorage("allowSwappingScores") private var allowSwapping = false

    var body: some View {
        let analysis = character.analysis
        VStack(spacing: 0) {
            Form {
                RandomSection(character: $character)
                ScoresSection(character: $character, analysis: analysis,
                              method: $method, allowSwapping: $allowSwapping)
                ClassSection(character: $character)
                AdjustSection(character: $character)
                DetailsSection(character: $character)
                HitPointsSection(character: $character)
                GoldSection(character: $character)
                StartingEquipmentSection(character: $character)
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                Text("Saves, attacks and skills are filled in from the rules.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Cancel", role: .cancel) { dismissWindow(id: Self.windowID) }
                    .keyboardShortcut(.cancelAction)
                Button("Create Character") {
                    let document = CharacterDocument(file: character.makeFile())
                    newDocument(document)
                    dismissWindow(id: Self.windowID)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!character.hasAllScores || character.classRules == nil)
            }
            .padding()
        }
        .frame(width: 600, height: 760)
        // The window's state outlives closing it; each opening is a new character.
        .onAppear { startOver() }
        .onDisappear { startOver() }
        .onChange(of: method) { character.method = method }
    }

    private func startOver() {
        character = NewCharacter()
        character.method = method
    }
}

// MARK: - Sections

private struct RandomSection: View {
    @Binding var character: NewCharacter

    var body: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Roll a whole character, then change anything you like.")
                    Text("Picks the class the scores suit best, adjusts scores for XP, and buys a starting kit.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Random Character", systemImage: "dice") {
                    let store = EquipmentListStore.shared
                    store.reload()
                    character.rollRandom(items: character.rules.shopItems(with: store.list))
                }
            }
        }
    }
}

private struct ScoresSection: View {
    @Binding var character: NewCharacter
    let analysis: RulesAnalysis
    @Binding var method: NewCharacter.RollMethod
    @Binding var allowSwapping: Bool

    var body: some View {
        Section {
            Picker("Roll", selection: $method) {
                Text("3d6 in order (the rules)").tag(NewCharacter.RollMethod.rules)
                Text("4d6, drop the lowest, in order (house rule)").tag(NewCharacter.RollMethod.fourDropLowest)
            }
            Toggle("Allow swapping scores (house rule)", isOn: $allowSwapping)
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    Text("")
                    Text("Roll").gridColumnAlignment(.trailing)
                    Text("Dice")
                    Text("Score").gridColumnAlignment(.trailing)
                    Text("Mod").gridColumnAlignment(.trailing)
                    if allowSwapping { Text("") }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                ForEach(NewCharacter.abilityOrder, id: \.self) { ability in
                    GridRow {
                        Text(ability.uppercased()).bold()
                        TextField(ability.uppercased(), value: Binding(
                            get: { character.rolledScores[ability] },
                            set: { character.setRolledScore($0, for: ability) }),
                            format: .number, prompt: Text("–"))
                            .labelsHidden()
                            .multilineTextAlignment(.trailing)
                            .frame(width: 44)
                        dice(character.scoreRolls[ability])
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 60, alignment: .leading)
                        Text(character.scores[ability].map(String.init) ?? "")
                            .monospacedDigit()
                            .foregroundStyle(character.adjustments[ability, default: 0] == 0 ? .primary : Color.accentColor)
                        Text(character.scores[ability] == nil ? "" : analysis.abilities[ability]?.headline ?? "")
                            .monospacedDigit()
                            .help(analysis.abilities[ability]?.effects.map { "\($0.label): \($0.value)" }
                                .joined(separator: "\n") ?? "")
                        if allowSwapping { swapMenu(ability) }
                    }
                }
            }
        } header: {
            HStack {
                Text("Ability Scores")
                Spacer()
                Button(character.hasAllScores ? "Roll Again" : "Roll \(character.abilityDice.description) in Order") {
                    character.rollScores()
                }
            }
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                if character.isSubPar {
                    Label("Optional rule: with every score below 9, or two or more below 7, "
                          + "the referee may let you roll a new character.",
                          systemImage: "info.circle")
                        .foregroundStyle(.orange)
                }
                Text("Roll here, or roll real dice and type the totals.")
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
        }
    }

    /// Each die, with dropped ones struck through.
    private func dice(_ roll: DiceRoll?) -> Text {
        guard let roll else { return Text("") }
        let dropped = roll.dropped
        return roll.results.indices.reduce(Text("")) { text, index in
            let die = Text((index == 0 ? "" : " ") + String(roll.results[index]))
            return Text("\(text)\(dropped.contains(index) ? die.strikethrough().foregroundStyle(.tertiary) : die)")
        }
    }

    private func swapMenu(_ ability: String) -> some View {
        Menu {
            ForEach(NewCharacter.abilityOrder.filter { $0 != ability }, id: \.self) { other in
                Button("With \(other.uppercased())" + (character.rolledScores[other].map { " (\($0))" } ?? "")) {
                    character.swapScores(ability, other)
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Swap \(ability.uppercased()) with another score")
        .disabled(character.rolledScores[ability] == nil)
    }
}

private struct ClassSection: View {
    @Binding var character: NewCharacter

    var body: some View {
        Section("Class") {
            Picker("Class", selection: $character.className) {
                ForEach(character.rules.classes, id: \.name) { classRules in
                    ClassRow(classRules: classRules, character: character)
                        .tag(Optional(classRules.name))
                }
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()
        }
    }
}

private struct ClassRow: View {
    let classRules: ClassRules
    let character: NewCharacter

    var body: some View {
        let unmet = character.hasAllScores ? character.unmetRequirements(for: classRules) : []
        HStack(alignment: .firstTextBaseline) {
            Text(classRules.name)
                .frame(width: 90, alignment: .leading)
            Text(details)
                .font(.callout)
                .foregroundStyle(.secondary)
            if !unmet.isEmpty {
                Text("Needs " + unmet.joined(separator: ", "))
                    .font(.callout)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var details: String {
        var parts = ["HD \(classRules.hitDie)",
                     "Prime " + classRules.primeRequisites.map { $0.uppercased() }.joined(separator: " & ")]
        if character.hasAllScores {
            let bonus = character.xpBonus(for: classRules)
            if bonus != 0 { parts.append("XP \(bonus > 0 ? "+" : "−")\(abs(bonus))%") }
        }
        return parts.joined(separator: " · ")
    }
}

private struct AdjustSection: View {
    @Binding var character: NewCharacter

    var body: some View {
        Section {
            DisclosureGroup("Adjust Scores (optional)") {
                Text(character.rules.creation.abilityAdjustment.note
                     + " Only STR, INT and WIS can be lowered, and not below \(character.rules.creation.abilityAdjustment.minimum).")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                HStack(spacing: 14) {
                    ForEach(NewCharacter.abilityOrder, id: \.self) { ability in
                        VStack(spacing: 2) {
                            Text(ability.uppercased()).font(.caption).foregroundStyle(.secondary)
                            Stepper(value: Binding(
                                get: { character.adjustments[ability, default: 0] },
                                set: { character.adjustments[ability] = $0 == 0 ? nil : $0 }),
                                in: -9...9) {
                                Text(adjustmentText(character.adjustments[ability, default: 0]))
                                    .monospacedDigit()
                                    .frame(width: 24, alignment: .trailing)
                            }
                        }
                    }
                }
                ForEach(character.adjustmentNotes, id: \.self) { note in
                    Label(note, systemImage: "exclamationmark.triangle")
                        .font(.callout)
                        .foregroundStyle(.orange)
                }
            }
            .disabled(!character.hasAllScores)
        }
    }

    private func adjustmentText(_ change: Int) -> String {
        change == 0 ? "0" : (change > 0 ? "+\(change)" : "−\(-change)")
    }
}

private struct DetailsSection: View {
    @Binding var character: NewCharacter

    var body: some View {
        Section("Details") {
            TextField("Name", text: $character.name, prompt: Text("Optional"))
            Picker("Alignment", selection: $character.alignment) {
                Text("Choose…").tag(String?.none)
                ForEach(character.rules.alignments, id: \.self) { Text($0).tag(Optional($0)) }
            }
            Picker("Armour Class", selection: $character.ascendingAC) {
                Text("Descending (THAC0)").tag(false)
                Text("Ascending (attack bonus)").tag(true)
            }
        }
    }
}

private struct HitPointsSection: View {
    @Binding var character: NewCharacter

    var body: some View {
        Section {
            if let die = character.hitDie {
                HStack {
                    Button(character.hitPointRoll == nil ? "Roll \(die.description)" : "Roll Again") { character.rollHitPoints() }
                    TextField("Hit die", value: $character.hitPointRoll, format: .number, prompt: Text("roll"))
                        .labelsHidden()
                        .frame(width: 50)
                        .help("Or type the roll you made")
                    if let roll = character.hitPointRoll, let total = character.hitPoints {
                        Text(summary(roll: roll, total: total))
                            .monospacedDigit()
                    }
                }
                let rerolls = character.rules.creation.hitPoints.optionalRerollAtFirstLevel
                if let roll = character.hitPointRoll, rerolls.contains(roll) {
                    Text("Optional rule: at 1st level, \(rerolls.map(String.init).joined(separator: "s and "))s may be rerolled.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Choose a class first.").foregroundStyle(.secondary)
            }
        } header: {
            Text("Hit Points")
        }
    }

    private func summary(roll: Int, total: Int) -> String {
        let con = character.conModifier
        let sum = con == 0 ? "\(roll)" : "\(roll) \(con > 0 ? "+" : "−") \(abs(con)) CON"
        return "\(sum) = \(total) hit point\(total == 1 ? "" : "s")"
    }
}

private struct GoldSection: View {
    @Binding var character: NewCharacter

    var body: some View {
        Section("Starting Gold") {
            HStack {
                Button(character.gold == nil ? "Roll \(character.goldDice.description)" : "Roll Again") { character.rollGold() }
                TextField("Gold", value: Binding(
                    get: { character.gold },
                    set: { character.gold = $0; character.goldRoll = nil }),
                    format: .number, prompt: Text("gp"))
                    .labelsHidden()
                    .frame(width: 60)
                    .help("Or type the gold you rolled")
                if let roll = character.goldRoll {
                    Text("\(roll.description) gp").monospacedDigit().foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct StartingEquipmentSection: View {
    @Binding var character: NewCharacter
    @State private var isShopping = false

    var body: some View {
        Section("Equipment") {
            let over = character.unaffordable
            ForEach(character.purchases.indices, id: \.self) { index in
                let purchase = character.purchases[index]
                let amount = (purchase.item.quantity ?? 1) * purchase.count
                HStack {
                    Text(purchase.item.itemName + (amount > 1 ? " × \(amount)" : ""))
                        .strikethrough(over.contains(purchase))
                    Spacer()
                    Text(purchase.paid ? Purse.priceText(purchase.price) : "given")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    Button("Remove", systemImage: "minus.circle") { character.purchases.remove(at: index) }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                }
            }
            if !over.isEmpty {
                Text("Not enough gold for: \(over.map(\.item.itemName).joined(separator: ", ")). They'll be left out.")
                    .foregroundStyle(.orange)
            }
            HStack {
                Button(character.purchases.isEmpty ? "Buy Equipment…" : "Buy More…") { isShopping = true }
                    .disabled(character.gold == nil)
                Spacer()
                if let left = character.moneyLeft {
                    Text("\(left.description) left").monospacedDigit()
                } else {
                    Text("Roll gold first").foregroundStyle(.secondary)
                }
            }
        }
        .sheet(isPresented: $isShopping) {
            ShopView(rules: character.rules, classRules: character.classRules, purse: character.moneyLeft ?? Purse()) { item, count, pay in
                if pay, item.price * count > character.moneyLeft?.totalCP ?? 0 { return false }
                character.buy(item, count: count, paid: pay)
                return true
            }
        }
    }
}
