import Foundation
import AppKit

enum AccessScope {
    case home, applications
    var url: URL {
        switch self {
        case .home: return FileManager.default.homeDirectoryForCurrentUser
        case .applications: return URL(fileURLWithPath: "/Applications")
        }
    }
    var defaultsKey: String {
        switch self { case .home: return "bookmark.home"; case .applications: return "bookmark.applications" }
    }
    var prompt: String {
        switch self {
        case .home: return String(localized: "Allow access to your home folder — to read the editor's theme and font.")
        case .applications: return String(localized: "Allow access to the Applications folder — to find installed editors.")
        }
    }
}

/// Хранит security-scoped закладки на ~ и /Applications. При отсутствии — запрашивает
/// доступ через NSOpenPanel (лениво, по требованию) и сохраняет app-scoped закладку.
@MainActor
final class BookmarkStore {
    func accessURL(for scope: AccessScope) -> URL? {
        if let url = resolveBookmark(scope) { return url }
        return requestAccess(scope)
    }

    /// Выполняет body с открытым доступом к scope (start/stop вокруг). nil — доступа нет.
    func withAccess<T>(_ scope: AccessScope, _ body: (URL) throws -> T) rethrows -> T? {
        guard let url = accessURL(for: scope) else { return nil }
        let ok = url.startAccessingSecurityScopedResource()
        defer { if ok { url.stopAccessingSecurityScopedResource() } }
        return try body(url)
    }

    private func resolveBookmark(_ scope: AccessScope) -> URL? {
        guard let data = UserDefaults.standard.data(forKey: scope.defaultsKey) else { return nil }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: [.withSecurityScope],
                                 relativeTo: nil, bookmarkDataIsStale: &stale) else { return nil }
        if stale { return requestAccess(scope) }
        return url
    }

    private func requestAccess(_ scope: AccessScope) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = scope.url
        panel.message = scope.prompt
        panel.prompt = String(localized: "Allow")
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        if let data = try? url.bookmarkData(options: [.withSecurityScope],
                                            includingResourceValuesForKeys: nil, relativeTo: nil) {
            UserDefaults.standard.set(data, forKey: scope.defaultsKey)
        }
        return url
    }
}
