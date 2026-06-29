import Foundation

public enum QuickLookersEngineFactory {
    /// Собирает движок. Если переданы каталоги импорта — они перекрывают бандл по id.
    public static func makeDefault(importedGrammarsDir: URL? = nil,
                                   importedThemesDir: URL? = nil) throws -> HighlightEngine {
        let runtime = try JSCoreRuntime(bundleScript: JSCoreRuntime.loadBundledScript())
        guard let grammarsDir = Bundle.module.url(forResource: "grammars", withExtension: nil) else {
            throw EngineError.resourceNotFound("grammars")
        }
        guard let themesDir = Bundle.module.url(forResource: "themes", withExtension: nil) else {
            throw EngineError.resourceNotFound("themes")
        }
        let bundledGrammars = BundledGrammarProvider(directory: grammarsDir)
        let bundledThemes = BundledThemeProvider(directory: themesDir)

        let grammars: GrammarProvider = importedGrammarsDir.map {
            CompositeGrammarProvider(primary: BundledGrammarProvider(directory: $0), fallback: bundledGrammars)
        } ?? bundledGrammars
        let themes: ThemeProvider = importedThemesDir.map {
            CompositeThemeProvider(primary: BundledThemeProvider(directory: $0), fallback: bundledThemes)
        } ?? bundledThemes

        return ShikiEngine(runtime: runtime, grammars: grammars, themes: themes)
    }
}
