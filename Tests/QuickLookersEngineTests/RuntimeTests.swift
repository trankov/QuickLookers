import XCTest
@testable import QuickLookersEngine

final class RuntimeTests: XCTestCase {
    func test_highlightRequest_storesFields() {
        let r = HighlightRequest(code: "let x = 1", languageId: "swift", themeId: "dark-plus")
        XCTAssertEqual(r.code, "let x = 1")
        XCTAssertEqual(r.languageId, "swift")
        XCTAssertEqual(r.themeId, "dark-plus")
    }

    func test_runtime_highlightsPlaintext() throws {
        let runtime = try JSCoreRuntime(bundleScript: JSCoreRuntime.loadBundledScript())
        try runtime.registerLanguage(json: #"{"name":"plaintext","scopeName":"source.plain","patterns":[]}"#)
        try runtime.registerTheme(json: ##"{"name":"t","type":"dark","colors":{"editor.foreground":"#ffffff"},"tokenColors":[]}"##)
        let html = try runtime.highlight(code: "hello", language: "plaintext", theme: "t")
        XCTAssertTrue(html.contains("<pre"))
        XCTAssertTrue(html.contains("hello"))
    }

    // MARK: - Edge cases

    func test_init_invalidScript_throwsScriptEvaluation() {
        XCTAssertThrowsError(try JSCoreRuntime(bundleScript: "this is not { valid javascript")) { error in
            guard case EngineError.scriptEvaluation = error else {
                return XCTFail("ожидали .scriptEvaluation, получили \(error)")
            }
        }
    }

    func test_registerLanguage_malformedJSON_throwsJSException() throws {
        let runtime = try JSCoreRuntime(bundleScript: JSCoreRuntime.loadBundledScript())
        XCTAssertThrowsError(try runtime.registerLanguage(json: "{not valid json")) { error in
            guard case EngineError.jsException = error else {
                return XCTFail("ожидали .jsException, получили \(error)")
            }
        }
    }

    func test_registerTheme_malformedJSON_throwsJSException() throws {
        let runtime = try JSCoreRuntime(bundleScript: JSCoreRuntime.loadBundledScript())
        XCTAssertThrowsError(try runtime.registerTheme(json: "{not valid json")) { error in
            guard case EngineError.jsException = error else {
                return XCTFail("ожидали .jsException, получили \(error)")
            }
        }
    }

    func test_highlight_unregisteredLanguage_throws() throws {
        let runtime = try JSCoreRuntime(bundleScript: JSCoreRuntime.loadBundledScript())
        try runtime.registerTheme(json: ##"{"name":"t","type":"dark","colors":{},"tokenColors":[]}"##)
        XCTAssertThrowsError(try runtime.highlight(code: "hello", language: "no-such-lang", theme: "t")) { error in
            guard case EngineError.jsException(let message) = error else {
                return XCTFail("ожидали .jsException, получили \(error)")
            }
            XCTAssertTrue(message.contains("not registered"), message)
        }
    }

    func test_highlight_unregisteredTheme_throws() throws {
        let runtime = try JSCoreRuntime(bundleScript: JSCoreRuntime.loadBundledScript())
        try runtime.registerLanguage(json: #"{"name":"plaintext","scopeName":"source.plain","patterns":[]}"#)
        XCTAssertThrowsError(try runtime.highlight(code: "hello", language: "plaintext", theme: "no-such-theme")) { error in
            guard case EngineError.jsException(let message) = error else {
                return XCTFail("ожидали .jsException, получили \(error)")
            }
            XCTAssertTrue(message.contains("not registered"), message)
        }
    }
}
