import XCTest
@testable import QuickLookersEditorKit

private struct StubCatalog: ThemeCatalogLookup {
    let map: [String: String]
    func themeId(forDisplayName name: String) -> String? { map[name] }
}

final class EditorThemeResolverTests: XCTestCase {
    private var extDir: URL { Bundle.module.url(forResource: "Fixtures/extensions", withExtension: nil)! }

    func testBundledByDisplayName() {
        let r = EditorThemeResolver.resolve(label: "Monokai",
            catalog: StubCatalog(map: ["Monokai": "monokai"]), extensionsDir: extDir)
        XCTAssertEqual(r, .bundled(themeId: "monokai"))
    }
    func testCustomFromExtensions() {
        let r = EditorThemeResolver.resolve(label: "Cool Dark",
            catalog: StubCatalog(map: [:]), extensionsDir: extDir)
        guard case let .custom(label, uiTheme, fileURL) = r else { return XCTFail("ожидался .custom: \(r)") }
        XCTAssertEqual(label, "Cool Dark")
        XCTAssertEqual(uiTheme, "vs-dark")
        XCTAssertTrue(fileURL.path.hasSuffix("themes/cool.json"))
    }
    func testNotFound() {
        let r = EditorThemeResolver.resolve(label: "Nope",
            catalog: StubCatalog(map: [:]), extensionsDir: extDir)
        XCTAssertEqual(r, .notFound)
    }
    /// Среди установленных расширений встречаются: с нечитаемым package.json и
    /// с пустым списком тем — цикл должен пропускать их и доходить до нужного.
    func testCustomThemeFoundAcrossMultipleExtensionsDespiteBrokenAndEmptyOnes() {
        let r = EditorThemeResolver.resolve(label: "Cool Dark",
            catalog: StubCatalog(map: [:]), extensionsDir: extDir)
        guard case .custom = r else { return XCTFail("ожидался .custom несмотря на сломанные соседние расширения: \(r)") }
    }
    /// Текущее поведение — точное (регистрозависимое) сравнение меток; документируем это,
    /// а не предполагаем нормализацию регистра, которой в коде нет.
    func testLabelMatchingIsCaseSensitive() {
        let r = EditorThemeResolver.resolve(label: "cool dark",
            catalog: StubCatalog(map: [:]), extensionsDir: extDir)
        XCTAssertEqual(r, .notFound)
    }
    func testNonexistentExtensionsDirYieldsNotFoundInsteadOfCrashing() {
        let missing = extDir.appendingPathComponent("does-not-exist")
        let r = EditorThemeResolver.resolve(label: "Cool Dark",
            catalog: StubCatalog(map: [:]), extensionsDir: missing)
        XCTAssertEqual(r, .notFound)
    }
}
