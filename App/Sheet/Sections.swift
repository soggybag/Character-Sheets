import CharacterKit
import SwiftUI

struct IdentitySection: View {
    @Binding var file: CharacterFile
    let analysis: RulesAnalysis
    let placeholderName: String
    let levelUp: () -> Void
    let levelDown: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("Name", text: $file.string(["name"]), prompt: Text(placeholderName))
                .textFieldStyle(.plain)
                .font(.system(size: 30, weight: .semibold, design: .serif))
            // One line when there's room; in a narrow window, level and XP
            // move under class and alignment.
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .fieldLine, spacing: 20) {
                    classAndAlignment
                    levelAndXP
                }
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .fieldLine, spacing: 20) { classAndAlignment }
                    HStack(alignment: .fieldLine, spacing: 20) {
                        levelAndXP
                        Spacer(minLength: 0)
                    }
                }
            }
            HStack(spacing: 20) {
                LineField(label: "Title", text: $file.string(["title"]))
                LineField(label: "Player", text: $file.string(["player"]))
            }
        }
    }

    @ViewBuilder private var classAndAlignment: some View {
        LineField(label: "Class", text: $file.string(["class"]), suggestions: OSE.classes)
            .frame(minWidth: 110)
        LineField(label: "Alignment", text: $file.string(["alignment"]), suggestions: OSE.alignments)
            .frame(minWidth: 110)
    }

    @ViewBuilder private var levelAndXP: some View {
        LineNumberField(label: "Level", value: $file.int(["level"]))
            .frame(width: 60)
        LineNumberField(label: "XP", value: $file.int(["xp"]), caption: xpCaption)
            .frame(width: 110)
            .help(xpHelp)
        levelUpButton
            .alignmentGuide(.fieldLine) { $0[VerticalAlignment.center] }
    }

    private var xpCaption: String? {
        guard let xp = analysis.xp else { return nil }
        let next = xp.nextLevel.map { "next \($0.formatted())" } ?? "max level"
        return xp.bonusPercent == 0 ? next : "\(next) · \(xp.bonusPercent > 0 ? "+" : "")\(xp.bonusPercent)%"
    }

    private var xpHelp: String {
        guard let xp = analysis.xp else { return "Experience points" }
        var lines = ["Experience points"]
        if let next = xp.nextLevel { lines.append("Next level at \(next.formatted()) XP") }
        if xp.bonusPercent != 0 { lines.append("Prime requisite: \(xp.bonusPercent > 0 ? "+" : "")\(xp.bonusPercent)% to XP awards") }
        return lines.joined(separator: "\n")
    }

    /// Level Up…, with Level Down… in its menu: losing a level is rare
    /// (energy drain) and shouldn't sit beside the everyday button.
    @ViewBuilder private var levelUpButton: some View {
        let button = Menu("Level Up…") {
            Button("Level Down…", action: levelDown)
                .disabled((analysis.level ?? 0) <= 1)
        } primaryAction: {
            levelUp()
        }
            .menuStyle(.button)
            .fixedSize()
            .disabled(analysis.classRules == nil || analysis.level == nil)
            .help(analysis.xp?.readyToLevelUp == true
                ? "Enough XP for the next level. Use the arrow to lose a level."
                : "Go up a level. Use the arrow to lose a level (energy drain).")
        if analysis.xp?.readyToLevelUp == true {
            button.buttonStyle(.borderedProminent)
        } else {
            button
        }
    }
}

struct AbilityScoresSection: View {
    @Binding var file: CharacterFile
    let analysis: RulesAnalysis

    private let scores = [("STR", "str", "Strength"), ("INT", "int", "Intelligence"), ("WIS", "wis", "Wisdom"),
                          ("DEX", "dex", "Dexterity"), ("CON", "con", "Constitution"), ("CHA", "cha", "Charisma")]

