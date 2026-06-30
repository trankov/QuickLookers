import XCTest
@testable import QuickLookersEditorKit

private struct StubCatalog: ThemeCatalogLookup {
    // Пустой каталог: тема в этом сценарии — кастомная, из расширения редактора,
    // а не встроенная в наш каталог.
    func themeId(forDisplayName name: String) -> String? { nil }
}

/// Сквозной прогон конвейера «найти редактор → прочитать его настройки → разрешить тему»
/// на синтетическом, но реалистичном дереве: product.json + settings.json (JSONC,
/// с комментарием и висячей запятой) + расширение редактора со своей темой.
final class EditorPipelineIntegrationTests: XCTestCase {
    private var pipelineRoot: URL { Bundle.module.url(forResource: "Fixtures/Pipeline", withExtension: nil)! }

    func testScanReadResolveEndToEnd() throws {
        let apps = pipelineRoot.appendingPathComponent("Applications")
        let appSupport = pipelineRoot.appendingPathComponent("AppSupport")
        let extensions = pipelineRoot.appendingPathComponent("extensions")

        let found = EditorScanner.scan(applicationsDir: apps)
        guard let demo = found.first(where: { $0.nameShort == "Demo" }) else {
            return XCTFail("EditorScanner не нашёл синтетический Demo.app: \(found)")
        }
        XCTAssertEqual(demo.nameLong, "Demo Editor")
        XCTAssertEqual(demo.dataFolderName, ".demo")

        let prefs = EditorSettingsReader.read(editor: demo, appSupportDir: appSupport)
        XCTAssertEqual(prefs.colorThemeLabel, "Pipeline Theme")
        XCTAssertEqual(prefs.fontFamily, "Menlo, monospace")
        XCTAssertEqual(prefs.fontSize, 12)

        guard let label = prefs.colorThemeLabel else { return XCTFail("ожидалась активная тема") }
        let resolution = EditorThemeResolver.resolve(label: label, catalog: StubCatalog(), extensionsDir: extensions)
        guard case let .custom(resolvedLabel, uiTheme, fileURL) = resolution else {
            return XCTFail("ожидался .custom: \(resolution)")
        }
        XCTAssertEqual(resolvedLabel, "Pipeline Theme")
        XCTAssertEqual(uiTheme, "vs-dark")
        XCTAssertTrue(fileURL.path.hasSuffix("themes/pipeline.json"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
    }
}
