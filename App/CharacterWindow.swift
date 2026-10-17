import CharacterKit
import SwiftUI

/// One document window: the sheet, or the file's text.
struct CharacterWindow: View {
    @Binding var document: CharacterDocument
    var fileURL: URL?

    /// Non-nil while a character is being edited as text.
    @State private var textDraft: String?

    var body: some View {
        Group {
            switch document.content {
            case .sheet:
                if let draft = Binding($textDraft) {
                    TextEditorView(text: draft, fileURL: fileURL)
                } else {
                    SheetView(file: sheet, placeholderName: placeholderName)
                }
            case .text:
                TextEditorView(text: plainText, fileURL: fileURL)
            }
        }
        .safeAreaInset(edge: .top) {
            if let summary = document.importSummary {
                ImportBanner(text: summary) { document.importSummary = nil }
            }
        }
        .frame(minWidth: 640, minHeight: 480)
        .toolbar { toolbar }
        .focusedSceneValue(\.printableCharacter, printable)
    }

    private var printable: PrintableCharacter? {
        guard case let .sheet(file) = document.content else { return nil }
        return PrintableCharacter(file: file, fallbackName: placeholderName)
    }

    private var placeholderName: String {
        fileURL?.deletingPathExtension().lastPathComponent ?? "Character name"
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        switch document.content {
        case let .sheet(file):
            if let draft = textDraft {
                ToolbarItem {
                    Button("Cancel") { textDraft = nil }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") { finishTextEditing(draft, original: file) }
                        .disabled((try? CharacterFile(text: draft)) == nil)
                        .keyboardShortcut(.return, modifiers: .command)
                }
            } else {
                ToolbarItem {
                    RulesMenu(file: sheet)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit as Text", systemImage: "curlybraces") { textDraft = file.text() }
                        .help("Edit the file's text directly")
                }
            }
        case let .text(text):
            ToolbarItem(placement: .primaryAction) {
                Button("Show Sheet", systemImage: "person.text.rectangle") {
                    document.content = CharacterDocument.content(for: text)
                }
                .disabled(!((try? CharacterFile(text: text))?.isCharacter ?? false))
                .help("Show this file as a character sheet")
            }
        }
    }

    private func finishTextEditing(_ draft: String, original: CharacterFile) {
        defer { textDraft = nil }
        guard draft != original.text() else { return }
        document.content = CharacterDocument.content(for: draft)
    }

    // MARK: Bindings into the document

    private var sheet: Binding<CharacterFile> {
        Binding {
            if case let .sheet(file) = document.content { return file }
            return CharacterFile()
        } set: {
            document.content = .sheet($0)
        }
    }

    private var plainText: Binding<String> {
        Binding {
            if case let .text(text) = document.content { return text }
            return ""
        } set: {
            document.content = .text($0)
        }
    }
}

/// Per-character rules options.
private struct RulesMenu: View {
    @Binding var file: CharacterFile

    var body: some View {
        Menu("Rules", systemImage: "slider.horizontal.3") {
            Toggle("Ascending AC", isOn: Binding(
                get: { file.usesAscendingAC },
                set: { file.setAscendingAC($0) }))
            Toggle("Variable Weapon Damage", isOn: Binding(
                get: { file.bool(["rules", "options", "variableWeaponDamage"]) ?? false },
                set: { file.setBool($0, at: ["rules", "options", "variableWeaponDamage"]) }))
            Divider()
            Button("Fill In Missing Values") {
                file.fillMissingValues(from: RulesAnalysis(file))
            }
            .help("Write the rules value into every empty field the rules cover")
            Divider()
            Picker("Encumbrance", selection: Binding(
                get: { file.string(["rules", "options", "encumbrance"]) ?? "basic" },
                set: { file.setString($0, at: ["rules", "options", "encumbrance"]) })) {
                Text("None").tag("none")
                Text("Basic").tag("basic")
                Text("Detailed").tag("detailed")
            }
        }
        .help("Rules options for this character")
    }
}

/// Says where an imported character came from.
private struct ImportBanner: View {
    let text: String
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Label(text, systemImage: "doc.richtext")
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Dismiss", systemImage: "xmark", action: dismiss)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
        }
        .font(.callout)
        .padding(10)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
    }
}
