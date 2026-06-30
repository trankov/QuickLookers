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
}
