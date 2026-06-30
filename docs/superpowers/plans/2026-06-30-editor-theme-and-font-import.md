# Импорт темы и шрифта из редактора + витрина тем — план реализации

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Дать пользователю одним нажатием получить превью «как в его редакторе» — скопировать активную тему и шрифт установленного VS Code-подобного редактора и сразу применить; плюс витрина вкладки «Темы» и ручная настройка шрифта.

**Architecture:** Чистые тестируемые модули (`QuickLookersImportKit`, новый `QuickLookersEditorKit`, `QuickLookersSettingsKit`, `QuickLookersPreviewKit`) под `swift test`; склейка с powerbox/WKWebView/SwiftUI — в слое приложения (`App/`, `PreviewExtension/`), проверяется живым запуском хоста из Xcode (⌘R). Импорт темы из редактора переиспользует существующий конвейер `.vsix` (`ThemeNormalizer` → `ImportedLibrary` → сайдкар).

**Tech Stack:** Swift 6.3 / SwiftPM (tools 5.9), macOS 13+, XcodeGen 2.45, Shiki 1.29.2 в JavaScriptCore, SwiftUI/AppKit, WKWebView, security-scoped bookmarks.

## Global Constraints

- Отвечать пользователю по-русски простым языком; код-комментарии и копирайт UI — по-русски.
- Хост остаётся в App Sandbox (иначе ломается регистрация расширения у `pkd`). Песочницу не выкидывать.
- App Group — префикс Team ID: `5FVC5YT2B5.com.quicklookers` (не `group.`).
- Доступ к данным редакторов — два ленивых гранта (`~` и `/Applications`) + app-scoped закладки; `.vsix`-импорт не меняется и от грантов не зависит.
- `.xcodeproj`, `*.entitlements`, `PreviewExtension/Info.plist` — артефакты XcodeGen: правят `project.yml` + `xcodegen generate`, не руками.
- Никакой миграции старого `settings.json`: реальных пользователей нет, пишем новую модель напрямую.
- **`.tmTheme` (plist) — обязательная поддержка**, не запасной вариант: активные темы редакторов реально в этом формате. Молчаливого пропуска формата быть не должно.
- TDD строго: падающий тест → запуск (падает) → реализация → запуск (зелёный) → коммит, по одному маленькому шагу.
- Копирайт UI — от пользователя, не от кода («просмотр», не «перехват»).
- Коммиты по-русски: `feat(scope): …` / `fix` / `refactor` / `test` / `docs`; трейлер `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`. Ветка: `feat/editor-theme-font-import`.
- Не трогать `.mcp.json` и `.code-index/` — они пользователя.

## Слой ↔ модуль (куда что кладём)

- `QuickLookersImportKit` (deps: CLibArchive) — `JSONCParser`, `ThemeFileLoader`. Низший уровень, тесты с фикстурами.
- Новый `QuickLookersEditorKit` (deps: QuickLookersImportKit) — `DetectedEditor`/`EditorScanner`, `EditorPreferences`/`EditorSettingsReader`, `EditorThemeResolver`. Чистый, хост-сторона.
- `QuickLookersSettingsKit` (deps: QuickLookersImportKit) — модель: `FontSettings`, `ManagerSettings.activeThemeId` (вместо `ThemeSelection`), обновлённый `SettingsStore`.
- `QuickLookersPreviewKit` (deps: QuickLookersEngine) — `previewPageHTML(font…)`, шрифт в `HTMLCacheKey`. Шрифт передаём примитивами (`fontFamily`/`fontSize`), чтобы не тащить SettingsKit в PreviewKit.
- `QuickLookersEngine` — без изменений API; используется в тесте-де-риске (Task 1) и в живом превью приложения.
- Слой приложения `App/` — `BookmarkStore`, меню «Из редактора», живое превью (WKWebView), новая `ThemesTab`, размеры окна, `SettingsModel`, `ImportModel.importFromEditor`.
- `PreviewExtension/PreviewViewController.swift` — читает `activeThemeId` + шрифт.

---

### Task 1: Де-риск `.tmTheme` — движок рисует тему в целевой форме конвертации

Снимаем главный риск ПЕРВЫМ: доказываем, что Shiki рисует тему в той форме, в которую мы будем конвертировать `.tmTheme` — канонический VS Code-JSON с `tokenColors`, где первый бесскоупный элемент несёт `background`/`foreground` (ровно так раскладывается массив `settings` из tmTheme).

**Files:**
- Test: `Tests/QuickLookersEngineTests/TmThemeShapeRenderTests.swift` (создать)

**Interfaces:**
- Consumes: `QuickLookersEngineFactory.makeDefault(importedGrammarsDir:importedThemesDir:) throws -> HighlightEngine`; `HighlightRequest(code:languageId:themeId:)`; `HighlightEngine.highlightToHTML(_) throws -> String`. Тема резолвится из `importedThemesDir` по имени файла `<themeId>.json`.
- Produces: подтверждённую целевую форму темы `{ "name", "type", "tokenColors": [...] }` для Task 3.

- [ ] **Step 1: Написать падающий тест**

```swift
import XCTest
import Foundation
@testable import QuickLookersEngine

final class TmThemeShapeRenderTests: XCTestCase {
    /// Тема в форме, в которую конвертируется .tmTheme (массив settings → tokenColors,
    /// первый бесскоупный элемент несёт background/foreground). Если рисуется —
    /// значит выбранная форма конвертации верна.
    func testEngineRendersTokenColorsThemeWithScopelessRoot() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("ql-tmtheme-\(UUID().uuidString)")
        let themesDir = tmp.appendingPathComponent("themes")
        try FileManager.default.createDirectory(at: themesDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let themeJSON = """
        {
          "name": "TmTest",
          "type": "dark",
          "tokenColors": [
            { "settings": { "background": "#102030", "foreground": "#eeeeee" } },
            { "scope": "string", "settings": { "foreground": "#88ff88" } }
          ]
        }
        """
        try Data(themeJSON.utf8).write(to: themesDir.appendingPathComponent("tmtest.json"))

        let engine = try QuickLookersEngineFactory.makeDefault(importedThemesDir: themesDir)
        let html = try engine.highlightToHTML(
            HighlightRequest(code: "{\"a\": \"b\"}", languageId: "json", themeId: "tmtest"))

        XCTAssertFalse(html.isEmpty)
        // Shiki вшивает фон темы в инлайновый стиль <pre> — проверяем, что наш фон применился.
        XCTAssertTrue(html.lowercased().contains("#102030"),
                      "Фон темы не применился — форма конвертации не принята движком: \(html.prefix(400))")
    }
}
```

- [ ] **Step 2: Запустить — убедиться, что падает (по нужной причине)**

Run: `swift test --filter TmThemeShapeRenderTests`
Expected: тест компилируется и **запускается**. Если он КРАСНЫЙ из-за того, что фон `#102030` не найден — это сигнал, что Shiki не принял форму `tokenColors`-с-бесскоупным-рутом. Тогда (и только тогда) подобрать рабочую форму: вынести фон/передний план в `"colors": { "editor.background": "#102030", "editor.foreground": "#eeeeee" }` рядом с `tokenColors`, и обновить ассерт/форму. Зафиксировать рабочую форму в комментарии теста — её использует Task 3.

- [ ] **Step 3: Сделать тест зелёным**

Менять реализацию движка НЕ нужно — задача исследовательская. Зелёный достигается подбором формы темы в фикстуре теста (Step 2). Как только тест зелёный — рабочая форма зафиксирована.

- [ ] **Step 4: Запустить — зелёный**

Run: `swift test --filter TmThemeShapeRenderTests`
Expected: PASS.

- [ ] **Step 5: Коммит**

```bash
git add Tests/QuickLookersEngineTests/TmThemeShapeRenderTests.swift
git commit -m "test(engine): де-риск .tmTheme — движок рисует целевую форму темы

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: `JSONCParser` — устойчивый разбор JSONC

`settings.json` редакторов и часть тем — JSONC (комментарии, висячие запятые). Нужен разбор с учётом строк.

**Files:**
- Create: `Sources/QuickLookersImportKit/JSONCParser.swift`
- Test: `Tests/QuickLookersImportKitTests/JSONCParserTests.swift`

**Interfaces:**
- Produces: `enum JSONCParser { static func toStrictJSON(_ data: Data) throws -> Data; static func object(from data: Data) throws -> Any }`. Ошибка: `enum JSONCError: Error { case invalid }`.

- [ ] **Step 1: Написать падающий тест**

```swift
import XCTest
@testable import QuickLookersImportKit

final class JSONCParserTests: XCTestCase {
    private func parse(_ s: String) throws -> [String: Any] {
        try JSONCParser.object(from: Data(s.utf8)) as! [String: Any]
    }

    func testLineComments() throws {
        let o = try parse("""
        {
          // активная тема
          "workbench.colorTheme": "Seti Monokai: Original", // хвостовой коммент
          "editor.fontSize": 13
        }
        """)
        XCTAssertEqual(o["workbench.colorTheme"] as? String, "Seti Monokai: Original")
        XCTAssertEqual(o["editor.fontSize"] as? Double, 13)
    }

    func testBlockCommentsAndTrailingCommas() throws {
        let o = try parse("""
        {
          /* блок
             комментарий */
          "a": 1,
          "b": [1, 2, 3,],
        }
        """)
        XCTAssertEqual(o["a"] as? Double, 1)
        XCTAssertEqual((o["b"] as? [Any])?.count, 3)
    }

