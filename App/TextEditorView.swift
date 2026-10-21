import CharacterKit
import SwiftUI

/// The file's text, with a status bar saying whether it reads as a character.
struct TextEditorView: View {
    @Binding var text: String
    var fileURL: URL?

    var body: some View {
        VStack(spacing: 0) {
            PlainTextEditor(text: $text, font: .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular),
                            inset: CGSize(width: 12, height: 12))
            Divider()
            StatusBar(status: TextFileStatus(text: text, fileName: fileURL?.deletingPathExtension().lastPathComponent))
        }
        .background(.background)
    }
}

private struct StatusBar: View {
    let status: TextFileStatus

    var body: some View {
        HStack(spacing: 6) {
            switch status {
            case let .character(summary):
                Image(systemName: "checkmark.circle").foregroundStyle(.green).accessibilityHidden(true)
                Text(summary)
            case let .equipmentList(summary, problems):
                if let first = problems.first {
                    Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
                        .accessibilityLabel("Problem")
                    Text(problems.count == 1 ? first : "\(first) (and \(problems.count - 1) more)")
                        .help(problems.joined(separator: "\n"))
                } else {
                    Image(systemName: "bag").foregroundStyle(.secondary).accessibilityHidden(true)
                    Text(summary)
                }
            case .notACharacter:
                Image(systemName: "doc.text").foregroundStyle(.secondary).accessibilityHidden(true)
                Text("Not a character file. The header needs formatVersion and rules.system.")
            case let .error(message):
                Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
                    .accessibilityLabel("Error")
                Text(message)
            }
            Spacer()
        }
        .font(.callout)
        .lineLimit(1)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}
