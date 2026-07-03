import XCTest
@testable import QuickLookersSettingsKit

final class PreviewRuleTests: XCTestCase {
    func test_defaultsEnabledWithGeneratedId() {
        let r = PreviewRule(pattern: "*.djhtml", action: .assign(languageId: "django-html"))
        XCTAssertTrue(r.isEnabled)
        XCTAssertEqual(r.pattern, "*.djhtml")
    }

    func test_codableRoundTrip_assign() throws {
        let r = PreviewRule(pattern: "*.config.js", action: .assign(languageId: "json"), isEnabled: false)
        let back = try JSONDecoder().decode(PreviewRule.self, from: JSONEncoder().encode(r))
        XCTAssertEqual(r, back)
    }

    func test_codableRoundTrip_neutral() throws {
        let r = PreviewRule(pattern: "*.log", action: .neutral)
        let back = try JSONDecoder().decode(PreviewRule.self, from: JSONEncoder().encode(r))
        XCTAssertEqual(r, back)
        XCTAssertEqual(back.action, .neutral)
    }
}
