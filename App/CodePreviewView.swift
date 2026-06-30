import SwiftUI
import WebKit

/// Тонкая обёртка над WKWebView для живого превью HTML темы. JS не нужен —
/// это статичный документ, как в расширении Preview.
struct CodePreviewView: NSViewRepresentable {
    let html: String

    final class Coordinator { var lastHTML: String? }
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.defaultWebpagePreferences.allowsContentJavaScript = false
        let web = WKWebView(frame: .zero, configuration: cfg)
        web.setValue(false, forKey: "drawsBackground")  // фон несёт тема
        return web
    }

    func updateNSView(_ web: WKWebView, context: Context) {
        // Не перегружаем вебвью, если HTML не изменился (SwiftUI зовёт update часто).
        guard context.coordinator.lastHTML != html else { return }
        context.coordinator.lastHTML = html
        web.loadHTMLString(html, baseURL: nil)
    }
}