    func testSlashesAndCommasInsideStringsArePreserved() throws {
        let o = try parse(#"{ "url": "https://x/y", "path": "a,b//c", "q": "he said \"hi\"" }"#)
        XCTAssertEqual(o["url"] as? String, "https://x/y")
        XCTAssertEqual(o["path"] as? String, "a,b//c")
        XCTAssertEqual(o["q"] as? String, "he said \"hi\"")
    }

    func testRawControlCharInStringDoesNotCrash() throws {
        // Реальные settings.json иногда несут сырой таб внутри строки.
        let o = try parse("{ \"x\": \"a\tb\" }")
        XCTAssertNotNil(o["x"] as? String)
    }

    func testToStrictJSONProducesParseableJSON() throws {
        let strict = try JSONCParser.toStrictJSON(Data("{ \"a\": 1, } // x".utf8))
        let o = try JSONSerialization.jsonObject(with: strict) as! [String: Any]
        XCTAssertEqual(o["a"] as? Double, 1)
    }
}
```

- [ ] **Step 2: Запустить — убедиться, что падает**

Run: `swift test --filter JSONCParserTests`
Expected: FAIL — `JSONCParser` не определён.

- [ ] **Step 3: Реализация**

```swift
import Foundation

public enum JSONCError: Error { case invalid }

/// Разбор JSONC (JSON с комментариями и висячими запятыми), как у settings.json VS Code.
/// Удаляет // и /* */ комментарии и висячие запятые С УЧЁТОМ строковых литералов;
/// экранирует сырые управляющие символы внутри строк, чтобы JSONSerialization не падал.
public enum JSONCParser {
    public static func object(from data: Data) throws -> Any {
        let strict = try toStrictJSON(data)
        guard let obj = try? JSONSerialization.jsonObject(with: strict, options: [.fragmentsAllowed]) else {
            throw JSONCError.invalid
        }
        return obj
    }

    public static func toStrictJSON(_ data: Data) throws -> Data {
        guard let s = String(data: data, encoding: .utf8) else { throw JSONCError.invalid }
        var out = String(); out.reserveCapacity(s.count)
        var inString = false
        var escape = false
        var i = s.startIndex
        while i < s.endIndex {
            let c = s[i]
            if inString {
                if escape {
                    out.append(c); escape = false
                } else if c == "\\" {
                    out.append(c); escape = true
                } else if c == "\"" {
                    out.append(c); inString = false
                } else if let scalar = c.unicodeScalars.first, scalar.value < 0x20 {
                    // Сырой управляющий символ внутри строки → экранируем.
                    switch c { case "\n": out += "\\n"; case "\t": out += "\\t"; case "\r": out += "\\r"
                    default: out += String(format: "\\u%04x", scalar.value) }
                } else {
                    out.append(c)
                }
                i = s.index(after: i); continue
            }
            // Вне строки.
            if c == "\"" { inString = true; out.append(c); i = s.index(after: i); continue }
            let next = s.index(after: i)
            if c == "/" && next < s.endIndex && s[next] == "/" {
                // Строчный комментарий до конца строки.
                i = next
                while i < s.endIndex && s[i] != "\n" { i = s.index(after: i) }
                continue
            }
            if c == "/" && next < s.endIndex && s[next] == "*" {
                // Блочный комментарий.
                i = s.index(after: next)
                while i < s.endIndex {
                    if s[i] == "*", s.index(after: i) < s.endIndex, s[s.index(after: i)] == "/" {
                        i = s.index(i, offsetBy: 2); break
                    }
                    i = s.index(after: i)
                }
                continue
            }
            out.append(c)
            i = next
        }
        // Висячие запятые: ,  } или ,  ] (с любыми пробелами между).
        let stripped = stripTrailingCommas(out)
        return Data(stripped.utf8)
    }

    private static func stripTrailingCommas(_ s: String) -> String {
        var out = String(); out.reserveCapacity(s.count)
        var inString = false, escape = false
        let chars = Array(s)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if inString {
                out.append(c)
                if escape { escape = false }
                else if c == "\\" { escape = true }
                else if c == "\"" { inString = false }
                i += 1; continue
            }
            if c == "\"" { inString = true; out.append(c); i += 1; continue }
            if c == "," {
                // Заглянуть вперёд: если следующий значимый символ — } или ], запятую выбросить.
                var j = i + 1
                while j < chars.count, chars[j] == " " || chars[j] == "\n" || chars[j] == "\t" || chars[j] == "\r" { j += 1 }
                if j < chars.count, chars[j] == "}" || chars[j] == "]" { i += 1; continue }
            }
            out.append(c); i += 1
        }
        return out
    }
}
```

- [ ] **Step 4: Запустить — зелёный**

Run: `swift test --filter JSONCParserTests`
Expected: PASS (все 5).

- [ ] **Step 5: Коммит**

```bash
git add Sources/QuickLookersImportKit/JSONCParser.swift Tests/QuickLookersImportKitTests/JSONCParserTests.swift
git commit -m "feat(import): JSONCParser — устойчивый разбор JSONC настроек и тем

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2b: Подключить `JSONCParser` к чтению тем `.vsix` (закрыть латентную дыру)

Сейчас тема из `.vsix` хранится как есть; JSONC-тема сломала бы движок. Прогоняем тему через `JSONCParser.toStrictJSON` перед нормализацией.

**Files:**
- Modify: `Sources/QuickLookersImportKit/VsixImporter.swift:33-44` (блок «Темы»)
- Test: `Tests/QuickLookersImportKitTests/VsixImporterTests.swift` (дополнить; если файла нет — создать)

**Interfaces:**
- Consumes: `JSONCParser.toStrictJSON(_:)` (Task 2).

- [ ] **Step 1: Падающий тест** — собрать минимальный `.vsix`-`Data` с темой-JSONC (комментарий внутри theme.json) и проверить, что импорт даёт тему, а её `json` парсится строгим `JSONSerialization`. (Использовать существующий способ сборки фикстур из `VsixImporterTests`; если такого нет — собрать ZIP через `ZipReader`-совместимый фикстур-хелпер, как в имеющихся тестах ImportKit.)

```swift
func testThemeJSONCIsNormalizedToStrictJSON() throws {
    // vsixData: extension/package.json со contributes.themes[0]={label,path,uiTheme},
    //           extension/themes/t.json с // комментарием.
    let result = try VsixImporter(bundledGrammarsDir: Self.bundledGrammars)(vsixData: Self.vsixWithJSONCTheme)
    let theme = try XCTUnwrap(result.artifacts.first { $0.kind == .theme })
    XCTAssertNoThrow(try JSONSerialization.jsonObject(with: theme.json))
}
```

- [ ] **Step 2: Запустить — падает** (тема хранится с комментарием → `JSONSerialization` бросает).
Run: `swift test --filter VsixImporterTests/testThemeJSONCIsNormalizedToStrictJSON`
Expected: FAIL.

- [ ] **Step 3: Реализация** — в цикле тем `VsixImporter.callAsFunction` прогнать сырьё через JSONC:

```swift
for t in manifest.themes {
    guard let raw = readEntry(t.path, in: vsixData) else {
        skips.append(.init(item: "тема «\(t.label)»", reason: "нет файла \(t.path)")); continue
    }
    // Темы расширений бывают JSONC → приводим к строгому JSON перед хранением/движком.
    let strict = (try? JSONCParser.toStrictJSON(raw)) ?? raw
    let n = ThemeNormalizer.normalize(label: t.label, uiTheme: t.uiTheme,
                                      themeJSON: strict, existingSlugs: themeSlugs)
    guard isSafeImportID(n.id) else {
        skips.append(.init(item: "тема «\(t.label)»", reason: "недопустимый идентификатор")); continue
    }
    themeSlugs.insert(n.id)
    artifacts.append(.init(kind: .theme, id: n.id, displayName: n.displayName,
                           isDark: n.isDark, json: n.json))
}
```

- [ ] **Step 4: Запустить — зелёный** (и весь ImportKit не сломан).
Run: `swift test --filter QuickLookersImportKitTests`
Expected: PASS.

- [ ] **Step 5: Коммит**

```bash
git add Sources/QuickLookersImportKit/VsixImporter.swift Tests/QuickLookersImportKitTests/VsixImporterTests.swift
git commit -m "fix(import): темы .vsix приводим к строгому JSON через JSONCParser

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: `ThemeFileLoader` — `.json`/`.jsonc` и `.tmTheme` → строгий JSON темы

**Files:**
- Create: `Sources/QuickLookersImportKit/ThemeFileLoader.swift`
- Test: `Tests/QuickLookersImportKitTests/ThemeFileLoaderTests.swift`
- Fixtures: `Tests/QuickLookersImportKitTests/Fixtures/themes/sample.tmTheme`, `Tests/QuickLookersImportKitTests/Fixtures/themes/sample.json` (создать)

**Interfaces:**
- Consumes: `JSONCParser.toStrictJSON(_:)` (Task 2); целевая форма темы из Task 1.
- Produces: `enum ThemeFileLoader { static func loadStrictThemeJSON(data: Data, fileExtension: String, uiTheme: String) throws -> Data }`. Ошибка: `enum ThemeFileError: Error { case badPlist, badJSON }`. `uiTheme` → поле `type` (`vs-dark`/`hc-black` → `"dark"`, иначе `"light"`).

- [ ] **Step 1: Создать фикстуры**

`Fixtures/themes/sample.tmTheme` (минимальный TextMate plist):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>name</key><string>Sample TM</string>
  <key>settings</key>
  <array>
    <dict>
      <key>settings</key>
      <dict>
        <key>background</key><string>#101010</string>
        <key>foreground</key><string>#fafafa</string>
      </dict>
    </dict>
    <dict>
      <key>scope</key><string>comment</string>
      <key>settings</key>
      <dict><key>foreground</key><string>#55aa55</string></dict>
    </dict>
  </array>
</dict>
</plist>
```

