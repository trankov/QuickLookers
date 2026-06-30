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
}
