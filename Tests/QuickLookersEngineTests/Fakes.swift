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

/// Отдаёт настоящую бандловую грамматику `bundledId`, но с подменённым полем
/// `name` (витринное имя ≠ id) — так выглядит грамматика, импортированная из
/// `.vsix` (VS Code хранит в `name` человекочитаемое «Django HTML», а не id).
/// Нужен, чтобы проверить: движок регистрирует грамматику под запрошенным id,
/// а не под её внутренним `name`, иначе Shiki не найдёт её при показе.
final class MisnamedGrammarProvider: GrammarProvider {
    let bundledId: String
    let displayName: String
    let directory: URL
    init(bundledId: String, displayName: String, directory: URL) {
        self.bundledId = bundledId; self.displayName = displayName; self.directory = directory
    }
    func grammarJSON(languageId: String) throws -> String {
        let url = directory.appendingPathComponent("\(bundledId).json")
        let data = try Data(contentsOf: url)
        guard var arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              !arr.isEmpty else { throw EngineError.resourceNotFound(bundledId) }
        arr[0]["name"] = displayName            // главная грамматика получает витринное имя ≠ id
        let out = try JSONSerialization.data(withJSONObject: arr)
        return String(data: out, encoding: .utf8)!
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
