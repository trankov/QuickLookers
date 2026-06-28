import XCTest
@testable import QuickLookersEngine

final class ShikiEngineTests: XCTestCase {
    private func makeEngine() throws -> (ShikiEngine, CountingGrammarProvider) {
        let runtime = try JSCoreRuntime(bundleScript: JSCoreRuntime.loadBundledScript())
        let grammarsDir = Bundle.module.url(forResource: "grammars", withExtension: nil)!
        let themesDir = Bundle.module.url(forResource: "themes", withExtension: nil)!
        let counting = CountingGrammarProvider(BundledGrammarProvider(directory: grammarsDir))
        let engine = ShikiEngine(runtime: runtime,
                                 grammars: counting,
                                 themes: BundledThemeProvider(directory: themesDir))
        return (engine, counting)
    }

    func test_highlightsSwiftCode() throws {
        let (engine, _) = try makeEngine()
        let html = try engine.highlightToHTML(
            HighlightRequest(code: "let x = 1", languageId: "swift", themeId: "dark-plus"))
        XCTAssertTrue(html.contains("<pre"))
        XCTAssertTrue(html.contains("style="))   // присутствуют инлайновые цвета
    }

    func test_grammarLoadedOncePerLanguage() throws {
        let (engine, counting) = try makeEngine()
        let req = HighlightRequest(code: "let x = 1", languageId: "swift", themeId: "dark-plus")
        _ = try engine.highlightToHTML(req)
        _ = try engine.highlightToHTML(req)
        XCTAssertEqual(counting.calls, ["swift"])  // грамматика прочитана один раз
    }
}