    var body: some View {
        SheetSection(title: "Ability Scores") {
            FlowLayout {
                ForEach(scores, id: \.1) { label, key, name in
                    let effects = analysis.abilities[key]
                    StatBox(label: label, value: $file.int(["abilityScores", .key(key)]), help: name,
                            caption: effects.map { $0.headline.isEmpty ? " " : $0.headline },
                            captionHelp: effects?.effects.map { "\($0.label): \($0.value)" }.joined(separator: "\n"))
                }
            }
        }
    }
}

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
                StatBox(label: "Max HP", value: $file.int(["hp", "max"]),
                        help: "Maximum hit points. They're rolled, so the rules can't fill them in"
                            + (analysis.hitPointRoll.map { ": \($0) per level (at least 1)" } ?? ""),
                        caption: analysis.hitDice.map { "HD \($0)" },
                        captionHelp: analysis.hitPointRoll.map { "Roll \($0) per level (at least 1)" },
                        emptyPrompt: "roll",
                        warning: warning(at: ["hp", "max"]))
                RuledStatBox(label: "AC", path: ["combat", "ac"], file: $file, analysis: analysis,
                             help: file.usesAscendingAC ? "Armour class (ascending)" : "Armour class")
                if file.usesAscendingAC {
                    RuledStatBox(label: "Attack", path: ["combat", "attackBonus"], file: $file, analysis: analysis,
                                 width: 72, help: "Attack bonus")
                } else {
                    RuledStatBox(label: "THAC0", path: ["combat", "thac0"], file: $file, analysis: analysis,
                                 help: "To hit AC 0")
                }
                RuledStatBox(label: "Move", path: ["movement"], file: $file, analysis: analysis, suffix: "'",
                             width: 72, help: "Base movement rate (feet per turn)",
                             caption: file.int(["movement"]).map { "\($0 / 3)' / round" },
                             captionHelp: "Encounter movement: a third of the base rate")
            }
        }
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
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            HStack(spacing: 4) {
                ListButton(title: "Damage", systemImage: "minus.circle") { apply(-1) }
                TextField("Amount", text: $amount, prompt: Text("1"))
                    .labelsHidden()
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.center)
                    .font(.title3.monospacedDigit())
                    .frame(width: 34)
                    .onSubmit { apply(-1) }
                    .help("Amount. Press Return to take damage.")
                ListButton(title: "Heal", systemImage: "plus.circle") { apply(1) }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 6)
            .background(.quaternary.opacity(0.6), in: .rect(cornerRadius: 8))
            Text(last ?? " ")
                .font(.caption.monospacedDigit())
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
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct ExplorationSection: View {
    @Binding var file: CharacterFile
    let analysis: RulesAnalysis

    private var className: String { file.string(["class"]) ?? "" }

    var body: some View {
        SheetSection(title: "Exploration") {
            FlowLayout {
                inSix("Listen", "listen", help: "Listen at doors")
                inSix("Secret doors", "secretDoors", help: "Find secret doors")
                inSix("Open doors", "openDoors", help: "Force open stuck doors")
                inSix("Room traps", "findTraps", help: "Find room traps")
                if className == "Dwarf" || file.int(["exploration", "constructionTricks"]) != nil {
                    inSix("Construction", "constructionTricks", help: "Detect construction tricks")
                }
            }
            if className == "Thief" || file.count(["thiefSkills"]) > 0 {
                FlowLayout {
                    percent("Climb", "climb", help: "Climb sheer surfaces")
                    percent("Traps", "traps", help: "Find or remove treasure traps")
                    RuledStatBox(label: "Hear", path: ["thiefSkills", "hearNoise"], file: $file, analysis: analysis,
                                 suffix: "in 6", width: 84, help: "Hear noise")
                    percent("Hide", "hide", help: "Hide in shadows")
                    percent("Move", "moveSilently", help: "Move silently")
                    percent("Locks", "openLocks", help: "Open locks")
                    percent("Pockets", "pickPockets", help: "Pick pockets")
                }
                .padding(.top, 6)
            }
        }
    }

    private func inSix(_ label: String, _ key: String, help: String) -> some View {
        RuledStatBox(label: label, path: ["exploration", .key(key)], file: $file, analysis: analysis,
                     suffix: "in 6", width: 84, help: help)
    }

    private func percent(_ label: String, _ key: String, help: String) -> some View {
        RuledStatBox(label: label, path: ["thiefSkills", .key(key)], file: $file, analysis: analysis,
                     suffix: "%", width: 72, help: help)
    }
}

struct LanguagesSection: View {
    @Binding var file: CharacterFile

    var body: some View {
        SheetSection(title: "Languages") {
            CommitTextField(prompt: "Alignment, Common, …",
                            value: file.strings(["languages"]).joined(separator: ", ")) { text in
                let languages = text.split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                file.setStrings(languages, at: ["languages"])
            }
            .textFieldStyle(.plain)
            Divider()
        }
    }
}

struct SpellsSection: View {
    @Binding var file: CharacterFile
    let analysis: RulesAnalysis

    private let ordinals = ["1st", "2nd", "3rd", "4th", "5th", "6th", "7th", "8th", "9th"]

