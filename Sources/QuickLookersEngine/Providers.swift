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
