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

    private var webView: WKWebView!
    private var loadContinuation: CheckedContinuation<Void, Error>?

    override func loadView() {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = false
        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        self.view = webView
    }

    func preparePreviewOfFile(at url: URL) async throws {
        let start = Date()
        let wasWarm = Self.cachedEngine != nil

        // Настройки из общего контейнера; нет/битый файл — умолчания.
        let settings = Self.settings()

        guard let lang = previewLanguageId(forPathExtension: url.pathExtension, settings: settings) else {
            // Не наш тип / язык выключен / убран из просмотра — отдаём системе.
            throw CocoaError(.featureUnsupported)
        }

        // Тема по текущему оформлению системы, с откатом если id пропал.
        let isDark = view.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let themeId = resolvedThemeId(settings.theme,
                                      availableThemeIds: try Self.themeIds(),
                                      appearanceIsDark: isDark)

        let code = try String(contentsOf: url, encoding: .utf8)
        let engine = try Self.engine()
        let fragment = try engine.highlightToHTML(
            HighlightRequest(code: code, languageId: lang, themeId: themeId)
        )
        let page = previewPageHTML(highlighted: fragment)

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            self.loadContinuation = cont
            webView.loadHTMLString(page, baseURL: nil)
        }

        let ms = Date().timeIntervalSince(start) * 1000
        Self.log.info("""
            preview pid=\(getpid()) warm=\(wasWarm, privacy: .public) \
            lang=\(lang, privacy: .public) theme=\(themeId, privacy: .public) \
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
        guard let container = quickLookersContainerURL() else { return .default }
        return SettingsStore(fileURL: container.appendingPathComponent("settings.json")).load()
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
