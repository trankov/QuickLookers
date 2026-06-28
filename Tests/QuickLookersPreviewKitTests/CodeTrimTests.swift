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
}
