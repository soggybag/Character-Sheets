import CharacterKit
import SwiftUI

struct IdentitySection: View {
    @Binding var file: CharacterFile
    let analysis: RulesAnalysis
    let placeholderName: String
    let levelUp: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("Name", text: $file.string(["name"]), prompt: Text(placeholderName))
                .textFieldStyle(.plain)
                .font(.system(size: 30, weight: .semibold, design: .serif))
            HStack(alignment: .bottom, spacing: 20) {
                LineField(label: "Class", text: $file.string(["class"]), suggestions: OSE.classes)
                LineField(label: "Alignment", text: $file.string(["alignment"]), suggestions: OSE.alignments)
                LineNumberField(label: "Level", value: $file.int(["level"]))
                    .frame(width: 60)
                LineNumberField(label: "XP", value: $file.int(["xp"]), caption: xpCaption)
                    .frame(width: 110)
                    .help(xpHelp)
                levelUpButton
            }
            HStack(spacing: 20) {
                LineField(label: "Title", text: $file.string(["title"]))
                LineField(label: "Player", text: $file.string(["player"]))
            }
        }
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

    @ViewBuilder private var levelUpButton: some View {
        let button = Button("Level Up…", action: levelUp)
            .disabled(analysis.classRules == nil || analysis.level == nil)
            .help(analysis.xp?.readyToLevelUp == true ? "Enough XP for the next level" : "Go up a level")
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
            HStack(spacing: 12) {
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

    var body: some View {
        SheetSection(title: "Combat") {
            HStack(alignment: .top, spacing: 12) {
                StatBox(label: "HP", value: $file.int(["hp", "current"]), help: "Current hit points")
                HitPointAdjuster(file: $file)
                StatBox(label: "Max HP", value: $file.int(["hp", "max"]), help: "Maximum hit points",
                        caption: analysis.hitDice.map { "HD \($0)" },
                        captionHelp: analysis.hitPointRoll.map { "Roll \($0) per level (at least 1)" })
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
            HStack(spacing: 12) {
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
            HStack(spacing: 12) {
                inSix("Listen", "listen", help: "Listen at doors")
                inSix("Secret doors", "secretDoors", help: "Find secret doors")
                inSix("Open doors", "openDoors", help: "Force open stuck doors")
                inSix("Room traps", "findTraps", help: "Find room traps")
                if className == "Dwarf" || file.int(["exploration", "constructionTricks"]) != nil {
                    inSix("Construction", "constructionTricks", help: "Detect construction tricks")
                }
            }
            if className == "Thief" || file.count(["thiefSkills"]) > 0 {
                HStack(spacing: 12) {
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
            HStack(alignment: .bottom, spacing: 12) {
                ForEach(0..<max(file.count(["spells", "slots"]), 1), id: \.self) { level in
                    StatBox(label: ordinals[min(level, ordinals.count - 1)], value: slot(level),
                            help: "Spells per day of level \(level + 1)")
                }
                ListButton(title: "Add spell level", systemImage: "plus.circle") {
                    file.appendInt(0, to: ["spells", "slots"])
                }
                .padding(.bottom, 10)
                if file.count(["spells", "slots"]) > 1 {
                    ListButton(title: "Remove spell level", systemImage: "minus.circle") {
                        file.removeItem(at: ["spells", "slots", .index(file.count(["spells", "slots"]) - 1)])
                    }
                    .padding(.bottom, 10)
                }
                slotRulesHint
                    .padding(.bottom, 10)
            }

            HStack(alignment: .top, spacing: 32) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Spell book").font(.caption).foregroundStyle(.secondary)
                    ForEach(0..<file.count(["spells", "spellbook"]), id: \.self) { index in
                        let path: NodePath = ["spells", "spellbook", .index(index)]
                        HStack {
                            TextField("Spell", text: $file.string(path + ["name"]))
                                .textFieldStyle(.plain)
                            NumberField(label: "Lvl", value: $file.int(path + ["level"]))
                                .textFieldStyle(.plain)
                                .frame(width: 28)
                                .help("Spell level")
                            ListButton(title: "Remove spell", systemImage: "minus.circle") {
                                file.removeItem(at: path)
                            }
                        }
                        Divider()
                    }
                    ListButton(title: "Add spell", systemImage: "plus.circle") {
                        let index = file.appendItem(to: ["spells", "spellbook"])
                        file.setInt(1, at: ["spells", "spellbook", .index(index), "level"])
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Memorized").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button("Rest") { file.resetCastSpells() }
                            .buttonStyle(.link)
                            .font(.caption)
                            .disabled(file.castSpellCount == 0)
                            .help("Clear every Cast mark after a night's rest")
                    }
                    ForEach(0..<file.count(["spells", "memorized"]), id: \.self) { index in
                        let path: NodePath = ["spells", "memorized", .index(index)]
                        HStack {
                            Toggle("Cast", isOn: $file.flag(path + ["cast"]))
                                .labelsHidden()
                                .help("Cast today")
                            TextField("Spell", text: $file.string(path + ["name"]))
                                .textFieldStyle(.plain)
                                .strikethrough(file.bool(path + ["cast"]) ?? false)
                            ListButton(title: "Remove", systemImage: "minus.circle") {
                                file.removeItem(at: path)
                            }
                        }
                        Divider()
                    }
                    ListButton(title: "Memorize a spell", systemImage: "plus.circle") {
                        file.appendItem(to: ["spells", "memorized"])
                    }
                }
            }
            .padding(.top, 6)
        }
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
                            .frame(minWidth: 160)
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
                        TextField("", text: $file.string(path + ["damage"]))
                            .frame(width: 60)
                        TextField("", text: $file.string(path + ["notes"]))
                            .frame(minWidth: 140)
                        ListButton(title: "Remove item", systemImage: "minus.circle") {
                            file.removeItem(at: path)
                        }
                    }
                    .textFieldStyle(.plain)
                }
            }
            ListButton(title: "Add item", systemImage: "plus.circle") {
                file.appendItem(to: ["equipment"])
            }
        }
    }
}

struct MoneySection: View {
    @Binding var file: CharacterFile

    private let coins = [("PP", "pp", "Platinum"), ("GP", "gp", "Gold"), ("EP", "ep", "Electrum"),
                         ("SP", "sp", "Silver"), ("CP", "cp", "Copper")]

    var body: some View {
        SheetSection(title: "Money") {
            HStack(spacing: 12) {
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
