import XCTest
import QuickLookersSettingsKit
import QuickLookersEngine

final class CatalogSourceTests: XCTestCase {
    private func makeTempDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ql-catalog-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Каталог из реальных ресурсов пакета (общий для интеграционных тестов).
    private func realCatalog() throws -> Catalog {
        try FileCatalogSource(
            grammarsDirectory: QuickLookersEngineResources.grammarsDirectory(),
            themesDirectory: QuickLookersEngineResources.themesDirectory()).loadCatalog()
    }

    func testReadsLanguagesAndThemesWithMetadata() throws {
        let grammars = try makeTempDir()
        let themes = try makeTempDir()
        try #"[{"name":"swift","displayName":"Swift","scopeName":"source.swift"}]"#
            .write(to: grammars.appendingPathComponent("swift.json"), atomically: true, encoding: .utf8)
        try #"{"name":"dark-plus","displayName":"Dark Plus","type":"dark"}"#
            .write(to: themes.appendingPathComponent("dark-plus.json"), atomically: true, encoding: .utf8)
        try #"{"name":"light-plus","displayName":"Light Plus","type":"light"}"#
            .write(to: themes.appendingPathComponent("light-plus.json"), atomically: true, encoding: .utf8)

        let source = FileCatalogSource(grammarsDirectory: grammars, themesDirectory: themes)
        let catalog = try source.loadCatalog()

        XCTAssertEqual(catalog.languages, [LanguageInfo(id: "swift", displayName: "Swift")])
        XCTAssertEqual(catalog.themes, [
            ThemeInfo(id: "dark-plus", displayName: "Dark Plus", isDark: true),
            ThemeInfo(id: "light-plus", displayName: "Light Plus", isDark: false),
        ])
    }

    func testDisplayNameFallsBackToName() throws {
        let grammars = try makeTempDir()
        let themes = try makeTempDir()
        try #"[{"name":"json"}]"#
            .write(to: grammars.appendingPathComponent("json.json"), atomically: true, encoding: .utf8)
        let source = FileCatalogSource(grammarsDirectory: grammars, themesDirectory: themes)
        let catalog = try source.loadCatalog()
        XCTAssertEqual(catalog.languages, [LanguageInfo(id: "json", displayName: "json")])
    }

    func test_grammarDisplayNameFromArrayEntry() throws {
        let catalog = try realCatalog()
        let js = try XCTUnwrap(catalog.languages.first { $0.id == "javascript" })
        XCTAssertEqual(js.displayName, "JavaScript")
    }

    func test_catalogLoadsFullLibrary() throws {
        let catalog = try realCatalog()
        XCTAssertGreaterThan(catalog.languages.count, 200)
        XCTAssertGreaterThan(catalog.themes.count, 50)
    }

    private func writeSidecar(_ json: String, to dir: URL) throws -> URL {
        let url = dir.appendingPathComponent("catalog-\(UUID().uuidString).json")
        try json.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func test_sidecarPresent_readsFromSidecarNotDirectories() throws {
        let dir = try makeTempDir()
        // Директории грамматик/тем намеренно пусты — если каталог не пуст,
        // значит данные пришли из сайдкара, а не из обхода.
        let grammars = try makeTempDir()
        let themes = try makeTempDir()
        let sidecar = try writeSidecar(#"""
        {"languages":[{"id":"swift","displayName":"Swift"}],
         "themes":[{"id":"dark-plus","displayName":"Dark Plus","isDark":true}]}
        """#, to: dir)

        let source = FileCatalogSource(grammarsDirectory: grammars, themesDirectory: themes,
                                       sidecarURLs: [sidecar])
        let catalog = try source.loadCatalog()

        XCTAssertEqual(catalog.languages, [LanguageInfo(id: "swift", displayName: "Swift")])
        XCTAssertEqual(catalog.themes, [ThemeInfo(id: "dark-plus", displayName: "Dark Plus", isDark: true)])
    }

    func test_noSidecar_fallsBackToDirectoryScan() throws {
        let grammars = try makeTempDir()
        let themes = try makeTempDir()
        try #"[{"name":"json","displayName":"JSON"}]"#
            .write(to: grammars.appendingPathComponent("json.json"), atomically: true, encoding: .utf8)
        // sidecarURLs пуст → должен сработать обход директорий.
        let source = FileCatalogSource(grammarsDirectory: grammars, themesDirectory: themes,
                                       sidecarURLs: [])
        let catalog = try source.loadCatalog()
        XCTAssertEqual(catalog.languages, [LanguageInfo(id: "json", displayName: "JSON")])
    }

    func test_malformedSidecar_fallsBackToDirectoryScan() throws {
        let dir = try makeTempDir()
        let grammars = try makeTempDir()
        let themes = try makeTempDir()
        try #"[{"name":"json","displayName":"JSON"}]"#
            .write(to: grammars.appendingPathComponent("json.json"), atomically: true, encoding: .utf8)
        let bad = try writeSidecar("{ not valid json", to: dir)

        let source = FileCatalogSource(grammarsDirectory: grammars, themesDirectory: themes,
                                       sidecarURLs: [bad])
        let catalog = try source.loadCatalog()
        // Битый сайдкар проигнорирован → фоллбэк-обход.
        XCTAssertEqual(catalog.languages, [LanguageInfo(id: "json", displayName: "JSON")])
    }

    /// Каталог из настоящего встроенного сайдкара.
    private func realSidecarCatalog() throws -> Catalog {
        let sidecar = try XCTUnwrap(QuickLookersEngineResources.catalogSidecarURL())
        return try FileCatalogSource(
            grammarsDirectory: QuickLookersEngineResources.grammarsDirectory(),
            themesDirectory: QuickLookersEngineResources.themesDirectory(),
            sidecarURLs: [sidecar]).loadCatalog()
    }

    func test_realSidecar_loadsFullLibrary() throws {
        let catalog = try realSidecarCatalog()
        XCTAssertEqual(catalog.languages.count, 218)
        XCTAssertEqual(catalog.themes.count, 54)
    }

    func test_realSidecar_matchesDirectoryScan() throws {
        // Сайдкар и фоллбэк-обход должны давать идентичный каталог.
        XCTAssertEqual(try realSidecarCatalog(), try realCatalog())
    }

    func test_twoSidecars_lastOverridesByID() throws {
        let dir = try makeTempDir()
        let grammars = try makeTempDir()
        let themes = try makeTempDir()
        let base = try writeSidecar(#"""
        {"languages":[{"id":"swift","displayName":"Swift"},{"id":"json","displayName":"JSON"}],
         "themes":[{"id":"dark-plus","displayName":"Dark Plus","isDark":true}]}
        """#, to: dir)
        let imported = try writeSidecar(#"""
        {"languages":[{"id":"swift","displayName":"Swift (custom)"}],
         "themes":[{"id":"dark-plus","displayName":"Dark Plus (custom)","isDark":true}]}
        """#, to: dir)

        let source = FileCatalogSource(grammarsDirectory: grammars, themesDirectory: themes,
                                       sidecarURLs: [base, imported])
        let catalog = try source.loadCatalog()

        XCTAssertEqual(catalog.languages, [
            LanguageInfo(id: "json", displayName: "JSON"),
            LanguageInfo(id: "swift", displayName: "Swift (custom)"),
        ])
        XCTAssertEqual(catalog.themes,
                       [ThemeInfo(id: "dark-plus", displayName: "Dark Plus (custom)", isDark: true)])
    }
}
