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
}
