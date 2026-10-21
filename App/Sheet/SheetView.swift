import CharacterKit
import SwiftUI

/// The character sheet: one quiet, scrolling page.
struct SheetView: View {
    @Binding var file: CharacterFile
    var placeholderName: String

    @State private var levelUpPlan: LevelUpPlan?
    @State private var levelDownPlan: LevelDownPlan?
    /// Narrow windows get narrower margins.
    @State private var isNarrow = false
    @AppStorage(SheetZoom.key) private var zoom = 1.0

    var body: some View {
        let analysis = RulesAnalysis.ofSheet(file)
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                if file.headerHadComments {
                    Notice(systemImage: "number",
                           text: "This file's header has # comments. They'll be removed when you save. Move them to Notes to keep them.")
                }
                IdentitySection(file: $file, analysis: analysis, placeholderName: placeholderName,
                                levelUp: { levelUpPlan = RulesAnalysis.ofSheet(file).levelUpPlan(for: file) ?? beep() },
                                levelDown: { levelDownPlan = RulesAnalysis.ofSheet(file).levelDownPlan(for: file) ?? beep() })
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
                if !analysis.classAbilities.isEmpty {
                    ClassAbilitiesSection(analysis: analysis)
                }
                LanguagesSection(file: $file)
                if showsSpells(analysis) {
                    SpellsSection(file: $file, analysis: analysis)
                }
                EquipmentSection(file: $file, analysis: analysis)
                MoneySection(file: $file)
                NotesSection(text: $file.body)
                if !file.unknownTopLevelKeys.isEmpty {
                    Notice(systemImage: "ellipsis.curlybraces",
                           text: "This file also has: \(file.unknownTopLevelKeys.joined(separator: ", ")). They're kept as they are; use Edit as Text to change them.")
                }
            }
            .padding(.horizontal, isNarrow ? 20 : 40)
            .padding(.vertical, 32)
            .frame(maxWidth: 820 * zoom)
            .frame(maxWidth: .infinity)
            .zoomFont(.body)
            .controlSize(zoom >= 1.3 ? .large : .regular)
            .environment(\.sheetZoom, zoom)
        }
        .background(.background)
        .onGeometryChange(for: Bool.self) { $0.size.width < 640 } action: { isNarrow = $0 }
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

    private func showsSpells(_ analysis: RulesAnalysis) -> Bool {
        file.count(["spells"]) > 0 || analysis.classRules?.spellcasting != nil
    }
}

private struct Notice: View {
    let systemImage: String
    let text: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .zoomFont(.callout)
            .foregroundStyle(.secondary)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 8))
    }
}

