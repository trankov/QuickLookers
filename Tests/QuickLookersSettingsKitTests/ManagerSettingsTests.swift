import XCTest
import QuickLookersSettingsKit

final class ManagerSettingsTests: XCTestCase {
    func testDefaults() {
        let s = ManagerSettings.default
        XCTAssertTrue(s.disabledLanguageIds.isEmpty)
        XCTAssertTrue(s.previewDisabledLanguageIds.isEmpty)
        XCTAssertEqual(s.activeThemeId, DefaultThemeIds.dark)
        XCTAssertNil(s.font.family)
        XCTAssertNil(s.font.size)
        XCTAssertEqual(s.schemaVersion, ManagerSettings.currentSchemaVersion)
        XCTAssertEqual(s.settingsVersion, 0)
    }

    func testCodableRoundTrip() throws {
        var s = ManagerSettings.default
        s.disabledLanguageIds = ["javascript"]
        s.previewDisabledLanguageIds = ["json"]
        s.activeThemeId = "github-dark"
        s.font = FontSettings(family: "JetBrains Mono", size: 13)
        s.settingsVersion = 7
        let data = try JSONEncoder().encode(s)
        let back = try JSONDecoder().decode(ManagerSettings.self, from: data)
        XCTAssertEqual(s, back)
    }
}
