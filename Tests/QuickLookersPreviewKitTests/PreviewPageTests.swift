import XCTest
@testable import QuickLookersPreviewKit

final class PreviewPageTests: XCTestCase {
    func test_pageWrapsFragment_andResetsMargins() {
        let fragment = #"<pre class="shiki" style="background-color:#1e1e1e">code</pre>"#
        let page = previewPageHTML(highlighted: fragment)

        XCTAssertTrue(page.contains("<html"), "должен быть полный документ")
        XCTAssertTrue(page.contains("margin: 0"), "поля сброшены, чтобы фон заполнял окно")
        XCTAssertTrue(page.contains(fragment), "фрагмент вставлен дословно")
    }

    func test_backgroundStretchesToFullWindowHeight() {
        // Короткий код не должен оставлять снизу «подвал» другого цвета:
        // <pre.shiki>, несущий цвет фона темы, тянется на всю высоту окна,
        // а border-box не даёт padding'у переполнить высоту (лишний скролл).
        let page = previewPageHTML(
            highlighted: #"<pre class="shiki" style="background-color:#1e1e1e">x</pre>"#)
        XCTAssertTrue(page.contains("min-height: 100vh"),
                      "фон растянут на всю высоту окна")
        XCTAssertTrue(page.contains("box-sizing: border-box"),
                      "padding не должен давать переполнение по высоте")
    }

    func test_fragmentIsNotDoubleEscaped() {
        let fragment = #"<span style="color:#569cd6">let</span>"#
        let page = previewPageHTML(highlighted: fragment)
        XCTAssertTrue(page.contains(fragment))
    }

    func test_pageWrapsLongLines() {
        let page = previewPageHTML(highlighted: #"<pre class="shiki">x</pre>"#)
        XCTAssertTrue(page.contains("pre-wrap"), "длинные строки должны переноситься")
        XCTAssertTrue(page.contains("overflow-wrap"), "длинные строки без пробелов ломаются")
    }

    func test_truncationNoticeShownWhenProvided() {
        let page = previewPageHTML(highlighted: "x", truncatedNotice: "Показаны первые 2000 строк")
        XCTAssertTrue(page.contains("ql-truncated"), "должна быть плашка обрезки")
        XCTAssertTrue(page.contains("Показаны первые 2000 строк"), "текст плашки вставлен")
    }

    func test_noTruncationNoticeByDefault() {
        let page = previewPageHTML(highlighted: "x")
        XCTAssertFalse(page.contains("ql-truncated"), "без обрезки плашки нет")
    }

    func test_injectsFamilyAndSize() {
        let html = previewPageHTML(highlighted: "<pre class=\"shiki\"></pre>",
                                   fontFamily: "JetBrains Mono", fontSize: 15)
        // Семейство из настроек — это уже готовый список (часто со своими кавычками),
        // подставляем как есть + monospace-откат, не оборачивая целиком.
        XCTAssertTrue(html.contains("font-family: JetBrains Mono, ui-monospace, monospace"))
        XCTAssertTrue(html.contains("font-size: 15px"))
    }

    func test_fontFamilyAlsoTargetsCodeElement() {
        // Shiki кладёт код в <pre class="shiki"><code>. У браузера есть UA-правило
        // code { font-family: monospace }, которое бьёт прямо по <code> и перебивает
        // унаследованный от pre.shiki шрифт. Поэтому селектор обязан накрывать и code,
        // иначе выбранное семейство в Finder не применяется (а размер — да, он наследуется).
        let html = previewPageHTML(highlighted: "<pre class=\"shiki\"><code>x</code></pre>",
                                   fontFamily: "JetBrains Mono", fontSize: 15)
        XCTAssertTrue(html.contains("pre.shiki code"), "font-family должен накрывать и <code>")
    }

    func test_nilFontKeepsDefaults() {
        let html = previewPageHTML(highlighted: "x", fontFamily: nil, fontSize: nil)
        XCTAssertTrue(html.contains("ui-monospace"))
        XCTAssertFalse(html.contains("font-size: 0"))
    }

    func test_sanitizesDangerousFamily() {
        let s = sanitizedFontFamily("Evil</style><script>;{}")
        XCTAssertNotNil(s)
        XCTAssertFalse(s!.contains("<"))
        XCTAssertFalse(s!.contains("{"))
        XCTAssertFalse(s!.contains(";"))
    }

    func test_rejectsAbsurdSize() {
        let html = previewPageHTML(highlighted: "x", fontFamily: nil, fontSize: 9999)
        XCTAssertFalse(html.contains("9999"))   // вне диапазона → размер не подставлен
    }

    func test_sanitizesEmptyStringToNil() {
        XCTAssertNil(sanitizedFontFamily(""))
    }

    func test_sanitizesWhitespaceOnlyToNil() {
        XCTAssertNil(sanitizedFontFamily("   "))
    }

    func test_sanitizesNilStaysNil() {
        XCTAssertNil(sanitizedFontFamily(nil))
    }

    func test_fullPagePreventsCSSInjectionViaFontFamily() {
        // familyCSS вставляется в <style> БЕЗ окружающих кавычек, поэтому
        // символы, которые могли бы закрыть правило/блок стиля или открыть
        // новый тег, обязаны быть вырезаны до подстановки.
        let malicious = #"x; } </style><script>alert(1)</script><style>body{background:url(javascript:alert(1))"#
        let html = previewPageHTML(highlighted: "<pre class=\"shiki\"></pre>",
                                   fontFamily: malicious, fontSize: 14)
        XCTAssertFalse(html.contains("<script>"), "не должно быть выхода в новый тег")
        XCTAssertEqual(html.components(separatedBy: "</style>").count, 2, "ровно один закрывающий </style>, инъекция не добавила второй")
        XCTAssertFalse(html.contains("url("), "url() не должен пройти")
        XCTAssertFalse(html.contains("javascript:"), "javascript: не должен пройти")
    }
}
