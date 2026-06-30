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

    func test_acceptsMaxLengthBoundary() {
        XCTAssertTrue(isSafeImportID(String(repeating: "x", count: 64)))   // ровно потолок — годен
    }

    func test_rejectsUnicodeLetters() {
        // ch.isLetter верен и для не-ASCII букв — без явной проверки ch.isASCII
        // кириллица/иероглифы проскочили бы в имя файла на диске.
        for id in ["café", "日本語", "naïve", "Москва"] {
            XCTAssertFalse(isSafeImportID(id), id)
        }
    }
}
