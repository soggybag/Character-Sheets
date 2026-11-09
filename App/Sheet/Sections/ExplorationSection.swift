import CharacterKit
import SwiftUI

struct ExplorationSection: View {
    @Binding var file: CharacterFile
    let analysis: RulesAnalysis

    var body: some View {
        SheetSection(title: "Exploration") {
            MovementRow(file: $file, analysis: analysis)
            FlowLayout {
                inSix("Listen", "listen", help: "Listen at doors")
                inSix("Secret doors", "secretDoors", help: "Find secret doors")
                inSix("Open doors", "openDoors", help: "Force open stuck doors")
                inSix("Room traps", "findTraps", help: "Find room traps")
                if analysis.classRules?.exploration?["constructionTricks"] != nil
                    || analysis.raceRules?.exploration?["constructionTricks"] != nil
                    || file.int(["exploration", "constructionTricks"]) != nil {
                    inSix("Construction", "constructionTricks", help: "Detect construction tricks")
                }
            }
            // The class's skills (a thief's, an acrobat's, a ranger's tracking).
            let skills = analysis.skillBoxes(for: file)
            if !skills.isEmpty {
                FlowLayout {
                    ForEach(skills) { skill in
                        RuledStatBox(label: skill.label, path: skill.path, file: $file, analysis: analysis,
                                     suffix: skill.suffix, width: skill.kind == .inSix || skill.label.count > 8 ? 84 : 72,
                                     help: skill.name)
                    }
                }
                .padding(.top, 6)
            }
        }
    }

    private func inSix(_ label: String, _ key: String, help: String) -> some View {
        RuledStatBox(label: label, path: ["exploration", .key(key)], file: $file, analysis: analysis,
                     suffix: "in 6", width: 84, help: help)
    }
}

/// Movement while exploring: the rate per turn, overland travel, and (for
/// basic encumbrance) whether the character carries a lot of treasure.
struct MovementRow: View {
    @Binding var file: CharacterFile
    let analysis: RulesAnalysis

    var body: some View {
        let movement = MovementSummary(file: file, analysis: analysis)
        FlowLayout(alignment: .top) {
            RuledStatBox(label: "Move", path: ["movement"], file: $file, analysis: analysis, suffix: "'",
                         width: 72, help: "Movement rate: feet per turn while exploring",
                         caption: movement.isEncumbered ? "encumbered" : "per turn",
                         captionHelp: movement.isEncumbered ? movement.explanation : "Feet per turn (10 minutes)",
                         highlighted: movement.isEncumbered)
            ValueBox(label: "Travel", value: movement.travelRate, suffix: "mi", width: 72,
                     help: "Overland travel: a fifth of the rate per turn, in miles a day. "
                         + "Terrain and forced marches change it.",
                     caption: "per day", highlighted: movement.isEncumbered)
            if case let .basic(treasure) = analysis.movement?.load {
                Toggle("Carrying treasure", isOn: Binding(
                    get: { treasure },
                    set: { file.setCarryingTreasure($0, equipmentList: analysis.equipmentList) }))
                    .toggleStyle(.checkbox)
                    .help("Basic encumbrance: a lot of treasure slows the character to the next rate down")
                    .padding(.top, 24)
            }
        }
    }
}

/// What the class (and race) can do at this level, from the rules, and
/// what comes later. Read-only: anything else (a magic item's power, a
/// house rule) goes in Notes.
struct ClassAbilitiesSection: View {
    let analysis: RulesAnalysis
    @Environment(\.sheetZoom) private var zoom

    var body: some View {
        SheetSection(title: analysis.raceAbilities.isEmpty ? "Class Abilities" : "Abilities") {
            // One Text, so a selection can run across abilities (and copy them all).
            abilities
                .lineSpacing(4 * zoom)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
            if !analysis.laterAbilities.isEmpty {
                Text("Later: " + analysis.laterAbilities
                    .map { "\($0.name) (level \($0.minLevel ?? 1))" }.joined(separator: ", "))
                    .zoomFont(.caption)
                    .foregroundStyle(.secondary)
                    .help(analysis.laterAbilities.map { "\($0.name), level \($0.minLevel ?? 1): \($0.summary)" }
                        .joined(separator: "\n"))
            }
        }
    }

    /// The class's abilities, then the race's under its name, a line each.
    private var abilities: Text {
        var lines = analysis.classAbilities.map(line)
        if let race = analysis.raceRules, !analysis.raceAbilities.isEmpty {
            lines.append(Text(race.name)
                .font(.system(size: SheetZoom.pointSize(.caption) * zoom))
                .foregroundStyle(.secondary))
            lines += analysis.raceAbilities.map(line)
        }
        return lines.enumerated().reduce(Text("")) { text, entry in
            Text("\(text)\(entry.offset == 0 ? "" : "\n")\(entry.element)")
        }
    }

    private func line(_ ability: ClassRules.Feature) -> Text {
        Text("\(Text(ability.name).bold())  \(Text(ability.summary).foregroundStyle(.secondary))")
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
