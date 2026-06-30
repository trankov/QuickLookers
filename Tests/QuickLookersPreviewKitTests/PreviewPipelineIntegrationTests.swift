import XCTest
@testable import QuickLookersPreviewKit

/// Интеграционный тест связки CodeTrim → PreviewPage: обрезка длинного файла
/// и сборка готовой HTML-страницы с плашкой обрезки — то, что реально делает
/// расширение перед показом (без самого движка подсветки).
final class PreviewPipelineIntegrationTests: XCTestCase {
    func test_trimmedLongFileProducesPageWithTruncationNotice() {
        let fakeFile = (1...5000).map { "line \($0)" }.joined(separator: "\n")
        let (trimmed, truncated) = trimToFirstLines(fakeFile, max: 2000)

        XCTAssertTrue(truncated)
        XCTAssertEqual(trimmed.split(separator: "\n").count, 2000)

        let highlighted = "<pre class=\"shiki\">\(trimmed)</pre>"
        let notice = truncated ? "Показаны первые 2000 строк" : nil
        let page = previewPageHTML(highlighted: highlighted, truncatedNotice: notice)

        XCTAssertTrue(page.contains("line 1\n"), "первая строка должна попасть в страницу")
        XCTAssertTrue(page.contains("line 2000</pre>"), "последняя оставленная строка должна попасть в страницу")
        XCTAssertFalse(page.contains("line 2001"), "строки за пределами обрезки не должны попасть в страницу")
        XCTAssertTrue(page.contains("ql-truncated"))
        XCTAssertTrue(page.contains("Показаны первые 2000 строк"))
    }

    func test_shortFileWithinLimitProducesPageWithoutTruncationNotice() {
        let fakeFile = (1...10).map { "line \($0)" }.joined(separator: "\n")
        let (trimmed, truncated) = trimToFirstLines(fakeFile, max: 2000)

        XCTAssertFalse(truncated)
        let page = previewPageHTML(highlighted: "<pre class=\"shiki\">\(trimmed)</pre>",
                                   truncatedNotice: truncated ? "Показаны первые 2000 строк" : nil)

        XCTAssertFalse(page.contains("ql-truncated"))
        XCTAssertTrue(page.contains("line 10<"))
    }
}
