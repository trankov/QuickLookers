import XCTest
import Foundation
@testable import QuickLookersEngine

final class TmThemeShapeRenderTests: XCTestCase {
    /// Тема в форме, в которую конвертируется .tmTheme (массив settings → tokenColors,
    /// первый бесскоупный элемент несёт background/foreground). Если рисуется —
    /// значит выбранная форма конвертации верна.
    func testEngineRendersTokenColorsThemeWithScopelessRoot() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("ql-tmtheme-\(UUID().uuidString)")
        let themesDir = tmp.appendingPathComponent("themes")
        try FileManager.default.createDirectory(at: themesDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let themeJSON = """
        {
          "name": "tmtest",
          "type": "dark",
          "tokenColors": [
            { "settings": { "background": "#102030", "foreground": "#eeeeee" } },
            { "scope": "string", "settings": { "foreground": "#88ff88" } }
          ]
        }
        """
        try Data(themeJSON.utf8).write(to: themesDir.appendingPathComponent("tmtest.json"))

        let engine = try QuickLookersEngineFactory.makeDefault(importedThemesDir: themesDir)
        let html = try engine.highlightToHTML(
            HighlightRequest(code: "{\"a\": \"b\"}", languageId: "json", themeId: "tmtest"))

        XCTAssertFalse(html.isEmpty)
        // Shiki вшивает фон темы в инлайновый стиль <pre> — проверяем, что наш фон применился.
        XCTAssertTrue(html.lowercased().contains("#102030"),
                      "Фон темы не применился — форма конвертации не принята движком: \(html.prefix(400))")
    }
}
