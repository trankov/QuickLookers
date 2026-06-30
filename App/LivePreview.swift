import Foundation
import AppKit
import QuickLookersEngine
import QuickLookersSettingsKit
import QuickLookersPreviewKit

/// Кэш последнего подсвеченного фрагмента (по ключу «язык|тема»). Ссылочный тип,
/// чтобы previewHTML не мутировал саму вью-модель во время отрисовки SwiftUI.
final class FragmentCache {
    private var key = ""
    private var fragment = "<pre class=\"shiki\"></pre>"

    /// Фрагмент для ключа; если ключ сменился — пересчитывает через `make`.
    func fragment(forKey newKey: String, make: () -> String) -> String {
        if key != newKey { key = newKey; fragment = make() }
        return fragment
    }
    func invalidate() { key = "" }
}

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

    /// HTML живого превью. Движок (≈190 мс) гоняем только при смене языка/темы;
    /// при смене шрифта берём готовый фрагмент из кэша и пересобираем лишь CSS-обёртку.
    func previewHTML(languageId: String, code: String) -> String {
        let themeId = resolvedThemeId(activeThemeId: settings.activeThemeId,
                                      availableThemeIds: Set(catalog.themes.map(\.id)))
        let fragment = fragmentCache.fragment(forKey: "\(languageId)|\(themeId)") {
            guard let engine = Self.previewEngine,
                  let html = try? engine.highlightToHTML(
                      HighlightRequest(code: code, languageId: languageId, themeId: themeId))
            else { return "<pre class=\"shiki\"></pre>" }
            return html
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
