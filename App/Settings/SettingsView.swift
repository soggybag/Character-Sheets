import AppKit
import CharacterKit
import SwiftUI

/// 3d6 → Settings…
struct SettingsView: View {
    var body: some View {
        TabView {
            EquipmentSettings()
                .tabItem { Label("Equipment", systemImage: "bag") }
        }
        .frame(width: 520)
    }
}

/// Which equipment list the shops use.
private struct EquipmentSettings: View {
    @State private var store = EquipmentListStore.shared
    @Environment(\.openDocument) private var openDocument

    var body: some View {
        Form {
            Section {
                LabeledContent("Shops use") {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(store.url == nil ? "The rules list" : store.name ?? "A custom list")
                        if let list = store.list {
                            Text(list.summary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else if store.url != nil {
                            Text("Using the rules list until this is fixed")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                }
                if let url = store.url {
                    LabeledContent("File") {
                        Text(url.path(percentEncoded: false))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(.secondary)
                            .help(url.path(percentEncoded: false))
                    }
                }
            } footer: {
                Text("A custom list changes the rules' prices, removes items, and adds house items. "
                     + "Characters don't record which list was used.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !store.problems.isEmpty {
                Section("Problems in the list") {
                    ForEach(store.problems, id: \.self) { problem in
                        Label(problem, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                }
            }

            Section {
                HStack {
                    Button("Choose…") { store.choose() }
                    Button("New List…") {
                        if let url = store.createNew() { edit(url) }
                    }
                    Spacer()
                    if let url = store.url {
                        Button("Edit") { edit(url) }
                            .help("Open the list to edit it")
                        Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                        Button("Use Rules List") { store.useRulesList() }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { store.reload() }
        // Edited elsewhere while Settings was in the background.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            store.reload()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            store.reload()
        }
    }

    private func edit(_ url: URL) {
        // The document must still be able to save after it opens.
        ScopedAccess.keep(url)
        Task { try? await openDocument(at: url) }
    }
}
