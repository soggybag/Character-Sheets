import CharacterKit
import SwiftUI

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
            .zoomFont(.caption)
            .foregroundStyle(.secondary)
            ForEach(rows.indices, id: \.self) { index in
                let row = rows[index]
                GridRow {
                    CommitTextField(prompt: "Spell", value: row.name) { file.renameSpell(row, to: $0) }
                        .textFieldStyle(.plain)
                        .strikethrough(!row.memorized.isEmpty && row.memorized.allSatisfy { file.isCast(memorized: $0) })
                        .help(row.bookIndex == nil ? "Memorized, but not in the spell book" : "")
                        .zoomFrame(minWidth: 160)
                    NumberField(label: "Level", value: Binding { row.level } set: { file.setSpellLevel(row, to: $0) },
                                prompt: "–")
                        .textFieldStyle(.plain)
                        .labelsHidden()
                        .zoomFrame(width: 32)
                    HStack(spacing: 2) {
                        ListButton(title: "Forget one", systemImage: "minus.circle") { file.forgetOne(row) }
                            .disabled(row.memorized.isEmpty)
                        Text("\(row.memorized.count)")
                            .monospacedDigit()
                            .zoomFrame(minWidth: 16)
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
                                .accessibilityLabel("Cast \(row.name)")
                        }
                    }
                    .zoomFrame(minWidth: 80, alignment: .leading)
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
                .zoomFont(.caption)
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
