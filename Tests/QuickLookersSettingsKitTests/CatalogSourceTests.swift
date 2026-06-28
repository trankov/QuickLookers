import XCTest
import QuickLookersSettingsKit

final class CatalogSourceTests: XCTestCase {
    private func makeTempDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ql-catalog-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func testReadsLanguagesAndThemesWithMetadata() throws {
        let grammars = try makeTempDir()
        let themes = try makeTempDir()
        try #"{"name":"swift","displayName":"Swift","scopeName":"source.swift"}"#
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
        try #"{"name":"json"}"#
            .write(to: grammars.appendingPathComponent("json.json"), atomically: true, encoding: .utf8)
        let source = FileCatalogSource(grammarsDirectory: grammars, themesDirectory: themes)
        let catalog = try source.loadCatalog()
        XCTAssertEqual(catalog.languages, [LanguageInfo(id: "json", displayName: "json")])
    }
}
