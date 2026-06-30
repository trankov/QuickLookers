import Foundation
import AppKit
import QuickLookersEngine
import QuickLookersSettingsKit
import QuickLookersPreviewKit

extension SettingsModel {
    /// Тёплый движок приложения для живого превью (ленивая инициализация).
    /// Импортированные грамматики/темы из контейнера перекрывают бандл по id.
    private static let previewEngine: HighlightEngine? = {
        var g: URL?, t: URL?
        if let c = quickLookersContainerURL() {
            let lib = ImportedLibrary(containerURL: c); g = lib.grammarsDir; t = lib.themesDir
        }
        return try? QuickLookersEngineFactory.makeDefault(importedGrammarsDir: g, importedThemesDir: t)
    }()

    /// HTML живого превью для выбранного языка и активной темы с текущим шрифтом.
    func previewHTML(languageId: String, code: String) -> String {
        let themeId = resolvedThemeId(activeThemeId: settings.activeThemeId,
                                      availableThemeIds: Set(catalog.themes.map(\.id)))
        var fragment = "<pre class=\"shiki\"></pre>"
        if let engine = Self.previewEngine,
           let html = try? engine.highlightToHTML(
               HighlightRequest(code: code, languageId: languageId, themeId: themeId)) {
            fragment = html
        }
        return previewPageHTML(highlighted: fragment,
                               fontFamily: settings.font.family, fontSize: settings.font.size)
    }
}

/// Список установленных моноширинных семейств для пикера шрифта.
enum MonospaceFonts {
    static let families: [String] = {
        NSFontManager.shared.availableFontFamilies.filter { family in
            guard let font = NSFont(name: family, size: 12) else { return false }
            return font.isFixedPitch
        }.sorted()
    }()
}
