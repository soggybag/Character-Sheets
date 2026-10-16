import CharacterKit
import SwiftUI

/// The file's text, with a status bar saying whether it reads as a character.
struct TextEditorView: View {
    @Binding var text: String
    var fileURL: URL?

    var body: some View {
        VStack(spacing: 0) {
            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .autocorrectionDisabled()
                .scrollContentBackground(.hidden)
                .padding(8)
            Divider()
            StatusBar(status: ParseStatus(text: text, fileURL: fileURL))
        }
        .background(.background)
    }
}

enum ParseStatus {
    case character(summary: String)
    case notACharacter
    case error(String)

    init(text: String, fileURL: URL?) {
        do {
            let file = try CharacterFile(text: text)
            guard file.isCharacter else {
                self = .notACharacter
                return
            }
            let name = file.name
                ?? fileURL?.deletingPathExtension().lastPathComponent
                ?? "Unnamed character"
            let details = [file.string(["class"]), file.int(["level"]).map { "level \($0)" }]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
            self = .character(summary: ([name] + details).joined(separator: " · "))
        } catch let error as CharacterFileError {
            self = error == .noFrontMatter ? .notACharacter : .error(error.description)
        } catch {
            self = .error(error.localizedDescription)
        }
    }
}

private struct StatusBar: View {
    let status: ParseStatus

    var body: some View {
        HStack(spacing: 6) {
            switch status {
            case let .character(summary):
                Image(systemName: "checkmark.circle").foregroundStyle(.green)
                Text(summary)
            case .notACharacter:
                Image(systemName: "doc.text").foregroundStyle(.secondary)
                Text("Not a character file. The header needs formatVersion and rules.system.")
            case let .error(message):
                Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
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
