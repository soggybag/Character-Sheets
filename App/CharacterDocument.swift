import CharacterKit
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let markdownText = UTType(importedAs: "net.daringfireball.markdown", conformingTo: .plainText)
}

/// A character file. Character files open as a sheet and are saved through
/// CharacterKit; anything else (or a header that doesn't parse) opens as
/// plain text and is saved exactly as typed.
struct CharacterDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.markdownText] }

    enum Content {
        case sheet(CharacterFile)
        case text(String)
    }

    var content: Content
    /// Shown above a just-imported character until dismissed. Not saved.
    var importSummary: String?

    init() {
        // The template is covered by CharacterKit's tests.
        content = .sheet(try! CharacterFile(text: CharacterFile.newCharacterTemplate))
    }

    /// A new, unsaved character.
    init(file: CharacterFile) {
        content = .sheet(file)
    }

    /// A new, unsaved character made from an imported PDF sheet.
    init(imported result: SheetImport, from url: URL) {
        content = .sheet(result.file)
        var summary = "Imported from “\(url.lastPathComponent)”. Check it against the PDF, then save."
        if !result.skipped.isEmpty {
            summary += " Not imported: " + result.skipped.joined(separator: ", ") + "."
        }
        importSummary = summary
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        guard let text = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }
        content = Self.content(for: text)
    }

    static func content(for text: String) -> Content {
        if let file = try? CharacterFile(text: text), file.isCharacter {
            return .sheet(file)
        }
        return .text(text)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let text = switch content {
        case let .sheet(file): file.text()
        case let .text(text): text
        }
        return FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
