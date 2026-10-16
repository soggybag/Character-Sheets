import CharacterKit
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let markdownText = UTType(importedAs: "net.daringfireball.markdown", conformingTo: .plainText)
}

/// A character file held as raw text. Saving writes back exactly what's in
/// the editor; parsing happens only to show the status bar.
struct CharacterTextDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.markdownText] }

    var text: String

    init(text: String = CharacterFile.newCharacterTemplate) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        guard let text = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }
        self.text = text
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
