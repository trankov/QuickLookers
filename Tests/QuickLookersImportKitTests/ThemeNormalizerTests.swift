import XCTest
@testable import QuickLookersImportKit

final class ThemeNormalizerTests: XCTestCase {
    func test_slugLowercasesAndDashes() {
        XCTAssertEqual(ThemeNormalizer.slug("My Cool Theme!"), "my-cool-theme")
        XCTAssertEqual(ThemeNormalizer.slug("Dracula (Soft)"), "dracula-soft")
    }

    func test_isDarkFromUiTheme() {
        XCTAssertTrue(ThemeNormalizer.isDark(uiTheme: "vs-dark"))
        XCTAssertTrue(ThemeNormalizer.isDark(uiTheme: "hc-black"))
        XCTAssertFalse(ThemeNormalizer.isDark(uiTheme: "vs"))
    }

    func test_normalizeBuildsMeta() {
        let n = ThemeNormalizer.normalize(label: "Night Owl", uiTheme: "vs-dark",
                                          themeJSON: Data("{}".utf8), existingSlugs: [])
        XCTAssertEqual(n.id, "night-owl")
        XCTAssertEqual(n.displayName, "Night Owl")
        XCTAssertTrue(n.isDark)
        XCTAssertEqual(n.json, Data("{}".utf8))
    }

    func test_slugCollisionGetsSuffix() {
        let n = ThemeNormalizer.normalize(label: "Night Owl", uiTheme: "vs",
                                          themeJSON: Data("{}".utf8), existingSlugs: ["night-owl"])
        XCTAssertEqual(n.id, "night-owl-2")
    }

    func test_nonAsciiLabelGetsSafeFallbackId() throws {
        let n = ThemeNormalizer.normalize(label: "Монокай Тема", uiTheme: "vs-dark",
                                          themeJSON: Data("{}".utf8), existingSlugs: [])
        XCTAssertTrue(n.id.hasPrefix("theme-"))
        XCTAssertTrue(isSafeImportID(n.id))          // id годен для имени файла
        XCTAssertEqual(n.displayName, "Монокай Тема") // показ — оригинал
    }

    func test_nonAsciiFallbackIsStable() throws {
        let a = ThemeNormalizer.normalize(label: "Монокай", uiTheme: "vs", themeJSON: Data("{}".utf8), existingSlugs: [])
        let b = ThemeNormalizer.normalize(label: "Монокай", uiTheme: "vs", themeJSON: Data("{}".utf8), existingSlugs: [])
        XCTAssertEqual(a.id, b.id)                   // детерминирован → повторный импорт перекроет
    }
}
