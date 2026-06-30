/// Оборачивает готовый фрагмент подсветки в самодостаточный HTML-документ.
/// Фон и цвета несёт сам фрагмент (его `<pre>` от Shiki); здесь только сброс
/// полей, моноширинный шрифт и перенос длинных строк, чтобы фон заполнял окно.
/// `truncatedNotice` (если задан) дорисовывает внизу неинтерактивную плашку.

import Foundation

/// Безопасное для CSS семейство шрифта: только буквы/цифры/пробел/-/_/,/'/" .
/// Возвращает nil, если после чистки пусто.
func sanitizedFontFamily(_ raw: String?) -> String? {
    guard let raw else { return nil }
    let allowed = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 -_,'\"")
    let cleaned = String(raw.filter { allowed.contains($0) }).trimmingCharacters(in: .whitespaces)
    return cleaned.isEmpty ? nil : cleaned
}

public func previewPageHTML(highlighted: String, fontFamily: String? = nil, fontSize: Double? = nil,
                            truncatedNotice: String? = nil) -> String {
    let family = sanitizedFontFamily(fontFamily)
    let familyCSS = family.map { "\($0), ui-monospace, monospace" } ?? "ui-monospace, \"SF Mono\", Menlo, monospace"
    // Граничный guard на стороне CSS (defense-in-depth): значение приходит примитивом,
    // канонический диапазон живёт на FontSettings.sizeRange (входной зажим — там).
    let size = (fontSize.flatMap { (6...48).contains(Int($0)) ? Int($0) : nil }) ?? 12

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
    /* Семейство задаём и на <code> внутри <pre.shiki>: у браузера есть UA-правило
       code { font-family: monospace }, которое бьёт прямо по <code> и иначе перебивает
       унаследованный шрифт (размер при этом наследуется — UA его на code не задаёт). */
    pre.shiki, pre.shiki code { font-family: \(familyCSS); }
    pre.shiki {
        margin: 0;
        padding: 12px;
        font-size: \(size)px;
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
