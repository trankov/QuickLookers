import XCTest
@testable import QuickLookersEditorKit

final class EditorSettingsReaderTests: XCTestCase {
    private var appSupport: URL { Bundle.module.url(forResource: "Fixtures/AppSupport", withExtension: nil)! }
    private let code = DetectedEditor(appURL: URL(fileURLWithPath: "/x/Code.app"),
        nameShort: "Code", nameLong: "Visual Studio Code", dataFolderName: ".vscode")

    func testReadsThemeAndFont() {
        let p = EditorSettingsReader.read(editor: code, appSupportDir: appSupport)
        XCTAssertEqual(p.colorThemeLabel, "Seti Monokai: Original")
        XCTAssertEqual(p.fontFamily, "FiraCode Nerd Font, Menlo, monospace")
        XCTAssertEqual(p.fontSize, 13)
    }
    func testMissingEditorYieldsNils() {
        let ghost = DetectedEditor(appURL: URL(fileURLWithPath: "/x/Ghost.app"),
            nameShort: "Ghost", nameLong: "Ghost", dataFolderName: ".ghost")
        let p = EditorSettingsReader.read(editor: ghost, appSupportDir: appSupport)
        XCTAssertNil(p.colorThemeLabel); XCTAssertNil(p.fontFamily); XCTAssertNil(p.fontSize)
    }
    /// editor.fontSize в settings.json встречается как строка (опечатка пользователя
    /// или ручная правка) — as? Double не кастует, поле должно остаться nil, а не падать.
    func testWrongTypeFontSizeYieldsNilNotCrash() {
        let editor = DetectedEditor(appURL: URL(fileURLWithPath: "/x/WrongTypes.app"),
            nameShort: "WrongTypes", nameLong: "WrongTypes", dataFolderName: ".wrong")
        let p = EditorSettingsReader.read(editor: editor, appSupportDir: appSupport)
        XCTAssertEqual(p.colorThemeLabel, "Seti Monokai: Original")
        XCTAssertEqual(p.fontFamily, "Menlo, monospace")
        XCTAssertNil(p.fontSize)
    }
    func testColorThemeKeyAbsentYieldsNilThemeButKeepsOtherFields() {
        let editor = DetectedEditor(appURL: URL(fileURLWithPath: "/x/NoTheme.app"),
            nameShort: "NoTheme", nameLong: "NoTheme", dataFolderName: ".notheme")
        let p = EditorSettingsReader.read(editor: editor, appSupportDir: appSupport)
        XCTAssertNil(p.colorThemeLabel)
        XCTAssertEqual(p.fontFamily, "Menlo, monospace")
        XCTAssertEqual(p.fontSize, 14)
    }
    /// Папка названа по nameLong, а не nameShort — читалка должна откатиться на второй кандидат.
    func testFallsBackToNameLongWhenNameShortFolderMissing() {
        let editor = DetectedEditor(appURL: URL(fileURLWithPath: "/x/Fallback.app"),
            nameShort: "FallbackShortMissing", nameLong: "FallbackLong", dataFolderName: ".fallback")
        let p = EditorSettingsReader.read(editor: editor, appSupportDir: appSupport)
        XCTAssertEqual(p.colorThemeLabel, "Fallback Theme")
        XCTAssertEqual(p.fontSize, 15)
    }
}
