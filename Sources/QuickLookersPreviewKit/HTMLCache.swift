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
