import XCTest
import QuickLookersSettingsKit

final class ResolutionTests: XCTestCase {
    func testDeclaredLanguageByExtension() {
        XCTAssertEqual(DeclaredTypes.languageId(forPathExtension: "swift"), "swift")
        XCTAssertEqual(DeclaredTypes.languageId(forPathExtension: "JSON"), "json") // регистронезависимо
        XCTAssertEqual(DeclaredTypes.languageId(forPathExtension: "js"), "javascript")
        XCTAssertNil(DeclaredTypes.languageId(forPathExtension: "docx"))
    }

    func testPreviewHappyPath() {
        let s = ManagerSettings.default
        XCTAssertEqual(previewLanguageId(forPathExtension: "swift", settings: s), "swift")
    }

    func testUnknownExtensionGivesNil() {
        XCTAssertNil(previewLanguageId(forPathExtension: "docx", settings: .default))
    }

    func test_previewLanguageForExpandedExtensions() {
        let s = ManagerSettings.default
        XCTAssertEqual(previewLanguageId(forPathExtension: "py", settings: s), "python")
        XCTAssertEqual(previewLanguageId(forPathExtension: "rs", settings: s), "rust")
        XCTAssertEqual(previewLanguageId(forPathExtension: "yml", settings: s), "yaml")
        XCTAssertEqual(previewLanguageId(forPathExtension: "tsx", settings: s), "tsx")
    }

    func testDisabledLanguageGivesNil() {
        var s = ManagerSettings.default
        s.disabledLanguageIds = ["json"]
        XCTAssertNil(previewLanguageId(forPathExtension: "json", settings: s))
    }

    func testPreviewDisabledLanguageGivesNil() {
        var s = ManagerSettings.default
        s.previewDisabledLanguageIds = ["json"]
        XCTAssertNil(previewLanguageId(forPathExtension: "json", settings: s))
        // но красить (Слой 1) язык по-прежнему можно
        XCTAssertTrue(isLanguageEnabled("json", settings: s))
    }

    func testDisabledLanguageAlsoDisablesPreview() {
        var s = ManagerSettings.default
        s.disabledLanguageIds = ["swift"]
        XCTAssertFalse(isPreviewEnabled("swift", settings: s))
    }

    func testUnknownDisabledIdIsHarmless() {
        var s = ManagerSettings.default
        s.disabledLanguageIds = ["ruby"] // нет в каталоге
        XCTAssertTrue(isLanguageEnabled("swift", settings: s))
    }

    func testEmptyExtensionGivesNil() {
        XCTAssertNil(DeclaredTypes.languageId(forPathExtension: ""))
        XCTAssertNil(previewLanguageId(forPathExtension: "", settings: .default))
    }

    func testBothDisabledFlagsSetForSameId() {
        // Реалистично избыточная, но возможная комбинация настроек: язык одновременно
        // в disabledLanguageIds и в previewDisabledLanguageIds. Поведение должно
        // остаться тем же, что и при одном только disabledLanguageIds.
        var s = ManagerSettings.default
        s.disabledLanguageIds = ["json"]
        s.previewDisabledLanguageIds = ["json"]
        XCTAssertFalse(isLanguageEnabled("json", settings: s))
        XCTAssertFalse(isPreviewEnabled("json", settings: s))
        XCTAssertNil(previewLanguageId(forPathExtension: "json", settings: s))
    }
}
