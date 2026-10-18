import CharacterKit
import SwiftUI

// MARK: - Bindings into the file

extension Binding where Value == CharacterFile {
    /// A whole number. Clearing the field removes the key.
    // Each setter does nothing when the value hasn't changed, so focusing or
    // tabbing through a field never marks the document edited or rewrites it.

    func int(_ path: NodePath) -> Binding<Int?> {
        Binding<Int?> { wrappedValue.int(path) } set: {
            guard $0 != wrappedValue.int(path) else { return }
            wrappedValue.setInt($0, at: path)
        }
    }

    /// Text. Clearing the field removes the key.
    func string(_ path: NodePath) -> Binding<String> {
        Binding<String> { wrappedValue.string(path) ?? "" } set: {
            guard $0 != wrappedValue.string(path) ?? "" else { return }
            wrappedValue.setString($0, at: path)
        }
    }

    /// A checkbox. Unchecking removes the key, keeping files tidy.
    func flag(_ path: NodePath) -> Binding<Bool> {
        Binding<Bool> { wrappedValue.bool(path) ?? false } set: {
            guard $0 != wrappedValue.bool(path) ?? false else { return }
            wrappedValue.setBool($0 ? true : nil, at: path)
        }
    }
}

// MARK: - Layout

/// A titled block of the sheet.
struct SheetSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(1.2)
                .foregroundStyle(.secondary)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Lays boxes out in a row, wrapping onto more rows when the window is
/// narrow. Order is kept, so Tab still moves left to right, then down.
struct FlowLayout: Layout {
    var spacing: CGFloat = 12
    var lineSpacing: CGFloat = 12
    var alignment: VerticalAlignment = .center

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = rows(for: subviews, width: proposal.width)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + lineSpacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(for: subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                let offset: CGFloat = switch alignment {
                case .top: 0
                case .bottom: row.height - size.height
                default: (row.height - size.height) / 2
                }
                subviews[index].place(at: CGPoint(x: x, y: y + offset), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func rows(for subviews: Subviews, width: CGFloat?) -> [Row] {
        let maxWidth = width ?? .infinity
        var rows: [Row] = []
        var row = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            if !row.indices.isEmpty && needed > maxWidth {
                rows.append(row)
                row = Row()
            }
            row.width = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            row.height = max(row.height, size.height)
            row.indices.append(index)
        }
        if !row.indices.isEmpty { rows.append(row) }
        return rows
    }
}

// MARK: - Fields

/// A labelled number in a small box: ability scores, saves, AC.
struct StatBox: View {
    let label: String
    @Binding var value: Int?
    var suffix: String?
    var width: CGFloat = 64
    var help: String?
    /// How the value compares with the rules.
    var status: FieldStatus = .noRule
    var useRulesValue: (() -> Void)?
    /// A line under the box, e.g. an ability modifier.
    var caption: String?
    var captionHelp: String?
    /// Shown in grey when the box is empty and the rules have no value.
    var emptyPrompt = "–"
    /// A rules warning about this value; the box gets an orange outline.
    var warning: String?

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                // Right-clicking the box itself reaches the text field's
                // own menu, so the label and the dot carry this one.
                .contextMenu { rulesMenu }
            HStack(spacing: 2) {
                NumberField(label: label, value: $value, prompt: prompt)
                    .labelsHidden()
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.center)
                    .font(.title3.monospacedDigit())
                if let suffix {
                    Text(suffix)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize()
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 6)
            .frame(width: width)
            .background(.quaternary.opacity(0.6), in: .rect(cornerRadius: 8))
            .overlay {
                if warning != nil {
                    RoundedRectangle(cornerRadius: 8).strokeBorder(.orange, lineWidth: 1.5)
                }
            }
            .overlay(alignment: .topTrailing) {
                if case .overridden = status {
                    overrideDot
                }
            }
            .help(boxHelp)
            if let caption {
                Text(caption)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .help(captionHelp ?? "")
            }
        }
    }

    /// The orange dot on an override. Click it for the rules value.
    private var overrideDot: some View {
        Menu {
            rulesMenu
        } label: {
            Circle()
                .fill(.orange)
                .frame(width: 9, height: 9)
                .padding(5)
                .contentShape(.rect)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("Differs from the rules")
    }

    @ViewBuilder
    private var rulesMenu: some View {
        if let rules = rulesValue, let useRulesValue {
            Button("Use Rules Value (\(rules.description))", action: useRulesValue)
        }
    }

    private var rulesValue: RulesValue? {
        switch status {
        case let .overridden(rules), let .missing(rules): rules
        case .matches, .noRule: nil
        }
    }

    private var prompt: String {
        if case let .missing(rules) = status { return rules.description }
        return emptyPrompt
    }

    private var boxHelp: String {
        if let warning { return "\(help ?? label). \(warning)" }
        let name = help ?? label
        switch status {
        case let .overridden(rules):
            return "\(name). The rules give \(rules); your value is kept. Click the orange dot to use the rules value."
        case let .missing(rules):
            return "\(name). The rules give \(rules) (shown in grey until you fill it in)."
        case .matches, .noRule:
            return name
        }
    }
}

