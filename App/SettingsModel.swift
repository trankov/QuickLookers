import Foundation
import Combine
import QuickLookersEngine
import QuickLookersSettingsKit

/// Состояние окна: настройки в памяти + каталог доступного.
/// Любое изменение сразу пишется в settings.json (с ростом settingsVersion).
@MainActor
final class SettingsModel: ObservableObject {
    /// Язык с объявленным типом: имя для показа и его расширения.
    struct FileTypeRow: Identifiable {
        let id: String          // languageId
        let displayName: String
        let extensions: String  // ".swift", ".json" …
    }

    @Published var settings: ManagerSettings
    @Published private(set) var warning: String?
    @Published private(set) var catalog: Catalog
    /// Идентификаторы импортированных языков и тем (из catalog-imported.json контейнера).
    @Published private(set) var importedIds: Set<String>

    var lightThemes:  [ThemeInfo]   { catalog.themes.filter { !$0.isDark } }
    var darkThemes:   [ThemeInfo]   { catalog.themes.filter { $0.isDark } }
    var fileTypeRows: [FileTypeRow] { Self.makeFileTypeRows(catalog: catalog) }

    private let store: SettingsStore?

    init() {
        let (loadedCatalog, loadedImportedIds) = Self.loadCatalog()
        self.catalog = loadedCatalog
        self.importedIds = loadedImportedIds

        // Хранилище — в общем контейнере. Нет контейнера → окно работает,
        // но предупреждаем: подпись/entitlement не настроены.
        if let container = quickLookersContainerURL() {
            let store = SettingsStore(fileURL: container.appendingPathComponent("settings.json"))
            self.store = store
            self.settings = store.load()
            self.warning = nil
        } else {
            self.store = nil
            self.settings = .default
            self.warning = "Контейнер App Group недоступен — изменения не сохраняются. Проверь подпись и entitlement."
        }
    }

    /// Перезагружает каталог (встроенный + импортированный) и обновляет производные.
    /// Вызывается после импорта .vsix или удаления импортированного элемента.
    func reloadCatalog() {
        let (newCatalog, newImportedIds) = Self.loadCatalog()
        catalog = newCatalog
        importedIds = newImportedIds
    }

    // MARK: - Private helpers

    /// Загрузка каталога: встроенный сайдкар + импортированный из контейнера.
    /// Возвращает каталог и множество id из импортированного сайдкара.
    private static func loadCatalog() -> (Catalog, Set<String>) {
        var sidecars = QuickLookersEngineResources.catalogSidecarURLs()
        var importedIds: Set<String> = []

        if let container = quickLookersContainerURL() {
            let lib = ImportedLibrary(containerURL: container)
            let importedSidecars = lib.sidecarURLsForCatalog()
            importedIds = lib.importedIds()
            sidecars += importedSidecars
        }

        let loadedCatalog: Catalog
        do {
            let source = FileCatalogSource(
                grammarsDirectory: try QuickLookersEngineResources.grammarsDirectory(),
                themesDirectory: try QuickLookersEngineResources.themesDirectory(),
                sidecarURLs: sidecars)
            loadedCatalog = try source.loadCatalog()
        } catch {
            loadedCatalog = Catalog(languages: [], themes: [])
        }
        return (loadedCatalog, importedIds)
    }

    /// Строки вкладки «Сопоставление»: объявленные языки + их расширения.
    private static func makeFileTypeRows(catalog: Catalog) -> [FileTypeRow] {
        let byLanguage = Dictionary(grouping: DeclaredTypes.all, by: { $0.languageId })
        return byLanguage.keys.sorted().map { lang in
            let exts = byLanguage[lang]!.map { ".\($0.pathExtension)" }.joined(separator: ", ")
            let name = catalog.languages.first { $0.id == lang }?.displayName ?? lang
            return FileTypeRow(id: lang, displayName: name, extensions: exts)
        }
    }

    /// Изменить настройки и сразу сохранить.
    func update(_ mutate: (inout ManagerSettings) -> Void) {
        mutate(&settings)
        guard let store else { return }
        if let saved = try? store.save(settings) {
            settings = saved
        }
    }

    // Удобные производные для вкладок.
    func isLanguageOn(_ id: String) -> Bool { isLanguageEnabled(id, settings: settings) }
    func isPreviewOn(_ id: String) -> Bool { isPreviewEnabled(id, settings: settings) }

    /// Включить/выключить язык в библиотеке (Слой 1).
    func setLanguageOn(_ id: String, _ on: Bool) {
        update { s in
            if on { s.disabledLanguageIds.remove(id) } else { s.disabledLanguageIds.insert(id) }
        }
    }

    /// Включить/выключить просмотр языка в Finder (Слой 2).
    func setPreviewOn(_ id: String, _ on: Bool) {
        update { s in
            if on { s.previewDisabledLanguageIds.remove(id) } else { s.previewDisabledLanguageIds.insert(id) }
        }
    }
}
