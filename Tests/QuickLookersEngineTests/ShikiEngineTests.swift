import XCTest
@testable import QuickLookersEngine

final class ShikiEngineTests: XCTestCase {
    // Тёплый рантайм на весь класс — см. RuntimeTests.swift. Кеш «загружено один раз»
    // живёт в самом ShikiEngine (и в провайдере-счётчике), а не в JSCoreRuntime, поэтому
    // общий рантайм не портит изоляцию между тестами на повторную загрузку.
    private static let sharedRuntime = try! JSCoreRuntime(bundleScript: JSCoreRuntime.loadBundledScript())

    private func makeEngine() throws -> (ShikiEngine, CountingGrammarProvider) {
        let runtime = Self.sharedRuntime
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

    // MARK: - Edge cases

    func test_themeLoadedOncePerTheme() throws {
        let runtime = Self.sharedRuntime
        let grammarsDir = Bundle.module.url(forResource: "grammars", withExtension: nil)!
        let themesDir = Bundle.module.url(forResource: "themes", withExtension: nil)!
        let countingThemes = CountingThemeProvider(BundledThemeProvider(directory: themesDir))
        let engine = ShikiEngine(runtime: runtime,
                                 grammars: BundledGrammarProvider(directory: grammarsDir),
                                 themes: countingThemes)
        let req = HighlightRequest(code: "let x = 1", languageId: "swift", themeId: "dark-plus")
        _ = try engine.highlightToHTML(req)
        _ = try engine.highlightToHTML(req)
        XCTAssertEqual(countingThemes.calls, ["dark-plus"])  // тема прочитана один раз
    }

    func test_failedGrammarLoad_isNotCached_retriesOnNextCall() throws {
        let runtime = Self.sharedRuntime
        let grammarsDir = Bundle.module.url(forResource: "grammars", withExtension: nil)!
        let themesDir = Bundle.module.url(forResource: "themes", withExtension: nil)!
        let flaky = FlakyOnceGrammarProvider(BundledGrammarProvider(directory: grammarsDir))
        let engine = ShikiEngine(runtime: runtime,
                                 grammars: flaky,
                                 themes: BundledThemeProvider(directory: themesDir))
        let req = HighlightRequest(code: "let x = 1", languageId: "swift", themeId: "dark-plus")

        XCTAssertThrowsError(try engine.highlightToHTML(req), "первая попытка должна провалиться (флак-провайдер)")
        // Вторая попытка должна повторно обратиться к провайдеру, а не считать язык
        // уже «загруженным» после неудачной первой попытки.
        let html = try engine.highlightToHTML(req)
        XCTAssertTrue(html.contains("<pre"))
    }

    func test_importedGrammarWithDisplayName_highlightsById() throws {
        // Грамматика из .vsix держит витринное имя (name != id). Движок ищет по id,
        // поэтому обязан регистрировать её под id, а не под внутренним `name` —
        // иначе Shiki бросает 'lang not registered' (реальный баг django-html).
        // Свой рантайм, чтобы регистрация под фейк-id не пачкала общий.
        let runtime = try JSCoreRuntime(bundleScript: JSCoreRuntime.loadBundledScript())
        let grammarsDir = Bundle.module.url(forResource: "grammars", withExtension: nil)!
        let themesDir = Bundle.module.url(forResource: "themes", withExtension: nil)!
        let misnamed = MisnamedGrammarProvider(bundledId: "json", displayName: "Fancy JSON",
                                               directory: grammarsDir)
        let engine = ShikiEngine(runtime: runtime, grammars: misnamed,
                                 themes: BundledThemeProvider(directory: themesDir))
        let html = try engine.highlightToHTML(
            HighlightRequest(code: "{\"a\":1}", languageId: "fancyjson", themeId: "dark-plus"))
        XCTAssertTrue(html.contains("<pre"))
        XCTAssertTrue(html.contains("style="))
    }

    func test_highlightsEmptyCode() throws {
        let (engine, _) = try makeEngine()
        let html = try engine.highlightToHTML(
            HighlightRequest(code: "", languageId: "swift", themeId: "dark-plus"))
        XCTAssertTrue(html.contains("<pre"))
    }
}
