import XCTest
@testable import QuickLookersSettingsKit

final class ResolutionTests: XCTestCase {
    func testDeclaredLanguageByExtension() {
        XCTAssertEqual(DeclaredTypes.languageId(forPathExtension: "swift"), "swift")
        XCTAssertEqual(DeclaredTypes.languageId(forPathExtension: "JSON"), "json") // регистронезависимо
        XCTAssertEqual(DeclaredTypes.languageId(forPathExtension: "js"), "javascript")
        XCTAssertNil(DeclaredTypes.languageId(forPathExtension: "py"))
    }

    func testPreviewHappyPath() {
        let s = ManagerSettings.default
        XCTAssertEqual(previewLanguageId(forPathExtension: "swift", settings: s), "swift")
    }

    func testUnknownExtensionGivesNil() {
        XCTAssertNil(previewLanguageId(forPathExtension: "py", settings: .default))
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
}
