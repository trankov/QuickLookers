import XCTest
@testable import QuickLookersImportKit

final class ZipReaderTests: XCTestCase {
    private func fixture(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "Fixtures/\(name)", withExtension: nil))
        return try Data(contentsOf: url)
    }

    func test_listsEntryNames() throws {
        let names = try ZipReader().entryNames(in: try fixture("theme-only.vsix"))
        XCTAssertTrue(names.contains("extension/package.json"))
        XCTAssertTrue(names.contains("extension/theme/cool.json"))
    }

    func test_extractsEntryBytes_deflate() throws {
        let data = try XCTUnwrap(try ZipReader().entry("extension/package.json", in: try fixture("grammar-json.vsix")))
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual((obj?["name"] as? String), "g")
    }

    func test_extractsEntryBytes_stored() throws {
        let data = try XCTUnwrap(try ZipReader().entry("extension/syntaxes/toy.tmLanguage.json",
                                                       in: try fixture("grammar-json-stored.vsix")))
        XCTAssertTrue(String(data: data, encoding: .utf8)!.contains("source.toy"))
    }

    func test_missingEntryReturnsNil() throws {
        XCTAssertNil(try ZipReader().entry("extension/nope.json", in: try fixture("theme-only.vsix")))
    }

    func test_notAnArchiveThrows() throws {
        XCTAssertThrowsError(try ZipReader().entryNames(in: try fixture("not-a-vsix.vsix")))
    }
}
