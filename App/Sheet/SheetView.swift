import CharacterKit
import SwiftUI

/// The character sheet: one quiet, scrolling page.
struct SheetView: View {
    @Binding var file: CharacterFile
    var placeholderName: String

    @State private var levelUpPlan: LevelUpPlan?
    @State private var levelDownPlan: LevelDownPlan?

    var body: some View {
        let analysis = RulesAnalysis(file)
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                if file.headerHadComments {
                    Notice(systemImage: "number",
                           text: "This file's header has # comments. They'll be removed when you save. Move them to Notes to keep them.")
                }
                IdentitySection(file: $file, analysis: analysis, placeholderName: placeholderName,
                                levelUp: { levelUpPlan = RulesAnalysis(file).levelUpPlan(for: file) ?? beep() },
                                levelDown: { levelDownPlan = RulesAnalysis(file).levelDownPlan(for: file) ?? beep() })
                if !analysis.notes.isEmpty {
                    RulesNotesSection(notes: analysis.notes)
                }
                AbilityScoresSection(file: $file, analysis: analysis)
                CombatSection(file: $file, analysis: analysis)
                if !analysis.weapons.isEmpty {
                    WeaponsSection(file: file, analysis: analysis)
                }
                SavesSection(file: $file, analysis: analysis)
                ExplorationSection(file: $file, analysis: analysis)
                LanguagesSection(file: $file)
                if showsSpells {
                    SpellsSection(file: $file, analysis: analysis)
                }
                EquipmentSection(file: $file)
                MoneySection(file: $file)
                NotesSection(text: $file.body)
                if !file.unknownTopLevelKeys.isEmpty {
                    Notice(systemImage: "ellipsis.curlybraces",
                           text: "This file also has: \(file.unknownTopLevelKeys.joined(separator: ", ")). They're kept as they are; use Edit as Text to change them.")
                }
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 32)
            .frame(maxWidth: 820)
            .frame(maxWidth: .infinity)
        }
        .background(.background)
        .sheet(item: $levelUpPlan) { plan in
            LevelUpSheet(plan: plan, file: $file)
        }
        .sheet(item: $levelDownPlan) { plan in
            LevelDownSheet(plan: plan, file: $file)
        }
    }

    // The plans above are made from the file as it is when clicked. A menu
    // can keep an action from when it was built, so the `analysis` captured
    // with it may be out of date (it once offered level 2 → 1 at level 1).

    private func beep<T>() -> T? {
        NSSound.beep()
        return nil
    }

    private var showsSpells: Bool {
        file.count(["spells"]) > 0 || OSE.spellcastingClasses.contains(file.string(["class"]) ?? "")
    }
}

private struct Notice: View {
    let systemImage: String
    let text: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 8))
    }
}

/// Classic Fantasy names used as suggestions.
enum OSE {
    static let classes = ["Cleric", "Dwarf", "Elf", "Fighter", "Halfling", "Magic-User", "Thief"]
    static let alignments = ["Lawful", "Neutral", "Chaotic"]
    static let spellcastingClasses: Set<String> = ["Cleric", "Elf", "Magic-User"]
}
