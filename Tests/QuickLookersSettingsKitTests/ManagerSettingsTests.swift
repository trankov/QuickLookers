import XCTest
import QuickLookersSettingsKit

final class ManagerSettingsTests: XCTestCase {
    func testDefaultHasEmptyDisabledSetsAndFollowSystem() {
        let s = ManagerSettings.default
        XCTAssertTrue(s.disabledLanguageIds.isEmpty)
        XCTAssertTrue(s.previewDisabledLanguageIds.isEmpty)
        XCTAssertTrue(s.theme.followSystem)
        XCTAssertEqual(s.schemaVersion, ManagerSettings.currentSchemaVersion)
        XCTAssertEqual(s.settingsVersion, 0)
    }

    func testCodableRoundTrip() throws {
        var s = ManagerSettings.default
        s.disabledLanguageIds = ["javascript"]
        s.previewDisabledLanguageIds = ["json"]
        s.settingsVersion = 7
        let data = try JSONEncoder().encode(s)
        let back = try JSONDecoder().decode(ManagerSettings.self, from: data)
        XCTAssertEqual(s, back)
    }

    func testResolvedThemeFollowSystem() {
        let t = ThemeSelection(followSystem: true, lightThemeId: "light-plus",
                               darkThemeId: "dark-plus", fixedThemeId: "dark-plus")
        XCTAssertEqual(t.resolvedThemeId(appearanceIsDark: true), "dark-plus")
        XCTAssertEqual(t.resolvedThemeId(appearanceIsDark: false), "light-plus")
    }

    func testResolvedThemeFixedWhenNotFollowing() {
        let t = ThemeSelection(followSystem: false, lightThemeId: "light-plus",
                               darkThemeId: "dark-plus", fixedThemeId: "light-plus")
        XCTAssertEqual(t.resolvedThemeId(appearanceIsDark: true), "light-plus")
        XCTAssertEqual(t.resolvedThemeId(appearanceIsDark: false), "light-plus")
    }
}
