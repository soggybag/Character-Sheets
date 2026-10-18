import AppKit
import SwiftUI

/// The open character sheet windows, for tiling and tabbing.
@MainActor
enum CharacterWindows {
    static let tabsKey = "opensSheetsInTabs"
    private static let tabbingIdentifier = "CharacterSheet"
    private static let windows = NSHashTable<NSWindow>.weakObjects()

    /// Called once a sheet's window exists.
    static func register(_ window: NSWindow) {
        guard !windows.contains(window) else { return }
        window.tabbingIdentifier = tabbingIdentifier
        // Join the frontmost sheet's tabs, when tabs are on.
        if UserDefaults.standard.bool(forKey: tabsKey),
           let host = frontmost(excluding: window), host.tabbedWindows?.contains(window) != true {
            host.addTabbedWindow(window, ordered: .above)
            window.makeKeyAndOrderFront(nil)
        }
        windows.add(window)
    }

    private static func frontmost(excluding window: NSWindow) -> NSWindow? {
        NSApp.orderedWindows.first { $0 !== window && windows.contains($0) && $0.isVisible }
    }

    /// One window per tab group, front to back, skipping minimized ones.
    private static var visible: [NSWindow] {
        var seen = Set<ObjectIdentifier>()
        return NSApp.orderedWindows.filter { window in
            guard windows.contains(window), window.isVisible, !window.isMiniaturized else { return false }
            let group = window.tabbedWindows ?? [window]
            guard !group.contains(where: { seen.contains(ObjectIdentifier($0)) }) else { return false }
            group.forEach { seen.insert(ObjectIdentifier($0)) }
            return true
        }
    }

    /// Side by side across the screen, in as many rows as it takes to keep
    /// each sheet at least its minimum width.
    static func tile() {
        let sheets = visible
        guard let screen = (NSApp.keyWindow?.screen ?? NSScreen.main)?.visibleFrame, !sheets.isEmpty else { return }
        let mostColumns = max(1, Int(screen.width / CharacterWindow.minWidth))
        let rows = (sheets.count + mostColumns - 1) / mostColumns
        // Even rows: four sheets are two by two, not three and one.
        let columns = (sheets.count + rows - 1) / rows
        let width = (screen.width / CGFloat(columns)).rounded(.down)
        let height = (screen.height / CGFloat(rows)).rounded(.down)
        // Left to right, top to bottom, in the order the windows are on screen.
        let ordered = sheets.sorted { ($0.frame.minX, -$0.frame.maxY) < ($1.frame.minX, -$1.frame.maxY) }
        for (index, window) in ordered.enumerated() {
            let column = index % columns
            let row = index / columns
            let frame = NSRect(x: screen.minX + CGFloat(column) * width,
                               y: screen.maxY - CGFloat(row + 1) * height,
                               width: width, height: height)
            window.setFrame(frame, display: true, animate: true)
        }
    }

    /// Every sheet in one window, as tabs.
    static func mergeIntoTabs() {
        let all = NSApp.orderedWindows.filter { windows.contains($0) && $0.isVisible }
        guard let host = all.first else { return }
        for window in all.dropFirst() where host.tabbedWindows?.contains(window) != true {
            host.addTabbedWindow(window, ordered: .above)
        }
        host.makeKeyAndOrderFront(nil)
    }
}

/// Hands the sheet's window to `CharacterWindows` once it has one.
struct CharacterWindowRegistration: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { Probe() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class Probe: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            // After SwiftUI has finished setting the window up.
            DispatchQueue.main.async { CharacterWindows.register(window) }
        }
    }
}

/// Window menu: tile or tab the sheets.
struct CharacterWindowCommands: View {
    @AppStorage(CharacterWindows.tabsKey) private var opensInTabs = false

    var body: some View {
        Button("Tile Character Sheets") { CharacterWindows.tile() }
            .help("Arrange the open character sheets side by side")
        Button("Merge Sheets into Tabs") { CharacterWindows.mergeIntoTabs() }
            .help("Put every open character sheet in one window, as tabs")
        Toggle("Open Sheets in Tabs", isOn: $opensInTabs)
            .help("Open each character sheet as a tab in the frontmost sheet's window")
    }
}
