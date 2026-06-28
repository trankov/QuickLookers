import Cocoa
import Quartz
import WebKit
import os
import QuickLookersEngine
import QuickLookersPreviewKit

final class PreviewViewController: NSViewController, QLPreviewingController {
    private static let log = Logger(subsystem: "com.quicklookers.preview", category: "preview")

    // Тёплый процесс: движок строится один раз на жизнь процесса расширения.
    // На втором показе он уже горячий — это и проверяет spike 1.
    private static var cachedEngine: HighlightEngine?

    private var webView: WKWebView!

    override func loadView() {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = false
        webView = WKWebView(frame: .zero, configuration: config)
        self.view = webView
    }

    func preparePreviewOfFile(at url: URL) async throws {
        let start = Date()
        let wasWarm = Self.cachedEngine != nil

        guard let lang = languageId(forPathExtension: url.pathExtension) else {
            // Тип не из нашего набора — отдаём системе (spike 3, лёгкая версия).
            throw CocoaError(.featureUnsupported)
        }

        let code = try String(contentsOf: url, encoding: .utf8)
        let engine = try Self.engine()
        let fragment = try engine.highlightToHTML(
            HighlightRequest(code: code, languageId: lang, themeId: "dark-plus")
        )
        let page = previewPageHTML(highlighted: fragment)
        webView.loadHTMLString(page, baseURL: nil)

        let ms = Date().timeIntervalSince(start) * 1000
        Self.log.info("""
            preview pid=\(getpid()) warm=\(wasWarm, privacy: .public) \
            lang=\(lang, privacy: .public) ms=\(ms, format: .fixed(precision: 1), privacy: .public)
            """)
    }

    private static func engine() throws -> HighlightEngine {
        if let engine = cachedEngine { return engine }
        let engine = try QuickLookersEngineFactory.makeDefault()
        cachedEngine = engine
        return engine
    }
}
