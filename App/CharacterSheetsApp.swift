import SwiftUI

@main
struct CharacterSheetsApp: App {
    init() {
        // The M1 editor shows raw YAML. Smart quotes and dashes would corrupt it.
        for key in ["NSAutomaticQuoteSubstitutionEnabled",
                    "NSAutomaticDashSubstitutionEnabled",
                    "NSAutomaticTextReplacementEnabled"] {
            UserDefaults.standard.set(false, forKey: key)
        }
    }

    var body: some Scene {
        DocumentGroup(newDocument: CharacterTextDocument()) { file in
            RawEditorView(document: file.$document, fileURL: file.fileURL)
        }
    }
}
