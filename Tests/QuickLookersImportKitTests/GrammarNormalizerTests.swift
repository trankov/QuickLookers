import XCTest
@testable import QuickLookersImportKit

final class GrammarNormalizerTests: XCTestCase {
    /// Временный каталог «встроенных грамматик» с одним языком css.
    private func bundledDir(css: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try css.write(to: dir.appendingPathComponent("css.json"), atomically: true, encoding: .utf8)
        return dir
    }

    func test_plistGrammarConvertedToJSON() throws {
        let plist = Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0"><dict><key>name</key><string>toy</string></dict></plist>
        """.utf8)
        let n = GrammarNormalizer(bundledGrammarsDir: try bundledDir(css: "[]"))
        let json = try n.toJSON(plist, path: "a.tmLanguage")
        let obj = try JSONSerialization.jsonObject(with: json) as? [String: Any]
        XCTAssertEqual(obj?["name"] as? String, "toy")
    }

    func test_jsonGrammarPassedThrough() throws {
        let n = GrammarNormalizer(bundledGrammarsDir: try bundledDir(css: "[]"))
        let src = Data(#"{"name":"toy"}"#.utf8)
        XCTAssertEqual(try n.toJSON(src, path: "a.tmLanguage.json"), src)
    }

    func test_embedsArePulledFromBundle() throws {
        // css.json во «встроенных» — массив из одной грамматики css.
        let n = GrammarNormalizer(bundledGrammarsDir: try bundledDir(css: #"[{"name":"css","patterns":[]}]"#))
        let vue = Data(#"{"name":"vue","patterns":[]}"#.utf8)
        let out = try n.normalize(languageId: "vue", grammarJSON: vue,
                                  embeddedLanguageIds: ["css"], siblingGrammars: [:])
        let arr = try XCTUnwrap(JSONSerialization.jsonObject(with: out) as? [[String: Any]])
        let names = arr.compactMap { $0["name"] as? String }
        XCTAssertTrue(names.contains("vue"))
        XCTAssertTrue(names.contains("css"))                 // дотянут из библиотеки
        let main = try XCTUnwrap(arr.first { $0["name"] as? String == "vue" })
        XCTAssertEqual(main["embeddedLangs"] as? [String], ["css"])  // внедрён
    }

    func test_embedFromSiblingPreferredOverBundle() throws {
        let n = GrammarNormalizer(bundledGrammarsDir: try bundledDir(css: #"[{"name":"css","from":"bundle"}]"#))
        let vue = Data(#"{"name":"vue"}"#.utf8)
        let sibling = Data(#"{"name":"css","from":"sibling"}"#.utf8)
        let out = try n.normalize(languageId: "vue", grammarJSON: vue,
                                  embeddedLanguageIds: ["css"], siblingGrammars: ["css": sibling])
        let arr = try XCTUnwrap(JSONSerialization.jsonObject(with: out) as? [[String: Any]])
        let css: [String: Any] = try XCTUnwrap(arr.first { $0["name"] as? String == "css" })
        XCTAssertEqual(css["from"] as? String, "sibling")   // из .vsix, не из бандла
    }

    func test_missingEmbedIsSkippedNotFatal() throws {
        let n = GrammarNormalizer(bundledGrammarsDir: try bundledDir(css: "[]"))
        let vue = Data(#"{"name":"vue"}"#.utf8)
        let out = try n.normalize(languageId: "vue", grammarJSON: vue,
                                  embeddedLanguageIds: ["nonexistent"], siblingGrammars: [:])
        let arr = try XCTUnwrap(JSONSerialization.jsonObject(with: out) as? [[String: Any]])
        XCTAssertEqual(arr.compactMap { $0["name"] as? String }, ["vue"])  // только главная, без падения
    }

    func test_mainGrammarNameForcedToLanguageId() throws {
        // Импортированная грамматика держит витринное имя VS Code («Django HTML»);
        // приводим `name` к id, иначе движок (регистрация по name, поиск по id) не
        // найдёт её при показе. `scopeName` не трогаем — это TextMate-scope.
        let n = GrammarNormalizer(bundledGrammarsDir: try bundledDir(css: "[]"))
        let raw = Data(#"{"name":"Django HTML","scopeName":"text.html.django"}"#.utf8)
        let out = try n.normalize(languageId: "django-html", grammarJSON: raw,
                                  embeddedLanguageIds: [], siblingGrammars: [:])
        let arr = try XCTUnwrap(JSONSerialization.jsonObject(with: out) as? [[String: Any]])
        let main = try XCTUnwrap(arr.first)
        XCTAssertEqual(main["name"] as? String, "django-html")
        XCTAssertEqual(main["scopeName"] as? String, "text.html.django")
    }

    func test_malformedPlistThrowsBadGrammar() throws {
        let n = GrammarNormalizer(bundledGrammarsDir: try bundledDir(css: "[]"))
        XCTAssertThrowsError(try n.toJSON(Data("not a plist at all".utf8), path: "a.tmLanguage")) { e in
            XCTAssertEqual(e as? GrammarError, .badGrammar)
        }
    }

    func test_malformedMainGrammarJSONThrowsBadGrammar() throws {
        // grammarJSON, переданный normalize, — не объект (например, обрублен/мусор из .vsix).
        let n = GrammarNormalizer(bundledGrammarsDir: try bundledDir(css: "[]"))
        XCTAssertThrowsError(try n.normalize(languageId: "vue", grammarJSON: Data("not json".utf8),
                                             embeddedLanguageIds: [], siblingGrammars: [:])) { e in
            XCTAssertEqual(e as? GrammarError, .badGrammar)
        }
    }

    func test_selfReferencingEmbedDoesNotDuplicateOrLoop() throws {
        // Грамматика, объявляющая сама себя как embedded language (встречается у некоторых
        // .vsix с неаккуратным package.json) — не должна задвоиться и не должна зациклиться.
        let n = GrammarNormalizer(bundledGrammarsDir: try bundledDir(css: "[]"))
        let vue = Data(#"{"name":"vue"}"#.utf8)
        let out = try n.normalize(languageId: "vue", grammarJSON: vue,
                                  embeddedLanguageIds: ["vue"], siblingGrammars: ["vue": vue])
        let arr = try XCTUnwrap(JSONSerialization.jsonObject(with: out) as? [[String: Any]])
        XCTAssertEqual(arr.compactMap { $0["name"] as? String }, ["vue"])  // не задвоилось
    }

    func test_corruptSiblingFallsBackToBundle() throws {
        // Сиблинг-грамматика того же .vsix битая (не разбирается как JSON-объект) —
        // дотягиваем встроенную версию вместо того, чтобы потерять вложенный язык целиком.
        let n = GrammarNormalizer(bundledGrammarsDir: try bundledDir(css: #"[{"name":"css","from":"bundle"}]"#))
        let vue = Data(#"{"name":"vue"}"#.utf8)
        let corruptSibling = Data("not valid json".utf8)
        let out = try n.normalize(languageId: "vue", grammarJSON: vue,
                                  embeddedLanguageIds: ["css"], siblingGrammars: ["css": corruptSibling])
        let arr = try XCTUnwrap(JSONSerialization.jsonObject(with: out) as? [[String: Any]])
        let css: [String: Any] = try XCTUnwrap(arr.first { $0["name"] as? String == "css" })
        XCTAssertEqual(css["from"] as? String, "bundle")    // упал на встроенную, не потерялся
    }
}
