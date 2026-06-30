import XCTest
@testable import QuickLookersEngine

final class ProviderTests: XCTestCase {
    private func resourceDir(_ name: String) throws -> URL {
        guard let url = Bundle.module.url(forResource: name, withExtension: nil) else {
            throw EngineError.resourceNotFound(name)
        }
        return url
    }

    func test_grammarProvider_returnsJSONContainingName() throws {
        let provider = BundledGrammarProvider(directory: try resourceDir("grammars"))
        let json = try provider.grammarJSON(languageId: "swift")
        XCTAssertTrue(json.contains("\"name\""))
        XCTAssertTrue(json.contains("swift"))
    }

    func test_themeProvider_missingThemeThrows() throws {
        let provider = BundledThemeProvider(directory: try resourceDir("themes"))
        XCTAssertThrowsError(try provider.themeJSON(themeId: "does-not-exist"))
    }

    func test_grammarProvider_missingLanguageThrows() throws {
        let provider = BundledGrammarProvider(directory: try resourceDir("grammars"))
        XCTAssertThrowsError(try provider.grammarJSON(languageId: "does-not-exist"))
    }
}
