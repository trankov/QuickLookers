import XCTest
import QuickLookersSettingsKit

final class SettingsStoreTests: XCTestCase {
    private func tempFile() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("ql-settings-\(UUID().uuidString).json")
    }

    func testLoadMissingFileReturnsDefault() {
        let store = SettingsStore(fileURL: tempFile())
        XCTAssertEqual(store.load(), .default)
    }

    func testSaveThenLoadRoundTrip() throws {
        let store = SettingsStore(fileURL: tempFile())
        var s = ManagerSettings.default
        s.disabledLanguageIds = ["javascript"]
        let saved = try store.save(s)
        let loaded = store.load()
        XCTAssertEqual(loaded.disabledLanguageIds, ["javascript"])
        XCTAssertEqual(loaded, saved)
    }

    func testSaveBumpsSettingsVersion() throws {
        let store = SettingsStore(fileURL: tempFile())
        let saved = try store.save(ManagerSettings.default) // version 0 -> 1
        XCTAssertEqual(saved.settingsVersion, 1)
        let saved2 = try store.save(saved) // 1 -> 2
        XCTAssertEqual(saved2.settingsVersion, 2)
    }

    func testCorruptFileReturnsDefault() throws {
        let url = tempFile()
        try "{ not json".write(to: url, atomically: true, encoding: .utf8)
        let store = SettingsStore(fileURL: url)
        XCTAssertEqual(store.load(), .default)
    }

    func testUnknownSchemaVersionReturnsDefault() throws {
        let url = tempFile()
        var s = ManagerSettings.default
        s.schemaVersion = 999
        try JSONEncoder().encode(s).write(to: url)
        let store = SettingsStore(fileURL: url)
        XCTAssertEqual(store.load(), .default)
    }

    func testResolvedThemePresentIdUsedAsIs() {
        let t = ThemeSelection(followSystem: true, lightThemeId: "light-plus",
                               darkThemeId: "dark-plus", fixedThemeId: "dark-plus")
        let id = resolvedThemeId(t, availableThemeIds: ["light-plus", "dark-plus"], appearanceIsDark: true)
        XCTAssertEqual(id, "dark-plus")
    }

    func testResolvedThemeMissingIdFallsBackByAppearance() {
        let t = ThemeSelection(followSystem: false, lightThemeId: "light-plus",
                               darkThemeId: "dark-plus", fixedThemeId: "monokai") // нет в каталоге
        let dark = resolvedThemeId(t, availableThemeIds: ["light-plus", "dark-plus"], appearanceIsDark: true)
        let light = resolvedThemeId(t, availableThemeIds: ["light-plus", "dark-plus"], appearanceIsDark: false)
        XCTAssertEqual(dark, "dark-plus")
        XCTAssertEqual(light, "light-plus")
    }
}
