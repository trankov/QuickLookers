import XCTest
import Foundation
import QuickLookersEngine

final class EngineResourcesTests: XCTestCase {
    func testGrammarsDirectoryContainsSwift() throws {
        let dir = try QuickLookersEngineResources.grammarsDirectory()
        let swift = dir.appendingPathComponent("swift.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: swift.path))
    }

    func testThemesDirectoryContainsDarkPlus() throws {
        let dir = try QuickLookersEngineResources.themesDirectory()
        let dark = dir.appendingPathComponent("dark-plus.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: dark.path))
    }

    func testCatalogSidecarURLsPointToExistingCatalogJSON() throws {
        let urls = QuickLookersEngineResources.catalogSidecarURLs()
        XCTAssertFalse(urls.isEmpty, "ожидали хотя бы собранный сайдкар-каталог пакета")
        for url in urls {
            XCTAssertEqual(url.lastPathComponent, "catalog.json")
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "сайдкар не существует: \(url)")
        }
    }

    func testAssociationsURLResolvesAndDecodes() throws {
        let url = try XCTUnwrap(QuickLookersEngineResources.associationsURL())
        let data = try Data(contentsOf: url)
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(obj?["version"] as? Int, 1)
        XCTAssertNotNil(obj?["languages"])
    }
}