`Fixtures/themes/sample.json` (VS Code-JSON с комментарием — проверяем JSONC-путь):

```json
{
  // образец
  "name": "Sample JSON",
  "type": "dark",
  "colors": { "editor.background": "#001122" },
  "tokenColors": [ { "scope": "keyword", "settings": { "foreground": "#cc66cc" } } ],
}
```

- [ ] **Step 2: Падающий тест**

```swift
import XCTest
@testable import QuickLookersImportKit

final class ThemeFileLoaderTests: XCTestCase {
    private func fixture(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "themes/\(name)", withExtension: nil))
        return try Data(contentsOf: url)
    }

    func testLoadsJSONCThemeToStrictJSON() throws {
        let out = try ThemeFileLoader.loadStrictThemeJSON(
            data: fixture("sample.json"), fileExtension: "json", uiTheme: "vs-dark")
        let o = try JSONSerialization.jsonObject(with: out) as! [String: Any]
        XCTAssertEqual((o["colors"] as? [String: Any])?["editor.background"] as? String, "#001122")
        XCTAssertNotNil(o["tokenColors"])
    }

    func testConvertsTmThemeToTokenColorsShape() throws {
        let out = try ThemeFileLoader.loadStrictThemeJSON(
            data: fixture("sample.tmTheme"), fileExtension: "tmTheme", uiTheme: "vs-dark")
        let o = try JSONSerialization.jsonObject(with: out) as! [String: Any]
        XCTAssertEqual(o["type"] as? String, "dark")
        let tokens = try XCTUnwrap(o["tokenColors"] as? [[String: Any]])
        XCTAssertEqual(tokens.count, 2)
        // Первый — бесскоупный рут с background/foreground.
        let root = try XCTUnwrap(tokens.first?["settings"] as? [String: Any])
        XCTAssertEqual(root["background"] as? String, "#101010")
        XCTAssertEqual(tokens[1]["scope"] as? String, "comment")
    }

    func testBadPlistThrows() throws {
        XCTAssertThrowsError(try ThemeFileLoader.loadStrictThemeJSON(
            data: Data("not a plist".utf8), fileExtension: "tmTheme", uiTheme: "vs-dark"))
    }
}
```

- [ ] **Step 3: Запустить — падает**
Run: `swift test --filter ThemeFileLoaderTests`
Expected: FAIL — `ThemeFileLoader` не определён.

- [ ] **Step 4: Реализация**

```swift
import Foundation

public enum ThemeFileError: Error { case badPlist, badJSON }

/// Приводит файл темы (из расширения редактора или .vsix) к строгому VS Code-JSON,
/// пригодному для ThemeNormalizer и движка. .json/.jsonc — через JSONCParser;
/// .tmTheme/.plist — plist → { name, type, tokenColors:[...] } (массив settings TextMate
/// раскладывается в tokenColors; первый бесскоупный элемент несёт background/foreground).
public enum ThemeFileLoader {
    public static func loadStrictThemeJSON(data: Data, fileExtension: String, uiTheme: String) throws -> Data {
        let ext = fileExtension.lowercased()
        if ext == "tmtheme" || ext == "plist" {
            return try convertTmTheme(data, uiTheme: uiTheme)
        }
        // .json / .jsonc / прочее → терпимый разбор в строгий JSON.
        do { return try JSONCParser.toStrictJSON(data) }
        catch { throw ThemeFileError.badJSON }
    }

    private static func convertTmTheme(_ data: Data, uiTheme: String) throws -> Data {
        guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let dict = plist as? [String: Any] else { throw ThemeFileError.badPlist }
        let name = dict["name"] as? String ?? "Imported Theme"
        let settings = dict["settings"] as? [[String: Any]] ?? []
        let type = (uiTheme == "vs-dark" || uiTheme == "hc-black") ? "dark" : "light"
        let theme: [String: Any] = ["name": name, "type": type, "tokenColors": settings]
        guard let out = try? JSONSerialization.data(withJSONObject: theme) else { throw ThemeFileError.badPlist }
        return out
    }
}
```

- [ ] **Step 5: Запустить — зелёный**
Run: `swift test --filter ThemeFileLoaderTests`
Expected: PASS (3).

- [ ] **Step 6: Коммит**

