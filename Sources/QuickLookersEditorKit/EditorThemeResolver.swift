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
            // Разбор contributes.themes переиспользуем из VsixManifest (та же форма,
            // тот же дефолт uiTheme = vs-dark); package.json бывает JSONC → нормализуем.
            guard let data = try? Data(contentsOf: pkg),
                  let strict = try? JSONCParser.toStrictJSON(data),
                  let manifest = try? VsixManifest.parse(packageJSON: strict),
                  let theme = manifest.themes.first(where: { $0.label == label }) else { continue }
            let rel = theme.path.hasPrefix("./") ? String(theme.path.dropFirst(2)) : theme.path
            return .custom(label: label, uiTheme: theme.uiTheme,
                           fileURL: ext.appendingPathComponent(rel))
        }
        return .notFound
    }
}
