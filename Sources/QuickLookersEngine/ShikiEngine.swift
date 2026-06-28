import Foundation

public final class ShikiEngine: HighlightEngine {
    private let runtime: JSCoreRuntime
    private let grammars: GrammarProvider
    private let themes: ThemeProvider
    private var loadedLanguages = Set<String>()
    private var loadedThemes = Set<String>()

    public init(runtime: JSCoreRuntime, grammars: GrammarProvider, themes: ThemeProvider) {
        self.runtime = runtime
        self.grammars = grammars
        self.themes = themes
    }

    public func highlightToHTML(_ request: HighlightRequest) throws -> String {
        if !loadedLanguages.contains(request.languageId) {
            try runtime.registerLanguage(json: grammars.grammarJSON(languageId: request.languageId))
            loadedLanguages.insert(request.languageId)
        }
        if !loadedThemes.contains(request.themeId) {
            try runtime.registerTheme(json: themes.themeJSON(themeId: request.themeId))
            loadedThemes.insert(request.themeId)
        }
        return try runtime.highlight(code: request.code,
                                     language: request.languageId,
                                     theme: request.themeId)
    }
}
