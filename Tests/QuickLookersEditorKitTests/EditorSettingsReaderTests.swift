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
}
