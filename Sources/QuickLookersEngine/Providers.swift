import Foundation

public protocol GrammarProvider {
    func grammarJSON(languageId: String) throws -> String
}

public protocol ThemeProvider {
    func themeJSON(themeId: String) throws -> String
}

private func readJSON(_ directory: URL, _ id: String) throws -> String {
    let url = directory.appendingPathComponent("\(id).json")
    guard let string = try? String(contentsOf: url, encoding: .utf8) else {
        throw EngineError.resourceNotFound(id)
    }
    return string
}

public struct BundledGrammarProvider: GrammarProvider {
    private let directory: URL
    public init(directory: URL) { self.directory = directory }
    public func grammarJSON(languageId: String) throws -> String {
        try readJSON(directory, languageId)
    }
}

public struct BundledThemeProvider: ThemeProvider {
    private let directory: URL
    public init(directory: URL) { self.directory = directory }
    public func themeJSON(themeId: String) throws -> String {
        try readJSON(directory, themeId)
    }
}

/// Провайдер «сначала primary, при отсутствии — fallback».
/// Контейнер импорта (primary) перекрывает бандл (fallback) по id.
public struct CompositeGrammarProvider: GrammarProvider {
    private let primary: GrammarProvider
    private let fallback: GrammarProvider
    public init(primary: GrammarProvider, fallback: GrammarProvider) {
        self.primary = primary; self.fallback = fallback
    }
    public func grammarJSON(languageId: String) throws -> String {
        if let s = try? primary.grammarJSON(languageId: languageId) { return s }
        return try fallback.grammarJSON(languageId: languageId)
    }
}

public struct CompositeThemeProvider: ThemeProvider {
    private let primary: ThemeProvider
    private let fallback: ThemeProvider
    public init(primary: ThemeProvider, fallback: ThemeProvider) {
        self.primary = primary; self.fallback = fallback
    }
    public func themeJSON(themeId: String) throws -> String {
        if let s = try? primary.themeJSON(themeId: themeId) { return s }
        return try fallback.themeJSON(themeId: themeId)
    }
}
