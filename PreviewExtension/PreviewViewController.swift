import Cocoa
import Quartz
import WebKit
import os
import QuickLookersEngine
import QuickLookersPreviewKit
import QuickLookersSettingsKit

final class PreviewViewController: NSViewController, QLPreviewingController, WKNavigationDelegate {
    private static let log = Logger(subsystem: "com.quicklookers.preview", category: "preview")

    // Тёплый процесс: движок, набор id тем и сам вебвью строятся один раз на
    // жизнь процесса. Общий вебвью переживает контроллеры — убирает холодный
    // старт WebContent (выбросы 1–2,6 с).
    private static var cachedEngine: HighlightEngine?
    private static var cachedThemeIds: Set<String>?
    private static let sharedWebView: WKWebView = {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = false
        return WKWebView(frame: .zero, configuration: config)
    }()

    // Константы фазы оптимизации (см. спеку 2026-06-29).
    private static let maxLines = 2000
    private static let largeFileThreshold = 2 * 1024 * 1024   // 2 МБ
    private static let cacheMaxBytes = 5 * 1024 * 1024         // 5 МБ
    private static let bundleVersion =
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "0"
    // URL контейнера App Group не меняется за жизнь процесса — считаем один раз.
    private static let sharedContainerURL: URL? = quickLookersContainerURL()

    private var loadContinuation: CheckedContinuation<Void, Error>?

    override func loadView() {
        // Общий вебвью переезжает к текущему контроллеру; делегат указываем на себя.
        Self.sharedWebView.navigationDelegate = self
        self.view = Self.sharedWebView
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

        let cache = Self.cache()
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
            Self.sharedWebView.loadHTMLString(page, baseURL: nil)
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

    private static func cache() -> HTMLCache? {
        guard let container = sharedContainerURL else { return nil }
        return HTMLCache(directory: container.appendingPathComponent("Caches/html"),
                         maxBytes: cacheMaxBytes)
    }

    private static func themeIds() throws -> Set<String> {
        if let ids = cachedThemeIds { return ids }
        let source = FileCatalogSource(
            grammarsDirectory: try QuickLookersEngineResources.grammarsDirectory(),
            themesDirectory: try QuickLookersEngineResources.themesDirectory())
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
