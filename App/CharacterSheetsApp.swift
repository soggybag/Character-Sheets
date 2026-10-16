import SwiftUI

@main
struct CharacterSheetsApp: App {
    init() {
        // Smart quotes and dashes would corrupt YAML in "Edit as Text".
        for key in ["NSAutomaticQuoteSubstitutionEnabled",
                    "NSAutomaticDashSubstitutionEnabled",
                    "NSAutomaticTextReplacementEnabled"] {
            UserDefaults.standard.set(false, forKey: key)
        }
    }

    var body: some Scene {
        DocumentGroup(newDocument: CharacterDocument()) { file in
            CharacterWindow(document: file.$document, fileURL: file.fileURL)
        }
        .defaultSize(width: 860, height: 1000)
        .commands {
            CommandGroup(after: .newItem) {
                NewCharacterButton()
                ImportSheetButton()
            }
        }

        Window("New Character", id: NewCharacterView.windowID) {
            NewCharacterView()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}
