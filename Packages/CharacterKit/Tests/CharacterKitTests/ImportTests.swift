import Foundation
import Testing
@testable import CharacterKit

/// Form fields read from real PDF character sheets (values only; the PDFs
/// themselves contain artwork and stay out of the repo).
private let fixtures = Bundle.module.url(forResource: "Fixtures/pdf-fields", withExtension: nil)!

private func imported(_ name: String) throws -> SheetImport {
    let data = try Data(contentsOf: fixtures.appending(path: "\(name).json"))
    return try SheetImport(fields: JSONDecoder().decode([String: String].self, from: data))
}

private let examples = URL(filePath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appending(path: "examples")

private func example(_ name: String) throws -> CharacterFile {
    try CharacterFile(text: String(contentsOf: examples.appending(path: "\(name).md"), encoding: .utf8))
}

private func equippedNames(_ file: CharacterFile) -> [String] {
    (0..<file.count(["equipment"])).compactMap { index in
        file.bool(["equipment", .index(index), "equipped"]) == true
            ? file.string(["equipment", .index(index), "name"]) : nil
    }.sorted()
}

@Suite("PDF import")
struct ImportTests {
    /// PDF → the hand-converted example of the same character.
    static let pairs: [(pdf: String, example: String, layout: SheetImport.Layout)] = [
        ("Cedric cleric", "Brother Cedric", .ascending),
        ("Fingle the Elf", "Fingle the Elf", .descending),
        ("Marlek the Magic-User", "Marlek the Magic-User", .descending),
        ("Ronk the Fighter", "Ronk the Fighter", .descending),
        ("the Halfling", "the Halfling", .ascending),
        ("the Thief", "the Thief", .descending),
    ]

    @Test(arguments: pairs.indices)
    func matchesTheHandConvertedExample(_ index: Int) throws {
        let (pdf, exampleName, layout) = Self.pairs[index]
        let result = try imported(pdf)
        let file = result.file
        let expected = try example(exampleName)

        #expect(result.layout == layout)
        #expect(result.skipped.isEmpty)
        let paths: [NodePath] = [
            ["rules", "options", "ascendingAC"], ["name"], ["class"], ["level"], ["alignment"], ["xp"],
            ["abilityScores"], ["hp"], ["combat"], ["saves"], ["languages"], ["money"], ["spells", "spellbook"],
        ]
        for path in paths {
            #expect(file[path] == expected[path], "\(pdf): \(path.dotted)")
        }
        #expect(equippedNames(file) == equippedNames(expected), "\(pdf)")
        #expect(file.count(["equipment"]) == expected.count(["equipment"]), "\(pdf)")
        // The result is a well-formed file that loads back unchanged.
        #expect(try CharacterFile(text: file.text()).text() == file.text())
    }

    @Test func sameCharacterOnThreeSheets() throws {
        var descending = try imported("the Cleric-1").file
        let ascending = try imported("Cedric cleric").file
        let illustrated = try imported("the Cleric-2")
        #expect(illustrated.layout == .illustrated)

        descending.setAscendingAC(true)
        for path: NodePath in [["combat"], ["abilityScores"], ["saves"], ["hp"], ["equipment"], ["money"]] {
            #expect(descending[path] == ascending[path], "\(path.dotted)")
            #expect(illustrated.file[path] == ascending[path], "\(path.dotted)")
        }
        #expect(illustrated.file.body == ascending.body)
    }

    @Test func bodyHasDescriptionAndNotes() throws {
        let cedric = try imported("Cedric cleric").file
        #expect(cedric.body == """

            # Description

            - **Appearance:** shadowy, willowy
            - **Background:** Armourer
            - **Personality:** merciful, lustful
            - **Misfortune:** poisoned

            # Notes

            """)
        let fingle = try imported("Fingle the Elf").file
        #expect(fingle.body.hasSuffix("# Notes\n\nAbove the golems path, where stone meets stone, seek the door that is not.”\n"))
    }

    @Test func spellsFromNotesAreNotRepeatedInTheBody() throws {
        let marlek = try imported("Marlek the Magic-User").file
        #expect(marlek.strings(["spells", "memorized"]).isEmpty)  // items are maps, not strings
        #expect(marlek.string(["spells", "memorized", 0, "name"]) == "Charm Person")
        #expect(!marlek.body.contains("Charm Person"))
    }

    @Test func currentAndMaxHitPointsInOneBox() throws {
        let result = try SheetImport(fields: ["Name": "Ada", "HP": "6/3", "THAC0": "19"])
        #expect(result.file.int(["hp", "max"]) == 6)
        #expect(result.file.int(["hp", "current"]) == 3)
    }

    @Test func unknownFieldsAreReported() throws {
        let result = try SheetImport(fields: ["Name": "Ada", "Favourite Colour": "Blue", "THAC4": "15", "Notes": ""])
        #expect(result.skipped == ["Favourite Colour"])
        #expect(result.layout == .unknown)
    }

    @Test func emptyOrUnrelatedFormsAreErrors() {
        #expect(throws: SheetImportError.noFormFields) { try SheetImport(fields: [:]) }
        #expect(throws: SheetImportError.noFormFields) { try SheetImport(fields: ["Name": "  "]) }
        #expect(throws: SheetImportError.nothingRecognised) { try SheetImport(fields: ["Invoice": "42"]) }
    }

    @Test func realPDFsWhenPresent() throws {
        let folder = URL(filePath: NSHomeDirectory()).appending(path: "Documents/Game/OSR/OSE/OSE Characters")
        let pdfs = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil))?
            .filter { $0.pathExtension == "pdf" } ?? []
        for pdf in pdfs {
            let fromPDF = try SheetImport(contentsOf: pdf)
            let fromFixture = try imported(pdf.deletingPathExtension().lastPathComponent)
            #expect(fromPDF.file.text() == fromFixture.file.text(), "\(pdf.lastPathComponent)")
        }
    }
}

@Suite("PDF import text parsing")
struct ImportParsingTests {
    @Test func items() {
        #expect(SheetImport.items(in: "Rations (iron, 7 days), Backpack, ") == ["Rations (iron, 7 days)", "Backpack"])
        #expect(SheetImport.items(in: ", Common") == ["Common"])
        #expect(SheetImport.items(in: "Long bow, Arrows\n    (16), Sword") == ["Long bow", "Arrows (16)", "Sword"])
    }

    @Test func quantities() {
        #expect(SheetImport.item("Torches (6)") == ("Torches", 6))
        #expect(SheetImport.item("Caltrops (bag of 20)") == ("Caltrops (bag of 20)", nil))
        #expect(SheetImport.item("Sword") == ("Sword", nil))
    }

    @Test func sections() {
        let text = "\n    Weapons: Long bow, Arrows\n    (16), Sword\n    Armour: 3 [16] 60 500\n \n    "
        #expect(SheetImport.sections(in: text) == ["weapons": "Long bow, Arrows (16), Sword", "armour": "3 [16] 60 500"])
    }

    @Test func armour() {
        let rules = OSERuleset.classic
        #expect(SheetImport.armourName("3 [16] 60 500", rules: rules) == "Plate mail")
        #expect(SheetImport.armourName("Unarmoured", rules: rules) == nil)
        #expect(SheetImport.armourName("Elven chain", rules: rules) == "Elven chain")
    }

    @Test func numbers() {
        #expect(SheetImport.firstNumber(in: "3 [16]") == 3)
        #expect(SheetImport.firstNumber(in: "+2") == 2)
        #expect(SheetImport.firstNumber(in: "−1") == -1)
        #expect(SheetImport.firstNumber(in: "2-in-6") == 2)
        #expect(SheetImport.firstNumber(in: "none") == nil)
    }
}
