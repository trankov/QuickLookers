import XCTest
import Foundation
@testable import QuickLookersEngine

final class EngineFactoryTests: XCTestCase {
    func testMakeDefault_noOverrides_producesWorkingEngine() throws {
        let engine = try QuickLookersEngineFactory.makeDefault()
        let html = try engine.highlightToHTML(
            HighlightRequest(code: "let x = 1", languageId: "swift", themeId: "dark-plus"))
        XCTAssertTrue(html.contains("<pre"))
    }

    /// Зеркало `TmThemeShapeRenderTests` (которая проверяет `importedThemesDir`),
    /// но для `importedGrammarsDir`: грамматика из каталога импорта должна реально
    /// дойти до JS-движка и подсветиться, а не просто победить в выборе провайдера
    /// (это уже проверено юнит-тестом `CompositeProviderTests`).
    func testMakeDefault_importedGrammarsDir_isUsedEndToEnd() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("ql-grammar-import-\(UUID().uuidString)")
        let grammarsDir = tmp.appendingPathComponent("grammars")
        try FileManager.default.createDirectory(at: grammarsDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        // Имя файла (id для провайдера) и поле "name" (id для движка) должны совпадать —
        // оба используются как languageId в HighlightRequest.
        let customGrammarJSON = #"{"name":"qltestlang","scopeName":"source.qltestlang","patterns":[]}"#
        try Data(customGrammarJSON.utf8).write(to: grammarsDir.appendingPathComponent("qltestlang.json"))

        let engine = try QuickLookersEngineFactory.makeDefault(importedGrammarsDir: grammarsDir)
        let html = try engine.highlightToHTML(
            HighlightRequest(code: "hello world", languageId: "qltestlang", themeId: "dark-plus"))

        XCTAssertFalse(html.isEmpty)
        XCTAssertTrue(html.contains("hello world"))
    }
}
