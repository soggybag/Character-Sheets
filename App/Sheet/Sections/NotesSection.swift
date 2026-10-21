import CharacterKit
import SwiftUI

struct NotesSection: View {
    @Binding var text: String
    @Environment(\.sheetZoom) private var zoom

    var body: some View {
        SheetSection(title: "Notes") {
            PlainTextEditor(text: $text, font: .systemFont(ofSize: SheetZoom.pointSize(.body) * zoom))
                .frame(minHeight: 280 * zoom)
                .background(.quaternary.opacity(0.3), in: .rect(cornerRadius: 8))
        }
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
                            .accessibilityLabel("Warning")
                        case .info: Image(systemName: "info.circle").foregroundStyle(.secondary)
                            .accessibilityLabel("Note")
                        }
                    }
                    .zoomFont(.callout)
                }
            }
        }
    }
}
