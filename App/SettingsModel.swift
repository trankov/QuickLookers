import Foundation
import Combine
import QuickLookersEngine
import QuickLookersSettingsKit
import QuickLookersEditorKit

/// Состояние окна: настройки в памяти + каталог доступного.
/// Любое изменение сразу пишется в settings.json (с ростом settingsVersion).
@MainActor
final class SettingsModel: ObservableObject {
    /// Строка таблицы правил Слоя 2.
    struct PreviewRuleRow: Identifiable {
        let id: String          // "ext:py" / "file:Dockerfile"
        let key: String         // "py" / "Dockerfile"
        let isFilename: Bool
        let languageId: String
        let languageName: String
    }

    @Published var settings: ManagerSettings
    @Published private(set) var warning: String?
    @Published private(set) var catalog: Catalog
    /// Идентификаторы импортированных языков и тем (из catalog-imported.json контейнера).
    @Published private(set) var importedIds: Set<String>

    /// Датасет соответствий «расширение/имя файла → язык» (из движка).
    let associations: FileTypeAssociations

    var lightThemes:  [ThemeInfo]   { catalog.themes.filter { !$0.isDark } }
    var darkThemes:   [ThemeInfo]   { catalog.themes.filter { $0.isDark } }

    var previewRules: [PreviewRuleRow] {
        let names = Dictionary(uniqueKeysWithValues: catalog.languages.map { ($0.id, $0.displayName) })
        func name(_ id: String) -> String { names[id] ?? id }

        // База: датасет + пользовательские override/добавления.
        var exts = associations.byExtension
        for (k, v) in settings.extensionOverrides { exts[k] = v }
        var files = associations.byFilename
        for (k, v) in settings.filenameOverrides { files[k] = v }

        let extRows = exts.map { (ext, lang) in
            PreviewRuleRow(id: "ext:\(ext)", key: ext, isFilename: false,
                           languageId: lang, languageName: name(lang))
        }
        let fileRows = files.map { (fn, lang) in
            PreviewRuleRow(id: "file:\(fn)", key: fn, isFilename: true,
                           languageId: lang, languageName: name(lang))
        }
        return (extRows + fileRows).sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
    }

    private let store: SettingsStore?
    /// Контейнер App Group, с которым работает эта модель — нужен, чтобы reloadCatalog()
    /// перечитывал именно его (а не глобальный quickLookersContainerURL()): так
    /// init(containerURL:) с временной директорией остаётся изолированным и в тестах.
    private let containerURL: URL?
    /// Кэш подсветки живого превью (см. LivePreview): движок гоняем только при смене
    /// языка/темы, при смене шрифта — лишь пересобираем CSS-обёртку.
    let fragmentCache = FragmentCache()

    convenience init() {
        self.init(containerURL: quickLookersContainerURL())
    }

    /// Инициализатор с явным контейнером — отдельная точка входа для тестов
    /// (временная директория вместо реального App Group, чтобы не трогать
    /// настоящие настройки пользователя).
    init(containerURL: URL?) {
        self.containerURL = containerURL
        let (loadedCatalog, loadedImportedIds) = Self.loadCatalog(containerURL: containerURL)
        self.catalog = loadedCatalog
        self.importedIds = loadedImportedIds
        self.associations = FileTypeAssociations.loaded(from: QuickLookersEngineResources.associationsURL())

        // Хранилище — в общем контейнере. Нет контейнера → окно работает,
        // но предупреждаем: подпись/entitlement не настроены.
        if let containerURL {
            let store = SettingsStore(fileURL: containerURL.appendingPathComponent("settings.json"))
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
        let (newCatalog, newImportedIds) = Self.loadCatalog(containerURL: containerURL)
        catalog = newCatalog
        importedIds = newImportedIds
        fragmentCache.invalidate()   // после импорта тема под тем же id могла смениться
    }

    // MARK: - Private helpers

    /// Загрузка каталога: встроенный сайдкар + импортированный из контейнера.
    /// Возвращает каталог и множество id из импортированного сайдкара.
    private static func loadCatalog(containerURL: URL?) -> (Catalog, Set<String>) {
        var sidecars = QuickLookersEngineResources.catalogSidecarURLs()
        var importedIds: Set<String> = []

        if let container = containerURL {
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

    /// Включить/выключить язык в библиотеке (Слой 1).
    func setLanguageOn(_ id: String, _ on: Bool) {
        update { s in
            if on { s.disabledLanguageIds.remove(id) } else { s.disabledLanguageIds.insert(id) }
        }
    }

    func isRuleOn(_ row: PreviewRuleRow) -> Bool {
        guard isLanguageEnabled(row.languageId, settings: settings) else { return false }
        return row.isFilename
            ? !settings.disabledFilenames.contains(row.key)
            : !settings.disabledExtensions.contains(row.key)
    }

    func setRuleOn(_ row: PreviewRuleRow, _ on: Bool) {
        update { s in
            if row.isFilename {
                if on { s.disabledFilenames.remove(row.key) } else { s.disabledFilenames.insert(row.key) }
            } else {
                if on { s.disabledExtensions.remove(row.key) } else { s.disabledExtensions.insert(row.key) }
            }
        }
    }

    func setRuleLanguage(_ row: PreviewRuleRow, _ languageId: String) {
        update { s in
            if row.isFilename { s.filenameOverrides[row.key] = languageId }
            else { s.extensionOverrides[row.key] = languageId }
        }
    }

    /// Добавить/переопределить правило по расширению (ведущая точка допускается).
    func addExtensionRule(ext: String, languageId: String) {
        let key = ext.hasPrefix(".") ? String(ext.dropFirst()) : ext
        let norm = key.lowercased()
        guard !norm.isEmpty else { return }
        update { s in s.extensionOverrides[norm] = languageId }
    }

    /// Поиск id темы по отображаемому имени — для EditorThemeResolver.
    struct CatalogLookup: ThemeCatalogLookup {
        let themes: [ThemeInfo]
        func themeId(forDisplayName name: String) -> String? {
            themes.first { $0.displayName == name }?.id
        }
    }
    var catalogLookup: CatalogLookup { CatalogLookup(themes: catalog.themes) }

    /// Применить результат импорта из редактора: активная тема (если есть) + шрифт.
    func applyEditorResult(themeId: String?, font: FontSettings) {
        update { s in
            if let themeId { s.activeThemeId = themeId }
            s.font = font
        }
    }
}
