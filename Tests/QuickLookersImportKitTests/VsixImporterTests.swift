import XCTest
@testable import QuickLookersImportKit

final class VsixImporterTests: XCTestCase {
    private func fixture(_ name: String) throws -> Data {
        try Data(contentsOf: try XCTUnwrap(Bundle.module.url(forResource: "Fixtures/\(name)", withExtension: nil)))
    }
    private func importer() -> VsixImporter {
        // Каталог встроенных грамматик не нужен этим тестам (без вложенных) — пустой временный.
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return VsixImporter(bundledGrammarsDir: dir)
    }

    func test_importsThemeArtifact() throws {
        let r = try importer()(vsixData: try fixture("theme-only.vsix"))
        XCTAssertEqual(r.artifacts.count, 1)
        let a = r.artifacts[0]
        XCTAssertEqual(a.kind, .theme)
        XCTAssertEqual(a.id, "my-cool-theme")
        XCTAssertEqual(a.displayName, "My Cool Theme")
        XCTAssertTrue(a.isDark)
    }

    func test_importsGrammarArtifact() throws {
        let r = try importer()(vsixData: try fixture("grammar-json.vsix"))
        XCTAssertEqual(r.artifacts.map(\.id), ["toy"])
        XCTAssertEqual(r.artifacts[0].kind, .grammar)
        XCTAssertEqual(r.artifacts[0].displayName, "Toy Lang")
    }

    func test_partialSuccessRecordsSkip() throws {
        let r = try importer()(vsixData: try fixture("broken-entry.vsix"))
        XCTAssertEqual(r.artifacts.map(\.id), ["good"])     // валидная импортирована
        XCTAssertEqual(r.skips.count, 1)                    // битая — пропущена
        XCTAssertTrue(r.skips[0].item.contains("Missing"))
    }

    func test_themeJSONCisNormalizedToStrictJSON() throws {
        let r = try importer()(vsixData: try fixture("theme-jsonc.vsix"))
        let theme = try XCTUnwrap(r.artifacts.first { $0.kind == .theme })
        // Тема расширения была JSONC (комментарий + висячая запятая) — должна храниться строгим JSON.
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: theme.json))
    }

    func test_notArchiveThrows() throws {
        XCTAssertThrowsError(try importer()(vsixData: try fixture("not-a-vsix.vsix"))) { e in
            XCTAssertEqual(e as? ImportError, .notArchive)
        }
    }

    func test_maliciousIdIsSkippedNotImported() throws {
        let r = try importer()(vsixData: try fixture("malicious-id.vsix"))
        XCTAssertTrue(r.artifacts.isEmpty)                       // ничего не импортировано
        XCTAssertEqual(r.skips.count, 1)
        XCTAssertTrue(r.skips[0].reason.contains("недопустимый идентификатор"))
    }
}
