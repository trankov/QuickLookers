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
    public let fontFamily: String?
    public let fontSize: Double?
    public let maxLines: Int
    public let bundleVersion: String
    /// Короткий стабильный хэш всех полей — имя файла записи в кэше.
    /// Считается один раз при создании ключа (на промахе кэша ключ используется
    /// дважды — в lookup и store).
    public let fileName: String

    public init(path: String, mtime: TimeInterval, size: Int,
                languageId: String, themeId: String,
                fontFamily: String? = nil, fontSize: Double? = nil,
                maxLines: Int, bundleVersion: String) {
        self.path = path
        self.mtime = mtime
        self.size = size
        self.languageId = languageId
        self.themeId = themeId
        self.fontFamily = fontFamily
        self.fontSize = fontSize
        self.maxLines = maxLines
        self.bundleVersion = bundleVersion
        let fontSizeStr = fontSize.map { String($0) } ?? "-"
        let raw = "\(path)|\(mtime)|\(size)|\(languageId)|\(themeId)|\(fontFamily ?? "-")|\(fontSizeStr)|\(maxLines)|\(bundleVersion)"
        let digest = SHA256.hash(data: Data(raw.utf8))
        self.fileName = digest.map { String(format: "%02x", $0) }.joined() + ".html"
    }
}

/// Файловый кэш готового HTML в заданной папке. Любая ошибка ввода-вывода
/// трактуется как промах/проглатывается — кэш не источник истины.
public struct HTMLCache {
    private let directory: URL
    private let maxBytes: Int

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
        try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: url.path)
        return html
    }

    /// Пишет HTML атомарно. Ошибка проглатывается (показ уже идёт).
    public func store(_ key: HTMLCacheKey, html: String) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(key.fileName)
        try? Data(html.utf8).write(to: url, options: .atomic)
    }

    /// Если суммарный размер кэша больше `maxBytes` — удаляет давно не
    /// использованные записи (по возрастанию mtime), пока не уложится.
    public func evictIfNeeded() {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]) else { return }

        var files: [(url: URL, size: Int, mtime: Date)] = []
        var total = 0
        for url in urls {
            let vals = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            let size = vals?.fileSize ?? 0
            let mtime = vals?.contentModificationDate ?? .distantPast
            files.append((url, size, mtime))
            total += size
        }
        guard total > maxBytes else { return }

        files.sort { $0.mtime < $1.mtime }   // давно использованные — первыми
        for f in files {
            if total <= maxBytes { break }
            if (try? FileManager.default.removeItem(at: f.url)) != nil {
                total -= f.size
            }
        }
    }
}
