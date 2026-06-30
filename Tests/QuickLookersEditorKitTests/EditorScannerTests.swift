import XCTest
@testable import QuickLookersEditorKit

final class EditorScannerTests: XCTestCase {
    private var appsDir: URL {
        Bundle.module.url(forResource: "Fixtures/Applications", withExtension: nil)!
    }
    func testFindsVSCodeLikeEditorsOnly() {
        let found = EditorScanner.scan(applicationsDir: appsDir)
        let names = Set(found.map(\.nameShort))
        XCTAssertEqual(names, ["Code", "Cursor"])
    }
    func testFieldsParsed() {
        let cursor = EditorScanner.scan(applicationsDir: appsDir).first { $0.nameShort == "Cursor" }
        XCTAssertEqual(cursor?.dataFolderName, ".cursor")
        XCTAssertEqual(cursor?.nameLong, "Cursor")
    }
    func testEmptyDirectoryYieldsNoEditors() {
        let empty = FileManager.default.temporaryDirectory
            .appendingPathComponent("ql-empty-apps-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: empty) }
        XCTAssertEqual(EditorScanner.scan(applicationsDir: empty), [])
    }
    func testUnreadableDirectoryYieldsNoEditorsInsteadOfCrashing() {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("ql-does-not-exist-\(UUID().uuidString)")
        XCTAssertEqual(EditorScanner.scan(applicationsDir: missing), [])
    }
}
