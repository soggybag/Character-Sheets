import AppKit
import CharacterKit
import Foundation

/// The custom equipment list chosen in Settings, if any. The file is
/// remembered as a security-scoped bookmark and reread each time a shop or
/// Settings shows it, so edits (here or in a shared folder) are picked up.
@MainActor @Observable
final class EquipmentListStore {
    static let shared = EquipmentListStore()
    private static let bookmarkKey = "equipmentListBookmark"

    /// The chosen file, or nil for the rules list.
    private(set) var url: URL?
    /// The list as last read. Nil when there's no file or it couldn't be read;
    /// the shop then uses the rules list.
    private(set) var list: EquipmentList?
    /// Everything wrong with the file, including not being able to read it.
    private(set) var problems: [String] = []

    private init() {
        if let bookmark = UserDefaults.standard.data(forKey: Self.bookmarkKey) {
            var stale = false
            url = try? URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, bookmarkDataIsStale: &stale)
            if stale, let url { remember(url) }
        }
        reload()
    }

    /// The list's name, or its file's.
    var name: String? {
        list?.name ?? url?.deletingPathExtension().lastPathComponent
    }

    func reload() {
        guard let url else {
            list = nil
            problems = []
            return
        }
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        do {
            let list = try EquipmentList(text: String(contentsOf: url, encoding: .utf8))
            self.list = list
            problems = list.allProblems()
        } catch let error as EquipmentListError {
            list = nil
            problems = [error.description]
        } catch {
            list = nil
            problems = ["Can't read “\(url.lastPathComponent)”: \(error.localizedDescription)"]
        }
    }

    func use(_ url: URL) {
        self.url = url
        remember(url)
        reload()
    }

    func useRulesList() {
        url = nil
        UserDefaults.standard.removeObject(forKey: Self.bookmarkKey)
        reload()
    }

    private func remember(_ url: URL) {
        if let bookmark = try? url.bookmarkData(options: .withSecurityScope) {
            UserDefaults.standard.set(bookmark, forKey: Self.bookmarkKey)
        }
    }

    // MARK: Panels

    /// Asks for a list file and uses it.
    func choose() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.markdownText]
        panel.message = "Choose an equipment list (a Markdown file with kind: equipment)."
        panel.prompt = "Use List"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        use(url)
    }

    /// Saves a starting list and uses it. Returns its URL, to open for editing.
    func createNew() -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.markdownText]
        panel.nameFieldStringValue = "Equipment.md"
        panel.message = "Save a new equipment list. Put it in a shared folder to use it with your group."
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        let name = url.deletingPathExtension().lastPathComponent
        do {
            try EquipmentList.template(name: name).write(to: url, atomically: true, encoding: .utf8)
        } catch {
            NSAlert(error: error).runModal()
            return nil
        }
        use(url)
        return url
    }
}