```bash
git add Sources/QuickLookersImportKit/ThemeFileLoader.swift Tests/QuickLookersImportKitTests/ThemeFileLoaderTests.swift Tests/QuickLookersImportKitTests/Fixtures/themes
git commit -m "feat(import): ThemeFileLoader — .json/.jsonc и .tmTheme → строгий JSON темы

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

#### Step 7: `ThemeNormalizer` переписывает `name` темы на её id (важно!)

Найдено при де-риске (Task 1): движок регистрирует тему под её JSON-полем `name`
(`qlRegisterTheme` → `themes.set(theme.name, …)`), а ищет по id (`qlHighlight(themeName=id)`).
Встроенные темы имеют `name == id`. Импортированная тема хранится под id-слагом, но её
исходный `name` другой → движок выдаёт `theme not registered`. Значит при нормализации
надо вписать `name = id`. Это чинит и латентный баг текущего `.vsix`-импорта.

- [ ] **Step 7a: Падающий тест** — `Tests/QuickLookersImportKitTests/ThemeNormalizerTests.swift` (дополнить/создать):

```swift
func testNormalizeRewritesNameToId() throws {
    let raw = Data(#"{ "name": "Seti Monokai: Original", "type": "dark", "tokenColors": [] }"#.utf8)
    let n = ThemeNormalizer.normalize(label: "Seti Monokai: Original", uiTheme: "vs-dark",
                                      themeJSON: raw, existingSlugs: [])
    let obj = try JSONSerialization.jsonObject(with: n.json) as! [String: Any]
    XCTAssertEqual(obj["name"] as? String, n.id)   // name == id, иначе движок не найдёт тему
}
```

- [ ] **Step 7b: Запустить — падает** (`name` пока исходный).
Run: `swift test --filter ThemeNormalizerTests/testNormalizeRewritesNameToId`
Expected: FAIL.

- [ ] **Step 7c: Реализация** — в `ThemeNormalizer.normalize`, перед `return`, переписать `name`:

```swift
let finalJSON = Self.withName(themeJSON, id) ?? themeJSON
return NormalizedTheme(id: id, displayName: label, isDark: isDark(uiTheme: uiTheme), json: finalJSON)
```

и приватный хелпер:

```swift
/// Вписывает name = id в JSON темы (движок регистрирует тему по её name, а ищет по id).
private static func withName(_ data: Data, _ id: String) -> Data? {
    guard var obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
    obj["name"] = id
    return try? JSONSerialization.data(withJSONObject: obj)
}
```

- [ ] **Step 7d: Запустить — зелёный** (и весь ImportKit).
Run: `swift test --filter QuickLookersImportKitTests`
Expected: PASS.

- [ ] **Step 7e: Коммит**

```bash
git add Sources/QuickLookersImportKit/ThemeNormalizer.swift Tests/QuickLookersImportKitTests/ThemeNormalizerTests.swift
git commit -m "fix(import): ThemeNormalizer вписывает name=id — иначе движок не находит тему

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: Модель — `FontSettings` + `ManagerSettings.activeThemeId` (вместо `ThemeSelection`)

Упрощаем выбор темы до одного id, добавляем шрифт, обновляем хранилище. Без миграции.

**Files:**
- Modify: `Sources/QuickLookersSettingsKit/ManagerSettings.swift` (целиком)
- Modify: `Sources/QuickLookersSettingsKit/SettingsStore.swift:33-39` (резолвер темы)
- Test: `Tests/QuickLookersSettingsKitTests/ManagerSettingsTests.swift` (дополнить/создать)

**Interfaces:**
- Produces:
  - `struct FontSettings: Codable, Equatable { var family: String?; var size: Double?; init(family:size:) }`
  - `ManagerSettings { var schemaVersion; var settingsVersion; var disabledLanguageIds: Set<String>; var activeThemeId: String; var font: FontSettings; var previewDisabledLanguageIds: Set<String> }`, `static let default` с `activeThemeId = DefaultThemeIds.dark`, `font = FontSettings(family: nil, size: nil)`.
  - `func resolvedThemeId(activeThemeId: String, availableThemeIds: Set<String>) -> String` (откат на `DefaultThemeIds.dark`).
  - `enum DefaultThemeIds` — сохранить.
- Consumes (далее): расширение (Task 6), приложение (Task 11–12).

- [ ] **Step 1: Падающий тест**

```swift
import XCTest
@testable import QuickLookersSettingsKit

final class ManagerSettingsTests: XCTestCase {
    func testDefaults() {
        let s = ManagerSettings.default
        XCTAssertEqual(s.activeThemeId, DefaultThemeIds.dark)
        XCTAssertNil(s.font.family)
        XCTAssertNil(s.font.size)
    }
    func testCodableRoundTrip() throws {
        var s = ManagerSettings.default
        s.activeThemeId = "github-dark"
        s.font = FontSettings(family: "JetBrains Mono", size: 13)
        let data = try JSONEncoder().encode(s)
        let back = try JSONDecoder().decode(ManagerSettings.self, from: data)
        XCTAssertEqual(back, s)
    }
    func testThemeFallbackWhenMissing() {
        XCTAssertEqual(resolvedThemeId(activeThemeId: "ghost", availableThemeIds: ["dark-plus"]),
                       DefaultThemeIds.dark)
        XCTAssertEqual(resolvedThemeId(activeThemeId: "github-dark", availableThemeIds: ["github-dark"]),
                       "github-dark")
    }
}
```

- [ ] **Step 2: Запустить — падает**
Run: `swift test --filter ManagerSettingsTests`
Expected: FAIL (нет `activeThemeId`/`FontSettings`/нового `resolvedThemeId`).

- [ ] **Step 3: Реализация — `ManagerSettings.swift` целиком**

```swift
/// Дефолтные id встроенных тем VS Code.
public enum DefaultThemeIds {
    public static let light = "light-plus"
    public static let dark = "dark-plus"
}

/// Шрифт превью. nil = умолчание движка (текущий моноширинный стек / размер).
public struct FontSettings: Codable, Equatable {
    public var family: String?
    public var size: Double?
    public init(family: String?, size: Double?) { self.family = family; self.size = size }
}

/// Настройки менеджера. Модель opt-out: храним выключенное, пусто = всё включено.
public struct ManagerSettings: Codable, Equatable {
    public var schemaVersion: Int
    public var settingsVersion: Int
    public var disabledLanguageIds: Set<String>
    public var activeThemeId: String
    public var font: FontSettings
    public var previewDisabledLanguageIds: Set<String>

    public init(schemaVersion: Int, settingsVersion: Int, disabledLanguageIds: Set<String>,
                activeThemeId: String, font: FontSettings, previewDisabledLanguageIds: Set<String>) {
        self.schemaVersion = schemaVersion
        self.settingsVersion = settingsVersion
        self.disabledLanguageIds = disabledLanguageIds
        self.activeThemeId = activeThemeId
        self.font = font
        self.previewDisabledLanguageIds = previewDisabledLanguageIds
    }

    public static let currentSchemaVersion = 1

    public static let `default` = ManagerSettings(
        schemaVersion: currentSchemaVersion,
        settingsVersion: 0,
        disabledLanguageIds: [],
        activeThemeId: DefaultThemeIds.dark,
        font: FontSettings(family: nil, size: nil),
        previewDisabledLanguageIds: []
    )
}
```

- [ ] **Step 4: Реализация — заменить резолвер в `SettingsStore.swift`** (строки 33-39):

```swift
/// id темы с откатом на тёмную по умолчанию, если выбранного нет в каталоге.
public func resolvedThemeId(activeThemeId: String, availableThemeIds: Set<String>) -> String {
    availableThemeIds.contains(activeThemeId) ? activeThemeId : DefaultThemeIds.dark
}
```

- [ ] **Step 5: Запустить — зелёный (весь SettingsKit)**
Run: `swift test --filter QuickLookersSettingsKitTests`
Expected: PASS. (Если в существующих тестах есть ссылки на `theme`/`ThemeSelection` — обновить их на `activeThemeId`.)

- [ ] **Step 6: Коммит**

```bash
git add Sources/QuickLookersSettingsKit/ManagerSettings.swift Sources/QuickLookersSettingsKit/SettingsStore.swift Tests/QuickLookersSettingsKitTests/ManagerSettingsTests.swift
git commit -m "feat(settings): activeThemeId + FontSettings вместо ThemeSelection

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 5: `previewPageHTML` — шрифт и размер + санитизация; шрифт в `HTMLCacheKey`

**Files:**
- Modify: `Sources/QuickLookersPreviewKit/PreviewPage.swift`
- Modify: `Sources/QuickLookersPreviewKit/HTMLCache.swift` (поля `HTMLCacheKey`)
- Test: `Tests/QuickLookersPreviewKitTests/PreviewPageTests.swift` (дополнить/создать)
- Test: `Tests/QuickLookersPreviewKitTests/HTMLCacheTests.swift` (дополнить — ключ зависит от шрифта)

**Interfaces:**
- Produces:
  - `func previewPageHTML(highlighted: String, fontFamily: String?, fontSize: Double?, truncatedNotice: String? = nil) -> String`
  - `func sanitizedFontFamily(_ raw: String?) -> String?` (internal, тестируемо через `@testable`)
  - `HTMLCacheKey(... , fontFamily: String?, fontSize: Double?, ...)`
- Consumes (далее): расширение (Task 6) и живое превью приложения (Task 12) передают примитивы из `settings.font`.

- [ ] **Step 1: Падающий тест (PreviewPage)**

```swift
import XCTest
@testable import QuickLookersPreviewKit

final class PreviewPageTests: XCTestCase {
    func testInjectsFamilyAndSize() {
        let html = previewPageHTML(highlighted: "<pre class=\"shiki\"></pre>",
                                   fontFamily: "JetBrains Mono", fontSize: 15)
        XCTAssertTrue(html.contains("font-family: \"JetBrains Mono\", ui-monospace, monospace"))
        XCTAssertTrue(html.contains("font-size: 15px"))
    }
    func testNilFontKeepsDefaults() {
        let html = previewPageHTML(highlighted: "x", fontFamily: nil, fontSize: nil)
        XCTAssertTrue(html.contains("ui-monospace"))
        XCTAssertFalse(html.contains("font-size: 0"))
    }
    func testSanitizesDangerousFamily() {
        let s = sanitizedFontFamily("Evil</style><script>;{}")
        XCTAssertNotNil(s)
        XCTAssertFalse(s!.contains("<"))
        XCTAssertFalse(s!.contains("{"))
        XCTAssertFalse(s!.contains(";"))
    }
    func testRejectsAbsurdSize() {
        let html = previewPageHTML(highlighted: "x", fontFamily: nil, fontSize: 9999)
        XCTAssertFalse(html.contains("9999"))   // вне диапазона → размер не подставлен
    }
}
```

- [ ] **Step 2: Запустить — падает**
Run: `swift test --filter PreviewPageTests`
Expected: FAIL — новой сигнатуры/`sanitizedFontFamily` нет.

- [ ] **Step 3: Реализация — `PreviewPage.swift`**

```swift
/// Безопасное для CSS семейство шрифта: только буквы/цифры/пробел/-/_/,/'/" .
/// Возвращает nil, если после чистки пусто.
func sanitizedFontFamily(_ raw: String?) -> String? {
    guard let raw else { return nil }
    let allowed = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 -_,'\"")
    let cleaned = String(raw.filter { allowed.contains($0) }).trimmingCharacters(in: .whitespaces)
    return cleaned.isEmpty ? nil : cleaned
}

public func previewPageHTML(highlighted: String, fontFamily: String?, fontSize: Double?,
                            truncatedNotice: String? = nil) -> String {
    let family = sanitizedFontFamily(fontFamily)
    let familyCSS = family.map { "\($0), ui-monospace, monospace" } ?? "ui-monospace, \"SF Mono\", Menlo, monospace"
    let size = (fontSize.flatMap { (6...48).contains(Int($0)) ? Int($0) : nil }) ?? 12

    let notice = truncatedNotice.map { #"<div class="ql-truncated">\#($0)</div>"# } ?? ""
    let truncatedStyle = truncatedNotice != nil ? """
        .ql-truncated {
            padding: 8px 12px;
            font-family: -apple-system, system-ui, sans-serif;
            font-size: 11px;
            color: #888;
            text-align: center;
        }
        """ : ""
    return """
    <!DOCTYPE html>
    <html>
    <head>
    <meta charset="utf-8">
    <style>
    html, body { margin: 0; padding: 0; }
    pre.shiki {
        margin: 0;
        padding: 12px;
        font-family: \(familyCSS);
        font-size: \(size)px;
        line-height: 1.5;
        tab-size: 4;
        white-space: pre-wrap;
        overflow-wrap: anywhere;
        word-break: break-word;
    }
    \(truncatedStyle)
    </style>
    </head>
    <body>
    \(highlighted)
    \(notice)
    </body>
    </html>
    """
}
```

- [ ] **Step 4: Падающий тест (ключ кэша зависит от шрифта)** — в `HTMLCacheTests` добавить:

```swift
func testCacheKeyDiffersByFont() {
    func key(_ family: String?, _ size: Double?) -> HTMLCacheKey {
        HTMLCacheKey(path: "/a", mtime: 1, size: 2, languageId: "swift", themeId: "dark-plus",
                     fontFamily: family, fontSize: size, maxLines: 2000, bundleVersion: "1")
    }
    XCTAssertNotEqual(key("Menlo", 13), key("Menlo", 14))
    XCTAssertNotEqual(key("Menlo", 13), key("SF Mono", 13))
    XCTAssertEqual(key("Menlo", 13), key("Menlo", 13))
}
```

- [ ] **Step 5: Запустить — падает** (у `HTMLCacheKey` нет полей шрифта).
Run: `swift test --filter HTMLCacheTests/testCacheKeyDiffersByFont`
Expected: FAIL.

- [ ] **Step 6: Реализация — добавить в `HTMLCacheKey`** поля `fontFamily: String?`, `fontSize: Double?` (в инициализатор и в строку, по которой считается идентичность/хэш ключа — найти, как ключ формирует свою каноническую строку, и дописать туда `fontFamily ?? "-"` и `fontSize.map(String.init) ?? "-"`).

- [ ] **Step 7: Запустить — зелёный (весь PreviewKit)**
Run: `swift test --filter QuickLookersPreviewKitTests`
Expected: PASS.

- [ ] **Step 8: Коммит**

```bash
git add Sources/QuickLookersPreviewKit Tests/QuickLookersPreviewKitTests
git commit -m "feat(preview): шрифт и размер в previewPageHTML + ключ кэша

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 6: Расширение читает `activeThemeId` + шрифт

Подгоняем `PreviewViewController` под новую модель: тема по `activeThemeId`, шрифт в страницу и в ключ кэша.

**Files:**
- Modify: `PreviewExtension/PreviewViewController.swift:91-121`

**Interfaces:**
- Consumes: `resolvedThemeId(activeThemeId:availableThemeIds:)` (Task 4); `previewPageHTML(highlighted:fontFamily:fontSize:truncatedNotice:)` и `HTMLCacheKey(...fontFamily:fontSize:...)` (Task 5).

- [ ] **Step 1: Правка** — заменить блок резолва темы и формирования страницы:

```swift
let themeId = resolvedThemeId(activeThemeId: settings.activeThemeId,
                              availableThemeIds: try Self.themeIds())

let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
let mtime = (attrs[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
let size = (attrs[.size] as? Int) ?? 0
let key = HTMLCacheKey(path: url.path, mtime: mtime, size: size,
                       languageId: lang, themeId: themeId,
                       fontFamily: settings.font.family, fontSize: settings.font.size,
                       maxLines: Self.maxLines, bundleVersion: Self.bundleVersion)
```

и в ветке промаха кэша:

```swift
page = previewPageHTML(highlighted: fragment,
                       fontFamily: settings.font.family, fontSize: settings.font.size,
                       truncatedNotice: notice)
```

Переменная `isDark` для выбора темы больше не нужна — убрать строку `let isDark = …`, если она нигде не используется.

- [ ] **Step 2: Проверка сборки расширения**

```bash
xcodegen generate
xcodebuild -project QuickLookers.xcodeproj -scheme QuickLookers \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Живая проверка** — запустить хост из Xcode (⌘R), пробел в Finder на `.swift`/`.json` → превью рисуется активной темой; логи `/usr/bin/log stream --info --predicate 'subsystem == "com.quicklookers.preview"'` показывают `theme=…`.

- [ ] **Step 4: Коммит**

```bash
git add PreviewExtension/PreviewViewController.swift
git commit -m "feat(preview): расширение читает activeThemeId и шрифт из настроек

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 7: Новый модуль `QuickLookersEditorKit` + `EditorScanner`

**Files:**
- Modify: `Package.swift` (новый target + testTarget)
- Create: `Sources/QuickLookersEditorKit/DetectedEditor.swift`
- Create: `Sources/QuickLookersEditorKit/EditorScanner.swift`
- Test: `Tests/QuickLookersEditorKitTests/EditorScannerTests.swift`

**Interfaces:**
- Consumes: `JSONCParser.object(from:)` (Task 2) для чтения `product.json`.
- Produces:
  - `struct DetectedEditor: Equatable { let appURL: URL; let nameShort: String; let nameLong: String; let dataFolderName: String }`
  - `enum EditorScanner { static func scan(applicationsDir: URL) -> [DetectedEditor] }`

- [ ] **Step 1: Package.swift — добавить target** (deps: `QuickLookersImportKit`) и testTarget с `resources: [.copy("Fixtures")]`:

```swift
.target(
    name: "QuickLookersEditorKit",
    dependencies: ["QuickLookersImportKit"]
),
.testTarget(
    name: "QuickLookersEditorKitTests",
    dependencies: ["QuickLookersEditorKit"],
    resources: [.copy("Fixtures")]
),
```
И добавить продукт `.library(name: "QuickLookersEditorKit", targets: ["QuickLookersEditorKit"])`.

- [ ] **Step 2: Падающий тест + фикстуры**

Создать фикстурное дерево `Tests/QuickLookersEditorKitTests/Fixtures/Applications/`:
- `Code.app/Contents/Resources/app/product.json` → `{"nameShort":"Code","nameLong":"Visual Studio Code","applicationName":"code","dataFolderName":".vscode"}`
- `Cursor.app/Contents/Resources/app/product.json` → `{"nameShort":"Cursor","nameLong":"Cursor","applicationName":"cursor","dataFolderName":".cursor"}`
- `Safari.app/Contents/Resources/...` (без product.json — не редактор)
- `Broken.app/Contents/Resources/app/product.json` → `not json`

```swift
import XCTest
@testable import QuickLookersEditorKit

final class EditorScannerTests: XCTestCase {
    private var appsDir: URL {
        Bundle.module.url(forResource: "Fixtures/Applications", withExtension: nil)!
    }
    func testFindsVSCodeLikeEditorsOnly() {
        let found = EditorScanner.scan(applicationsDir: appsDir)
        let names = Set(found.map(\.nameShort))
        XCTAssertEqual(names, ["Code", "Cursor"])
    }
    func testFieldsParsed() {
        let cursor = EditorScanner.scan(applicationsDir: appsDir).first { $0.nameShort == "Cursor" }
        XCTAssertEqual(cursor?.dataFolderName, ".cursor")
        XCTAssertEqual(cursor?.nameLong, "Cursor")
    }
}
```

- [ ] **Step 3: Запустить — падает**
Run: `swift test --filter EditorScannerTests`
Expected: FAIL — модуль/типы не определены.

- [ ] **Step 4: Реализация**

`DetectedEditor.swift`:

```swift
import Foundation

public struct DetectedEditor: Equatable {
    public let appURL: URL
    public let nameShort: String     // папка под ~/Library/Application Support
    public let nameLong: String      // показываемое имя
    public let dataFolderName: String // ".vscode"/".cursor" → ~/<...>/extensions
    public init(appURL: URL, nameShort: String, nameLong: String, dataFolderName: String) {
        self.appURL = appURL; self.nameShort = nameShort
        self.nameLong = nameLong; self.dataFolderName = dataFolderName
    }
}
```

`EditorScanner.swift`:

```swift
import Foundation
import QuickLookersImportKit

/// Находит VS Code-подобные редакторы в каталоге приложений по product.json
/// (манифест сборки Code-OSS). Маркер: product.json парсится и содержит
/// nameShort + nameLong + dataFolderName. По bundleId НЕ ориентируемся
/// (у Cursor он com.todesktop.*).
public enum EditorScanner {
    public static func scan(applicationsDir: URL) -> [DetectedEditor] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(at: applicationsDir,
                  includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { return [] }
        var result: [DetectedEditor] = []
        for app in entries where app.pathExtension == "app" {
            let pj = app.appendingPathComponent("Contents/Resources/app/product.json")
            guard let data = try? Data(contentsOf: pj),
                  let obj = try? JSONCParser.object(from: data) as? [String: Any],
                  let nameShort = obj["nameShort"] as? String,
                  let nameLong = obj["nameLong"] as? String,
                  let dataFolderName = obj["dataFolderName"] as? String
            else { continue }
            result.append(DetectedEditor(appURL: app, nameShort: nameShort,
                                         nameLong: nameLong, dataFolderName: dataFolderName))
        }
        return result.sorted { $0.nameLong < $1.nameLong }
    }
}
```

- [ ] **Step 5: Запустить — зелёный**
Run: `swift test --filter EditorScannerTests`
Expected: PASS (2).

- [ ] **Step 6: Коммит**

```bash
git add Package.swift Sources/QuickLookersEditorKit Tests/QuickLookersEditorKitTests
git commit -m "feat(editor): QuickLookersEditorKit + EditorScanner по product.json

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 8: `EditorSettingsReader` — активная тема и шрифт из `settings.json`

**Files:**
- Create: `Sources/QuickLookersEditorKit/EditorSettingsReader.swift`
- Test: `Tests/QuickLookersEditorKitTests/EditorSettingsReaderTests.swift`
- Fixtures: `Tests/QuickLookersEditorKitTests/Fixtures/AppSupport/Code/User/settings.json` (JSONC)

**Interfaces:**
- Consumes: `JSONCParser.object(from:)` (Task 2); `DetectedEditor` (Task 7).
- Produces:
  - `struct EditorPreferences: Equatable { let colorThemeLabel: String?; let fontFamily: String?; let fontSize: Double? }`
  - `enum EditorSettingsReader { static func read(editor: DetectedEditor, appSupportDir: URL) -> EditorPreferences }`
    Папка настроек: `<appSupportDir>/<nameShort>/User/settings.json`, при отсутствии — `<nameLong>`; нет файла → все поля nil.

- [ ] **Step 1: Фикстура** `Fixtures/AppSupport/Code/User/settings.json`:

```json
{
  // тема и шрифт
  "workbench.colorTheme": "Seti Monokai: Original",
  "editor.fontFamily": "FiraCode Nerd Font, Menlo, monospace",
  "editor.fontSize": 13,
}
```

- [ ] **Step 2: Падающий тест**

```swift
import XCTest
@testable import QuickLookersEditorKit

final class EditorSettingsReaderTests: XCTestCase {
    private var appSupport: URL { Bundle.module.url(forResource: "Fixtures/AppSupport", withExtension: nil)! }
    private let code = DetectedEditor(appURL: URL(fileURLWithPath: "/x/Code.app"),
        nameShort: "Code", nameLong: "Visual Studio Code", dataFolderName: ".vscode")

    func testReadsThemeAndFont() {
        let p = EditorSettingsReader.read(editor: code, appSupportDir: appSupport)
        XCTAssertEqual(p.colorThemeLabel, "Seti Monokai: Original")
        XCTAssertEqual(p.fontFamily, "FiraCode Nerd Font, Menlo, monospace")
        XCTAssertEqual(p.fontSize, 13)
    }
    func testMissingEditorYieldsNils() {
        let ghost = DetectedEditor(appURL: URL(fileURLWithPath: "/x/Ghost.app"),
            nameShort: "Ghost", nameLong: "Ghost", dataFolderName: ".ghost")
        let p = EditorSettingsReader.read(editor: ghost, appSupportDir: appSupport)
        XCTAssertNil(p.colorThemeLabel); XCTAssertNil(p.fontFamily); XCTAssertNil(p.fontSize)
    }
}
```

- [ ] **Step 3: Запустить — падает**
Run: `swift test --filter EditorSettingsReaderTests`
Expected: FAIL.

- [ ] **Step 4: Реализация**

```swift
import Foundation
import QuickLookersImportKit

public struct EditorPreferences: Equatable {
    public let colorThemeLabel: String?
    public let fontFamily: String?
    public let fontSize: Double?
    public init(colorThemeLabel: String?, fontFamily: String?, fontSize: Double?) {
        self.colorThemeLabel = colorThemeLabel; self.fontFamily = fontFamily; self.fontSize = fontSize
    }
}

/// Читает <appSupportDir>/<nameShort|nameLong>/User/settings.json (JSONC) и
/// достаёт активную тему и шрифт. Любая ошибка/отсутствие → nil-поля.
public enum EditorSettingsReader {
    public static func read(editor: DetectedEditor, appSupportDir: URL) -> EditorPreferences {
        let fm = FileManager.default
        let candidates = [editor.nameShort, editor.nameLong]
        let url = candidates.lazy
            .map { appSupportDir.appendingPathComponent("\($0)/User/settings.json") }
            .first { fm.fileExists(atPath: $0.path) }
        guard let url,
              let data = try? Data(contentsOf: url),
              let obj = try? JSONCParser.object(from: data) as? [String: Any]
        else { return EditorPreferences(colorThemeLabel: nil, fontFamily: nil, fontSize: nil) }
        let size = (obj["editor.fontSize"] as? Double) ?? (obj["editor.fontSize"] as? Int).map(Double.init)
        return EditorPreferences(
            colorThemeLabel: obj["workbench.colorTheme"] as? String,
            fontFamily: obj["editor.fontFamily"] as? String,
            fontSize: size)
    }
}
```

- [ ] **Step 5: Запустить — зелёный**
Run: `swift test --filter EditorSettingsReaderTests`
Expected: PASS (2).

- [ ] **Step 6: Коммит**

```bash
git add Sources/QuickLookersEditorKit/EditorSettingsReader.swift Tests/QuickLookersEditorKitTests/EditorSettingsReaderTests.swift Tests/QuickLookersEditorKitTests/Fixtures/AppSupport
git commit -m "feat(editor): EditorSettingsReader — активная тема и шрифт из settings.json

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 9: `EditorThemeResolver` — тема по имени: каталог или расширение

**Files:**
- Create: `Sources/QuickLookersEditorKit/EditorThemeResolver.swift`
- Test: `Tests/QuickLookersEditorKitTests/EditorThemeResolverTests.swift`
- Fixtures: `Tests/QuickLookersEditorKitTests/Fixtures/extensions/pub.theme-x-0.0.1/package.json` (+ файл темы)

**Interfaces:**
- Produces:
  - `protocol ThemeCatalogLookup { func themeId(forDisplayName name: String) -> String? }`
  - `enum EditorThemeResolution: Equatable { case bundled(themeId: String); case custom(label: String, uiTheme: String, fileURL: URL); case notFound }`
  - `enum EditorThemeResolver { static func resolve(label: String, catalog: ThemeCatalogLookup, extensionsDir: URL) -> EditorThemeResolution }`
- Consumes (далее): слой приложения (Task 11) на `.custom` зовёт `ThemeFileLoader` + `ThemeNormalizer`.

- [ ] **Step 1: Фикстуры**

`Fixtures/extensions/pub.theme-x-0.0.1/package.json`:

```json
{
  "contributes": {
    "themes": [
      { "label": "Cool Dark", "uiTheme": "vs-dark", "path": "./themes/cool.json" }
    ]
  }
}
```
`Fixtures/extensions/pub.theme-x-0.0.1/themes/cool.json`: `{ "name": "Cool Dark", "type": "dark", "tokenColors": [] }`

- [ ] **Step 2: Падающий тест**

```swift
import XCTest
@testable import QuickLookersEditorKit

private struct StubCatalog: ThemeCatalogLookup {
    let map: [String: String]
    func themeId(forDisplayName name: String) -> String? { map[name] }
}

final class EditorThemeResolverTests: XCTestCase {
    private var extDir: URL { Bundle.module.url(forResource: "Fixtures/extensions", withExtension: nil)! }

    func testBundledByDisplayName() {
        let r = EditorThemeResolver.resolve(label: "Monokai",
            catalog: StubCatalog(map: ["Monokai": "monokai"]), extensionsDir: extDir)
        XCTAssertEqual(r, .bundled(themeId: "monokai"))
    }
    func testCustomFromExtensions() {
        let r = EditorThemeResolver.resolve(label: "Cool Dark",
            catalog: StubCatalog(map: [:]), extensionsDir: extDir)
        guard case let .custom(label, uiTheme, fileURL) = r else { return XCTFail("ожидался .custom: \(r)") }
        XCTAssertEqual(label, "Cool Dark")
        XCTAssertEqual(uiTheme, "vs-dark")
        XCTAssertTrue(fileURL.path.hasSuffix("themes/cool.json"))
    }
    func testNotFound() {
        let r = EditorThemeResolver.resolve(label: "Nope",
            catalog: StubCatalog(map: [:]), extensionsDir: extDir)
        XCTAssertEqual(r, .notFound)
    }
}
```

- [ ] **Step 3: Запустить — падает**
Run: `swift test --filter EditorThemeResolverTests`
Expected: FAIL.

- [ ] **Step 4: Реализация**

```swift
import Foundation
import QuickLookersImportKit

public protocol ThemeCatalogLookup {
    func themeId(forDisplayName name: String) -> String?
}

public enum EditorThemeResolution: Equatable {
    case bundled(themeId: String)
    case custom(label: String, uiTheme: String, fileURL: URL)
    case notFound
}

/// Сопоставляет активную тему редактора (по отображаемому имени) с нашим каталогом,
/// иначе ищет её в расширениях редактора (package.json → contributes.themes).
public enum EditorThemeResolver {
    public static func resolve(label: String, catalog: ThemeCatalogLookup,
                               extensionsDir: URL) -> EditorThemeResolution {
        if let id = catalog.themeId(forDisplayName: label) { return .bundled(themeId: id) }

        let fm = FileManager.default
        guard let exts = try? fm.contentsOfDirectory(at: extensionsDir,
                  includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { return .notFound }
        for ext in exts {
            let pkg = ext.appendingPathComponent("package.json")
            guard let data = try? Data(contentsOf: pkg),
                  let obj = try? JSONCParser.object(from: data) as? [String: Any],
                  let contributes = obj["contributes"] as? [String: Any],
                  let themes = contributes["themes"] as? [[String: Any]] else { continue }
            for t in themes {
                guard (t["label"] as? String) == label, let path = t["path"] as? String else { continue }
                let rel = path.hasPrefix("./") ? String(path.dropFirst(2)) : path
                let uiTheme = t["uiTheme"] as? String ?? "vs-dark"
                return .custom(label: label, uiTheme: uiTheme,
                               fileURL: ext.appendingPathComponent(rel))
            }
        }
        return .notFound
    }
}
```

- [ ] **Step 5: Запустить — зелёный**
Run: `swift test --filter EditorThemeResolverTests`
Expected: PASS (3).

- [ ] **Step 6: Коммит**

```bash
git add Sources/QuickLookersEditorKit/EditorThemeResolver.swift Tests/QuickLookersEditorKitTests/EditorThemeResolverTests.swift Tests/QuickLookersEditorKitTests/Fixtures/extensions
git commit -m "feat(editor): EditorThemeResolver — тема из каталога или расширения

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 10: `BookmarkStore` + entitlement `bookmarks.app-scope`

Доступ к `~` и `/Applications` через powerbox + app-scoped закладки. Слой приложения, проверяется живым запуском (NSOpenPanel модальный).

**Files:**
- Modify: `project.yml` (в entitlements ХОСТА добавить `com.apple.security.files.bookmarks.app-scope: true`)
- Create: `App/BookmarkStore.swift`
- Linkage: добавить `QuickLookersEditorKit` в зависимости таргета хоста в `project.yml`.

**Interfaces:**
- Produces:
  - `enum AccessScope { case home, applications }`
  - `@MainActor final class BookmarkStore { func accessURL(for: AccessScope) -> URL?; func withAccess<T>(_ scope: AccessScope, _ body: (URL) throws -> T) rethrows -> T? }`

- [ ] **Step 1: project.yml** — в блоке entitlements хоста (после строки 57) добавить:

```yaml
        com.apple.security.files.bookmarks.app-scope: true
```
и в `dependencies` таргета хоста добавить package-продукт `QuickLookersEditorKit` (рядом с уже подключёнными QuickLookers*Kit). Затем `xcodegen generate`.

- [ ] **Step 2: Реализация `App/BookmarkStore.swift`**

```swift
import Foundation
import AppKit

enum AccessScope {
    case home, applications
    var url: URL {
        switch self {
        case .home: return FileManager.default.homeDirectoryForCurrentUser
        case .applications: return URL(fileURLWithPath: "/Applications")
        }
    }
    var defaultsKey: String {
        switch self { case .home: return "bookmark.home"; case .applications: return "bookmark.applications" }
    }
    var prompt: String {
        switch self {
        case .home: return "Разрешите доступ к домашней папке — чтобы прочитать тему и шрифт редактора."
        case .applications: return "Разрешите доступ к папке «Программы» — чтобы найти установленные редакторы."
        }
    }
}

/// Хранит security-scoped закладки на ~ и /Applications. При отсутствии — запрашивает
/// доступ через NSOpenPanel (лениво, по требованию) и сохраняет app-scoped закладку.
@MainActor
final class BookmarkStore {
    func accessURL(for scope: AccessScope) -> URL? {
        if let url = resolveBookmark(scope) { return url }
        return requestAccess(scope)
    }

    /// Выполняет body с открытым доступом к scope (start/stop вокруг). nil — доступа нет.
    func withAccess<T>(_ scope: AccessScope, _ body: (URL) throws -> T) rethrows -> T? {
        guard let url = accessURL(for: scope) else { return nil }
        let ok = url.startAccessingSecurityScopedResource()
        defer { if ok { url.stopAccessingSecurityScopedResource() } }
        return try body(url)
    }

    private func resolveBookmark(_ scope: AccessScope) -> URL? {
        guard let data = UserDefaults.standard.data(forKey: scope.defaultsKey) else { return nil }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: [.withSecurityScope],
                                 relativeTo: nil, bookmarkDataIsStale: &stale) else { return nil }
        if stale { return requestAccess(scope) }
        return url
    }

    private func requestAccess(_ scope: AccessScope) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = scope.url
        panel.message = scope.prompt
        panel.prompt = "Разрешить"
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        if let data = try? url.bookmarkData(options: [.withSecurityScope],
                                            includingResourceValuesForKeys: nil, relativeTo: nil) {
            UserDefaults.standard.set(data, forKey: scope.defaultsKey)
        }
        return url
    }
}
```

- [ ] **Step 3: Проверка сборки**

```bash
xcodegen generate
xcodebuild -project QuickLookers.xcodeproj -scheme QuickLookers \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Коммит**

