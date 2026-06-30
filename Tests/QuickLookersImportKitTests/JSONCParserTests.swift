import XCTest
@testable import QuickLookersImportKit

final class JSONCParserTests: XCTestCase {
    private func parse(_ s: String) throws -> [String: Any] {
        try JSONCParser.object(from: Data(s.utf8)) as! [String: Any]
    }

    func testLineComments() throws {
        let o = try parse("""
        {
          // активная тема
          "workbench.colorTheme": "Seti Monokai: Original", // хвостовой коммент
          "editor.fontSize": 13
        }
        """)
        XCTAssertEqual(o["workbench.colorTheme"] as? String, "Seti Monokai: Original")
        XCTAssertEqual(o["editor.fontSize"] as? Double, 13)
    }

    func testBlockCommentsAndTrailingCommas() throws {
        let o = try parse("""
        {
          /* блок
             комментарий */
          "a": 1,
          "b": [1, 2, 3,],
        }
        """)
        XCTAssertEqual(o["a"] as? Double, 1)
        XCTAssertEqual((o["b"] as? [Any])?.count, 3)
    }

    func testSlashesAndCommasInsideStringsArePreserved() throws {
        let o = try parse(#"{ "url": "https://x/y", "path": "a,b//c", "q": "he said \"hi\"" }"#)
        XCTAssertEqual(o["url"] as? String, "https://x/y")
        XCTAssertEqual(o["path"] as? String, "a,b//c")
        XCTAssertEqual(o["q"] as? String, "he said \"hi\"")
    }

    func testRawControlCharInStringDoesNotCrash() throws {
        // Реальные settings.json иногда несут сырой таб внутри строки.
        let o = try parse("{ \"x\": \"a\tb\" }")
        XCTAssertNotNil(o["x"] as? String)
    }

    func testToStrictJSONProducesParseableJSON() throws {
        let strict = try JSONCParser.toStrictJSON(Data("{ \"a\": 1, } // x".utf8))
        let o = try JSONSerialization.jsonObject(with: strict) as! [String: Any]
        XCTAssertEqual(o["a"] as? Double, 1)
    }
}
