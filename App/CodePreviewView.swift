import SwiftUI
import WebKit

/// Тонкая обёртка над WKWebView для живого превью HTML темы. JS не нужен —
/// это статичный документ, как в расширении Preview.
struct CodePreviewView: NSViewRepresentable {
    let html: String

    func makeNSView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.defaultWebpagePreferences.allowsContentJavaScript = false
        let web = WKWebView(frame: .zero, configuration: cfg)
        web.setValue(false, forKey: "drawsBackground")  // фон несёт тема
        return web
    }

    func updateNSView(_ web: WKWebView, context: Context) {
        web.loadHTMLString(html, baseURL: nil)
    }
}