```bash
git add project.yml App/BookmarkStore.swift
git commit -m "feat(app): BookmarkStore — ленивые гранты на ~ и /Applications

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 11: Импорт из редактора — оркестрация (`ImportModel.importFromEditor`)

Связываем EditorKit + BookmarkStore + существующий конвейер тем. На `.custom` — `ThemeFileLoader` → `ThemeNormalizer` → `ImportedLibrary`. Затем применяем тему и шрифт.

**Files:**
- Modify: `App/ImportModel.swift` (добавить методы)
- Modify: `App/SettingsModel.swift` (хелпер `applyEditor(...)`/`setActiveTheme`/`setFont`, `ThemeCatalogLookup`-адаптер)

**Interfaces:**
- Consumes: `EditorScanner.scan`, `EditorSettingsReader.read`, `EditorThemeResolver.resolve` (Tasks 7–9); `BookmarkStore` (Task 10); `ThemeFileLoader.loadStrictThemeJSON`, `ThemeNormalizer.normalize`, `ImportedLibrary.write` (existing); `ManagerSettings.activeThemeId/font` (Task 4).
- Produces:
  - `ImportModel.scanEditors(_ store: BookmarkStore) -> [DetectedEditor]`
  - `ImportModel.importFromEditor(_ editor: DetectedEditor, store: BookmarkStore, catalog: ThemeCatalogLookup) -> EditorImportOutcome`
    где `struct EditorImportOutcome { let themeId: String?; let font: FontSettings; let message: String? }`.

- [ ] **Step 1: SettingsModel — адаптер каталога и применение**

В `SettingsModel` добавить:

```swift
import QuickLookersEditorKit
// ...
/// Поиск id темы по отображаемому имени — для EditorThemeResolver.
struct CatalogLookup: ThemeCatalogLookup {
    let themes: [ThemeInfo]
    func themeId(forDisplayName name: String) -> String? {
        themes.first { $0.displayName == name }?.id
    }
}
var catalogLookup: CatalogLookup { CatalogLookup(themes: catalog.themes) }

