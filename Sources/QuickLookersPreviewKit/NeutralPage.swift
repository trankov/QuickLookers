/// Нейтральный показ: код без подсветки, моноширинным текстом, на нейтральном
/// системном фоне. Для выключенного/неизвестного формата — ближе к родному
/// текстовому превью, чем системный дженерик. Фон/цвет — от системной темы вебвью
/// (prefers-color-scheme), поэтому здесь без жёстких цветов.

import Foundation

/// Экранирует спецсимволы HTML (порядок важен: `&` первым).
public func htmlEscaped(_ s: String) -> String {
    s.replacingOccurrences(of: "&", with: "&amp;")
     .replacingOccurrences(of: "<", with: "&lt;")
     .replacingOccurrences(of: ">", with: "&gt;")
     .replacingOccurrences(of: "\"", with: "&quot;")
}

public func neutralPageHTML(code: String, fontFamily: String? = nil, fontSize: Double? = nil,
                            truncatedNotice: String? = nil) -> String {
    let family = sanitizedFontFamily(fontFamily)
    let familyCSS = family.map { "\($0), ui-monospace, monospace" } ?? "ui-monospace, \"SF Mono\", Menlo, monospace"
    let size = (fontSize.flatMap { (6...48).contains(Int($0)) ? Int($0) : nil }) ?? 12
    let notice = truncatedNotice.map { #"<div class="ql-truncated">\#(htmlEscaped($0))</div>"# } ?? ""
    let truncatedStyle = truncatedNotice != nil ? """
        .ql-truncated { padding: 8px 12px; font-family: -apple-system, system-ui, sans-serif;
            font-size: 11px; color: #888; text-align: center; }
        """ : ""
    return """
    <!DOCTYPE html>
    <html>
    <head>
    <meta charset="utf-8">
    <style>
    html, body { margin: 0; padding: 0; }
    body { background: Canvas; color: CanvasText; }
    pre.ql-neutral {
        margin: 0; padding: 12px;
        box-sizing: border-box; min-height: 100vh;
        font-family: \(familyCSS);
        font-size: \(size)px; line-height: 1.5; tab-size: 4;
        white-space: pre-wrap; overflow-wrap: anywhere; word-break: break-word;
    }
    \(truncatedStyle)
    </style>
    </head>
    <body>
    <pre class="ql-neutral">\(htmlEscaped(code))</pre>
    \(notice)
    </body>
    </html>
    """
}
