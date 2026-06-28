import XCTest
@testable import QuickLookersPreviewKit

final class CodeTrimTests: XCTestCase {
    func test_keepsWhenWithinLimit() {
        let r = trimToFirstLines("a\nb", max: 2)
        XCTAssertEqual(r.code, "a\nb")
        XCTAssertFalse(r.truncated)
    }

    func test_trimsWhenOverLimit() {
        let r = trimToFirstLines("a\nb\nc", max: 2)
        XCTAssertEqual(r.code, "a\nb")
        XCTAssertTrue(r.truncated)
    }

    func test_emptyInput() {
        let r = trimToFirstLines("", max: 2)
        XCTAssertEqual(r.code, "")
        XCTAssertFalse(r.truncated)
    }

    func test_singleLine() {
        let r = trimToFirstLines("a", max: 2)
        XCTAssertEqual(r.code, "a")
        XCTAssertFalse(r.truncated)
    }
}
