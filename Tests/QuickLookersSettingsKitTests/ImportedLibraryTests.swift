import XCTest
@testable import QuickLookersSettingsKit
import QuickLookersImportKit

final class ImportedLibraryTests: XCTestCase {
    private func tempContainer() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ql-imp-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func test_writeStoresFilesAndSidecar() throws {
        let lib = ImportedLibrary(containerURL: try tempContainer())
        let result = ImportResult(artifacts: [
            .init(kind: .theme, id: "cool", displayName: "Cool", isDark: true, json: Data("{}".utf8)),
            .init(kind: .grammar, id: "toy", displayName: "Toy", isDark: false, json: Data("[]".utf8)),
        ], skips: [])
        try lib.write(result)

        XCTAssertTrue(FileManager.default.fileExists(atPath: lib.themesDir.appendingPathComponent("cool.json").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: lib.grammarsDir.appendingPathComponent("toy.json").path))
        let sidecar = try JSONSerialization.jsonObject(with: Data(contentsOf: lib.sidecarURL)) as? [String: Any]
        let themes = sidecar?["themes"] as? [[String: Any]]
        XCTAssertEqual(themes?.first?["id"] as? String, "cool")
        XCTAssertEqual(themes?.first?["isDark"] as? Bool, true)
        XCTAssertEqual(lib.sidecarURLsForCatalog(), [lib.sidecarURL])
    }

    func test_removeDeletesFileAndSidecarEntry() throws {
        let lib = ImportedLibrary(containerURL: try tempContainer())
        try lib.write(ImportResult(artifacts: [
            .init(kind: .theme, id: "cool", displayName: "Cool", isDark: true, json: Data("{}".utf8)),
        ], skips: []))
        try lib.remove(kind: .theme, id: "cool")

        XCTAssertFalse(FileManager.default.fileExists(atPath: lib.themesDir.appendingPathComponent("cool.json").path))
        let sidecar = try JSONSerialization.jsonObject(with: Data(contentsOf: lib.sidecarURL)) as? [String: Any]
        XCTAssertEqual((sidecar?["themes"] as? [[String: Any]])?.count, 0)
    }

    func test_writeRejectsUnsafeId() throws {
        let container = try tempContainer()
        let lib = ImportedLibrary(containerURL: container)
        try lib.write(ImportResult(artifacts: [
            .init(kind: .grammar, id: "../evil", displayName: "X", isDark: false, json: Data("[]".utf8)),
        ], skips: []))
        // Файл за пределами grammarsDir не создан.
        XCTAssertFalse(FileManager.default.fileExists(atPath: container.appendingPathComponent("evil.json").path))
        // Сайдкар (если создан) не содержит небезопасный id.
        if let data = try? Data(contentsOf: lib.sidecarURL),
           let s = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            XCTAssertEqual((s["languages"] as? [[String: Any]])?.count ?? 0, 0)
        }
    }

    func test_writeMergesWithExisting() throws {
        let lib = ImportedLibrary(containerURL: try tempContainer())
        try lib.write(ImportResult(artifacts: [
            .init(kind: .theme, id: "a", displayName: "A", isDark: true, json: Data("{}".utf8)),
        ], skips: []))
        try lib.write(ImportResult(artifacts: [
            .init(kind: .theme, id: "b", displayName: "B", isDark: false, json: Data("{}".utf8)),
        ], skips: []))
        let sidecar = try JSONSerialization.jsonObject(with: Data(contentsOf: lib.sidecarURL)) as? [String: Any]
        XCTAssertEqual(Set((sidecar?["themes"] as? [[String: Any]] ?? []).compactMap { $0["id"] as? String }),
                       ["a", "b"])
    }
}
