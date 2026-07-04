import Foundation

/// Совпадение из датасета для показа во вкладке (секция «По умолчанию»).
public struct DatasetMatch: Equatable, Identifiable {
    public enum Key: Equatable { case ext(String); case filename(String) }
    public let id: String          // "ext:js" / "file:Dockerfile"
    public let key: Key
    public let languageId: String

    public init(key: Key, languageId: String) {
        self.key = key
        self.languageId = languageId
        switch key {
        case .ext(let e):      self.id = "ext:\(e)"
        case .filename(let f): self.id = "file:\(f)"
        }
    }
}

/// Ищет в датасете совпадения по подстроке в ключе (расширение/имя файла) или в
/// имени языка. Фильтрует словари и строит строки ТОЛЬКО для попаданий (до `limit`),
/// РАНЖИРУЯ по релевантности: точное совпадение ключа впереди подстрочного, а оба —
/// впереди совпадения лишь по имени языка (id — стабильный тай-брейк). Так «json»
/// показывает сам `.json`, а не хоронит его под алфавитом расширений с тем же языком.
/// Пустой запрос → пусто (вкладка показывает только правила пользователя).
public func searchDataset(query: String, limit: Int, associations: FileTypeAssociations,
                          languageName: (String) -> String?) -> [DatasetMatch] {
    let q = query.lowercased()
    guard !q.isEmpty else { return [] }

    // Ранг релевантности: точное совпадение ключа (0) < ключ содержит запрос (1) <
    // только имя языка (2). Так поиск «json» показывает сам `.json` первым, а не
    // хоронит его под алфавитом расширений, чьё ИМЯ ЯЗЫКА содержит «json».
    func rank(key: String, lang: String) -> Int? {
        let k = key.lowercased()
        if k == q { return 0 }
        if k.contains(q) { return 1 }
        if languageName(lang)?.lowercased().contains(q) == true { return 2 }
        return nil
    }

    var scored: [(rank: Int, match: DatasetMatch)] = []
    for (ext, lang) in associations.byExtension {
        if let r = rank(key: ext, lang: lang) { scored.append((r, DatasetMatch(key: .ext(ext), languageId: lang))) }
    }
    for (file, lang) in associations.byFilename {
        if let r = rank(key: file, lang: lang) { scored.append((r, DatasetMatch(key: .filename(file), languageId: lang))) }
    }
    scored.sort { $0.rank != $1.rank ? $0.rank < $1.rank : $0.match.id < $1.match.id }
    return Array(scored.prefix(limit).map(\.match))
}
