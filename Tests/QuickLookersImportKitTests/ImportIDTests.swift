import XCTest
@testable import QuickLookersImportKit

final class ImportIDTests: XCTestCase {
    func test_acceptsNormalIds() {
        for id in ["swift", "objective-c", "java_script", "vue", "c", "a1-b2_c3"] {
            XCTAssertTrue(isSafeImportID(id), id)
        }
    }
    func test_rejectsTraversalAndOddInput() {
        for id in ["../evil", "..", "a/b", "a\\b", ".", ".hidden", "", "a.b", "with space",
                   String(repeating: "x", count: 65)] {
            XCTAssertFalse(isSafeImportID(id), id)
        }
    }
}
