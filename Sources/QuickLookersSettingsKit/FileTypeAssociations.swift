import Foundation

/// Таблица соответствий «расширение/имя файла → язык подсветки».
/// Данные приходят из сгенерированного датасета движка (associations.json);
/// SettingsKit не зависит от движка — URL передаёт вызывающая сторона.
public struct FileTypeAssociations: Equatable {
    /// Ключ — расширение в нижнем регистре без точки. Значение — id языка Shiki.
    public let byExtension: [String: String]
    /// Ключ — точное имя файла (Dockerfile, Makefile). Значение — id языка Shiki.
    public let byFilename: [String: String]

    public init(byExtension: [String: String], byFilename: [String: String]) {
        self.byExtension = byExtension
        self.byFilename = byFilename
    }

    public static let empty = FileTypeAssociations(byExtension: [:], byFilename: [:])

    /// Загружает датасет по URL, отдавая `.empty` на отсутствующем контейнере
    /// или битом файле — вызывающая сторона не должна падать из-за него.
    public static func loaded(from url: URL?) -> FileTypeAssociations {
        guard let url, let associations = try? FileTypeAssociations(contentsOf: url) else { return .empty }
        return associations
    }

    // DTO отделён от домена: во внешнем JSON — списки по языкам, внутри — обратные карты.
    private struct DTO: Decodable {
        struct Language: Decodable { let id: String; let extensions: [String]; let filenames: [String] }
        let version: Int
        let languages: [Language]
    }

    public init(contentsOf url: URL) throws {
        let dto = try JSONDecoder().decode(DTO.self, from: Data(contentsOf: url))
        var ext: [String: String] = [:]
        var file: [String: String] = [:]
        for lang in dto.languages {
            for e in lang.extensions { ext[e.lowercased()] = lang.id }
            for f in lang.filenames { file[f] = lang.id }
        }
        self.byExtension = ext
        self.byFilename = file
    }
}
