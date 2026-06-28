/// Оборачивает готовый фрагмент подсветки в самодостаточный HTML-документ.
/// Фон и цвета несёт сам фрагмент (его `<pre>` от Shiki); здесь только сброс
/// полей, моноширинный шрифт и перенос длинных строк, чтобы фон заполнял окно.
/// `truncatedNotice` (если задан) дорисовывает внизу неинтерактивную плашку.
public func previewPageHTML(highlighted: String, truncatedNotice: String? = nil) -> String {
    let notice = truncatedNotice.map { #"<div class="ql-truncated">\#($0)</div>"# } ?? ""
    let truncatedStyle = truncatedNotice != nil ? """
        .ql-truncated {
            padding: 8px 12px;
            font-family: -apple-system, system-ui, sans-serif;
            font-size: 11px;
            color: #888;
            text-align: center;
        }
        """ : ""
    return """
    <!DOCTYPE html>
    <html>
    <head>
    <meta charset="utf-8">
    <style>
    html, body { margin: 0; padding: 0; }
    pre.shiki {
        margin: 0;
        padding: 12px;
        font-family: ui-monospace, "SF Mono", Menlo, monospace;
        font-size: 12px;
        line-height: 1.5;
        tab-size: 4;
        white-space: pre-wrap;
        overflow-wrap: anywhere;
        word-break: break-word;
    }
    \(truncatedStyle)
    </style>
    </head>
    <body>
    \(highlighted)
    \(notice)
    </body>
    </html>
    """
}
