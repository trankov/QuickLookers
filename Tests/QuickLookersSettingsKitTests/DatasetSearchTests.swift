import XCTest
@testable import QuickLookersSettingsKit

final class DatasetSearchTests: XCTestCase {
    private let assoc = FileTypeAssociations(
        byExtension: ["js": "javascript", "jsx": "javascript", "json": "json", "py": "python"],
        byFilename: ["Dockerfile": "docker", "Makefile": "make"])

    private func name(_ id: String) -> String? {
        ["javascript": "JavaScript", "json": "JSON", "python": "Python",
         "docker": "Docker", "make": "Makefile"][id]
    }

    func test_matchesByExtensionKey() {
        let r = searchDataset(query: "js", limit: 50, associations: assoc, languageName: name)
        XCTAssertTrue(r.contains { $0.key == .ext("js") })
        XCTAssertTrue(r.contains { $0.key == .ext("jsx") })
        XCTAssertTrue(r.contains { $0.key == .ext("json") })   // "js" ⊂ "json"
    }

    func test_matchesByFilenameKey() {
        let r = searchDataset(query: "docker", limit: 50, associations: assoc, languageName: name)
        XCTAssertTrue(r.contains { $0.key == .filename("Dockerfile") })
    }

    func test_matchesByLanguageName() {
        let r = searchDataset(query: "python", limit: 50, associations: assoc, languageName: name)
        XCTAssertTrue(r.contains { $0.key == .ext("py") })
    }

    func test_respectsLimit() {
        let r = searchDataset(query: "j", limit: 2, associations: assoc, languageName: name)
        XCTAssertEqual(r.count, 2)
    }

    func test_emptyQuery_returnsNothing() {
        XCTAssertTrue(searchDataset(query: "", limit: 50, associations: assoc, languageName: name).isEmpty)
    }

    func test_sortedByKey_stable() {
        let r = searchDataset(query: "j", limit: 50, associations: assoc, languageName: name)
        XCTAssertEqual(r.map(\.id), r.map(\.id).sorted())
    }

    func test_keyMatchOutranksLanguageNameMatch() {
        let a = FileTypeAssociations(byExtension: ["json": "json", "avsc": "json"], byFilename: [:])
        let r = searchDataset(query: "json", limit: 1, associations: a,
                              languageName: { $0 == "json" ? "JSON" : nil })
        XCTAssertEqual(r.first?.key, .ext("json"))   // ключевое совпадение впереди name-only
    }
}
