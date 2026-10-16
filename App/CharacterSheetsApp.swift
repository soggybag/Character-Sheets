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
            CommandGroup(replacing: .help) {
                HelpCommands()
            }
        }

        Window("New Character", id: NewCharacterView.windowID) {
            NewCharacterView()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        Window("Character Sheets Help", id: HelpView.windowID) {
            HelpView()
        }
        .defaultSize(width: 640, height: 720)
        .defaultLaunchBehavior(UserDefaults.standard.bool(forKey: HelpView.seenKey) ? .suppressed : .presented)

        Window("Open Game License", id: LicenseView.windowID) {
            LicenseView()
        }
        .defaultSize(width: 640, height: 720)
    }
}
