import Foundation

public protocol CatalogSource {
    func loadCatalog() throws -> Catalog
}

/// Каталог из JSON-файлов библиотеки. Метаданные берём из самих дескрипторов,
/// чтобы тот же путь чтения позже использовал импортёр .vsix.
public struct FileCatalogSource: CatalogSource {
    private let grammarsDirectory: URL
    private let themesDirectory: URL

    public init(grammarsDirectory: URL, themesDirectory: URL) {
        self.grammarsDirectory = grammarsDirectory
        self.themesDirectory = themesDirectory
    }

    private struct GrammarEntry: Decodable { let name: String; let displayName: String? }
    private struct ThemeMeta: Decodable { let name: String; let displayName: String?; let type: String? }

    public func loadCatalog() throws -> Catalog {
        let languages = try jsonFiles(in: grammarsDirectory).compactMap { url -> LanguageInfo? in
            let id = url.deletingPathExtension().lastPathComponent
            guard let entries = try? JSONDecoder().decode([GrammarEntry].self,
                                                           from: Data(contentsOf: url))
            else { return nil }
            let main = entries.first { $0.name == id }
            return LanguageInfo(id: id, displayName: main?.displayName ?? id)
        }
        let themes = try jsonFiles(in: themesDirectory).compactMap { url -> ThemeInfo? in
            guard let meta = try? JSONDecoder().decode(ThemeMeta.self, from: Data(contentsOf: url))
            else { return nil }
            return ThemeInfo(id: meta.name,
                             displayName: meta.displayName ?? meta.name,
                             isDark: meta.type == "dark")
        }
        return Catalog(languages: languages.sorted { $0.id < $1.id },
                       themes: themes.sorted { $0.id < $1.id })
    }

    private func jsonFiles(in directory: URL) throws -> [URL] {
        let all = try FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil)
        return all.filter { $0.pathExtension == "json" }
    }
}
