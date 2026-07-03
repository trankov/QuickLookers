import XCTest
@testable import QuickLookersSettingsKit

final class GlobMatcherTests: XCTestCase {
    func test_extensionPattern_matches() {
        let m = GlobMatcher("*.djhtml")
        XCTAssertTrue(m.matches(fileName: "index.djhtml"))
        XCTAssertFalse(m.matches(fileName: "index.html"))
    }

    func test_matching_isCaseInsensitive() {
        XCTAssertTrue(GlobMatcher("*.djhtml").matches(fileName: "Index.DJHTML"))
    }

    func test_compoundExtension_matches() {
        let m = GlobMatcher("*.config.js")
        XCTAssertTrue(m.matches(fileName: "webpack.config.js"))
        XCTAssertFalse(m.matches(fileName: "webpack.js"))
    }

    func test_filenamePrefix_matches() {
        let m = GlobMatcher("Dockerfile.*")
        XCTAssertTrue(m.matches(fileName: "Dockerfile.dev"))
        XCTAssertFalse(m.matches(fileName: "Dockerfile"))   // '*' требует хотя бы 0 символов после точки, но точка обязательна
    }

    func test_questionMark_matchesSingleChar() {
        let m = GlobMatcher("*.djhtm?")
        XCTAssertTrue(m.matches(fileName: "a.djhtml"))
        XCTAssertTrue(m.matches(fileName: "a.djhtmX"))
        XCTAssertFalse(m.matches(fileName: "a.djhtm"))
    }

    func test_exactFilename_matches() {
        let m = GlobMatcher("Dockerfile")
        XCTAssertTrue(m.matches(fileName: "Dockerfile"))
        XCTAssertFalse(m.matches(fileName: "Dockerfile.dev"))
    }

    func test_specificity_exactBeatsGlob_andLongerLiteralsWin() {
        XCTAssertGreaterThan(GlobMatcher("Dockerfile").specificity, GlobMatcher("*.js").specificity)
        XCTAssertGreaterThan(GlobMatcher("*.config.js").specificity, GlobMatcher("*.js").specificity)
    }

    func test_fastExtension_onlyForSingleTokenStarDot() {
        XCTAssertEqual(GlobMatcher("*.js").fastExtension, "js")
        XCTAssertEqual(GlobMatcher("*.JS").fastExtension, "js")
        XCTAssertNil(GlobMatcher("*.config.js").fastExtension)   // есть точка в остатке
        XCTAssertNil(GlobMatcher("Dockerfile").fastExtension)
    }

    func test_exactFilename_property() {
        XCTAssertEqual(GlobMatcher("Dockerfile").exactFilename, "Dockerfile")
        XCTAssertNil(GlobMatcher("*.js").exactFilename)
    }

    func test_probeExtension_derivesTestableExtension() {
        XCTAssertEqual(GlobMatcher("*.js").probeExtension, "js")
        XCTAssertEqual(GlobMatcher("a.min.js").probeExtension, "js")  // литерал с точкой → хвост
        XCTAssertNil(GlobMatcher("*.config.js").probeExtension)       // wildcard + точка → неопределимо
        XCTAssertNil(GlobMatcher("Dockerfile").probeExtension)        // нет точки
    }

    func test_optional_matchesZeroOrOne() {
        // Семьи расширений: htm/html, yml/yaml — одним шаблоном.
        XCTAssertTrue(GlobMatcher("*.htm~").matches(fileName: "a.htm"))    // ноль
        XCTAssertTrue(GlobMatcher("*.htm~").matches(fileName: "a.html"))   // один
        XCTAssertTrue(GlobMatcher("*.y~ml").matches(fileName: "a.yml"))    // ноль
        XCTAssertTrue(GlobMatcher("*.y~ml").matches(fileName: "a.yaml"))   // один
    }

    func test_escape_tildeIsLiteral() {
        let m = GlobMatcher("backup/~")     // /~ → обычная тильда
        XCTAssertTrue(m.matches(fileName: "backup~"))
        XCTAssertFalse(m.matches(fileName: "backup"))    // тильда обязательна как литерал
        XCTAssertFalse(m.matches(fileName: "backupX"))
        XCTAssertNil(m.probeExtension)
        XCTAssertEqual(m.exactFilename, "backup~")        // экранированная тильда — литерал → точное имя
    }

    func test_escape_starIsLiteral() {
        let m = GlobMatcher("a/*b")         // /* → звёздочка-литерал
        XCTAssertTrue(m.matches(fileName: "a*b"))
        XCTAssertFalse(m.matches(fileName: "axb"))
    }

    func test_optional_countsAsWildcard_forSpecificityAndExactName() {
        XCTAssertNil(GlobMatcher("*.htm~").exactFilename)                 // есть wildcard
        XCTAssertNil(GlobMatcher("*.htm~").fastExtension)                 // ~ в остатке → не быстрый путь
        XCTAssertLessThan(GlobMatcher("*.htm~").specificity, GlobMatcher("index.html").specificity)
    }
}
