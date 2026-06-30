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

    func test_normalizeBuildsMeta() throws {
        let n = ThemeNormalizer.normalize(label: "Night Owl", uiTheme: "vs-dark",
                                          themeJSON: Data("{}".utf8), existingSlugs: [])
        XCTAssertEqual(n.id, "night-owl")
        XCTAssertEqual(n.displayName, "Night Owl")
        XCTAssertTrue(n.isDark)
        // json больше не «как есть»: name вписывается = id (движок ищет тему по id).
        let obj = try JSONSerialization.jsonObject(with: n.json) as! [String: Any]
        XCTAssertEqual(obj["name"] as? String, "night-owl")
    }

    func test_normalizeRewritesNameToId() throws {
        let raw = Data(#"{ "name": "Seti Monokai: Original", "type": "dark", "tokenColors": [] }"#.utf8)
        let n = ThemeNormalizer.normalize(label: "Seti Monokai: Original", uiTheme: "vs-dark",
                                          themeJSON: raw, existingSlugs: [])
        let obj = try JSONSerialization.jsonObject(with: n.json) as! [String: Any]
        XCTAssertEqual(obj["name"] as? String, n.id)   // name == id, иначе движок не найдёт тему
        XCTAssertEqual(obj["type"] as? String, "dark") // прочие поля сохранены
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

    func test_punctuationOnlyLabelGetsSafeFallbackId() {
        // Label целиком из пунктуации/дефисов тоже схлопывается в пустой слаг,
        // не только не-ASCII — тот же запасной путь должен сработать.
        let n = ThemeNormalizer.normalize(label: "---!!!", uiTheme: "vs-dark",
                                          themeJSON: Data("{}".utf8), existingSlugs: [])
        XCTAssertTrue(n.id.hasPrefix("theme-"))
        XCTAssertTrue(isSafeImportID(n.id))
    }

    func test_normalizeWithNonObjectJSONKeepsOriginal() throws {
        // themeJSON — валидный JSON, но не объект (массив) → вписать name=id некуда,
        // normalize не должен падать, должен вернуть исходный JSON как есть.
        let raw = Data("[1,2,3]".utf8)
        let n = ThemeNormalizer.normalize(label: "Weird", uiTheme: "vs-dark",
                                          themeJSON: raw, existingSlugs: [])
        XCTAssertEqual(n.json, raw)
        let obj = try JSONSerialization.jsonObject(with: n.json) as? [Int]
        XCTAssertEqual(obj, [1, 2, 3])
    }

    func test_existingSlugsExhaustedSuffixesKeepIncrementing() {
        // Несколько тем с одинаковым label подряд (типичный повторный импорт) —
        // суффикс должен расти, а не зацикливаться/коллизировать.
        var slugs: Set<String> = ["dup", "dup-2", "dup-3"]
        let n = ThemeNormalizer.normalize(label: "Dup", uiTheme: "vs", themeJSON: Data("{}".utf8), existingSlugs: slugs)
        XCTAssertEqual(n.id, "dup-4")
        slugs.insert(n.id)
        XCTAssertFalse(slugs.contains("dup-5"))
    }
}
