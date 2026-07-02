import Cocoa
import Quartz
import WebKit
import os
import QuickLookersEngine
import QuickLookersPreviewKit
import QuickLookersSettingsKit

final class PreviewViewController: NSViewController, QLPreviewingController, WKNavigationDelegate {
    private static let log = Logger(subsystem: "com.quicklookers.preview", category: "preview")

    // Тёплый процесс: движок и набор id тем строятся один раз на жизнь процесса.
    private static var cachedEngine: HighlightEngine?
    private static var cachedThemeIds: Set<String>?

    // Таблица соответствий строится один раз на процесс (тёплый рантайм).
    private static let associations = FileTypeAssociations.loaded(from: QuickLookersEngineResources.associationsURL())

    // Пул тёплых вебвью. Один общий вебвью держать нельзя: Finder показывает
    // превью ПАРАЛЛЕЛЬНО (панель «Просмотр» + QuickLook-пробел, галерея) — один
    // вебвью не обслужит два показа сразу: второй перехватит делегата и навигацию,
    // и континуация первого не разрешится (бесконечный спиннер). Пул выдаёт
    // каждому показу свой вебвью и переиспользует освободившиеся (тепло сохраняется).
    // Доступ только с главного потока (QLPreviewingController @MainActor).
    private static var idleWebViews: [WKWebView] = []
    // Сколько тёплых вебвью держать про запас. Пик параллельных показов — панель
    // «Просмотр» + QuickLook + пара ячеек галереи; сверх потолка отпускаем (ARC).
    private static let maxPooledWebViews = 3

