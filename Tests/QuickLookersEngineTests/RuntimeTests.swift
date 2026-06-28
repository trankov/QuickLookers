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
}
