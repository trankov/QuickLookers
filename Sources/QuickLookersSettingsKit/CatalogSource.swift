import Foundation

public protocol CatalogSource {
    func loadCatalog() throws -> Catalog
}

/// Каталог из сайдкаров `catalog.json` или, если их нет/они битые, из обхода
/// директорий грамматик/тем. Сайдкар — расширяемый индекс: список URL сливается
/// (последний перекрывает по `id`), что готовит путь под будущий импорт .vsix.
public struct FileCatalogSource: CatalogSource {
    private let grammarsDirectory: URL
    private let themesDirectory: URL
    private let sidecarURLs: [URL]

    public init(grammarsDirectory: URL, themesDirectory: URL, sidecarURLs: [URL] = []) {
        self.grammarsDirectory = grammarsDirectory
        self.themesDirectory = themesDirectory
        self.sidecarURLs = sidecarURLs
    }

    private struct GrammarEntry: Decodable { let name: String; let displayName: String? }
    private struct ThemeMeta: Decodable { let name: String; let displayName: String?; let type: String? }

    private struct Sidecar: Decodable {
        struct Language: Decodable { let id: String; let displayName: String }
        struct Theme: Decodable { let id: String; let displayName: String; let isDark: Bool }
        let languages: [Language]
        let themes: [Theme]
    }

    public func loadCatalog() throws -> Catalog {
        if let catalog = catalogFromSidecars() { return catalog }
        return try catalogFromDirectories()
    }

    /// Каталог из слияния валидных сайдкаров; nil, если ни одного валидного нет.
    private func catalogFromSidecars() -> Catalog? {
        let sidecars = sidecarURLs.compactMap { url -> Sidecar? in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? JSONDecoder().decode(Sidecar.self, from: data)
        }
        guard !sidecars.isEmpty else { return nil }

        var langs: [String: LanguageInfo] = [:]
        var themes: [String: ThemeInfo] = [:]
        for sidecar in sidecars {   // порядок списка → последний перекрывает по id
            for l in sidecar.languages {
                langs[l.id] = LanguageInfo(id: l.id, displayName: l.displayName)
            }
            for t in sidecar.themes {
                themes[t.id] = ThemeInfo(id: t.id, displayName: t.displayName, isDark: t.isDark)
            }
        }
        // Пустой результат слияния трактуем как «валидного сайдкара нет» →
        // фоллбэк-обход (гарантия: каталог не пустеет из-за проблем с сайдкаром).
        guard !(langs.isEmpty && themes.isEmpty) else { return nil }
        return Catalog(languages: langs.values.sorted { $0.id < $1.id },
                       themes: themes.values.sorted { $0.id < $1.id })
    }

    /// Фоллбэк: метаданные из самих файлов грамматик/тем (страховка, если
    /// сайдкара нет). Тот же путь чтения позже использует импортёр .vsix.
    private func catalogFromDirectories() throws -> Catalog {
        let languages = try jsonFiles(in: grammarsDirectory).compactMap { url -> LanguageInfo? in
            let id = url.deletingPathExtension().lastPathComponent
            guard let entries = try? JSONDecoder().decode([GrammarEntry].self,
                                                           from: Data(contentsOf: url))
            else { return nil }
            // Главная грамматика — запись с name == id (в массиве может быть не первой:
            // напр. у vue она идёт последней, после встроенных html/css/js).
            return LanguageInfo(id: id,
                                displayName: entries.first { $0.name == id }?.displayName ?? id)
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
