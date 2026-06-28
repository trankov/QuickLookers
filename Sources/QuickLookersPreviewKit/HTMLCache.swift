import Foundation
import CryptoKit

/// Ключ записи кэша. Все поля влияют на готовый HTML; имя файла — их хэш.
/// Поля считаются дёшево из атрибутов файла, без чтения содержимого.
public struct HTMLCacheKey: Equatable {
    public let path: String
    public let mtime: TimeInterval
    public let size: Int
    public let languageId: String
    public let themeId: String
    public let maxLines: Int
    public let bundleVersion: String

    public init(path: String, mtime: TimeInterval, size: Int,
                languageId: String, themeId: String, maxLines: Int, bundleVersion: String) {
        self.path = path
        self.mtime = mtime
        self.size = size
        self.languageId = languageId
        self.themeId = themeId
        self.maxLines = maxLines
        self.bundleVersion = bundleVersion
    }

    /// Короткий стабильный хэш всех полей — имя файла записи в кэше.
    public var fileName: String {
        let raw = "\(path)|\(mtime)|\(size)|\(languageId)|\(themeId)|\(maxLines)|\(bundleVersion)"
        let digest = SHA256.hash(data: Data(raw.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return hex + ".html"
    }
}

/// Файловый кэш готового HTML в заданной папке. Любая ошибка ввода-вывода
/// трактуется как промах/проглатывается — кэш не источник истины.
public struct HTMLCache {
    private let directory: URL
    private let maxBytes: Int
    private let fm = FileManager.default

    public init(directory: URL, maxBytes: Int) {
        self.directory = directory
        self.maxBytes = maxBytes
    }

    /// HTML записи или nil (нет файла / не читается / не UTF-8).
    /// При попадании обновляет отметку использования (mtime файла) для LRU.
    public func lookup(_ key: HTMLCacheKey) -> String? {
        let url = directory.appendingPathComponent(key.fileName)
        guard let data = try? Data(contentsOf: url),
              let html = String(data: data, encoding: .utf8) else { return nil }
        try? fm.setAttributes([.modificationDate: Date()], ofItemAtPath: url.path)
        return html
    }

    /// Пишет HTML атомарно. Ошибка проглатывается (показ уже идёт).
    public func store(_ key: HTMLCacheKey, html: String) {
        try? fm.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(key.fileName)
        try? Data(html.utf8).write(to: url, options: .atomic)
    }
}
