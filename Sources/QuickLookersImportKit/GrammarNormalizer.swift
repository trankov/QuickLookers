import Foundation

public enum GrammarError: Error { case badGrammar }

/// Нормализация грамматики из .vsix: plist→JSON и дособирание вложенных языков
/// в массив [главная + вложенные], как у встроенных грамматик.
public struct GrammarNormalizer {
    private let bundledGrammarsDir: URL
    public init(bundledGrammarsDir: URL) { self.bundledGrammarsDir = bundledGrammarsDir }

    /// XML-plist (.tmLanguage/.plist) → JSON; .json/.tmLanguage.json — как есть.
    public func toJSON(_ data: Data, path: String) throws -> Data {
        if path.hasSuffix(".json") { return data }
        guard let obj = try? PropertyListSerialization.propertyList(from: data, format: nil),
              JSONSerialization.isValidJSONObject(obj),
              let json = try? JSONSerialization.data(withJSONObject: obj)
        else { throw GrammarError.badGrammar }
        return json
    }

    /// Массив [главная + вложенные]. На главную внедряется embeddedLangs;
    /// вложенные берутся из siblingGrammars (тот же .vsix), иначе из встроенной библиотеки.
    public func normalize(languageId: String, grammarJSON: Data,
                          embeddedLanguageIds: [String], siblingGrammars: [String: Data]) throws -> Data {
        guard var main = try? JSONSerialization.jsonObject(with: grammarJSON) as? [String: Any]
        else { throw GrammarError.badGrammar }
        // Контракт движка: грамматика ищется по id, а Shiki регистрирует её по полю
        // `name`. Импортированные из .vsix держат витринное имя VS Code («Django HTML»)
        // → приводим `name` главной грамматики к id (как ThemeNormalizer для тем).
        // `scopeName` не трогаем — это TextMate-scope, не идентификатор языка.
        main["name"] = languageId
        if !embeddedLanguageIds.isEmpty { main["embeddedLangs"] = embeddedLanguageIds }

        var result: [[String: Any]] = [main]
        var seen = Set([main["name"] as? String ?? languageId])

        for embed in embeddedLanguageIds {
            for entry in grammarEntries(for: embed, siblings: siblingGrammars) {
                let name = entry["name"] as? String ?? ""
                if seen.insert(name).inserted { result.append(entry) }
            }
        }
        return try JSONSerialization.data(withJSONObject: result)
    }

    /// Грамматики вложенного языка: сначала из .vsix (один объект), иначе из
    /// встроенного <id>.json (он уже массив с транзитивными вложенными).
    private func grammarEntries(for id: String, siblings: [String: Data]) -> [[String: Any]] {
        if let raw = siblings[id],
           let obj = try? JSONSerialization.jsonObject(with: raw) as? [String: Any] {
            return [obj]
        }
        let url = bundledGrammarsDir.appendingPathComponent("\(id).json")
        guard let data = try? Data(contentsOf: url),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return [] }     // нет нигде → вложенный кусок без подсветки (осознанный край)
        return arr
    }
}
