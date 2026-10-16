import AppKit
import CharacterKit
import SwiftUI

/// File → Import PDF Character Sheet…: each chosen PDF opens as a new,
/// unsaved character.
struct ImportSheetButton: View {
    @Environment(\.newDocument) private var newDocument

    var body: some View {
        Button("Import PDF Character Sheet…") {
            let panel = NSOpenPanel()
            panel.allowedContentTypes = [.pdf]
            panel.allowsMultipleSelection = true
            panel.message = "Choose fillable PDF character sheets to import."
            guard panel.runModal() == .OK else { return }
            for url in panel.urls {
                do {
                    let result = try SheetImport(contentsOf: url)
                    newDocument(CharacterDocument(imported: result, from: url))
                } catch {
                    let alert = NSAlert()
                    alert.messageText = "“\(url.lastPathComponent)” couldn't be imported."
                    alert.informativeText = error.localizedDescription
                    alert.runModal()
                }
            }
        }
        .keyboardShortcut("i", modifiers: [.command, .shift])
    }
}
