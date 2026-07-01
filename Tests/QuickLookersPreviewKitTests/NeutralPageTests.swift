import XCTest
@testable import QuickLookersPreviewKit

final class NeutralPageTests: XCTestCase {
    func testEscapesHTML() {
        XCTAssertEqual(htmlEscaped("a < b && c > d \"q\""),
                       "a &lt; b &amp;&amp; c &gt; d &quot;q&quot;")
    }

    func testNeutralPageHasNoShikiMarkupAndEscapes() {
        let html = neutralPageHTML(code: "<script>x</script>")
        XCTAssertFalse(html.contains("class=\"shiki\""))
        XCTAssertTrue(html.contains("&lt;script&gt;"))
        XCTAssertFalse(html.contains("<script>x</script>")) // сырой код не попал в DOM
    }

    func testNeutralPageFullHeightAndMonospace() {
        let html = neutralPageHTML(code: "x")
        XCTAssertTrue(html.contains("min-height: 100vh"))
        XCTAssertTrue(html.contains("monospace"))
    }

    func testNeutralPageAppliesFontFamily() {
        let html = neutralPageHTML(code: "x", fontFamily: "Fira Code")
        XCTAssertTrue(html.contains("Fira Code"))
    }

    func testNeutralNoticeRendered() {
        let html = neutralPageHTML(code: "x", truncatedNotice: "Показаны первые 2000 строк")
        XCTAssertTrue(html.contains("Показаны первые 2000 строк"))
    }
}
