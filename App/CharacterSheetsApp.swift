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
        Self.renderWindowIfAsked()
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

    /// Debug builds only: `-renderWindow about|legal <out.png> [-dark]` draws
    /// that window's content to a PNG and quits, for checking its layout.
    @MainActor
    private static func renderWindowIfAsked() {
        let arguments = CommandLine.arguments
        guard let index = arguments.firstIndex(of: "-renderWindow"), arguments.count > index + 2 else { return }
        let content: AnyView = switch arguments[index + 1] {
        case "legal": AnyView(LegalContent().padding(24).frame(width: 640))
        default: AnyView(AboutView())
        }
        let dark = arguments.contains("-dark")
        let view = content
            .background(dark ? Color.black : Color.white)
            .environment(\.colorScheme, dark ? .dark : .light)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
              let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { exit(1) }
        try? png.write(to: URL(filePath: arguments[index + 2]))
        exit(0)
    }
    #endif

    var body: some Scene {
        DocumentGroup(newDocument: CharacterDocument()) { file in
            CharacterWindow(document: file.$document, fileURL: file.fileURL)
        }
        .defaultSize(width: 860, height: 1000)
        .commands {
            // New Character… (the generator) takes ⌘N; a blank sheet is
            // for people who rolled their character elsewhere.
            CommandGroup(replacing: .newItem) {
                NewCharacterButton()
                NewBlankSheetButton()
            }
            CommandGroup(after: .newItem) {
                ImportSheetButton()
                OpenPartyButton()
            }
            CommandGroup(after: .pasteboard) {
                Divider()
                RulesValueCommand()
            }
            CommandGroup(after: .toolbar) {
                Divider()
                ZoomCommands()
            }
            CommandGroup(replacing: .printItem) {
                PrintCommands()
            }
            CommandGroup(before: .windowArrangement) {
                CharacterWindowCommands()
                Divider()
            }
            CommandGroup(replacing: .appInfo) {
                AboutCommand()
            }
            CommandGroup(replacing: .help) {
                HelpCommands()
            }
        }

        WindowGroup("Party", for: PartyFolder.self) { $folder in
            PartyView(partyFolder: folder)
        }
        .defaultSize(width: 860, height: 360)

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

        Window("About Character Sheets", id: AboutView.windowID) {
            AboutView()
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .defaultPosition(.center)

        Window("Licenses and Legal", id: LicenseView.windowID) {
            LicenseView()
        }
        .defaultSize(width: 640, height: 720)

        Settings {
            SettingsView()
        }
    }
}
