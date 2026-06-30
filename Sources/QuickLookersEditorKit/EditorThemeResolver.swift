import Foundation
import QuickLookersImportKit

public protocol ThemeCatalogLookup {
    func themeId(forDisplayName name: String) -> String?
}

public enum EditorThemeResolution: Equatable {
    case bundled(themeId: String)
    case custom(label: String, uiTheme: String, fileURL: URL)
    case notFound
}

/// Сопоставляет активную тему редактора (по отображаемому имени) с нашим каталогом,
/// иначе ищет её в расширениях редактора (package.json → contributes.themes).
public enum EditorThemeResolver {
    public static func resolve(label: String, catalog: ThemeCatalogLookup,
                               extensionsDir: URL) -> EditorThemeResolution {
        if let id = catalog.themeId(forDisplayName: label) { return .bundled(themeId: id) }

        let fm = FileManager.default
        guard let exts = try? fm.contentsOfDirectory(at: extensionsDir,
                  includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { return .notFound }
        for ext in exts {
            let pkg = ext.appendingPathComponent("package.json")
            guard let data = try? Data(contentsOf: pkg),
                  let obj = try? JSONCParser.object(from: data) as? [String: Any],
                  let contributes = obj["contributes"] as? [String: Any],
                  let themes = contributes["themes"] as? [[String: Any]] else { continue }
            for t in themes {
                guard (t["label"] as? String) == label, let path = t["path"] as? String else { continue }
                let rel = path.hasPrefix("./") ? String(path.dropFirst(2)) : path
                let uiTheme = t["uiTheme"] as? String ?? "vs-dark"
                return .custom(label: label, uiTheme: uiTheme,
                               fileURL: ext.appendingPathComponent(rel))
            }
        }
        return .notFound
    }
}
