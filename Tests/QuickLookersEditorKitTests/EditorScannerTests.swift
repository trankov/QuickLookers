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
}
