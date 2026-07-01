import XCTest
import QuickLookersSettingsKit

final class ResolutionTests: XCTestCase {
    private let assoc = FileTypeAssociations(
        byExtension: ["swift": "swift", "py": "python", "json": "json"],
        byFilename: ["Dockerfile": "docker"])

    func testHighlightByExtension() {
        XCTAssertEqual(
            resolvePreview(fileName: "a.swift", pathExtension: "swift", associations: assoc, settings: .default),
            .highlight(languageId: "swift"))
    }

    func testExtensionCaseInsensitive() {
        XCTAssertEqual(
            resolvePreview(fileName: "A.SWIFT", pathExtension: "SWIFT", associations: assoc, settings: .default),
            .highlight(languageId: "swift"))
    }

    func testHighlightByFilename() {
        XCTAssertEqual(
            resolvePreview(fileName: "Dockerfile", pathExtension: "", associations: assoc, settings: .default),
            .highlight(languageId: "docker"))
    }

    func testUnknownExtensionIsNeutral() {
        XCTAssertEqual(
            resolvePreview(fileName: "a.docx", pathExtension: "docx", associations: assoc, settings: .default),
            .neutral)
    }

    func testDisabledExtensionIsNeutral() {
        var s = ManagerSettings.default
        s.disabledExtensions = ["json"]
        XCTAssertEqual(
            resolvePreview(fileName: "a.json", pathExtension: "json", associations: assoc, settings: s),
            .neutral)
    }

    func testDisabledFilenameIsNeutral() {
        var s = ManagerSettings.default
        s.disabledFilenames = ["Dockerfile"]
        XCTAssertEqual(
            resolvePreview(fileName: "Dockerfile", pathExtension: "", associations: assoc, settings: s),
            .neutral)
    }

    func testDisabledLanguageLayer1IsNeutral() {
        var s = ManagerSettings.default
        s.disabledLanguageIds = ["swift"]
        XCTAssertEqual(
            resolvePreview(fileName: "a.swift", pathExtension: "swift", associations: assoc, settings: s),
            .neutral)
    }

    func testExtensionOverrideWins() {
        var s = ManagerSettings.default
        s.extensionOverrides = ["json": "javascript"]
        XCTAssertEqual(
            resolvePreview(fileName: "a.json", pathExtension: "json", associations: assoc, settings: s),
            .highlight(languageId: "javascript"))
    }

    func testFilenameRuleWinsOverExtension() {
        // Файл с именем из карты имён и одновременно расширением — имя приоритетнее.
        let a = FileTypeAssociations(byExtension: ["txt": "plaintext"],
                                     byFilename: ["CMakeLists.txt": "cmake"])
        XCTAssertEqual(
            resolvePreview(fileName: "CMakeLists.txt", pathExtension: "txt", associations: a, settings: .default),
            .highlight(languageId: "cmake"))
    }

    func testAddedExtensionRuleForUnknown() {
        var s = ManagerSettings.default
        s.extensionOverrides = ["myext": "python"]
        XCTAssertEqual(
            resolvePreview(fileName: "a.myext", pathExtension: "myext", associations: assoc, settings: s),
            .highlight(languageId: "python"))
    }

    func testEmptyExtensionNoFilenameIsNeutral() {
        XCTAssertEqual(
            resolvePreview(fileName: "README", pathExtension: "", associations: assoc, settings: .default),
            .neutral)
    }

    func testIsLanguageEnabled() {
        var s = ManagerSettings.default
        s.disabledLanguageIds = ["json"]
        XCTAssertFalse(isLanguageEnabled("json", settings: s))
        XCTAssertTrue(isLanguageEnabled("swift", settings: s))
    }
}
