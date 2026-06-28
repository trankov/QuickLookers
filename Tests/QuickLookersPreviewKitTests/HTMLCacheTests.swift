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
}