/// A stat box for a stored field the rules have a value for.
struct RuledStatBox: View {
    let label: String
    let path: NodePath
    @Binding var file: CharacterFile
    let analysis: RulesAnalysis
    var suffix: String?
    var width: CGFloat = 64
    var help: String?
    var caption: String?
    var captionHelp: String?

    var body: some View {
        StatBox(label: label, value: $file.int(path), suffix: suffix, width: width, help: help,
                status: analysis.status(of: path, in: file),
                useRulesValue: analysis.suggestions[path].map { value in { file.setRulesValue(value, at: path) } },
                caption: caption, captionHelp: captionHelp)
    }
}

extension VerticalAlignment {
    private enum FieldLine: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat { context[VerticalAlignment.bottom] }
    }

    /// The text line of a `LineField` or `LineNumberField`. Rows of fields
    /// align on it so their text sits level, whatever is above or below;
    /// macOS orders Tab by position, so a field that sits higher is visited first.
    static let fieldLine = VerticalAlignment(FieldLine.self)
}

/// A labelled line of text with an optional menu of suggestions.
/// Suggestions only help: any text is allowed.
struct LineField: View {
    let label: String
    @Binding var text: String
    var prompt = ""
    var suggestions: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 4) {
                TextField(label, text: $text, prompt: Text(prompt))
                    .textFieldStyle(.plain)
                    .labelsHidden()
                    .alignmentGuide(.fieldLine) { $0[VerticalAlignment.center] }
                if !suggestions.isEmpty {
                    Menu {
                        ForEach(suggestions, id: \.self) { suggestion in
                            Button(suggestion) { text = suggestion }
                        }
                    } label: {
                        EmptyView()
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.visible)
                    .fixedSize()
                    .help("Choose a \(label.lowercased())")
                }
            }
            Divider()
        }
    }
}

/// A number on a line, for values like XP that aren't stat boxes.
struct LineNumberField: View {
    let label: String
    @Binding var value: Int?
    var prompt = ""
    var caption: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            NumberField(label: label, value: $value, prompt: prompt, grouping: true)
                .textFieldStyle(.plain)
                .monospacedDigit()
                .labelsHidden()
                .alignmentGuide(.fieldLine) { $0[VerticalAlignment.center] }
            Divider()
            if let caption {
                Text(caption)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
    }
}

/// A whole-number field that writes only when you change the number and press
/// Return or leave the field. Tabbing through never rewrites the file, and a
/// stored value that isn't a whole number ("1,200 gp") is left alone unless you
/// type over it. Text that isn't a number is undone with a beep.
struct NumberField: View {
    let label: String
    @Binding var value: Int?
    var prompt = ""
    /// Show thousands separators (XP, gold).
    var grouping = false

    @State private var draft = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField(label, text: $draft, prompt: Text(prompt))
            .focused($isFocused)
            .onAppear { draft = shown }
            // Follow changes made elsewhere (Use Rules Value, undo), even
            // while focused, unless there's an unsaved edit in the field.
            .onChange(of: shown) { old, new in if !isFocused || draft == old { draft = new } }
            .onChange(of: isFocused) { if !isFocused { commit() } }
            .onSubmit(commit)
    }

    private var shown: String {
        value.map { grouping ? $0.formatted() : String($0) } ?? ""
    }

    private func commit() {
        guard draft != shown else { return }
        let text = draft.trimmingCharacters(in: .whitespaces)
        if text.isEmpty {
            value = nil
        } else if let number = Self.parse(text) {
            value = number
            draft = shown
        } else {
            NSSound.beep()
            draft = shown
        }
    }

    /// "1,200", "+2", "−1" (minus sign) and "1 200" all parse.
    static func parse(_ text: String) -> Int? {
        let separators = Set([",", " ", "\u{00A0}", "\u{202F}", Locale.current.groupingSeparator ?? ","].joined())
        let cleaned = text.replacing("−", with: "-").filter { !separators.contains($0) }
        return Int(cleaned.hasPrefix("+") ? String(cleaned.dropFirst()) : cleaned)
    }
}

/// A text field that only writes back when you press Return or leave it,
/// for values that are reshaped on save (e.g. a comma-separated list).
struct CommitTextField: View {
    let prompt: String
    let value: String
    let commit: (String) -> Void

    @State private var draft = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField(prompt, text: $draft)
            .focused($isFocused)
            .onAppear { draft = value }
            .onChange(of: value) { old, new in if !isFocused || draft == old { draft = new } }
            .onChange(of: isFocused) { if !isFocused { finish() } }
            .onSubmit(finish)
    }

    /// Commits a change, then shows the stored value: the change once it
    /// lands, or the old text if the change was refused.
    private func finish() {
        if draft != value { commit(draft) }
        draft = value
    }
}

/// Small borderless +/− buttons for lists.
struct ListButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(title, systemImage: systemImage, action: action)
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .help(title)
    }
}
