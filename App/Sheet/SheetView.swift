import CharacterKit
import SwiftUI

/// The character sheet: one quiet, scrolling page.
struct SheetView: View {
    @Binding var file: CharacterFile
    var placeholderName: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                if file.headerHadComments {
                    Notice(systemImage: "number",
                           text: "This file's header has # comments. They'll be removed when you save. Move them to Notes to keep them.")
                }
                IdentitySection(file: $file, placeholderName: placeholderName)
                AbilityScoresSection(file: $file)
                CombatSection(file: $file)
                SavesSection(file: $file)
                ExplorationSection(file: $file)
                LanguagesSection(file: $file)
                if showsSpells {
                    SpellsSection(file: $file)
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

/// OSE Classic names used as suggestions. Replaced by the rules data in M3.
enum OSE {
    static let classes = ["Cleric", "Dwarf", "Elf", "Fighter", "Halfling", "Magic-User", "Thief"]
    static let alignments = ["Lawful", "Neutral", "Chaotic"]
    static let spellcastingClasses: Set<String> = ["Cleric", "Elf", "Magic-User"]
}
