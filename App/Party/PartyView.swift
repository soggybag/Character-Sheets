import AppKit
import CharacterKit
import SwiftUI

/// A folder the party window shows, kept as a security-scoped bookmark so
/// the window can reopen it after the app relaunches.
struct PartyFolder: Codable, Hashable {
    let bookmark: Data

    init?(url: URL) {
        guard let bookmark = try? url.bookmarkData(options: .withSecurityScope) else { return nil }
        self.bookmark = bookmark
    }

    var url: URL? {
        var stale = false
        return try? URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, bookmarkDataIsStale: &stale)
    }
}

/// File → Open Party Folder…
struct OpenPartyButton: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Open Party Folder…") {
            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.message = "Choose a folder of character files to see the whole party."
            panel.prompt = "Open Party"
            guard panel.runModal() == .OK, let url = panel.url, let folder = PartyFolder(url: url) else { return }
            openWindow(value: folder)
        }
        .keyboardShortcut("o", modifiers: [.command, .shift])
    }
}

/// Watches a folder and reads the characters in it.
@MainActor @Observable
final class PartyModel {
    private(set) var folder: URL?
    private(set) var members: [PartyMember] = []
    @ObservationIgnored private var source: DispatchSourceFileSystemObject?

    func start(_ partyFolder: PartyFolder?) {
        stop()
        guard let url = partyFolder?.url, ScopedAccess.keep(url) else {
            folder = nil
            return
        }
        folder = url
        reload()
        // Saving replaces the file, which changes the folder, so this sees
        // edits as well as new, renamed and deleted characters.
        let descriptor = open(url.path, O_EVTONLY)
        guard descriptor >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: .write,
                                                               queue: .main)
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.reload() }
        }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        self.source = source
    }

    /// Stops watching. Access to the folder is kept for the rest of the
    /// session, so characters opened from it can still be saved.
    func stop() {
        source?.cancel()
        source = nil
        folder = nil
    }

    func reload() {
        guard let folder else { return }
        members = PartyMember.load(folder: folder, equipmentList: EquipmentListStore.shared.list)
    }
}

/// Everyone in a folder at a glance. Double-click a character to open it.
struct PartyView: View {
    let partyFolder: PartyFolder?

    @Environment(\.openDocument) private var openDocument
    @State private var model = PartyModel()
    @State private var selection = Set<URL>()

    var body: some View {
        content
            .frame(minWidth: 720, minHeight: 240)
            .navigationTitle(model.folder?.lastPathComponent ?? "Party")
            .toolbar {
                ToolbarItem {
                    Button("Show in Finder", systemImage: "folder") {
                        if let folder = model.folder { NSWorkspace.shared.activateFileViewerSelecting([folder]) }
                    }
                    .disabled(model.folder == nil)
                }
                ToolbarItem {
                    Button("Refresh", systemImage: "arrow.clockwise") { model.reload() }
                        .keyboardShortcut("r", modifiers: .command)
                        .disabled(model.folder == nil)
                }
            }
            .onAppear { model.start(partyFolder) }
            .onDisappear { model.stop() }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                model.reload()
            }
    }

    @ViewBuilder
    private var content: some View {
        if let folder = model.folder {
            if model.members.isEmpty {
                ContentUnavailableView("No Characters", systemImage: "person.3",
                                       description: Text("Character files saved in “\(folder.lastPathComponent)” appear here."))
            } else {
                VStack(spacing: 0) {
                    table
                    Divider()
                    legend
                }
            }
        } else {
            ContentUnavailableView("Folder Unavailable", systemImage: "questionmark.folder",
                                   description: Text("The folder may have been moved or renamed. Choose File → Open Party Folder… to open it again."))
        }
    }

    private var table: some View {
        Table(model.members, selection: $selection) {
            TableColumn("Name") { member in
                HStack(spacing: 4) {
                    Text(member.name)
                    if !member.warnings.isEmpty {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .help(member.warnings.joined(separator: "\n"))
                            .accessibilityLabel(member.warnings.count == 1 ? "Warning" : "\(member.warnings.count) warnings")
                            .accessibilityValue(member.warnings.joined(separator: " "))
                    }
                }
            }
            .width(min: 120, ideal: 160)
            TableColumn("Class") { member in Text(member.className ?? "") }
                .width(min: 70, ideal: 90)
            TableColumn("Level") { member in number(member.level) }
                .width(40)
            TableColumn("HP") { member in hitPoints(member) }
                .width(min: 56, ideal: 64)
            TableColumn("AC") { member in number(member.ac) }
                .width(32)
            TableColumn(attackHeader) { member in
                Text(member.attack.map { member.ascendingAC ? $0.signedText : String($0) } ?? "")
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(52)
            TableColumn("Saves  D  W  P  B  S") { member in
                Text(PartyMember.saveKeys.map { member.saves[$0].map { String(format: "%2d", $0) } ?? " –" }
                    .joined(separator: " "))
                    .font(.body.monospacedDigit())
                    .help("Death, Wands, Paralysis, Breath, Spells")
            }
            .width(min: 130, ideal: 140)
            TableColumn("XP") { member in
                HStack(spacing: 4) {
                    if member.readyToLevelUp {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundStyle(.green)
                            .help("Ready to level up")
                            .accessibilityLabel("Ready to level up")
                    }
                    Text(member.xp?.formatted() ?? "").monospacedDigit()
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 60, ideal: 80)
        }
        .contextMenu(forSelectionType: URL.self) { urls in
            Button("Open") { open(urls) }
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting(Array(urls)) }
        } primaryAction: { urls in
            open(urls)
        }
    }

    /// What the colours and symbols mean. Hover over one for details.
    private var legend: some View {
        HStack(spacing: 16) {
            Label("Rules warning", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange, .secondary)
            Label("HP at half or less", systemImage: "circle.fill")
                .foregroundStyle(.orange, .secondary)
            Label("HP 0 or less", systemImage: "circle.fill")
                .foregroundStyle(.red, .secondary)
            Label("Ready to level up", systemImage: "arrow.up.circle.fill")
                .foregroundStyle(.green, .secondary)
            Spacer()
        }
        .labelStyle(LegendLabelStyle())
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private struct LegendLabelStyle: LabelStyle {
        func makeBody(configuration: Configuration) -> some View {
            HStack(spacing: 4) {
                configuration.icon
                configuration.title.foregroundStyle(.secondary)
            }
        }
    }

    private var attackHeader: String {
        let ascending = model.members.map(\.ascendingAC)
        if ascending.allSatisfy({ $0 }) { return "Attack" }
        if ascending.allSatisfy({ !$0 }) { return "THAC0" }
        return "THAC0/Atk"
    }

    private func number(_ value: Int?) -> some View {
        Text(value.map(String.init) ?? "")
            .monospacedDigit()
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func hitPoints(_ member: PartyMember) -> some View {
        let current = member.currentHP ?? member.maxHP
        let text = switch (current, member.maxHP) {
        case let (current?, max?): "\(current) / \(max)"
        case let (current?, nil): String(current)
        default: ""
        }
        let (colour, help): (Color, String) = switch (current, member.maxHP) {
        case let (current?, _) where current <= 0: (.red, "0 hit points or fewer")
        case let (current?, max?) where current * 2 <= max: (.orange, "Half hit points or less")
        default: (.primary, "")
        }
        return Text(text)
            .monospacedDigit()
            .foregroundStyle(colour)
            .help(help)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func open(_ urls: Set<URL>) {
        for url in urls {
            Task {
                do {
                    try await openDocument(at: url)
                } catch {
                    NSAlert(error: error).runModal()
                }
            }
        }
    }
}
