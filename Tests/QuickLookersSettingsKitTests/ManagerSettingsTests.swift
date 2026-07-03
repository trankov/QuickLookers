import XCTest
import QuickLookersSettingsKit

final class ManagerSettingsTests: XCTestCase {
    func testDefaults() {
        let s = ManagerSettings.default
        XCTAssertTrue(s.disabledLanguageIds.isEmpty)
        XCTAssertEqual(s.activeThemeId, DefaultThemeIds.dark)
        XCTAssertNil(s.font.family)
        XCTAssertNil(s.font.size)
        XCTAssertEqual(s.schemaVersion, ManagerSettings.currentSchemaVersion)
        XCTAssertEqual(s.settingsVersion, 0)
    }

    func testCodableRoundTrip() throws {
        var s = ManagerSettings.default
        s.disabledLanguageIds = ["javascript"]
        s.activeThemeId = "github-dark"
        s.font = FontSettings(family: "JetBrains Mono", size: 13)
        s.settingsVersion = 7
        let data = try JSONEncoder().encode(s)
        let back = try JSONDecoder().decode(ManagerSettings.self, from: data)
        XCTAssertEqual(s, back)
    }

    func testClampSizeAtBoundaries() {
        XCTAssertEqual(FontSettings.clampSize(6), 6)
        XCTAssertEqual(FontSettings.clampSize(48), 48)
    }

    func testClampSizeOutsideBoundaries() {
        XCTAssertEqual(FontSettings.clampSize(5.999), 6)
        XCTAssertEqual(FontSettings.clampSize(48.001), 48)
        XCTAssertEqual(FontSettings.clampSize(-1000), 6)
        XCTAssertEqual(FontSettings.clampSize(1_000_000), 48)
    }

    func testClampSizeNilStaysNil() {
        XCTAssertNil(FontSettings.clampSize(nil))
    }

    func testClampSizeNaNPassesThroughUnclamped() {
        // Документируем реальное поведение min/max со стандартной библиотекой:
        // сравнения с NaN всегда false, поэтому NaN проходит зажим не тронутым.
        // На практике это безопасно: оба источника значения (NSFont.pointSize
        // и числа из JSON/JSONC) физически не производят NaN.
        XCTAssertTrue(FontSettings.clampSize(Double.nan)?.isNaN ?? false)
    }

    func testDefaultHasEmptyRules() {
        let s = ManagerSettings.default
        XCTAssertEqual(s.schemaVersion, 3)
        XCTAssertTrue(s.previewRules.isEmpty)
    }

    func testRoundTripEncodesPreviewRules() throws {
        var s = ManagerSettings.default
        s.previewRules = [
            PreviewRule(pattern: "*.djhtml", action: .assign(languageId: "django-html")),
            PreviewRule(pattern: "*.log", action: .neutral, isEnabled: false)
        ]
        let back = try JSONDecoder().decode(ManagerSettings.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(back.previewRules, s.previewRules)
    }
}
