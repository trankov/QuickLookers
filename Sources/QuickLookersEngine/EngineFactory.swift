import Foundation

public enum QuickLookersEngineFactory {
    public static func makeDefault() throws -> ShikiEngine {
        let runtime = try JSCoreRuntime(bundleScript: JSCoreRuntime.loadBundledScript())
        guard let grammarsDir = Bundle.module.url(forResource: "grammars", withExtension: nil),
              let themesDir = Bundle.module.url(forResource: "themes", withExtension: nil) else {
            throw EngineError.resourceNotFound("resource directories")
        }
        return ShikiEngine(runtime: runtime,
                           grammars: BundledGrammarProvider(directory: grammarsDir),
                           themes: BundledThemeProvider(directory: themesDir))
    }
}
