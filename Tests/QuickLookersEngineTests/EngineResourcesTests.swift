import XCTest
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
}
