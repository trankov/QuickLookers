import Foundation
import Combine
import QuickLookersEngine
import QuickLookersSettingsKit
import QuickLookersEditorKit

/// Состояние окна: настройки в памяти + каталог доступного.
/// Любое изменение сразу пишется в settings.json (с ростом settingsVersion).
@MainActor
final class SettingsModel: ObservableObject {
    @Published var settings: ManagerSettings
    @Published private(set) var warning: String?
    @Published private(set) var catalog: Catalog
    /// Идентификаторы импортированных языков и тем (из catalog-imported.json контейнера).
    @Published private(set) var importedIds: Set<String>

    /// Датасет соответствий «расширение/имя файла → язык» (из движка).
    let associations: FileTypeAssociations

    /// Имя языка по id за O(1). Иначе линейный скан каталога в цикле поиска датасета
    /// давал бы O(датасет × языки) на каждый символ ввода. Пересобирается при смене
    /// каталога (init/reloadCatalog).
    private var languageNamesById: [String: String]

    private static func namesById(_ catalog: Catalog) -> [String: String] {
        Dictionary(catalog.languages.map { ($0.id, $0.displayName) }) { first, _ in first }
    }

    var lightThemes:  [ThemeInfo]   { catalog.themes.filter { !$0.isDark } }
    var darkThemes:   [ThemeInfo]   { catalog.themes.filter { $0.isDark } }

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
        self.languageNamesById = Self.namesById(loadedCatalog)
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
        languageNamesById = Self.namesById(newCatalog)
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

    // MARK: - Правила просмотра (Слой 2)

    var userRules: [PreviewRule] { settings.previewRules }

    /// Во что шаблон разрешается сейчас в датасете (без учёта самого правила).
    enum PatternDefault: Equatable { case language(String); case neutral; case indeterminate }

    struct RuleSearchResults { let mine: [PreviewRule]; let defaults: [DatasetMatch] }

    func languageDisplayName(_ id: String) -> String {
        languageNamesById[id] ?? id
    }

    /// Поиск: свои правила (по шаблону/языку) + совпадения датасета (капнутые).
    /// Пустой запрос → только свои правила, датасет пуст.
    func searchRules(query: String, limit: Int) -> RuleSearchResults {
        let q = query.lowercased()
        let mine = q.isEmpty ? userRules : userRules.filter { rule in
            rule.pattern.lowercased().contains(q)
                || ruleLanguageName(rule).lowercased().contains(q)
        }
        let defaults = searchDataset(query: query, limit: limit, associations: associations,
                                     languageName: { [weak self] in self?.languageDisplayName($0) })
        return RuleSearchResults(mine: mine, defaults: defaults)
    }

    /// Отображение действия правила (язык или «не подсвечивать») — используют и поиск,
    /// и вкладка правил (не дублировать в вью).
    func ruleLanguageName(_ rule: PreviewRule) -> String {
        switch rule.action {
        case .assign(let id): return languageDisplayName(id)
        case .neutral:        return "не подсвечивать"
        }
    }

    /// Добавить правило; шаблон-дубль обновляет существующее, а не плодит второе.
    func addRule(pattern: String, action: RuleAction) {
        let p = pattern.trimmingCharacters(in: .whitespaces)
        guard !p.isEmpty else { return }
        update { s in
            // Сравнение шаблонов регистронезависимо — как и само glob-сопоставление
            // (иначе *.SWIFT и *.swift дали бы два правила на одни файлы).
            if let i = s.previewRules.firstIndex(where: { $0.pattern.caseInsensitiveCompare(p) == .orderedSame }) {
                s.previewRules[i].action = action
                s.previewRules[i].isEnabled = true
            } else {
                s.previewRules.append(PreviewRule(pattern: p, action: action))
            }
        }
    }

    func updateRule(_ rule: PreviewRule) {
        update { s in
            if let i = s.previewRules.firstIndex(where: { $0.id == rule.id }) { s.previewRules[i] = rule }
        }
    }

    func deleteRule(_ rule: PreviewRule) {
        update { s in s.previewRules.removeAll { $0.id == rule.id } }
    }

    func toggleRule(_ rule: PreviewRule, on: Bool) {
        update { s in
            if let i = s.previewRules.firstIndex(where: { $0.id == rule.id }) { s.previewRules[i].isEnabled = on }
        }
    }

    /// Черновик правила-перекрытия для дефолтного совпадения (для листа правки).
    func draftOverride(for match: DatasetMatch) -> PreviewRule {
        let pattern: String
        switch match.key {
        case .ext(let e):      pattern = "*.\(e)"
        case .filename(let f): pattern = f
        }
        return PreviewRule(pattern: pattern, action: .assign(languageId: match.languageId))
    }

    /// Что шаблон значит сейчас по датасету — для строки «Сейчас так».
    func currentDefault(forPattern pattern: String) -> PatternDefault {
        let m = GlobMatcher(pattern)
        if let name = m.exactFilename, let lang = associations.byFilename[name] { return .language(lang) }
        if let ext = m.fastExtension, let lang = associations.byExtension[ext] { return .language(lang) }
        if m.exactFilename != nil || m.fastExtension != nil { return .neutral }
        return .indeterminate
    }

    /// Статус перехвата для шаблона; nil если расширение неопределимо (строку прячем).
    func interceptionStatus(forPattern pattern: String) -> InterceptionStatus? {
        guard let ext = GlobMatcher(pattern).probeExtension else { return nil }
        return QuickLookersSettingsKit.interceptionStatus(
            forExtension: ext,
            systemType: InterceptionDeclarations.systemType(forExtension: ext),
            declared: Self.declaredInterceptSet)
    }

    /// Набор перехвата читаем один раз (не меняется в рантайме).
    private static let declaredInterceptSet: DeclaredInterceptSet = InterceptionDeclarations.load()

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
