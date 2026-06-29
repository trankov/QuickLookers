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

    func preparePreviewOfFile(at url: URL) async throws {
        let start = Date()
        let wasWarm = Self.cachedEngine != nil

        let settings = Self.settings()
        guard let lang = previewLanguageId(forPathExtension: url.pathExtension, settings: settings) else {
            // Не наш тип / язык выключен / убран из просмотра — отдаём системе.
            throw CocoaError(.featureUnsupported)
        }

        let isDark = view.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let themeId = resolvedThemeId(settings.theme,
                                      availableThemeIds: try Self.themeIds(),
                                      appearanceIsDark: isDark)

        // Дешёвый ключ кэша: атрибуты файла без чтения содержимого.
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        let mtime = (attrs[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        let size = (attrs[.size] as? Int) ?? 0
        let key = HTMLCacheKey(path: url.path, mtime: mtime, size: size,
                               languageId: lang, themeId: themeId,
                               maxLines: Self.maxLines, bundleVersion: Self.bundleVersion)

        let cache = Self.sharedCache
        let page: String
        let cacheHit: Bool
        if let cached = cache?.lookup(key) {
            page = cached
            cacheHit = true
        } else {
            cacheHit = false
            let code = size > Self.largeFileThreshold
                ? try readBoundedPrefix(of: url, maxBytes: Self.largeFileThreshold)
                : try String(contentsOf: url, encoding: .utf8)
            let (trimmed, truncated) = trimToFirstLines(code, max: Self.maxLines)
            let engine = try Self.engine()
            let fragment = try engine.highlightToHTML(
                HighlightRequest(code: trimmed, languageId: lang, themeId: themeId))
            let notice = truncated ? "Показаны первые \(Self.maxLines) строк" : nil
            page = previewPageHTML(highlighted: fragment, truncatedNotice: notice)
            cache?.store(key, html: page)
        }

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            self.loadContinuation = cont
            self.webView.loadHTMLString(page, baseURL: nil)
        }

        // Вытеснение — после показа, вне горячего пути.
        if !cacheHit { cache?.evictIfNeeded() }

        let ms = Date().timeIntervalSince(start) * 1000
        Self.log.info("""
            preview pid=\(getpid()) warm=\(wasWarm, privacy: .public) \
            cache=\(cacheHit, privacy: .public) lang=\(lang, privacy: .public) \
            theme=\(themeId, privacy: .public) \
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
        // Каталог из встроенного сайдкара; нет сайдкара → FileCatalogSource
        // сам откатится на обход директорий.
        let source = FileCatalogSource(
            grammarsDirectory: try QuickLookersEngineResources.grammarsDirectory(),
            themesDirectory: try QuickLookersEngineResources.themesDirectory(),
            sidecarURLs: [QuickLookersEngineResources.catalogSidecarURL()].compactMap { $0 })
        let ids = Set(try source.loadCatalog().themes.map(\.id))
        cachedThemeIds = ids
        return ids
    }

    private static func engine() throws -> HighlightEngine {
        if let engine = cachedEngine { return engine }
        let engine = try QuickLookersEngineFactory.makeDefault()
        cachedEngine = engine
        return engine
    }
}
