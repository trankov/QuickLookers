import XCTest
import QuickLookersEngine
import QuickLookersSettingsKit

final class ResolutionTests: XCTestCase {
    private let assoc = FileTypeAssociations(
        byExtension: ["swift": "swift", "py": "python", "json": "json"],
        byFilename: ["Dockerfile": "docker"])

    // Боевой датасет парсим один раз на весь класс (а не заново в каждом тесте).
    private static let datasetAssoc =
        FileTypeAssociations.loaded(from: QuickLookersEngineResources.associationsURL())

    // MARK: - Невод public.data: безрасширенные файлы (Dockerfile/Makefile) по имени

    func test_resolve_dockerfile_byName_highlightsDocker() throws {
        let assoc = Self.datasetAssoc
        let r = resolvePreview(fileName: "Dockerfile", pathExtension: "",
                               associations: assoc, settings: .default)
        XCTAssertEqual(r, .highlight(languageId: "docker"))
    }

    func test_resolve_unknownExtensionlessName_isNeutral() throws {
        let assoc = Self.datasetAssoc
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
        s.previewRules = [PreviewRule(pattern: "*.json", action: .neutral)]
        XCTAssertEqual(
            resolvePreview(fileName: "a.json", pathExtension: "json", associations: assoc, settings: s),
            .neutral)
    }

    func testDisabledFilenameIsNeutral() {
        var s = ManagerSettings.default
        s.previewRules = [PreviewRule(pattern: "Dockerfile", action: .neutral)]
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
        s.previewRules = [PreviewRule(pattern: "*.json", action: .assign(languageId: "javascript"))]
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
        s.previewRules = [PreviewRule(pattern: "*.myext", action: .assign(languageId: "python"))]
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
        let assoc = Self.datasetAssoc
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

    // MARK: - Системные UTI, объявленные для «чужетипных» расширений (механизм 1a)

    func test_resolve_1a_extensions_mapToLanguages() throws {
        let assoc = Self.datasetAssoc
        let cases: [(String, String)] = [("app.ts","typescript"), ("model.r","r"),
                                          ("u.pas","pascal"), ("page.html","html"),
                                          ("a.m","objective-c"), ("s.f90","fortran-free-form"),
                                          ("v.proto","proto")]
        for (name, lang) in cases {
            let ext = (name as NSString).pathExtension
            XCTAssertEqual(resolvePreview(fileName: name, pathExtension: ext,
                                          associations: assoc, settings: .default),
                           .highlight(languageId: lang), "\(name)")
        }
    }

    // Живая проверка вскрыла пробелы: Makefile (лист public.make-source, по имени) и
    // .ini (лист com.microsoft.ini, по расширению) — оба добавлены в 1a-невод.
    func test_resolve_makefile_and_ini() throws {
        let assoc = Self.datasetAssoc
        XCTAssertEqual(resolvePreview(fileName: "Makefile", pathExtension: "",
                                      associations: assoc, settings: .default),
                       .highlight(languageId: "make"))
        XCTAssertEqual(resolvePreview(fileName: "app.ini", pathExtension: "ini",
                                      associations: assoc, settings: .default),
                       .highlight(languageId: "ini"))
    }

    // MARK: - Правила пользователя (Task 3): специфичность, маска, тумблер

    func test_userRule_beatsDataset() {
        var s = ManagerSettings.default
        s.previewRules = [PreviewRule(pattern: "*.swift", action: .assign(languageId: "javascript"))]
        XCTAssertEqual(
            resolvePreview(fileName: "a.swift", pathExtension: "swift", associations: assoc, settings: s),
            .highlight(languageId: "javascript"))
    }

    func test_moreSpecificRuleWins() {
        var s = ManagerSettings.default
        s.previewRules = [
            PreviewRule(pattern: "*.js", action: .assign(languageId: "javascript")),
            PreviewRule(pattern: "*.config.js", action: .assign(languageId: "json"))
        ]
        XCTAssertEqual(
            resolvePreview(fileName: "webpack.config.js", pathExtension: "js", associations: assoc, settings: s),
            .highlight(languageId: "json"))
    }

    func test_disabledRule_isIgnored_fallsToDataset() {
        var s = ManagerSettings.default
        s.previewRules = [PreviewRule(pattern: "*.swift", action: .assign(languageId: "javascript"), isEnabled: false)]
        XCTAssertEqual(
            resolvePreview(fileName: "a.swift", pathExtension: "swift", associations: assoc, settings: s),
            .highlight(languageId: "swift"))   // правило выключено → датасет
    }

    func test_ruleAssignsDisabledLayer1Language_isNeutral() {
        var s = ManagerSettings.default
        s.disabledLanguageIds = ["javascript"]
        s.previewRules = [PreviewRule(pattern: "*.swift", action: .assign(languageId: "javascript"))]
        XCTAssertEqual(
            resolvePreview(fileName: "a.swift", pathExtension: "swift", associations: assoc, settings: s),
            .neutral)
    }

    func test_prefixMask_matchesCompoundFilename() {
        var s = ManagerSettings.default
        s.previewRules = [PreviewRule(pattern: "Dockerfile.*", action: .assign(languageId: "docker"))]
        XCTAssertEqual(
            resolvePreview(fileName: "Dockerfile.dev", pathExtension: "dev", associations: assoc, settings: s),
            .highlight(languageId: "docker"))
    }
}
