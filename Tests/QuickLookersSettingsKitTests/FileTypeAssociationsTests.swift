import XCTest
import Foundation
import QuickLookersSettingsKit

final class FileTypeAssociationsTests: XCTestCase {
    private func write(_ json: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".json")
        try Data(json.utf8).write(to: url)
        return url
    }

    func testDecodesReverseMaps() throws {
        let url = try write(#"""
        {"version":1,"languages":[
          {"id":"python","extensions":["py","pyi"],"filenames":[]},
          {"id":"docker","extensions":[],"filenames":["Dockerfile"]}
        ]}
        """#)
        let a = try FileTypeAssociations(contentsOf: url)
        XCTAssertEqual(a.byExtension["py"], "python")
        XCTAssertEqual(a.byExtension["pyi"], "python")
        XCTAssertEqual(a.byFilename["Dockerfile"], "docker")
        XCTAssertNil(a.byExtension["docx"])
    }

    func testExtensionsLowercased() throws {
        let url = try write(#"{"version":1,"languages":[{"id":"swift","extensions":["swift"],"filenames":[]}]}"#)
        let a = try FileTypeAssociations(contentsOf: url)
        XCTAssertEqual(a.byExtension["swift"], "swift")
    }

    func testEmpty() {
        XCTAssertTrue(FileTypeAssociations.empty.byExtension.isEmpty)
        XCTAssertTrue(FileTypeAssociations.empty.byFilename.isEmpty)
    }

    func testLoadedFromValidURL() throws {
        let url = try write(#"{"version":1,"languages":[{"id":"swift","extensions":["swift"],"filenames":[]}]}"#)
        XCTAssertEqual(FileTypeAssociations.loaded(from: url).byExtension["swift"], "swift")
    }

    func testLoadedFallsBackToEmpty() {
        XCTAssertEqual(FileTypeAssociations.loaded(from: nil), .empty)
        XCTAssertEqual(FileTypeAssociations.loaded(from: URL(fileURLWithPath: "/nonexistent.json")), .empty)
    }
}
