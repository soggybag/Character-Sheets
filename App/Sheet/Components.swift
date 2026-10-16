import CharacterKit
import SwiftUI

// MARK: - Bindings into the file

extension Binding where Value == CharacterFile {
    /// A whole number. Clearing the field removes the key.
    func int(_ path: NodePath) -> Binding<Int?> {
        Binding<Int?> { wrappedValue.int(path) } set: { wrappedValue.setInt($0, at: path) }
    }

    /// Text. Clearing the field removes the key.
    func string(_ path: NodePath) -> Binding<String> {
        Binding<String> { wrappedValue.string(path) ?? "" } set: { wrappedValue.setString($0, at: path) }
    }

    /// A checkbox. Unchecking removes the key, keeping files tidy.
    func flag(_ path: NodePath) -> Binding<Bool> {
        Binding<Bool> { wrappedValue.bool(path) ?? false } set: { wrappedValue.setBool($0 ? true : nil, at: path) }
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

// MARK: - Fields

/// A labelled number in a small box: ability scores, saves, AC.
struct StatBox: View {
    let label: String
    @Binding var value: Int?
    var suffix: String?
    var width: CGFloat = 64
    var help: String?

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            HStack(spacing: 2) {
                TextField("–", value: $value, format: .number.grouping(.never))
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
        }
        .help(help ?? label)
    }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(label, value: $value, format: .number, prompt: Text(prompt))
                .textFieldStyle(.plain)
                .monospacedDigit()
                .labelsHidden()
            Divider()
        }
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
            .onChange(of: value) { if !isFocused { draft = value } }
            .onChange(of: isFocused) { if !isFocused, draft != value { commit(draft) } }
            .onSubmit { commit(draft) }
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
