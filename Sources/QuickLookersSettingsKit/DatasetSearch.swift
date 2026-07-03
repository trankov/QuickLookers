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
/// отсортированных по id — никакого полного обхода/материализации тысяч строк.
/// Пустой запрос → пусто (вкладка показывает только правила пользователя).
public func searchDataset(query: String, limit: Int, associations: FileTypeAssociations,
                          languageName: (String) -> String?) -> [DatasetMatch] {
    let q = query.lowercased()
    guard !q.isEmpty else { return [] }

    func hit(key: String, lang: String) -> Bool {
        key.lowercased().contains(q) || (languageName(lang)?.lowercased().contains(q) ?? false)
    }

    var out: [DatasetMatch] = []
    for (ext, lang) in associations.byExtension where hit(key: ext, lang: lang) {
        out.append(DatasetMatch(key: .ext(ext), languageId: lang))
    }
    for (file, lang) in associations.byFilename where hit(key: file, lang: lang) {
        out.append(DatasetMatch(key: .filename(file), languageId: lang))
    }
    out.sort { $0.id < $1.id }
    return Array(out.prefix(limit))
}
