import Foundation

public enum QuickLookersEngineFactory {
    public static func makeDefault() throws -> HighlightEngine {
        let runtime = try JSCoreRuntime(bundleScript: JSCoreRuntime.loadBundledScript())
        guard let grammarsDir = Bundle.module.url(forResource: "grammars", withExtension: nil) else {
            throw EngineError.resourceNotFound("grammars")
        }
        guard let themesDir = Bundle.module.url(forResource: "themes", withExtension: nil) else {
            throw EngineError.resourceNotFound("themes")
        }
        return ShikiEngine(runtime: runtime,
                           grammars: BundledGrammarProvider(directory: grammarsDir),
                           themes: BundledThemeProvider(directory: themesDir))
    }
}
