import XCTest
import QuickLookersSettingsKit
@testable import QuickLookers

/// Все тесты используют init(containerURL:) с временной директорией —
/// НЕ реальный App Group контейнер пользователя, чтобы прогон тестов не
/// портил настоящие настройки.
@MainActor
final class SettingsModelTests: XCTestCase {
    func test_init_withTempContainer_loadsDefaultSettingsAndNoWarning() throws {
        let model = SettingsModel(containerURL: try makeTempContainer())
        XCTAssertNil(model.warning)
        XCTAssertFalse(model.catalog.languages.isEmpty)
        XCTAssertFalse(model.catalog.themes.isEmpty)
    }

    func test_init_withNilContainer_setsWarningAndDefaultSettings() {
        let model = SettingsModel(containerURL: nil)
        XCTAssertNotNil(model.warning)
        XCTAssertEqual(model.settings, .default)
    }

    func test_reloadCatalog_afterInit_keepsCatalogPopulated() throws {
        let model = SettingsModel(containerURL: try makeTempContainer())
        let before = model.catalog.languages.count
        model.reloadCatalog()
        XCTAssertEqual(model.catalog.languages.count, before)
    }

    func test_setLanguageOn_off_then_on_toggleIsLanguageOn() throws {
        let model = SettingsModel(containerURL: try makeTempContainer())
        guard let lang = model.catalog.languages.first else {
            return XCTFail("ожидался непустой каталог языков")
        }
        XCTAssertTrue(model.isLanguageOn(lang.id))

        model.setLanguageOn(lang.id, false)
        XCTAssertFalse(model.isLanguageOn(lang.id))

        model.setLanguageOn(lang.id, true)
        XCTAssertTrue(model.isLanguageOn(lang.id))
    }

    @MainActor
    func testRuleToggleWritesDisabledExtension() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let model = SettingsModel(containerURL: dir)
        guard let row = model.previewRules.first(where: { $0.key == "swift" && !$0.isFilename }) else {
            return XCTFail("нет правила для .swift")
        }
        XCTAssertTrue(model.isRuleOn(row))
        model.setRuleOn(row, false)
        XCTAssertTrue(model.settings.disabledExtensions.contains("swift"))
        XCTAssertFalse(model.isRuleOn(row))
    }

    @MainActor
    func testSetRuleLanguageWritesOverride() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let model = SettingsModel(containerURL: dir)
        guard let row = model.previewRules.first(where: { $0.key == "json" && !$0.isFilename }) else {
            return XCTFail("нет правила для .json")
        }
        model.setRuleLanguage(row, "javascript")
        XCTAssertEqual(model.settings.extensionOverrides["json"], "javascript")
    }

    @MainActor
    func testAddExtensionRule() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let model = SettingsModel(containerURL: dir)
        model.addExtensionRule(ext: ".myext", languageId: "python")
        XCTAssertEqual(model.settings.extensionOverrides["myext"], "python")
        XCTAssertTrue(model.previewRules.contains { $0.key == "myext" && $0.languageId == "python" })
    }

    func test_update_persistsAcrossSubsequentReads() throws {
        let container = try makeTempContainer()
        let model = SettingsModel(containerURL: container)
        model.update { $0.activeThemeId = "light-plus" }
        XCTAssertEqual(model.settings.activeThemeId, "light-plus")

        // Перечитываем тем же контейнером — изменение должно было сохраниться на диск.
        let reloaded = SettingsModel(containerURL: container)
        XCTAssertEqual(reloaded.settings.activeThemeId, "light-plus")
    }

    func test_applyEditorResult_withThemeId_updatesThemeAndFont() throws {
        let model = SettingsModel(containerURL: try makeTempContainer())
        let font = FontSettings(family: "Menlo", size: 14)

        model.applyEditorResult(themeId: "dracula", font: font)

        XCTAssertEqual(model.settings.activeThemeId, "dracula")
        XCTAssertEqual(model.settings.font, font)
    }

    func test_applyEditorResult_withNilThemeId_keepsExistingThemeButAppliesFont() throws {
        let model = SettingsModel(containerURL: try makeTempContainer())
        let originalTheme = model.settings.activeThemeId
        let font = FontSettings(family: "Fira Code", size: 13)

        model.applyEditorResult(themeId: nil, font: font)

        XCTAssertEqual(model.settings.activeThemeId, originalTheme)
        XCTAssertEqual(model.settings.font, font)
    }
}

final class CatalogLookupTests: XCTestCase {
    func test_themeId_findsExactDisplayNameMatch() {
        let lookup = SettingsModel.CatalogLookup(themes: [
            ThemeInfo(id: "dark-plus", displayName: "Dark+ (default dark)", isDark: true),
            ThemeInfo(id: "light-plus", displayName: "Light+ (default light)", isDark: false)
        ])
        XCTAssertEqual(lookup.themeId(forDisplayName: "Dark+ (default dark)"), "dark-plus")
    }

    func test_themeId_returnsNilForUnknownName() {
        let lookup = SettingsModel.CatalogLookup(themes: [
            ThemeInfo(id: "dark-plus", displayName: "Dark+ (default dark)", isDark: true)
        ])
        XCTAssertNil(lookup.themeId(forDisplayName: "Nonexistent Theme"))
    }

    func test_themeId_isCaseSensitive() {
        let lookup = SettingsModel.CatalogLookup(themes: [
            ThemeInfo(id: "dark-plus", displayName: "Dark+ (default dark)", isDark: true)
        ])
        XCTAssertNil(lookup.themeId(forDisplayName: "dark+ (default dark)"))
    }
}
