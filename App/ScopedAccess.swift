import Foundation

/// Security-scoped access that lasts for the rest of the session, for files
/// and folders the user chose earlier (bookmarks): documents opened from
/// them must still be able to save. Each URL is started once; starting it
/// again would only add to the system's count of open accesses.
@MainActor
enum ScopedAccess {
    private static var kept = Set<URL>()

    /// Starts access to `url` if it isn't already kept. Returns whether the
    /// app can use it.
    @discardableResult
    static func keep(_ url: URL) -> Bool {
        let key = url.standardizedFileURL
        if kept.contains(key) { return true }
        guard url.startAccessingSecurityScopedResource() else { return false }
        kept.insert(key)
        return true
    }
}
