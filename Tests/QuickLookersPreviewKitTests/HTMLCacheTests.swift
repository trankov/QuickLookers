import XCTest
@testable import QuickLookersPreviewKit

final class HTMLCacheTests: XCTestCase {
    private func sampleKey(
        path: String = "/a/b.swift", mtime: TimeInterval = 100, size: Int = 10,
        languageId: String = "swift", themeId: String = "dark-plus",
        maxLines: Int = 2000, bundleVersion: String = "1"
    ) -> HTMLCacheKey {
        HTMLCacheKey(path: path, mtime: mtime, size: size, languageId: languageId,
                     themeId: themeId, maxLines: maxLines, bundleVersion: bundleVersion)
    }

    func test_fileNameChangesByFont() {
        func key(_ family: String?, _ size: Double?) -> HTMLCacheKey {
            HTMLCacheKey(path: "/a", mtime: 1, size: 2, languageId: "swift", themeId: "dark-plus",
                         fontFamily: family, fontSize: size, maxLines: 2000, bundleVersion: "1")
        }
        XCTAssertNotEqual(key("Menlo", 13).fileName, key("Menlo", 14).fileName)
        XCTAssertNotEqual(key("Menlo", 13).fileName, key("SF Mono", 13).fileName)
        XCTAssertEqual(key("Menlo", 13).fileName, key("Menlo", 13).fileName)
    }

    func test_fileNameStableForSameInputs() {
        XCTAssertEqual(sampleKey().fileName, sampleKey().fileName)
        XCTAssertTrue(sampleKey().fileName.hasSuffix(".html"))
    }

    func test_fileNameChangesPerField() {
        let base = sampleKey().fileName
        XCTAssertNotEqual(base, sampleKey(path: "/other").fileName)
        XCTAssertNotEqual(base, sampleKey(mtime: 200).fileName)
        XCTAssertNotEqual(base, sampleKey(size: 20).fileName)
        XCTAssertNotEqual(base, sampleKey(languageId: "json").fileName)
        XCTAssertNotEqual(base, sampleKey(themeId: "light-plus").fileName)
        XCTAssertNotEqual(base, sampleKey(maxLines: 1000).fileName)
        XCTAssertNotEqual(base, sampleKey(bundleVersion: "2").fileName)
    }

    private func makeTempDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ql-htmlcache-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func test_storeThenLookupReturnsSameHtml() throws {
        let dir = try makeTempDir()
        let cache = HTMLCache(directory: dir, maxBytes: 5 * 1024 * 1024)
        let key = sampleKey()
        cache.store(key, html: "<html>hi</html>")
        XCTAssertEqual(cache.lookup(key), "<html>hi</html>")
    }

    func test_storeOverwritesExistingKey() throws {
        let dir = try makeTempDir()
        let cache = HTMLCache(directory: dir, maxBytes: 5 * 1024 * 1024)
        let key = sampleKey()
        cache.store(key, html: "<html>first</html>")
        cache.store(key, html: "<html>second</html>")
        XCTAssertEqual(cache.lookup(key), "<html>second</html>", "повторная запись по тому же ключу перезаписывает содержимое")
    }

    func test_lookupMissOnEmptyDir() throws {
        let dir = try makeTempDir()
        let cache = HTMLCache(directory: dir, maxBytes: 5 * 1024 * 1024)
        XCTAssertNil(cache.lookup(sampleKey()))
    }

    func test_corruptEntryIsMiss() throws {
        let dir = try makeTempDir()
        let cache = HTMLCache(directory: dir, maxBytes: 5 * 1024 * 1024)
        let key = sampleKey()
        // Невалидный UTF-8 в файле записи → lookup должен дать nil, не упасть.
        try Data([0xFF, 0xFE]).write(to: dir.appendingPathComponent(key.fileName))
        XCTAssertNil(cache.lookup(key))
    }

    func test_evictKeepsUnderCapAndDropsOldest() throws {
        let dir = try makeTempDir()
        // Потолок мал: вмещает примерно одну запись по 1000 байт.
        let cache = HTMLCache(directory: dir, maxBytes: 1500)
        let oldKey = sampleKey(path: "/old.swift")
        let newKey = sampleKey(path: "/new.swift")
        let html = String(repeating: "x", count: 1000)

        cache.store(oldKey, html: html)
        // Старую запись помечаем давно использованной.
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 1)],
            ofItemAtPath: dir.appendingPathComponent(oldKey.fileName).path)
        cache.store(newKey, html: html)   // свежая отметка — сейчас

        cache.evictIfNeeded()

        XCTAssertNil(cache.lookup(oldKey), "давняя запись вытеснена")
        XCTAssertNotNil(cache.lookup(newKey), "свежая запись осталась")
    }

    func test_evictNoopWhenUnderCap() throws {
        let dir = try makeTempDir()
        let cache = HTMLCache(directory: dir, maxBytes: 5 * 1024 * 1024)
        let key = sampleKey()
        cache.store(key, html: "small")
        cache.evictIfNeeded()
        XCTAssertNotNil(cache.lookup(key), "под потолком ничего не удаляется")
    }
}
