import CharacterKit
import SwiftUI

struct IdentitySection: View {
    @Binding var file: CharacterFile
    let placeholderName: String

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
                LineNumberField(label: "XP", value: $file.int(["xp"]))
                    .frame(width: 100)
            }
            HStack(spacing: 20) {
                LineField(label: "Title", text: $file.string(["title"]))
                LineField(label: "Player", text: $file.string(["player"]))
            }
        }
    }
}

struct AbilityScoresSection: View {
    @Binding var file: CharacterFile

    private let scores = [("STR", "str", "Strength"), ("INT", "int", "Intelligence"), ("WIS", "wis", "Wisdom"),
                          ("DEX", "dex", "Dexterity"), ("CON", "con", "Constitution"), ("CHA", "cha", "Charisma")]

    var body: some View {
        SheetSection(title: "Ability Scores") {
            HStack(spacing: 12) {
                ForEach(scores, id: \.1) { label, key, name in
                    StatBox(label: label, value: $file.int(["abilityScores", .key(key)]), help: name)
                }
            }
        }
    }
}

struct CombatSection: View {
    @Binding var file: CharacterFile

    var body: some View {
        SheetSection(title: "Combat") {
            HStack(spacing: 12) {
                StatBox(label: "HP", value: $file.int(["hp", "current"]), help: "Current hit points")
                StatBox(label: "Max HP", value: $file.int(["hp", "max"]), help: "Maximum hit points")
                StatBox(label: "AC", value: $file.int(["combat", "ac"]),
                        help: file.usesAscendingAC ? "Armour class (ascending)" : "Armour class")
                if file.usesAscendingAC {
                    StatBox(label: "Attack", value: $file.int(["combat", "attackBonus"]), width: 72,
                            help: "Attack bonus")
                } else {
                    StatBox(label: "THAC0", value: $file.int(["combat", "thac0"]), help: "To hit AC 0")
                }
                StatBox(label: "Move", value: $file.int(["movement"]), suffix: "'", width: 72,
                        help: "Base movement rate (feet per turn)")
            }
        }
    }
}

struct SavesSection: View {
    @Binding var file: CharacterFile

    private let saves = [("Death", "death", "Death / poison"), ("Wands", "wands", "Wands"),
                         ("Paralysis", "paralysis", "Paralysis / petrify"), ("Breath", "breath", "Breath attacks"),
                         ("Spells", "spells", "Spells / rods / staves")]

    var body: some View {
        SheetSection(title: "Saving Throws") {
            HStack(spacing: 12) {
                ForEach(saves, id: \.1) { label, key, help in
                    StatBox(label: label, value: $file.int(["saves", .key(key)]), width: 72, help: help)
                }
            }
        }
    }
}

struct ExplorationSection: View {
    @Binding var file: CharacterFile

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
                    StatBox(label: "Hear", value: $file.int(["thiefSkills", "hearNoise"]), suffix: "in 6",
                            width: 84, help: "Hear noise")
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
        StatBox(label: label, value: $file.int(["exploration", .key(key)]), suffix: "in 6", width: 84, help: help)
    }

    private func percent(_ label: String, _ key: String, help: String) -> some View {
        StatBox(label: label, value: $file.int(["thiefSkills", .key(key)]), suffix: "%", width: 72, help: help)
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
            }

            HStack(alignment: .top, spacing: 32) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Spell book").font(.caption).foregroundStyle(.secondary)
                    ForEach(0..<file.count(["spells", "spellbook"]), id: \.self) { index in
                        let path: NodePath = ["spells", "spellbook", .index(index)]
                        HStack {
                            TextField("Spell", text: $file.string(path + ["name"]))
                                .textFieldStyle(.plain)
                            TextField("Lvl", value: $file.int(path + ["level"]), format: .number)
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
                    Text("Memorized").font(.caption).foregroundStyle(.secondary)
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
                        TextField("1", value: $file.int(path + ["qty"]), format: .number)
                            .frame(width: 44)
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
