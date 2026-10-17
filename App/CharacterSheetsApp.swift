import CharacterKit
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
        #if DEBUG
        Self.renderPDFIfAsked()
        #endif
    }

    #if DEBUG
    /// Debug builds only: `-renderPDF <character.md> <out.pdf>` writes the
    /// printed sheet and quits, for checking the print layout.
    private static func renderPDFIfAsked() {
        let arguments = CommandLine.arguments
        guard let index = arguments.firstIndex(of: "-renderPDF"), arguments.count > index + 2 else { return }
        let input = URL(filePath: arguments[index + 1])
        guard let text = try? String(contentsOf: input, encoding: .utf8),
              let file = try? CharacterFile(text: text) else { exit(1) }
        let sheet = PrintedSheet(file: file, fallbackName: input.deletingPathExtension().lastPathComponent)
        let paper = arguments.contains("-a4") ? CGSize(width: 595, height: 842) : CGSize(width: 612, height: 792)
        try? SheetPDF.make(sheet, paperSize: paper).write(to: URL(filePath: arguments[index + 2]))
        exit(0)
    }
    #endif

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
            CommandGroup(replacing: .printItem) {
                PrintCommands()
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
