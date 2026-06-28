/// Оборачивает готовый фрагмент подсветки в самодостаточный HTML-документ.
/// Фон и цвета несёт сам фрагмент (его `<pre>` от Shiki); здесь только
/// сброс полей и моноширинный шрифт, чтобы фон заполнял всё окно превью.
public func previewPageHTML(highlighted: String) -> String {
    """
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
    }
    </style>
    </head>
    <body>
    \(highlighted)
    </body>
    </html>
    """
}
