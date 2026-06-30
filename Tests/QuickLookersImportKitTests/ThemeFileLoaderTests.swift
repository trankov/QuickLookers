import XCTest
@testable import QuickLookersImportKit

final class ThemeFileLoaderTests: XCTestCase {
    private func fixture(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "Fixtures/themes/\(name)", withExtension: nil))
        return try Data(contentsOf: url)
    }

    func testLoadsJSONCThemeToStrictJSON() throws {
        let out = try ThemeFileLoader.loadStrictThemeJSON(
            data: fixture("sample.json"), fileExtension: "json", uiTheme: "vs-dark")
        let o = try JSONSerialization.jsonObject(with: out) as! [String: Any]
        XCTAssertEqual((o["colors"] as? [String: Any])?["editor.background"] as? String, "#001122")
        XCTAssertNotNil(o["tokenColors"])
    }

    func testConvertsTmThemeToTokenColorsShape() throws {
        let out = try ThemeFileLoader.loadStrictThemeJSON(
            data: fixture("sample.tmTheme"), fileExtension: "tmTheme", uiTheme: "vs-dark")
        let o = try JSONSerialization.jsonObject(with: out) as! [String: Any]
        XCTAssertEqual(o["type"] as? String, "dark")
        let tokens = try XCTUnwrap(o["tokenColors"] as? [[String: Any]])
        XCTAssertEqual(tokens.count, 2)
        // Первый — бесскоупный рут с background/foreground.
        let root = try XCTUnwrap(tokens.first?["settings"] as? [String: Any])
        XCTAssertEqual(root["background"] as? String, "#101010")
        XCTAssertEqual(tokens[1]["scope"] as? String, "comment")
    }

    func testBadPlistThrows() throws {
        XCTAssertThrowsError(try ThemeFileLoader.loadStrictThemeJSON(
            data: Data("not a plist".utf8), fileExtension: "tmTheme", uiTheme: "vs-dark")) { e in
            XCTAssertEqual(e as? ThemeFileError, .badPlist)
        }
    }

    func testPlistExtensionIsAcceptedLikeTmTheme() throws {
        // .plist — то же имя расширения, что и у .tmTheme не по словарю, проверяем явно.
        let out = try ThemeFileLoader.loadStrictThemeJSON(
            data: fixture("sample.tmTheme"), fileExtension: "plist", uiTheme: "vs-dark")
        let o = try JSONSerialization.jsonObject(with: out) as! [String: Any]
        XCTAssertEqual(o["type"] as? String, "dark")
    }

    func testUppercaseExtensionIsCaseInsensitive() throws {
        let out = try ThemeFileLoader.loadStrictThemeJSON(
            data: fixture("sample.tmTheme"), fileExtension: "TMTHEME", uiTheme: "vs")
        let o = try JSONSerialization.jsonObject(with: out) as! [String: Any]
        XCTAssertEqual(o["type"] as? String, "light")
    }

    func testMalformedJSONThemeThrowsBadJSON() throws {
        // Не plist-расширение, но содержимое — не разбираемый даже как JSONC мусор
        // (незакрытая строка ломает разбор и до strict-JSON).
        XCTAssertThrowsError(try ThemeFileLoader.loadStrictThemeJSON(
            data: Data(#"{ "name": "broken, "#.utf8), fileExtension: "json", uiTheme: "vs-dark")) { e in
            XCTAssertEqual(e as? ThemeFileError, .badJSON)
        }
    }

    func testInvalidUTF8ThemeThrowsBadJSON() throws {
        XCTAssertThrowsError(try ThemeFileLoader.loadStrictThemeJSON(
            data: Data([0xFF, 0xFE, 0x00]), fileExtension: "json", uiTheme: "vs-dark")) { e in
            XCTAssertEqual(e as? ThemeFileError, .badJSON)
        }
    }
}