func applyEditorResult(themeId: String?, font: FontSettings) {
    update { s in
        if let themeId { s.activeThemeId = themeId }
        s.font = font
    }
}
```

- [ ] **Step 2: ImportModel — обнаружение и импорт**

```swift
import QuickLookersEditorKit
// ...
struct EditorImportOutcome { let themeId: String?; let font: FontSettings; let message: String? }

func scanEditors(_ store: BookmarkStore) -> [DetectedEditor] {
    store.withAccess(.applications) { appsURL in
        EditorScanner.scan(applicationsDir: appsURL)
    } ?? []
}

/// Читает из редактора активную тему и шрифт, на .custom — импортирует тему,
/// возвращает что применить. Доступ к ~ берётся внутри (грант при первом разе).
func importFromEditor(_ editor: DetectedEditor, store: BookmarkStore,
                      catalog: ThemeCatalogLookup) -> EditorImportOutcome {
    guard let container = quickLookersContainerURL() else {
        return EditorImportOutcome(themeId: nil, font: FontSettings(family: nil, size: nil),
                                   message: "Нет общего контейнера — импорт недоступен.")
    }
    return store.withAccess(.home) { home in
        let appSupport = home.appendingPathComponent("Library/Application Support")
        let prefs = EditorSettingsReader.read(editor: editor, appSupportDir: appSupport)
        let font = FontSettings(family: prefs.fontFamily, size: prefs.fontSize)
        guard let label = prefs.colorThemeLabel else {
            return EditorImportOutcome(themeId: nil, font: font,
                                       message: "У редактора не задана тема — применён только шрифт.")
        }
        let extDir = home.appendingPathComponent("\(editor.dataFolderName)/extensions")
        switch EditorThemeResolver.resolve(label: label, catalog: catalog, extensionsDir: extDir) {
        case .bundled(let id):
            return EditorImportOutcome(themeId: id, font: font, message: nil)
        case .custom(let lbl, let uiTheme, let fileURL):
            guard let raw = try? Data(contentsOf: fileURL),
                  let strict = try? ThemeFileLoader.loadStrictThemeJSON(
                      data: raw, fileExtension: fileURL.pathExtension, uiTheme: uiTheme) else {
                return EditorImportOutcome(themeId: nil, font: font,
                                           message: "Тема «\(lbl)» не прочиталась — применён только шрифт.")
            }
            let existing = Set(ImportedLibrary(containerURL: container).importedIds())
            let n = ThemeNormalizer.normalize(label: lbl, uiTheme: uiTheme,
                                              themeJSON: strict, existingSlugs: existing)
            let artifact = ImportArtifact(kind: .theme, id: n.id, displayName: n.displayName,
                                          isDark: n.isDark, json: n.json)
            try? ImportedLibrary(containerURL: container).write(ImportResult(artifacts: [artifact], skips: []))
            return EditorImportOutcome(themeId: n.id, font: font, message: nil)
        case .notFound:
            return EditorImportOutcome(themeId: nil, font: font,
                                       message: "Тема «\(label)» не найдена — применён только шрифт.")
        }
    } ?? EditorImportOutcome(themeId: nil, font: FontSettings(family: nil, size: nil),
                             message: "Доступ к домашней папке не разрешён.")
}
```

- [ ] **Step 3: Проверка сборки**

```bash
xcodegen generate
xcodebuild -project QuickLookers.xcodeproj -scheme QuickLookers \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Коммит**

