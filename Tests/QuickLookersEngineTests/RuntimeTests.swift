import XCTest
@testable import QuickLookersEngine

final class RuntimeTests: XCTestCase {
    func test_highlightRequest_storesFields() {
        let r = HighlightRequest(code: "let x = 1", languageId: "swift", themeId: "dark-plus")
        XCTAssertEqual(r.code, "let x = 1")
        XCTAssertEqual(r.languageId, "swift")
        XCTAssertEqual(r.themeId, "dark-plus")
    }
}
