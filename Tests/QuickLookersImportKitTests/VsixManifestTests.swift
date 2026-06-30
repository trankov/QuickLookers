import XCTest
@testable import QuickLookersImportKit

final class VsixManifestTests: XCTestCase {
    func test_parsesThemesGrammarsLanguages() throws {
        let json = Data(#"""
        {"contributes":{
          "languages":[{"id":"astro","aliases":["Astro"]}],
          "grammars":[
            {"language":"astro","scopeName":"source.astro","path":"./s/astro.json",
             "embeddedLanguages":{"source.css":"css","source.ts":"typescript"}},
            {"scopeName":"text.html.markdown.astro","path":"./s/md.json","injectTo":["source.astro"]}
          ],
          "themes":[{"label":"Astro Dark","uiTheme":"vs-dark","path":"./t/dark.json"}]
        }}
        """#.utf8)
        let m = try VsixManifest.parse(packageJSON: json)
        XCTAssertEqual(m.themes, [.init(label: "Astro Dark", uiTheme: "vs-dark", path: "./t/dark.json")])
        XCTAssertEqual(m.grammars.count, 2)
        XCTAssertEqual(m.grammars[0].language, "astro")
        XCTAssertEqual(m.grammars[0].embeddedLanguageIds.sorted(), ["css", "typescript"])
        XCTAssertNil(m.grammars[1].language)          // инъекция: language нет
        XCTAssertEqual(m.languageDisplayNames["astro"], "Astro")
    }

    func test_noContributionsThrows() throws {
        XCTAssertThrowsError(try VsixManifest.parse(packageJSON: Data(#"{"name":"x"}"#.utf8))) { e in
            XCTAssertEqual(e as? ManifestError, .noContributions)
        }
    }

    func test_badJSONThrows() throws {
        XCTAssertThrowsError(try VsixManifest.parse(packageJSON: Data("{ broken".utf8))) { e in
            XCTAssertEqual(e as? ManifestError, .badJSON)
        }
    }

    func test_malformedContributionEntriesAreSkippedNotFatal() throws {
        // package.json — недоверенный вход: themes без обязательных полей отфильтровываются,
        // embeddedLanguages неверного типа не валит разбор, grammar без path не падает.
        let json = Data(#"""
        {"contributes":{
          "grammars":[
            {"language":"weird","scopeName":"source.weird","embeddedLanguages":["not","a","dict"]},
            {"language":"nopath"}
          ],
          "themes":[
            {"label":"No path"},
            {"path":"./t/nolabel.json"},
            {"label":"Good","path":"./t/good.json"}
          ]
        }}
        """#.utf8)
        let m = try VsixManifest.parse(packageJSON: json)
        XCTAssertEqual(m.grammars.count, 2)
        XCTAssertEqual(m.grammars[0].embeddedLanguageIds, [])     // неверный тип → пусто, не падение
        XCTAssertEqual(m.grammars[1].path, "")                   // нет path → дефолт "", не падение
        XCTAssertEqual(m.themes.map(\.label), ["Good"])           // только полная запись прошла
    }
}
