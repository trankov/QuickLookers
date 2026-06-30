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
            data: Data("not a plist".utf8), fileExtension: "tmTheme", uiTheme: "vs-dark"))
    }
}