    var body: some View {
        SheetSection(title: "Spells") {
            FlowLayout(alignment: .bottom) {
                ForEach(0..<max(file.count(["spells", "slots"]), 1), id: \.self) { level in
                    StatBox(label: ordinals[min(level, ordinals.count - 1)], value: slot(level),
                            help: "Spells per day of level \(level + 1)",
                            caption: memorizedCaption(level: level + 1))
                }
                ListButton(title: "Add spell level", systemImage: "plus.circle") {
                    file.appendInt(0, to: ["spells", "slots"])
                }
                .padding(.bottom, 27)
                if file.count(["spells", "slots"]) > 1 {
                    ListButton(title: "Remove spell level", systemImage: "minus.circle") {
                        file.removeItem(at: ["spells", "slots", .index(file.count(["spells", "slots"]) - 1)])
                    }
                    .padding(.bottom, 27)
                }
                slotRulesHint
                    .padding(.bottom, 27)
            }

            spellList
                .padding(.top, 6)
        }
    }

    /// One row per spell: its level, how many copies are memorized, and a
    /// Cast box for each copy.
    private var spellList: some View {
        let rows = file.spellRows
        return Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
            GridRow {
                Text("Spell")
                Text("Level")
                Text("Memorized")
                HStack {
                    Text("Cast")
                    Spacer()
                    Button("Rest") { file.resetCastSpells() }
                        .buttonStyle(.link)
                        .disabled(file.castSpellCount == 0)
                        .help("Clear every Cast mark after a night's rest")
                }
                .gridCellColumns(2)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            ForEach(rows.indices, id: \.self) { index in
                let row = rows[index]
                GridRow {
                    CommitTextField(prompt: "Spell", value: row.name) { file.renameSpell(row, to: $0) }
                        .textFieldStyle(.plain)
                        .strikethrough(!row.memorized.isEmpty && row.memorized.allSatisfy { file.isCast(memorized: $0) })
                        .help(row.bookIndex == nil ? "Memorized, but not in the spell book" : "")
                        .frame(minWidth: 160)
                    NumberField(label: "Level", value: Binding { row.level } set: { file.setSpellLevel(row, to: $0) },
                                prompt: "–")
                        .textFieldStyle(.plain)
                        .labelsHidden()
                        .frame(width: 32)
                    HStack(spacing: 2) {
                        ListButton(title: "Forget one", systemImage: "minus.circle") { file.forgetOne(row) }
                            .disabled(row.memorized.isEmpty)
                        Text("\(row.memorized.count)")
                            .monospacedDigit()
                            .frame(minWidth: 16)
                            .foregroundStyle(row.memorized.isEmpty ? .secondary : .primary)
                        ListButton(title: "Memorize one more", systemImage: "plus.circle") { file.memorize(row) }
                            .disabled(row.name.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    HStack(spacing: 6) {
                        ForEach(row.memorized, id: \.self) { copy in
                            Toggle("Cast", isOn: Binding { file.isCast(memorized: copy) }
                                   set: { file.setCast($0, memorized: copy) })
                                .labelsHidden()
                                .help("Cast today")
                        }
                    }
                    .frame(minWidth: 80, alignment: .leading)
                    ListButton(title: "Remove spell", systemImage: "trash") { file.removeSpell(row) }
                        .help(row.memorized.isEmpty ? "Remove spell" : "Remove spell and its memorized copies")
                }
                Divider().gridCellUnsizedAxes(.horizontal)
            }
            GridRow {
                ListButton(title: "Add spell", systemImage: "plus.circle") { file.addSpell() }
                    .gridCellColumns(5)
            }
        }
    }

    private func memorizedCaption(level: Int) -> String {
        // Always shown, so the boxes stay level (Tab follows position).
        "\(file.memorizedCount(level: level)) memorized"
    }

    /// Shown when the slots differ from (or are missing compared with) the rules.
    @ViewBuilder private var slotRulesHint: some View {
        let path: NodePath = ["spells", "slots"]
        switch analysis.status(of: path, in: file) {
        case let .overridden(rules), let .missing(rules):
            Button("Rules: \(rules.description)") { file.setRulesValue(rules, at: path) }
                .buttonStyle(.link)
                .font(.caption)
                .help("Use the spells per day from the rules")
        case .matches, .noRule:
            EmptyView()
        }
    }

    /// Slot counts are a list; writing past the end extends it.
    private func slot(_ level: Int) -> Binding<Int?> {
        Binding {
            file.int(["spells", "slots", .index(level)])
        } set: { value in
            if level < file.count(["spells", "slots"]) {
                file.setInt(value ?? 0, at: ["spells", "slots", .index(level)])
            } else if let value {
                file.appendInt(value, to: ["spells", "slots"])
            }
        }
    }
}

struct EquipmentSection: View {
    @Binding var file: CharacterFile
    @State private var isShopping = false

    var body: some View {
        SheetSection(title: "Equipment") {
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 6) {
                GridRow {
                    Image(systemName: "hand.raised").help("Equipped")
                    Text("Item")
                    Text("Qty")
                    Text("Damage")
                    Text("Notes")
                    Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                ForEach(0..<file.count(["equipment"]), id: \.self) { index in
                    let path: NodePath = ["equipment", .index(index)]
                    GridRow {
                        Toggle("Equipped", isOn: $file.flag(path + ["equipped"]))
                            .labelsHidden()
                            .help("Equipped")
                        TextField("Item", text: $file.string(path + ["name"]))
                            .frame(minWidth: 120)
                        HStack(spacing: 2) {
                            NumberField(label: "Qty", value: $file.int(path + ["qty"]), prompt: "1")
                                .frame(width: 40)
                            if let quantity = file.int(path + ["qty"]), quantity > 0 {
                                ListButton(title: "Use one", systemImage: "minus.square") {
                                    file.useOne(ofItemAt: index)
                                }
                            }
                        }
                        .frame(width: 64, alignment: .leading)
                        TextField("", text: $file.string(path + ["damage"]), prompt: Text(rulesDamage(at: index)))
                            .frame(width: 60)
                        TextField("", text: $file.string(path + ["notes"]))
                            .frame(minWidth: 100)
                        ListButton(title: "Remove item", systemImage: "minus.circle") {
                            file.removeItem(at: path)
                        }
                    }
                    .textFieldStyle(.plain)
                }
            }
            HStack(spacing: 12) {
                ListButton(title: "Add item", systemImage: "plus.circle") {
                    file.appendItem(to: ["equipment"])
                }
                Button("Add from List…") { isShopping = true }
                    .help("Buy or add weapons, armour and gear from the rules")
            }
        }
        .sheet(isPresented: $isShopping) {
            ShopView(classRules: OSERuleset.classic.classRules(named: file.string(["class"]) ?? ""),
                     purse: Purse(file)) { item, count, pay in
                file.buy(item, count: count, pay: pay)
            }
        }
    }

    /// The rules damage for a weapon, shown in grey when none is typed.
    private func rulesDamage(at index: Int) -> String {
        guard let name = file.string(["equipment", .index(index), "name"]),
              let weapon = OSERuleset.classic.weapon(named: name) else { return "" }
        return file.bool(["rules", "options", "variableWeaponDamage"]) == true ? weapon.damage : "1d6"
    }
}

struct MoneySection: View {
    @Binding var file: CharacterFile

    private let coins = [("PP", "pp", "Platinum"), ("GP", "gp", "Gold"), ("EP", "ep", "Electrum"),
                         ("SP", "sp", "Silver"), ("CP", "cp", "Copper")]

    var body: some View {
        SheetSection(title: "Money") {
            FlowLayout {
                ForEach(coins, id: \.1) { label, key, name in
                    StatBox(label: label, value: $file.int(["money", .key(key)]), width: 80, help: "\(name) pieces")
                }
            }
        }
    }
}

struct NotesSection: View {
    @Binding var text: String

    var body: some View {
        SheetSection(title: "Notes") {
            TextEditor(text: $text)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(8)
                .frame(minHeight: 280)
                .background(.quaternary.opacity(0.3), in: .rect(cornerRadius: 8))
        }
    }
}

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
                .font(.caption)
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
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func attack(_ attack: Attack?) -> some View {
        Group {
            if let attack {
                Text("\(attack.notation)  \(attack.damage)")
                    .monospacedDigit()
                    .help("THAC0 \(attack.thac0) (attack bonus \(attack.bonus >= 0 ? "+" : "")\(attack.bonus)), damage \(attack.damage)")
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

struct RulesNotesSection: View {
    let notes: [RuleNote]

    var body: some View {
        SheetSection(title: "Rules Notes") {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(notes) { note in
                    Label {
                        Text(note.message)
                    } icon: {
                        switch note.kind {
                        case .warning: Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
                        case .info: Image(systemName: "info.circle").foregroundStyle(.secondary)
                        }
                    }
                    .font(.callout)
                }
            }
        }
    }
}
