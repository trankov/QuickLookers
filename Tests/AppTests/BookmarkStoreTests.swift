import XCTest
@testable import QuickLookers

final class AccessScopeTests: XCTestCase {
    func test_home_url_isHomeDirectory() {
        XCTAssertEqual(AccessScope.home.url, FileManager.default.homeDirectoryForCurrentUser)
    }

    func test_applications_url_isApplicationsDirectory() {
        XCTAssertEqual(AccessScope.applications.url, URL(fileURLWithPath: "/Applications"))
    }

    func test_defaultsKeys_areDistinct() {
        XCTAssertNotEqual(AccessScope.home.defaultsKey, AccessScope.applications.defaultsKey)
    }

    func test_prompts_areNonEmptyAndDistinct() {
        XCTAssertFalse(AccessScope.home.prompt.isEmpty)
        XCTAssertFalse(AccessScope.applications.prompt.isEmpty)
        XCTAssertNotEqual(AccessScope.home.prompt, AccessScope.applications.prompt)
    }
}
