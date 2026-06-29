import XCTest
@testable import QuickLookersEngine

final class CompositeProviderTests: XCTestCase {
    private func dirWith(_ file: String, _ content: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try content.write(to: dir.appendingPathComponent(file), atomically: true, encoding: .utf8)
        return dir
    }

    func test_primaryWins() throws {
        let primary = BundledGrammarProvider(directory: try dirWith("swift.json", "PRIMARY"))
        let fallback = BundledGrammarProvider(directory: try dirWith("swift.json", "FALLBACK"))
        let c = CompositeGrammarProvider(primary: primary, fallback: fallback)
        XCTAssertEqual(try c.grammarJSON(languageId: "swift"), "PRIMARY")
    }

    func test_fallbackWhenPrimaryMissing() throws {
        let primary = BundledGrammarProvider(directory: try dirWith("other.json", "X"))
        let fallback = BundledGrammarProvider(directory: try dirWith("swift.json", "FALLBACK"))
        let c = CompositeGrammarProvider(primary: primary, fallback: fallback)
        XCTAssertEqual(try c.grammarJSON(languageId: "swift"), "FALLBACK")
    }

    func test_themeComposite() throws {
        let primary = BundledThemeProvider(directory: try dirWith("nope.json", "X"))
        let fallback = BundledThemeProvider(directory: try dirWith("dark-plus.json", "FB"))
        let c = CompositeThemeProvider(primary: primary, fallback: fallback)
        XCTAssertEqual(try c.themeJSON(themeId: "dark-plus"), "FB")
    }
}
