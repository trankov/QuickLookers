import XCTest
@testable import QuickLookersPreviewKit

final class CodeTrimTests: XCTestCase {
    func test_keepsWhenWithinLimit() {
        let r = trimToFirstLines("a\nb", max: 2)
        XCTAssertEqual(r.code, "a\nb")
        XCTAssertFalse(r.truncated)
    }

    func test_trimsWhenOverLimit() {
        let r = trimToFirstLines("a\nb\nc", max: 2)
        XCTAssertEqual(r.code, "a\nb")
        XCTAssertTrue(r.truncated)
    }

    func test_emptyInput() {
        let r = trimToFirstLines("", max: 2)
        XCTAssertEqual(r.code, "")
        XCTAssertFalse(r.truncated)
    }

    func test_singleLine() {
        let r = trimToFirstLines("a", max: 2)
        XCTAssertEqual(r.code, "a")
        XCTAssertFalse(r.truncated)
    }

    func test_trailingNewlineAtExactLimitIsNotFalselyTruncated() {
        // Большинство текстовых файлов оканчиваются на "\n" — это не лишняя
        // строка, а просто завершение последней. Файл с ровно `max` строками
        // содержимого и финальным "\n" не должен помечаться как обрезанный.
        let r = trimToFirstLines("a\nb\n", max: 2)
        XCTAssertFalse(r.truncated, "финальный перевод строки не считается лишней строкой")
    }

    func test_trailingNewlineOneLineOverLimitIsTruncated() {
        let r = trimToFirstLines("a\nb\nc\n", max: 2)
        XCTAssertTrue(r.truncated)
        XCTAssertEqual(r.code, "a\nb")
    }

    func test_veryLongSingleLineWithinLimitIsUnchanged() {
        let longLine = String(repeating: "x", count: 50_000)
        let r = trimToFirstLines(longLine, max: 2000)
        XCTAssertEqual(r.code, longLine)
        XCTAssertFalse(r.truncated)
    }

    private func writeTemp(_ data: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ql-trim-\(UUID().uuidString)")
        try data.write(to: url)
        return url
    }

    func test_readsWholeSmallFile() throws {
        let url = try writeTemp(Data("hello".utf8))
        let s = try readBoundedPrefix(of: url, maxBytes: 1024)
        XCTAssertEqual(s, "hello")
    }

    func test_readsBoundedPrefixOfLargeFile() throws {
        let url = try writeTemp(Data(String(repeating: "a", count: 10_000).utf8))
        let s = try readBoundedPrefix(of: url, maxBytes: 100)
        XCTAssertLessThanOrEqual(s.utf8.count, 100)
        XCTAssertEqual(s, String(repeating: "a", count: 100))
    }

    func test_doesNotCrashOnMultibyteBoundary() throws {
        // "я" = 2 байта в UTF-8; лимит в 5 байт разрежет на середине символа.
        let url = try writeTemp(Data(String(repeating: "я", count: 10).utf8))
        let s = try readBoundedPrefix(of: url, maxBytes: 5)
        XCTAssertLessThanOrEqual(s.utf8.count, 5)
        XCTAssertTrue(s.allSatisfy { $0 == "я" }, "не должно быть мусорных символов")
    }

    func test_throwsOnUndecodableData() throws {
        // Непустые не-UTF-8 байты → ошибка (откат к системному превью), не пустая строка.
        let url = try writeTemp(Data([0xFF, 0xFF, 0xFF, 0xFF]))
        XCTAssertThrowsError(try readBoundedPrefix(of: url, maxBytes: 1024))
    }

    func test_emptyFileStillReturnsEmptyString() throws {
        let url = try writeTemp(Data())
        XCTAssertEqual(try readBoundedPrefix(of: url, maxBytes: 1024), "")
    }

    func test_fileExactlyAtMaxBytesReadsWholeFileNoCrash() throws {
        let url = try writeTemp(Data(String(repeating: "a", count: 100).utf8))
        let s = try readBoundedPrefix(of: url, maxBytes: 100)
        XCTAssertEqual(s, String(repeating: "a", count: 100))
    }

    func test_missingFileThrows() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ql-trim-missing-\(UUID().uuidString)")
        XCTAssertThrowsError(try readBoundedPrefix(of: url, maxBytes: 1024))
    }
}