```bash
git add App/ImportModel.swift App/SettingsModel.swift
git commit -m "feat(app): импорт активной темы и шрифта из установленного редактора

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 12: Витрина вкладки «Темы» + размеры окна

Финальная сборка UI: сегменты языков → живое превью → строка шрифта → единый список тем (фикс дубля) → блок импорта (`.vsix` + «Из редактора»). Окно резиновое. Проверяется живым запуском.

**Files:**
- Modify: `App/ThemesTab.swift` (переписать)
- Modify: `App/ContentView.swift` (резиновое окно)
- Modify: `App/SettingsModel.swift` (живое превью: движок + сниппеты; убрать `lightThemes`/`darkThemes` если больше не нужны)
- Create: `App/CodePreviewView.swift` (WKWebView-обёртка `NSViewRepresentable`)
- Create: `App/PreviewSnippets.swift` (сниппеты по языкам)
- Modify: `project.yml` (если сниппеты как ресурсы хоста — добавить в `sources`/`resources`; иначе встроить строками в `PreviewSnippets.swift`)

**Interfaces:**
- Consumes: `previewPageHTML(highlighted:fontFamily:fontSize:)` (Task 5); движок `QuickLookersEngineFactory.makeDefault(...)`; `importFromEditor`/`scanEditors` (Task 11); `BookmarkStore` (Task 10).

- [ ] **Step 1: Сниппеты** — `App/PreviewSnippets.swift`: словарь `languageId → код` для 5–7 языков (`swift`, `javascript`, `typescript`, `json`, `python`, `html`, `css`), по 10–20 строк показательного кода (строки, числа, комментарии, ключевые слова — чтобы тема «играла»). Встроить как строковые литералы (без файловых ресурсов — проще для песочницы).

```swift
enum PreviewSnippets {
    /// (id языка, отображаемое имя, код). Порядок = порядок сегментов.
    static let all: [(id: String, name: String, code: String)] = [
        ("swift", "Swift", #"""
        struct Point: Equatable {       // модель
            let x, y: Double
            func distance(to p: Point) -> Double {
                ((x - p.x) * (x - p.x) + (y - p.y) * (y - p.y)).squareRoot()
            }
        }
        let origin = Point(x: 0, y: 0)
        print("d = \(origin.distance(to: Point(x: 3, y: 4)))")
        """#),
        ("json", "JSON", #"""
        { "name": "quicklookers", "version": 1, "tags": ["code", "preview"],
          "nested": { "ok": true, "ratio": 0.75 } }
        """#),
        // …аналогично javascript, typescript, python, html, css
    ]
}
```

- [ ] **Step 2: Живое превью в SettingsModel** — отдельный движок приложения (тёплый), рендер `код+язык+тема → HTML`:

```swift
import QuickLookersPreviewKit

@MainActor
extension SettingsModel {
    /// Тёплый движок приложения для живого превью (ленивая инициализация).
    private static var previewEngine: HighlightEngine? = {
        var g: URL?, t: URL?
        if let c = quickLookersContainerURL() {
            let lib = ImportedLibrary(containerURL: c); g = lib.grammarsDir; t = lib.themesDir
        }
        return try? QuickLookersEngineFactory.makeDefault(importedGrammarsDir: g, importedThemesDir: t)
    }()

    /// HTML живого превью для выбранного языка и активной темы с текущим шрифтом.
    func previewHTML(languageId: String, code: String) -> String {
        let themeId = resolvedThemeId(activeThemeId: settings.activeThemeId,
                                      availableThemeIds: Set(catalog.themes.map(\.id)))
        let fragment = (try? Self.previewEngine?.highlightToHTML(
            HighlightRequest(code: code, languageId: languageId, themeId: themeId))) ?? "<pre class=\"shiki\"></pre>"
        return previewPageHTML(highlighted: fragment,
                               fontFamily: settings.font.family, fontSize: settings.font.size)
    }
}
```

- [ ] **Step 3: `App/CodePreviewView.swift`** — `NSViewRepresentable` поверх `WKWebView`, грузит HTML-строку, JS не нужен:

```swift
import SwiftUI
import WebKit

struct CodePreviewView: NSViewRepresentable {
    let html: String
    func makeNSView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.defaultWebpagePreferences.allowsContentJavaScript = false
        let web = WKWebView(frame: .zero, configuration: cfg)
        web.setValue(false, forKey: "drawsBackground")  // прозрачный фон под тему
        return web
    }
    func updateNSView(_ web: WKWebView, context: Context) {
        web.loadHTMLString(html, baseURL: nil)
    }
}
```

- [ ] **Step 4: `App/ThemesTab.swift`** — переписать целиком:

```swift
import SwiftUI
import QuickLookersSettingsKit
import QuickLookersImportKit
import QuickLookersEditorKit

struct ThemesTab: View {
    @ObservedObject var model: SettingsModel
    @ObservedObject var importModel: ImportModel
    @State private var langIndex = 0
    @State private var errorText: String?
    @State private var editors: [DetectedEditor] = []
    private let bookmarks = BookmarkStore()

    private var snippets: [(id: String, name: String, code: String)] { PreviewSnippets.all }

    var body: some View {
        VStack(spacing: 10) {
            Picker("Язык образца", selection: $langIndex) {
                ForEach(Array(snippets.enumerated()), id: \.offset) { i, s in Text(s.name).tag(i) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            CodePreviewView(html: model.previewHTML(languageId: snippets[langIndex].id,
                                                    code: snippets[langIndex].code))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .border(.separator)

            HStack {
                Text("Шрифт:")
                Picker("", selection: Binding(
                    get: { model.settings.font.family ?? "" },
                    set: { v in model.update { $0.font.family = v.isEmpty ? nil : v } })) {
                    Text("По умолчанию").tag("")
                    ForEach(MonospaceFonts.families, id: \.self) { Text($0).tag($0) }
                }.labelsHidden().frame(width: 220)
                Spacer()
                Text("Размер:")
                Stepper(value: Binding(
                    get: { model.settings.font.size ?? 12 },
                    set: { v in model.update { $0.font.size = v } }), in: 6...48) {
                    Text("\(Int(model.settings.font.size ?? 12))")
                }
            }

            List(selection: Binding(
                get: { model.settings.activeThemeId },
                set: { id in model.update { $0.activeThemeId = id } })) {
                ForEach(model.catalog.themes) { theme in
                    HStack {
                        Text(theme.displayName)
                        if model.importedIds.contains(theme.id) {
                            Text("импортирована").font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Button(role: .destructive) {
                                importModel.remove(kind: .theme, id: theme.id)
                                model.reloadCatalog(); errorText = nil
                            } label: { Image(systemName: "minus.circle") }
                            .buttonStyle(.plain)
                        }
                    }
                    .tag(theme.id)
                }
            }
            .frame(minHeight: 120)

            HStack {
                Button("Импортировать .vsix…") {
                    if let outcome = importModel.runImport() {
                        if outcome.didChange { model.reloadCatalog(); errorText = nil }
                        else { errorText = outcome.errorText }
                    }
                }
                Menu("Из редактора") {
                    if editors.isEmpty {
                        Text("Нет найденных редакторов").disabled(true)
                    }
                    ForEach(editors, id: \.nameShort) { ed in
                        Button(ed.nameLong) {
                            let r = importModel.importFromEditor(ed, store: bookmarks, catalog: model.catalogLookup)
                            model.reloadCatalog()
                            model.applyEditorResult(themeId: r.themeId, font: r.font)
                            errorText = r.message
                        }
                    }
                }
                .onTapGesture { editors = importModel.scanEditors(bookmarks) }   // ленивое сканирование при открытии
                .frame(width: 160)
                if let errorText {
                    Text(errorText).font(.caption).foregroundStyle(.red).lineLimit(2)
                }
                Spacer()
            }
        }
        .padding()
    }
}
```

Примечания к Step 4 (реализатору — довести до сборки):
- `MonospaceFonts.families` — отдельный маленький хелпер: `NSFontManager.shared.availableFontFamilies`, оставить моноширинные (проверка `NSFont(name:size:)?.isFixedPitch == true` для репрезентативного начертания). Если шрифт из настроек (`settings.font.family`) отсутствует в списке — добавить его пунктом, чтобы выбор отображался (иначе Picker не покажет тег).
- `Menu(...).onTapGesture` для ленивого скана может не сработать на самом меню — как надёжный вариант пересканировать в `.onAppear` вкладки и/или по кнопке-обновлению рядом; выбрать рабочий путь при живой проверке (цель: список редакторов свежий, гранты запрашиваются лениво при первом доступе внутри `scanEditors`/`importFromEditor`).

- [ ] **Step 5: `App/ContentView.swift`** — резиновое окно вместо фиксированного:

```swift
        .frame(minWidth: 480, idealWidth: 580, maxWidth: .infinity,
               minHeight: 560, idealHeight: 680, maxHeight: .infinity)
```
(заменить строку `.frame(width: 620, height: 420)`).

- [ ] **Step 6: Проверка сборки**

```bash
xcodegen generate
xcodebuild -project QuickLookers.xcodeproj -scheme QuickLookers \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 7: Живая проверка (⌘R)** — сценарии:
  - переключение сегментов языков меняет образец, выбор языка держится;
  - выбор темы в списке мгновенно меняет превью; импортированная тема — одна строка с пометкой и крестиком (дубля нет);
  - смена шрифта/размера сразу видна в превью;
  - «Из редактора» при первом разе запрашивает гранты (2 диалога), показывает Code/Cursor, по выбору — тема+шрифт применяются, превью обновляется; пробел в Finder подтверждает то же в реальном превью;
  - окно свободно меняет размер, превью растёт.

- [ ] **Step 8: Коммит**

```bash
git add App/ThemesTab.swift App/ContentView.swift App/SettingsModel.swift App/CodePreviewView.swift App/PreviewSnippets.swift project.yml
git commit -m "feat(app): витрина тем — живое превью, шрифт, единый список, импорт из редактора

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Финальная проверка

- [ ] `swift test` — все таргеты зелёные (Engine, ImportKit, EditorKit, SettingsKit, PreviewKit).
- [ ] `xcodebuild … build` — BUILD SUCCEEDED.
- [ ] Живые сценарии Task 12 Step 7 пройдены, в т. ч. импорт `.tmTheme`-темы (например, активная «Seti Monokai» в VS Code) рисуется и в живом превью, и в Finder.
- [ ] Обновить `CLAUDE.md` (раздел «Текущее состояние»: добавить фазу про импорт из редактора + шрифт + витрину) и при необходимости память проекта — отдельным `docs:`-коммитом.
- [ ] Завершить ветку через superpowers:finishing-a-development-branch.

## Заметки реализатору

- App-слой (`App/`, `PreviewExtension/`) под `swift test` не попадает — проверяется сборкой `xcodebuild` и живым запуском. Это нормально для проекта (Xcode-обвязка поверх SwiftPM).
- Диагностика SourceKit в редакторе при правках Xcode-таргетов («No such module …») — задержка индексатора, не ошибка сборки.
- В zsh `log` — встроенная команда; для логов расширения всегда полный путь `/usr/bin/log`.
- Главный риск (`.tmTheme`) снимается Task 1 до всей обвязки; если форма не принялась — рабочую форму фиксируем там же и используем в Task 3.
