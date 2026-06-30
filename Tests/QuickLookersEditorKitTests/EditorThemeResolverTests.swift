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
    /// extDir также содержит расширения с нечитаемым package.json и с пустым списком
    /// тем (aaa.broken-1.0.0, bbb.no-theme-1.0.0) — резолвер должен пропускать их
    /// по пути и всё равно находить нужную тему среди остальных расширений.
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
