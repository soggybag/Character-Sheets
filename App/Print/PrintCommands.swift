import CharacterKit
import SwiftUI

/// The character in the frontmost window, for printing.
struct PrintableCharacter {
    let file: CharacterFile
    let fallbackName: String
}

extension FocusedValues {
    @Entry var printableCharacter: PrintableCharacter?
}

/// File → Export as PDF… and Print…
struct PrintCommands: View {
    @FocusedValue(\.printableCharacter) private var character

    var body: some View {
        Button("Export as PDF…") {
            guard let character else { return }
            SheetPDF.export(PrintedSheet(file: character.file, fallbackName: character.fallbackName))
        }
        .disabled(character == nil)
        Button("Print…") {
            guard let character else { return }
            SheetPDF.print(PrintedSheet(file: character.file, fallbackName: character.fallbackName))
        }
        .keyboardShortcut("p")
        .disabled(character == nil)
    }
}
