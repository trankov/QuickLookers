import Foundation
@testable import QuickLookersEngine

final class CountingGrammarProvider: GrammarProvider {
    let inner: GrammarProvider
    private(set) var calls: [String] = []
    init(_ inner: GrammarProvider) { self.inner = inner }
    func grammarJSON(languageId: String) throws -> String {
        calls.append(languageId)
        return try inner.grammarJSON(languageId: languageId)
    }
}

final class CountingThemeProvider: ThemeProvider {
    let inner: ThemeProvider
    private(set) var calls: [String] = []
    init(_ inner: ThemeProvider) { self.inner = inner }
    func themeJSON(themeId: String) throws -> String {
        calls.append(themeId)
        return try inner.themeJSON(themeId: themeId)
    }
}

/// Бросает ошибку при первом обращении к данному id, при последующих — отдаёт
/// результат `inner`. Нужен, чтобы проверить, что `ShikiEngine` не запоминает
/// неудачную попытку загрузки как «уже загружено» и повторяет её на следующем вызове.
final class FlakyOnceGrammarProvider: GrammarProvider {
    let inner: GrammarProvider
    private var failedOnce = Set<String>()
    init(_ inner: GrammarProvider) { self.inner = inner }
    func grammarJSON(languageId: String) throws -> String {
        if !failedOnce.contains(languageId) {
            failedOnce.insert(languageId)
            throw EngineError.resourceNotFound(languageId)
        }
        return try inner.grammarJSON(languageId: languageId)
    }
}
