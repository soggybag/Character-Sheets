import Foundation
import Testing
import Yams
@testable import CharacterKit

/// The repo's examples/ folder.
private let examplesURL = URL(filePath: #filePath)
    .deletingLastPathComponent()   // CharacterKitTests
    .deletingLastPathComponent()   // Tests
    .deletingLastPathComponent()   // CharacterKit
    .deletingLastPathComponent()   // Packages
    .deletingLastPathComponent()   // repo root
    .appending(path: "examples")

private let exampleFiles: [URL] = {
    let urls = (try? FileManager.default.contentsOfDirectory(at: examplesURL, includingPropertiesForKeys: nil)) ?? []
    return urls.filter { $0.pathExtension == "md" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
}()

@Suite("Example files")
struct ExampleFileTests {
    @Test func examplesExist() {
        #expect(exampleFiles.count >= 7)
    }

    @Test("Load and save without changing a byte", arguments: exampleFiles)
    func roundTrip(_ url: URL) throws {
        let original = try String(contentsOf: url, encoding: .utf8)
        let file = try CharacterFile(text: original)
        #expect(file.text() == original)
    }

    @Test("Recognised as OSE characters", arguments: exampleFiles)
    func recognised(_ url: URL) throws {
        let file = try CharacterFile(text: String(contentsOf: url, encoding: .utf8))
        #expect(file.isCharacter)
        #expect(file.formatVersion == 1)
        #expect(file.system == "ose")
    }
}

@Suite("Round trips")
struct RoundTripTests {
    @Test func unknownKeysKeepTheirPlaceAndValue() throws {
        let text = """
        ---
        formatVersion: 1
        homebrew:
          sanity: 12
          corruption: { level: 2, source: "The Black Pool" }
        rules:
          system: ose
          houseRule: true
        name: Ronk
        ---
        Notes.

        """
        var file = try CharacterFile(text: text)
        file.header["name"] = "Ronk the Bold"
        #expect(file.text() == text.replacingOccurrences(of: "name: Ronk", with: "name: Ronk the Bold"))
    }

    @Test func blockMapsStayBlockAndFlowMapsStayFlow() throws {
        let text = """
        ---
        abilityScores:
          str: 13
          int: 9
        saves: { death: 12, wands: 13 }
        languages:
          - Common
          - Elvish
        ---

        """
        #expect(try CharacterFile(text: text).text() == text)
    }

    @Test func quotingIsKept() throws {
        let text = """
        ---
        a: "No"
        b: 'it''s'
        c: "Rope (50')"
        d: { name: "Rope, 50'" }
        e: "12"
        ---

        """
        let file = try CharacterFile(text: text)
        #expect(file.text() == text)
        #expect(file.header["a"]?.string == "No")
        #expect(file.header["e"]?.string == "12")
    }

    @Test func literalBlocksRoundTrip() throws {
        let text = """
        ---
        backstory: |
          Born in a ditch.

          Raised by wolves.
        motto: |-
          No retreat
        ---

        """
        let file = try CharacterFile(text: text)
        #expect(file.text() == text)
        #expect(file.header["backstory"]?.string == "Born in a ditch.\n\nRaised by wolves.\n")
    }

    @Test func commentsAreDroppedButValuesKept() throws {
        let file = try CharacterFile(text: "---\n# a comment\nlevel: 2 # trailing\n---\n")
        #expect(file.text() == "---\nlevel: 2\n---\n")
    }

    @Test func bodyIsUntouched() throws {
        let body = "\n\n# Notes\n\n---\n\nA horizontal rule above.  \n\t tabbed\n"
        let text = "---\nlevel: 1\n---\n" + body
        let file = try CharacterFile(text: text)
        #expect(file.body == body)
        #expect(file.text() == text)
    }

    @Test func emptyBodyAndEmptyHeader() throws {
        #expect(try CharacterFile(text: "---\nlevel: 1\n---\n").text() == "---\nlevel: 1\n---\n")
        let empty = try CharacterFile(text: "---\n---\nJust notes.")
        #expect(empty.header.mapping?.isEmpty == true)
        #expect(empty.text() == "---\n---\nJust notes.")
    }

    @Test func windowsLineEndingsRoundTrip() throws {
        let text = "---\r\nname: Ronk\r\nlevel: 1\r\n---\r\nNotes\r\n"
        let file = try CharacterFile(text: text)
        #expect(file.lineEnding == .crlf)
        #expect(file.name == "Ronk")
        #expect(file.text() == text)
    }

    @Test func byteOrderMarkRoundTrips() throws {
        let text = "\u{FEFF}---\nname: Ronk\n---\n"
        #expect(try CharacterFile(text: text).text() == text)
    }
}

@Suite("Writing new values")
struct WritingTests {
    private func written(_ value: Node) -> String {
        var file = CharacterFile()
        file.header["v"] = value
        return file.text()
    }

    @Test(arguments: [
        ("Ronk", "Ronk"),
        ("Short bow", "Short bow"),
        ("1d8", "1d8"),
        ("Rope (50')", "Rope (50')"),
        ("No", "\"No\""),
        ("yes", "\"yes\""),
        ("12", "\"12\""),
        ("1.5", "\"1.5\""),
        ("null", "\"null\""),
        ("", "\"\""),
        ("Sir Ronk: the Bold", "\"Sir Ronk: the Bold\""),
        ("#1 fighter", "\"#1 fighter\""),
        ("- dash", "\"- dash\""),
        (" padded", "\" padded\""),
        ("two\nlines", "\"two\\nlines\""),
        ("say \"hi\"", "say \"hi\""),
    ])
    func newStringsAreQuotedOnlyWhenNeeded(input: String, expected: String) throws {
        let text = written(.text(input))
        #expect(text == "---\nv: \(expected)\n---\n")
        // And it reads back as the same string.
        #expect(try CharacterFile(text: text).header["v"]?.string == input)
    }

    @Test func commasAreQuotedInsideFlowMaps() throws {
        let text = written(Node([(Node("name"), .text("Rations (iron, 7 days)"))]))
        #expect(text == "---\nv: { name: \"Rations (iron, 7 days)\" }\n---\n")
    }

    @Test func numbersAndBooleansAreWrittenPlain() {
        #expect(written(13) == "---\nv: 13\n---\n")
        #expect(written(Node("true", Tag(.bool))) == "---\nv: true\n---\n")
    }

    @Test func shortScalarMapsBecomeFlowAndLongOnesBlock() {
        let scores: Node = ["str": 13, "int": 9, "wis": 10, "dex": 14, "con": 11, "cha": 10]
        #expect(written(scores) == "---\nv: { str: 13, int: 9, wis: 10, dex: 14, con: 11, cha: 10 }\n---\n")

        let long = Node((1...12).map { (Node("key\($0)"), Node("some longer value")) })
        #expect(written(long).hasPrefix("---\nv:\n  key1: some longer value\n"))
    }

    @Test func listsOfMapsUseDashes() {
        let spellbook: Node = [["name": "Sleep", "level": 1], ["name": "Light", "level": 1]]
        #expect(written(spellbook) == """
        ---
        v:
          - { name: Sleep, level: 1 }
          - { name: Light, level: 1 }
        ---

        """)
    }
}

@Suite("Errors and recognition")
struct ErrorTests {
    @Test func plainMarkdownHasNoFrontMatter() {
        #expect(throws: CharacterFileError.noFrontMatter) { try CharacterFile(text: "# Shopping list\n") }
    }

    @Test func unterminatedHeader() {
        #expect(throws: CharacterFileError.unterminatedFrontMatter) { try CharacterFile(text: "---\nname: Ronk\n") }
    }

    @Test func listHeaderIsRejected() {
        #expect(throws: CharacterFileError.headerNotMapping) { try CharacterFile(text: "---\n- a\n- b\n---\n") }
    }

    @Test func yamlErrorsReportTheFileLine() throws {
        let error = #expect(throws: CharacterFileError.self) {
            try CharacterFile(text: "---\nname: Ronk\nlevel: [1\nxp: 0\n---\n")
        }
        guard case let .invalidYAML(_, line) = error else {
            Issue.record("expected invalidYAML, got \(String(describing: error))")
            return
        }
        #expect(line != nil && line! >= 3)
    }

    @Test func otherFrontMatterIsNotACharacter() throws {
        let blogPost = try CharacterFile(text: "---\ntitle: My post\n---\nHello")
        #expect(!blogPost.isCharacter)
    }

    @Test func missingOrBlankNameIsNil() throws {
        #expect(try CharacterFile(text: "---\nlevel: 1\n---\n").name == nil)
        #expect(try CharacterFile(text: "---\nname: \"  \"\n---\n").name == nil)
        #expect(try CharacterFile(text: "---\nname: \"Brother Cedric\n\"\n---\n").name == "Brother Cedric")
    }
}

@Suite("Template")
struct TemplateTests {
    @Test func newCharacterTemplateIsACharacterAndRoundTrips() throws {
        let file = try CharacterFile(text: CharacterFile.newCharacterTemplate)
        #expect(file.isCharacter)
        #expect(file.name == nil)
        #expect(file.text() == CharacterFile.newCharacterTemplate)
    }
}