    private static func makeWebView() -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = false
        // Между показами QuickLook убирает вебвью из окна. По умолчанию WebKit
        // тогда тормозит/усыпляет WebContent (jetsam-приоритет падает) → первый
        // показ после простоя ждёт пробуждения процесса (~1,4 с, пустой экран).
        // .none держит вебвью активным вне окна; JS выключен, поэтому почти даром.
        if #available(macOS 14.0, *) {
            config.preferences.inactiveSchedulingPolicy = .none
        }
        return WKWebView(frame: .zero, configuration: config)
    }

    private static func acquireWebView() -> WKWebView {
        idleWebViews.popLast() ?? makeWebView()
    }

    private static func releaseWebView(_ webView: WKWebView) {
        webView.navigationDelegate = nil
        guard idleWebViews.count < maxPooledWebViews else { return }
        idleWebViews.append(webView)
    }

    // Константы фазы оптимизации (см. спеку 2026-06-29).
    private static let maxLines = 2000
    private static let largeFileThreshold = 2 * 1024 * 1024   // 2 МБ
    private static let cacheMaxBytes = 5 * 1024 * 1024         // 5 МБ
    private static let bundleVersion =
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "0"
    // URL контейнера App Group не меняется за жизнь процесса — считаем один раз.
    private static let sharedContainerURL: URL? = quickLookersContainerURL()

    private var webView: WKWebView!
    private var loadContinuation: CheckedContinuation<Void, Error>?

    override func loadView() {
        // Берём вебвью из пула (или создаём); делегат — на себя.
        let wv = Self.acquireWebView()
        wv.navigationDelegate = self
        self.webView = wv
        self.view = wv
    }

    deinit {
        // Превью закрыто — возвращаем вебвью в пул. Вебвью — UI-объект, трогаем
        // на главном потоке (deinit может прийти не с него).
        guard let wv = webView else { return }
        if Thread.isMainThread {
            Self.releaseWebView(wv)
        } else {
            DispatchQueue.main.async { Self.releaseWebView(wv) }
        }
    }

    /// Читает файл (с ограничением префикса для больших) и режет до maxLines.
    /// Бросает на нечитаемом/не-UTF-8 файле → системный дженерик.
    private static func loadTrimmed(_ url: URL, size: Int) throws -> (code: String, truncated: Bool) {
        let code = size > largeFileThreshold
            ? try readBoundedPrefix(of: url, maxBytes: largeFileThreshold)
            : try String(contentsOf: url, encoding: .utf8)
        return trimToFirstLines(code, max: maxLines)
    }

    private static func truncatedNotice(_ truncated: Bool) -> String? {
        truncated ? "Показаны первые \(maxLines) строк" : nil
    }

    func preparePreviewOfFile(at url: URL) async throws {
        let start = Date()
        let wasWarm = Self.cachedEngine != nil
        let settings = Self.settings()

        let resolution = resolvePreview(fileName: url.lastPathComponent,
                                        pathExtension: url.pathExtension,
                                        associations: Self.associations,
                                        settings: settings)

        // Дешёвый ключ кэша: атрибуты файла без чтения содержимого.
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        let mtime = (attrs[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        let size = (attrs[.size] as? Int) ?? 0

        let page: String
        let cacheHit: Bool
        let logLang: String
        var pruneCache = false

        switch resolution {
        case .highlight(let lang):
            logLang = lang
            let themeId = resolvedThemeId(activeThemeId: settings.activeThemeId,
                                          availableThemeIds: try Self.themeIds())
            let key = HTMLCacheKey(path: url.path, mtime: mtime, size: size,
                                   languageId: lang, themeId: themeId,
                                   fontFamily: settings.font.family, fontSize: settings.font.size,
                                   maxLines: Self.maxLines, bundleVersion: Self.bundleVersion)
            let cache = Self.sharedCache
            if let cached = cache?.lookup(key) {
                page = cached; cacheHit = true
            } else {
                cacheHit = false
                let (trimmed, truncated) = try Self.loadTrimmed(url, size: size)
                let fragment = try Self.engine().highlightToHTML(
                    HighlightRequest(code: trimmed, languageId: lang, themeId: themeId))
                page = previewPageHTML(highlighted: fragment,
                                       fontFamily: settings.font.family, fontSize: settings.font.size,
                                       truncatedNotice: Self.truncatedNotice(truncated))
                cache?.store(key, html: page)
                pruneCache = true
            }

        case .neutral:
            logLang = "neutral"
            cacheHit = false
            let (trimmed, truncated) = try Self.loadTrimmed(url, size: size)
            page = neutralPageHTML(code: trimmed,
                                   fontFamily: settings.font.family, fontSize: settings.font.size,
                                   truncatedNotice: Self.truncatedNotice(truncated))
        }

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            self.loadContinuation = cont
            self.webView.loadHTMLString(page, baseURL: nil)
        }

        // Вытеснение — после показа, вне горячего пути.
        if pruneCache { Self.sharedCache?.evictIfNeeded() }

        let ms = Date().timeIntervalSince(start) * 1000
        Self.log.info("""
            preview pid=\(getpid()) warm=\(wasWarm, privacy: .public) \
            cache=\(cacheHit, privacy: .public) lang=\(logLang, privacy: .public) \
            ms=\(ms, format: .fixed(precision: 1), privacy: .public)
            """)
    }

    private func finishLoad(_ result: Result<Void, Error>) {
        guard let cont = loadContinuation else { return }
        loadContinuation = nil
        cont.resume(with: result)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        finishLoad(.success(()))
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        finishLoad(.failure(error))
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        finishLoad(.failure(error))
    }

    private static func settings() -> ManagerSettings {
        guard let container = sharedContainerURL else { return .default }
        return SettingsStore(fileURL: container.appendingPathComponent("settings.json")).load()
    }

    // Песочница превью-расширения НЕ даёт запись в ГРУППОВОЙ контейнер
    // (kernel: deny file-write-create и в корне, и в Library/Caches) — превью
    // задумано «только смотреть», поэтому групповой контейнер для расширения
    // доступен лишь на чтение (так читаются настройки, которые пишет приложение).
    // Кэш HTML пишет и читает ТОЛЬКО расширение, поэтому держим его в СВОЁМ
    // контейнере расширения. Директория и потолок постоянны → считаем раз.
    private static let sharedCache: HTMLCache? = {
        guard let caches = try? FileManager.default.url(
            for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        else { return nil }
        return HTMLCache(directory: caches.appendingPathComponent("QuickLookersHTML"),
                         maxBytes: cacheMaxBytes)
    }()

    private static func themeIds() throws -> Set<String> {
        if let ids = cachedThemeIds { return ids }
        // Встроенный сайдкар + импортированный из контейнера App Group (только чтение).
        var sidecars = QuickLookersEngineResources.catalogSidecarURLs()
        if let container = sharedContainerURL {
            sidecars += ImportedLibrary(containerURL: container).sidecarURLsForCatalog()
        }
        let source = FileCatalogSource(
            grammarsDirectory: try QuickLookersEngineResources.grammarsDirectory(),
            themesDirectory: try QuickLookersEngineResources.themesDirectory(),
            sidecarURLs: sidecars)
        let ids = Set(try source.loadCatalog().themes.map(\.id))
        cachedThemeIds = ids
        return ids
    }

    private static func engine() throws -> HighlightEngine {
        if let engine = cachedEngine { return engine }
        // Если в контейнере есть импортированные грамматики/темы — они перекрывают
        // бандл по id (контейнер старше бандла). Расширение читает из контейнера,
        // но не пишет (sandbox: deny file-write-create на групповом контейнере).
        var importedGrammars: URL?, importedThemes: URL?
        if let container = sharedContainerURL {
            let lib = ImportedLibrary(containerURL: container)
            importedGrammars = lib.grammarsDir
            importedThemes = lib.themesDir
        }
        let engine = try QuickLookersEngineFactory.makeDefault(
            importedGrammarsDir: importedGrammars,
            importedThemesDir: importedThemes)
        cachedEngine = engine
        return engine
    }
}
