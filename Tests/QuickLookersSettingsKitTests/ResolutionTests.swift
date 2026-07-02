import XCTest
import QuickLookersEngine
import QuickLookersSettingsKit

final class ResolutionTests: XCTestCase {
    private let assoc = FileTypeAssociations(
        byExtension: ["swift": "swift", "py": "python", "json": "json"],
        byFilename: ["Dockerfile": "docker"])

    // MARK: - Невод public.data: безрасширенные файлы (Dockerfile/Makefile) по имени

    func test_resolve_dockerfile_byName_highlightsDocker() throws {
        let assoc = FileTypeAssociations.loaded(from: QuickLookersEngineResources.associationsURL())
        let r = resolvePreview(fileName: "Dockerfile", pathExtension: "",
                               associations: assoc, settings: .default)
        XCTAssertEqual(r, .highlight(languageId: "docker"))
    }

    func test_resolve_unknownExtensionlessName_isNeutral() throws {
        let assoc = FileTypeAssociations.loaded(from: QuickLookersEngineResources.associationsURL())
        let r = resolvePreview(fileName: ".gitignore", pathExtension: "",
                               associations: assoc, settings: .default)
        XCTAssertEqual(r, .neutral)   // .gitignore нет в датасете → нейтральный текст, не бросок
    }

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

    // MARK: - Свободные (dyn.*) расширения: свой UTI com.quicklookers.source-code (механизм 1b)

    func test_resolve_freeExtensions_mapToLanguages() throws {
        let assoc = FileTypeAssociations.loaded(from: QuickLookersEngineResources.associationsURL())
        let cases: [(String, String)] = [("a.kt","kotlin"), ("a.kts","kotlin"),
                                          ("a.graphql","graphql"), ("a.gql","graphql"),
                                          ("a.dart","dart"), ("a.nim","nim"), ("a.zig","zig")]
        for (name, lang) in cases {
            let ext = (name as NSString).pathExtension
            XCTAssertEqual(resolvePreview(fileName: name, pathExtension: ext,
                                          associations: assoc, settings: .default),
                           .highlight(languageId: lang), "\(name)")
        }
    }
}
