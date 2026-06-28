import XCTest
@testable import QuickLookersPreviewKit

final class LanguageMapTests: XCTestCase {
    func test_knownExtensions_mapToGrammarIds() {
        XCTAssertEqual(languageId(forPathExtension: "swift"), "swift")
        XCTAssertEqual(languageId(forPathExtension: "json"), "json")
        XCTAssertEqual(languageId(forPathExtension: "js"), "javascript")
    }

    func test_extension_isCaseInsensitive() {
        XCTAssertEqual(languageId(forPathExtension: "SWIFT"), "swift")
        XCTAssertEqual(languageId(forPathExtension: "JS"), "javascript")
    }

    func test_unknownExtension_returnsNil() {
        XCTAssertNil(languageId(forPathExtension: "txt"))
        XCTAssertNil(languageId(forPathExtension: ""))
    }
}
