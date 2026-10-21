import AppKit
import CharacterKit
import SwiftUI

/// The Help menu: help, a sample character, the license, and feedback.
struct HelpCommands: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.newDocument) private var newDocument

    var body: some View {
        Button("Character Sheets Help") { openWindow(id: HelpView.windowID) }
            .keyboardShortcut("?", modifiers: .command)
        Button("Open Sample Character") { openSample() }
        Divider()
        Button("Licenses and Legal") { openWindow(id: LicenseView.windowID) }
        Divider()
        Button("Send Feedback…") { Feedback.compose() }
    }

    private func openSample() {
        guard let document = HelpView.sampleDocument() else { return }
        newDocument(document)
    }
}

/// Help, shown by itself on first launch.
struct HelpView: View {
    static let windowID = "help"
    static let seenKey = "hasSeenWelcome"

    @Environment(\.newDocument) private var newDocument
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                MarkdownBlocksView(text: Self.bundledText("Help"))
                    .padding(24)
                    .frame(maxWidth: 640, alignment: .leading)
                    .frame(maxWidth: .infinity)
            }
            Divider()
            HStack {
                Button("Send Feedback…") { Feedback.compose() }
                Spacer()
                Button("Open Sample Character") {
                    if let document = Self.sampleDocument() { newDocument(document) }
                }
                Button("New Character…") { openWindow(id: NewCharacterView.windowID) }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(minWidth: 520, minHeight: 480)
        .onAppear { UserDefaults.standard.set(true, forKey: Self.seenKey) }
    }

    /// A copy of the sample character as a new, unsaved document.
    static func sampleDocument() -> CharacterDocument? {
        guard let url = Bundle.main.url(forResource: "Sample Character", withExtension: "md"),
              let text = try? String(contentsOf: url, encoding: .utf8),
              let file = try? CharacterFile(text: text) else { return nil }
        return CharacterDocument(file: file)
    }

    static func bundledText(_ name: String) -> String {
        Bundle.main.url(forResource: name, withExtension: "md")
            .flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
    }
}

/// The Open Game License for the rules data.
/// Help → Licenses and Legal: the third-party license's notices, the Open
/// Game License the rules data is used under, and the code's licenses.
struct LicenseView: View {
    static let windowID = "license"

    var body: some View {
        ScrollView {
            LegalContent()
                .padding(24)
                .frame(maxWidth: 640, alignment: .leading)
                .frame(maxWidth: .infinity)
        }
        .frame(minWidth: 520, minHeight: 480)
    }
}

/// What Licenses and Legal shows, without its scroll view.
struct LegalContent: View {
    var body: some View {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Old-School Essentials").font(.title2.bold())
                    DesignedForOSELogo(width: 180)
                    Text(Legal.requires).fontWeight(.semibold)
                    Text(Legal.independent)
                    Text(Legal.trademark)
                    Text(Legal.rulesData)
                }
                Divider()
                MarkdownBlocksView(text: OSERuleset.licenseText)
                Divider()
                VStack(alignment: .leading, spacing: 10) {
                    Text("Yams").font(.title2.bold())
                    Text(Legal.yams).font(.callout)
                }
            }
            .textSelection(.enabled)
    }
}

enum Feedback {
    static let address = "soggybag@gmail.com"

    /// Opens a new email with the app and macOS versions filled in.
    static func compose() {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "?"
        let build = info["CFBundleVersion"] as? String ?? "?"
        let system = ProcessInfo.processInfo.operatingSystemVersionString
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = address
        components.queryItems = [
            URLQueryItem(name: "subject", value: "Character Sheets feedback"),
            URLQueryItem(name: "body", value: "\n\n—\nCharacter Sheets \(version) (\(build)), macOS \(system)"),
        ]
        if let url = components.url { NSWorkspace.shared.open(url) }
    }
}

/// Just enough Markdown for the help and license: headings, paragraphs,
/// bullet lists and code blocks, with inline bold, italics, code and links.
struct MarkdownBlocksView: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(MarkdownBlock.parse(text).enumerated()), id: \.offset) { _, block in
                switch block {
                case let .heading(level, text):
                    Text(inline(text))
                        .font(level == 1 ? .title.bold() : level == 2 ? .title3.bold() : .headline)
                        .padding(.top, level == 1 ? 0 : 8)
                case let .paragraph(text):
                    Text(inline(text))
                case let .bullet(text):
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•")
                        Text(inline(text))
                    }
                    .padding(.leading, 4)
                case let .code(text):
                    Text(text)
                        .font(.system(.callout, design: .monospaced))
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 6))
                case .rule:
                    Divider()
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func inline(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(text)
    }
}

enum MarkdownBlock {
    case heading(Int, String)
    case paragraph(String)
    case bullet(String)
    case code(String)
    case rule

    static func parse(_ text: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var paragraph: [String] = []
        var code: [String]?

        func flush() {
            guard !paragraph.isEmpty else { return }
            let joined = paragraph.joined(separator: " ")
            if joined.hasPrefix("- ") || joined.hasPrefix("* ") {
                blocks.append(.bullet(String(joined.dropFirst(2))))
            } else {
                blocks.append(.paragraph(joined))
            }
            paragraph = []
        }

        for line in text.components(separatedBy: .newlines) {
            if line.hasPrefix("```") {
                if let lines = code {
                    blocks.append(.code(lines.joined(separator: "\n")))
                    code = nil
                } else {
                    flush()
                    code = []
                }
                continue
            }
            if code != nil {
                code?.append(line)
                continue
            }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                flush()
            } else if let match = trimmed.wholeMatch(of: /(#{1,6})\s+(.*)/) {
                flush()
                blocks.append(.heading(match.output.1.count, String(match.output.2)))
            } else if trimmed == "---" || trimmed == "***" {
                flush()
                blocks.append(.rule)
            } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                flush()
                paragraph = [trimmed]
            } else {
                paragraph.append(trimmed)
            }
        }
        flush()
        return blocks
    }
}
