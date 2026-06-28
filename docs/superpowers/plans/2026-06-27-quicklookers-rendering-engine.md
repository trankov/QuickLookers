# QuickLookers — Движок рендеринга (план реализации)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Собрать изолированную, тестируемую библиотеку, которая превращает `код + язык + тема` в готовый HTML с подсветкой VS Code-качества через Shiki в JavaScriptCore.

**Architecture:** Swift Package (`QuickLookersEngine`) с единственной ответственностью — подсветка. Внутри: тонкий JS-бандл Shiki (синхронное ядро + JS-движок регулярок, без WASM), обёртка над `JavaScriptCore`, провайдеры грамматик и тем из ресурсов, и публичный протокол `HighlightEngine`. Грамматики и темы — обычные JSON-ресурсы, чтобы позже их можно было пополнять импортом `.vsix`. Всё, что выше (расширения QuickLook, приложение) — отдельные планы, они зависят от этого пакета.

**Tech Stack:** Swift 5.9 / SwiftPM, JavaScriptCore, Shiki (`shiki/core` + `shiki/engine/javascript`), esbuild + Node (только как шаг сборки JS-бандла), XCTest.

## Статус выполнения

Реализация идёт в ветке `feat/rendering-engine`.

- [x] **Task 1** — каркас пакета. Коммит `6e69372`. `swift test` зелёный (1 тест). Добавлен `.gitignore`.
- [x] **Task 2** — JS-бандл Shiki. Коммит `e64c8b2`. Бандл собран (349 КБ), node-смоук зелёный.
- [ ] **Task 3** — обёртка `JSCoreRuntime`.
- [ ] **Task 4** — провайдеры + ресурсы Shiki.
- [ ] **Task 5** — `ShikiEngine` + фабрика.
- [ ] **Task 6** — бенчмарк бюджета.

**Зафиксированные факты и отклонения от плана:**
- Установленные версии: **shiki 1.29.2**, **esbuild 0.20.2** (см. `js/package-lock.json`).
- Метод `codeToHtml` у `createHighlighterCoreSync` в этой версии **есть** — смоук подтвердил (`<pre>` + текст). Сверка из Task 2 снята: Task 3 идёт без правок API.
- **Поправка плана:** в `js/test/smoke.mjs` путь к бандлу `../Sources/...` исправлен на `../../Sources/...` (файл лежит в `js/test/`, бандл — в корне репозитория).
- npm-окружение блокирует postinstall-скрипты (предупреждение про esbuild) — на сборку не влияет.

## Global Constraints

- Платформа: **macOS 13+** (`.macOS(.v13)` в Package.swift).
- Движок подсветки изолирован за протоколом `HighlightEngine` — потребители не знают про Shiki/JSC.
- Движок регулярок Shiki — **только JS, без WASM** (`createJavaScriptRegexEngine({ forgiving: true })`).
- Всё работает **офлайн**: JS-бандл, грамматики и темы лежат в ресурсах пакета.
- Вывод — **готовый HTML-строка** (для статичного показа в WebView с выключенным JS).
- Визуальный паритет с VS Code обеспечивается тем, что грамматики и темы — настоящие из коллекции Shiki (`@shikijs/langs`, `@shikijs/themes`), не самописные.
- Бюджет производительности: «тёплый» повторный показ — ориентир ≤ ~100 мс на типичном файле.
- Идентификатор языка/темы в API = поле `name` внутри соответствующего JSON (для бандла Shiki это имя файла, напр. `javascript`, `dark-plus`).

---

## Структура файлов

```
Package.swift
js/
  package.json                      # npm + esbuild, шаг сборки бандла
  build.mjs                         # скрипт сборки
  src/highlight.mjs                 # точка входа: вешает globalThis.ql*
  test/smoke.mjs                    # node-смоук готового бандла
Sources/QuickLookersEngine/
  HighlightEngine.swift             # протокол + HighlightRequest + EngineError
  Providers.swift                   # GrammarProvider / ThemeProvider + бандл-реализации
  JSCoreRuntime.swift               # обёртка над JavaScriptCore
  ShikiEngine.swift                 # реализация HighlightEngine
  EngineFactory.swift               # сборка движка из Bundle.module
  Resources/
    shiki-bundle.js                 # СОБИРАЕТСЯ из js/ (артефакт)
    grammars/                       # *.json грамматики Shiki
    themes/                         # *.json темы Shiki
Tests/QuickLookersEngineTests/
  RuntimeTests.swift
  ShikiEngineTests.swift
  ProviderTests.swift
  PerformanceTests.swift
  Fakes.swift                       # счётные фейки провайдеров
```

---

## Task 1: Каркас Swift-пакета

**Files:**
- Create: `Package.swift`
- Create: `Sources/QuickLookersEngine/HighlightEngine.swift`
- Test: `Tests/QuickLookersEngineTests/RuntimeTests.swift`

**Interfaces:**
- Produces: пакет `QuickLookersEngine`; типы `HighlightRequest`, `EngineError`, протокол `HighlightEngine`.

- [ ] **Step 1: Написать падающий тест**

`Tests/QuickLookersEngineTests/RuntimeTests.swift`:
```swift
import XCTest
@testable import QuickLookersEngine

final class RuntimeTests: XCTestCase {
    func test_highlightRequest_storesFields() {
        let r = HighlightRequest(code: "let x = 1", languageId: "swift", themeId: "dark-plus")
        XCTAssertEqual(r.code, "let x = 1")
        XCTAssertEqual(r.languageId, "swift")
        XCTAssertEqual(r.themeId, "dark-plus")
    }
}
```

- [ ] **Step 2: Запустить тест — убедиться, что не компилируется/падает**

Run: `swift test`
Expected: FAIL — нет типа `HighlightRequest` / нет `Package.swift`.

- [ ] **Step 3: Создать `Package.swift`**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "QuickLookersEngine",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "QuickLookersEngine", targets: ["QuickLookersEngine"]),
    ],
    targets: [
        .target(
            name: "QuickLookersEngine",
            resources: [
                .copy("Resources/shiki-bundle.js"),
                .copy("Resources/grammars"),
                .copy("Resources/themes"),
            ]
        ),
        .testTarget(
            name: "QuickLookersEngineTests",
            dependencies: ["QuickLookersEngine"]
        ),
    ]
)
```

- [ ] **Step 4: Создать минимальные типы и пустые ресурсы**

`Sources/QuickLookersEngine/HighlightEngine.swift`:
```swift
import Foundation

public struct HighlightRequest: Equatable, Sendable {
    public let code: String
    public let languageId: String
    public let themeId: String

    public init(code: String, languageId: String, themeId: String) {
        self.code = code
        self.languageId = languageId
        self.themeId = themeId
    }
}

public enum EngineError: Error, Equatable {
    case contextCreationFailed
    case scriptEvaluation(String)
    case missingFunction(String)
    case callFailed(String)
    case jsException(String)
    case unexpectedResult
    case resourceNotFound(String)
}

public protocol HighlightEngine: AnyObject {
    func highlightToHTML(_ request: HighlightRequest) throws -> String
}
```

Создать заглушки ресурсов, чтобы пакет собирался (будут заменены в Task 2/4):
```bash
mkdir -p Sources/QuickLookersEngine/Resources/grammars Sources/QuickLookersEngine/Resources/themes
printf '// placeholder, replaced in Task 2\n' > Sources/QuickLookersEngine/Resources/shiki-bundle.js
printf '{}' > Sources/QuickLookersEngine/Resources/grammars/.keep.json
printf '{}' > Sources/QuickLookersEngine/Resources/themes/.keep.json
```

- [ ] **Step 5: Запустить тест — убедиться, что проходит**

Run: `swift test`
Expected: PASS (1 тест).

- [ ] **Step 6: Коммит**

```bash
git add Package.swift Sources Tests
git commit -m "feat(engine): каркас пакета QuickLookersEngine и базовые типы"
```

---

## Task 2: JS-бандл Shiki для JavaScriptCore

Собираем единый файл, который вешает на `globalThis` три функции: регистрация грамматики, регистрация темы, подсветка. Используем синхронное ядро Shiki — оно не требует Node/fetch/WASM.

**Files:**
- Create: `js/package.json`, `js/build.mjs`, `js/src/highlight.mjs`, `js/test/smoke.mjs`
- Modify: `Sources/QuickLookersEngine/Resources/shiki-bundle.js` (генерируется)

**Interfaces:**
- Produces: глобальные JS-функции `qlRegisterLang(json) -> name`, `qlRegisterTheme(json) -> name`, `qlHighlight(code, langName, themeName) -> html`.

- [ ] **Step 1: Написать точку входа**

`js/src/highlight.mjs`:
```js
import { createHighlighterCoreSync } from 'shiki/core'
import { createJavaScriptRegexEngine } from 'shiki/engine/javascript'

// Один движок регулярок на всё, без WASM.
const engine = createJavaScriptRegexEngine({ forgiving: true })

// Грамматики/темы регистрируются один раз; подсветчики кэшируются по паре (язык, тема).
const langs = new Map()   // name -> language object
const themes = new Map()  // name -> theme object
const highlighters = new Map() // `${lang} ${theme}` -> HighlighterCore

globalThis.qlRegisterLang = (json) => {
  const lang = JSON.parse(json)
  langs.set(lang.name, lang)
  return lang.name
}

globalThis.qlRegisterTheme = (json) => {
  const theme = JSON.parse(json)
  themes.set(theme.name, theme)
  return theme.name
}

globalThis.qlHighlight = (code, langName, themeName) => {
  const key = langName + ' ' + themeName
  let hl = highlighters.get(key)
  if (!hl) {
    const lang = langs.get(langName)
    const theme = themes.get(themeName)
    if (!lang) throw new Error('lang not registered: ' + langName)
    if (!theme) throw new Error('theme not registered: ' + themeName)
    hl = createHighlighterCoreSync({ themes: [theme], langs: [lang], engine })
    highlighters.set(key, hl)
  }
  return hl.codeToHtml(code, { lang: langName, theme: themeName })
}
```

- [ ] **Step 2: Настроить npm и сборку**

`js/package.json`:
```json
{
  "name": "quicklookers-shiki-bundle",
  "private": true,
  "type": "module",
  "scripts": {
    "build": "node build.mjs",
    "test": "node test/smoke.mjs"
  },
  "dependencies": {
    "shiki": "^1.0.0"
  },
  "devDependencies": {
    "esbuild": "^0.20.0"
  }
}
```

`js/build.mjs`:
```js
import { build } from 'esbuild'

await build({
  entryPoints: ['src/highlight.mjs'],
  bundle: true,
  format: 'iife',
  target: ['safari16'],
  platform: 'neutral',
  outfile: '../Sources/QuickLookersEngine/Resources/shiki-bundle.js',
})

console.log('built shiki-bundle.js')
```

- [ ] **Step 3: Написать node-смоук готового бандла**

`js/test/smoke.mjs`:
```js
import { createRequire } from 'module'
import assert from 'assert'

const require = createRequire(import.meta.url)
// Выполнение iife-файла вешает globalThis.ql*
require('../Sources/QuickLookersEngine/Resources/shiki-bundle.js')

const minimalLang = JSON.stringify({
  name: 'plaintext', scopeName: 'source.plain', patterns: []
})
const minimalTheme = JSON.stringify({
  name: 't', type: 'dark', colors: { 'editor.foreground': '#ffffff' }, tokenColors: []
})

globalThis.qlRegisterLang(minimalLang)
globalThis.qlRegisterTheme(minimalTheme)
const html = globalThis.qlHighlight('hello', 'plaintext', 't')

assert.ok(html.includes('<pre'), 'ожидался <pre> в выводе')
assert.ok(html.includes('hello'), 'ожидался текст в выводе')
console.log('smoke OK')
```

- [ ] **Step 4: Собрать и прогнать смоук**

Run:
```bash
cd js && npm install && npm run build && npm test
```
Expected: вывод `built shiki-bundle.js` затем `smoke OK`; файл `Sources/QuickLookersEngine/Resources/shiki-bundle.js` перезаписан реальным бандлом.

> Если `codeToHtml` отсутствует у объекта из `createHighlighterCoreSync` в установленной версии Shiki — это единственная точка, требующая сверки с актуальной сигнатурой ядра (`shiki/core`); заменить вызов на эквивалентный метод подсветки в HTML той же версии.

- [ ] **Step 5: Коммит**

```bash
git add js Sources/QuickLookersEngine/Resources/shiki-bundle.js
git commit -m "feat(engine): JS-бандл Shiki (sync core + JS regex) для JavaScriptCore"
```

---

## Task 3: Обёртка над JavaScriptCore

**Files:**
- Create: `Sources/QuickLookersEngine/JSCoreRuntime.swift`
- Modify: `Tests/QuickLookersEngineTests/RuntimeTests.swift`

**Interfaces:**
- Consumes: глобальные JS-функции из Task 2; `EngineError`.
- Produces: класс `JSCoreRuntime` с методами `registerLanguage(json:)`, `registerTheme(json:)`, `highlight(code:language:theme:) -> String`; статический `JSCoreRuntime.loadBundledScript() -> String`.

- [ ] **Step 1: Написать падающий тест**

Добавить в `Tests/QuickLookersEngineTests/RuntimeTests.swift`:
```swift
func test_runtime_highlightsPlaintext() throws {
    let runtime = try JSCoreRuntime(bundleScript: JSCoreRuntime.loadBundledScript())
    try runtime.registerLanguage(json: #"{"name":"plaintext","scopeName":"source.plain","patterns":[]}"#)
    try runtime.registerTheme(json: #"{"name":"t","type":"dark","colors":{"editor.foreground":"#ffffff"},"tokenColors":[]}"#)
    let html = try runtime.highlight(code: "hello", language: "plaintext", theme: "t")
    XCTAssertTrue(html.contains("<pre"))
    XCTAssertTrue(html.contains("hello"))
}
```

- [ ] **Step 2: Запустить тест — убедиться, что падает**

Run: `swift test --filter RuntimeTests/test_runtime_highlightsPlaintext`
Expected: FAIL — нет `JSCoreRuntime`.

- [ ] **Step 3: Реализовать обёртку**

`Sources/QuickLookersEngine/JSCoreRuntime.swift`:
```swift
import Foundation
import JavaScriptCore

public final class JSCoreRuntime {
    private let context: JSContext

    public init(bundleScript: String) throws {
        guard let ctx = JSContext() else { throw EngineError.contextCreationFailed }
        self.context = ctx

        var thrown: JSValue?
        ctx.exceptionHandler = { _, exc in thrown = exc }
        ctx.evaluateScript(bundleScript)
        if let exc = thrown {
            throw EngineError.scriptEvaluation(exc.toString() ?? "unknown")
        }
    }

    public static func loadBundledScript() throws -> String {
        guard let url = Bundle.module.url(forResource: "shiki-bundle", withExtension: "js"),
              let script = try? String(contentsOf: url, encoding: .utf8) else {
            throw EngineError.resourceNotFound("shiki-bundle.js")
        }
        return script
    }

    public func registerLanguage(json: String) throws { _ = try call("qlRegisterLang", [json]) }
    public func registerTheme(json: String) throws { _ = try call("qlRegisterTheme", [json]) }

    public func highlight(code: String, language: String, theme: String) throws -> String {
        let result = try call("qlHighlight", [code, language, theme])
        guard let html = result.toString() else { throw EngineError.unexpectedResult }
        return html
    }

    @discardableResult
    private func call(_ functionName: String, _ args: [Any]) throws -> JSValue {
        guard let fn = context.objectForKeyedSubscript(functionName), !fn.isUndefined else {
            throw EngineError.missingFunction(functionName)
        }
        var thrown: JSValue?
        context.exceptionHandler = { _, exc in thrown = exc }
        guard let result = fn.call(withArguments: args) else {
            throw EngineError.callFailed(functionName)
        }
        if let exc = thrown {
            throw EngineError.jsException(exc.toString() ?? "unknown")
        }
        return result
    }
}
```

- [ ] **Step 4: Запустить тест — убедиться, что проходит**

Run: `swift test --filter RuntimeTests/test_runtime_highlightsPlaintext`
Expected: PASS.

- [ ] **Step 5: Коммит**

```bash
git add Sources/QuickLookersEngine/JSCoreRuntime.swift Tests/QuickLookersEngineTests/RuntimeTests.swift
git commit -m "feat(engine): обёртка JSCoreRuntime над JavaScriptCore"
```

---

## Task 4: Провайдеры грамматик и тем + реальные ресурсы

**Files:**
- Create: `Sources/QuickLookersEngine/Providers.swift`
- Create: `Tests/QuickLookersEngineTests/ProviderTests.swift`
- Modify: `Sources/QuickLookersEngine/Resources/grammars/*.json`, `Resources/themes/*.json`

**Interfaces:**
- Consumes: `EngineError`.
- Produces: протоколы `GrammarProvider { func grammarJSON(languageId:) throws -> String }`, `ThemeProvider { func themeJSON(themeId:) throws -> String }`; реализации `BundledGrammarProvider(directory:)`, `BundledThemeProvider(directory:)`.

- [ ] **Step 1: Добавить реальные ресурсы Shiki**

Скопировать стартовый набор JSON из npm-пакетов Shiki (имя файла = id):
```bash
cd js && npm install
cp node_modules/@shikijs/langs/dist/javascript.json ../Sources/QuickLookersEngine/Resources/grammars/javascript.json
cp node_modules/@shikijs/langs/dist/swift.json      ../Sources/QuickLookersEngine/Resources/grammars/swift.json
cp node_modules/@shikijs/langs/dist/json.json       ../Sources/QuickLookersEngine/Resources/grammars/json.json
cp node_modules/@shikijs/themes/dist/dark-plus.json ../Sources/QuickLookersEngine/Resources/themes/dark-plus.json
cp node_modules/@shikijs/themes/dist/light-plus.json ../Sources/QuickLookersEngine/Resources/themes/light-plus.json
rm -f ../Sources/QuickLookersEngine/Resources/grammars/.keep.json ../Sources/QuickLookersEngine/Resources/themes/.keep.json
```

> Точные пути внутри `dist` сверить по установленной версии (`ls node_modules/@shikijs/langs/dist`). Каждый JSON содержит поле `name`, равное id (`javascript`, `swift`, `dark-plus`, ...).

- [ ] **Step 2: Написать падающий тест**

`Tests/QuickLookersEngineTests/ProviderTests.swift`:
```swift
import XCTest
@testable import QuickLookersEngine

final class ProviderTests: XCTestCase {
    private func resourceDir(_ name: String) throws -> URL {
        guard let url = Bundle.module.url(forResource: name, withExtension: nil) else {
            throw EngineError.resourceNotFound(name)
        }
        return url
    }

    func test_grammarProvider_returnsJSONContainingName() throws {
        let provider = BundledGrammarProvider(directory: try resourceDir("grammars"))
        let json = try provider.grammarJSON(languageId: "swift")
        XCTAssertTrue(json.contains("\"name\""))
        XCTAssertTrue(json.contains("swift"))
    }

    func test_themeProvider_missingThemeThrows() throws {
        let provider = BundledThemeProvider(directory: try resourceDir("themes"))
        XCTAssertThrowsError(try provider.themeJSON(themeId: "does-not-exist"))
    }
}
```

- [ ] **Step 3: Запустить тест — убедиться, что падает**

Run: `swift test --filter ProviderTests`
Expected: FAIL — нет `BundledGrammarProvider`.

- [ ] **Step 4: Реализовать провайдеры**

`Sources/QuickLookersEngine/Providers.swift`:
```swift
import Foundation

public protocol GrammarProvider {
    func grammarJSON(languageId: String) throws -> String
}

public protocol ThemeProvider {
    func themeJSON(themeId: String) throws -> String
}

private func readJSON(_ directory: URL, _ id: String) throws -> String {
    let url = directory.appendingPathComponent("\(id).json")
    guard let data = try? Data(contentsOf: url),
          let string = String(data: data, encoding: .utf8) else {
        throw EngineError.resourceNotFound(id)
    }
    return string
}

public struct BundledGrammarProvider: GrammarProvider {
    private let directory: URL
    public init(directory: URL) { self.directory = directory }
    public func grammarJSON(languageId: String) throws -> String {
        try readJSON(directory, languageId)
    }
}

public struct BundledThemeProvider: ThemeProvider {
    private let directory: URL
    public init(directory: URL) { self.directory = directory }
    public func themeJSON(themeId: String) throws -> String {
        try readJSON(directory, themeId)
    }
}
```

- [ ] **Step 5: Запустить тест — убедиться, что проходит**

Run: `swift test --filter ProviderTests`
Expected: PASS.

- [ ] **Step 6: Коммит**

```bash
git add Sources/QuickLookersEngine/Providers.swift Sources/QuickLookersEngine/Resources Tests/QuickLookersEngineTests/ProviderTests.swift
git commit -m "feat(engine): провайдеры грамматик/тем и стартовые ресурсы Shiki"
```

---

## Task 5: ShikiEngine — реализация HighlightEngine с ленивой загрузкой

**Files:**
- Create: `Sources/QuickLookersEngine/ShikiEngine.swift`
- Create: `Sources/QuickLookersEngine/EngineFactory.swift`
- Create: `Tests/QuickLookersEngineTests/ShikiEngineTests.swift`
- Create: `Tests/QuickLookersEngineTests/Fakes.swift`

**Interfaces:**
- Consumes: `HighlightEngine`, `HighlightRequest`, `JSCoreRuntime`, `GrammarProvider`, `ThemeProvider`.
- Produces: класс `ShikiEngine(runtime:grammars:themes:)`; `enum QuickLookersEngineFactory { static func makeDefault() throws -> ShikiEngine }`.

- [ ] **Step 1: Написать счётные фейки и падающий тест**

`Tests/QuickLookersEngineTests/Fakes.swift`:
```swift
import Foundation
@testable import QuickLookersEngine

final class CountingGrammarProvider: GrammarProvider {
    let inner: GrammarProvider
    private(set) var calls: [String] = []
    init(_ inner: GrammarProvider) { self.inner = inner }
    func grammarJSON(languageId: String) throws -> String {
        calls.append(languageId)
        return try inner.grammarJSON(languageId: languageId)
    }
}
```

`Tests/QuickLookersEngineTests/ShikiEngineTests.swift`:
```swift
import XCTest
@testable import QuickLookersEngine

final class ShikiEngineTests: XCTestCase {
    private func makeEngine() throws -> (ShikiEngine, CountingGrammarProvider) {
        let runtime = try JSCoreRuntime(bundleScript: JSCoreRuntime.loadBundledScript())
        let grammarsDir = Bundle.module.url(forResource: "grammars", withExtension: nil)!
        let themesDir = Bundle.module.url(forResource: "themes", withExtension: nil)!
        let counting = CountingGrammarProvider(BundledGrammarProvider(directory: grammarsDir))
        let engine = ShikiEngine(runtime: runtime,
                                 grammars: counting,
                                 themes: BundledThemeProvider(directory: themesDir))
        return (engine, counting)
    }

    func test_highlightsSwiftCode() throws {
        let (engine, _) = try makeEngine()
        let html = try engine.highlightToHTML(
            HighlightRequest(code: "let x = 1", languageId: "swift", themeId: "dark-plus"))
        XCTAssertTrue(html.contains("<pre"))
        XCTAssertTrue(html.contains("style="))   // присутствуют инлайновые цвета
    }

    func test_grammarLoadedOncePerLanguage() throws {
        let (engine, counting) = try makeEngine()
        let req = HighlightRequest(code: "let x = 1", languageId: "swift", themeId: "dark-plus")
        _ = try engine.highlightToHTML(req)
        _ = try engine.highlightToHTML(req)
        XCTAssertEqual(counting.calls, ["swift"])  // грамматика прочитана один раз
    }
}
```

- [ ] **Step 2: Запустить тест — убедиться, что падает**

Run: `swift test --filter ShikiEngineTests`
Expected: FAIL — нет `ShikiEngine`.

- [ ] **Step 3: Реализовать движок и фабрику**

`Sources/QuickLookersEngine/ShikiEngine.swift`:
```swift
import Foundation

public final class ShikiEngine: HighlightEngine {
    private let runtime: JSCoreRuntime
    private let grammars: GrammarProvider
    private let themes: ThemeProvider
    private var loadedLanguages = Set<String>()
    private var loadedThemes = Set<String>()

    public init(runtime: JSCoreRuntime, grammars: GrammarProvider, themes: ThemeProvider) {
        self.runtime = runtime
        self.grammars = grammars
        self.themes = themes
    }

    public func highlightToHTML(_ request: HighlightRequest) throws -> String {
        if !loadedLanguages.contains(request.languageId) {
            try runtime.registerLanguage(json: grammars.grammarJSON(languageId: request.languageId))
            loadedLanguages.insert(request.languageId)
        }
        if !loadedThemes.contains(request.themeId) {
            try runtime.registerTheme(json: themes.themeJSON(themeId: request.themeId))
            loadedThemes.insert(request.themeId)
        }
        return try runtime.highlight(code: request.code,
                                     language: request.languageId,
                                     theme: request.themeId)
    }
}
```

`Sources/QuickLookersEngine/EngineFactory.swift`:
```swift
import Foundation

public enum QuickLookersEngineFactory {
    public static func makeDefault() throws -> ShikiEngine {
        let runtime = try JSCoreRuntime(bundleScript: JSCoreRuntime.loadBundledScript())
        guard let grammarsDir = Bundle.module.url(forResource: "grammars", withExtension: nil),
              let themesDir = Bundle.module.url(forResource: "themes", withExtension: nil) else {
            throw EngineError.resourceNotFound("resource directories")
        }
        return ShikiEngine(runtime: runtime,
                           grammars: BundledGrammarProvider(directory: grammarsDir),
                           themes: BundledThemeProvider(directory: themesDir))
    }
}
```

- [ ] **Step 4: Запустить тест — убедиться, что проходит**

Run: `swift test --filter ShikiEngineTests`
Expected: PASS (2 теста).

- [ ] **Step 5: Коммит**

```bash
git add Sources/QuickLookersEngine/ShikiEngine.swift Sources/QuickLookersEngine/EngineFactory.swift Tests/QuickLookersEngineTests/ShikiEngineTests.swift Tests/QuickLookersEngineTests/Fakes.swift
git commit -m "feat(engine): ShikiEngine с ленивой загрузкой и фабрика по умолчанию"
```

---

## Task 6: Бенчмарк производительности (spike по бюджету)

Закладываем измеримый бюджет: «холодный» первый показ и «тёплый» повторный. Тест печатает тайминги и проверяет тёплый показ против ориентира.

**Files:**
- Create: `Tests/QuickLookersEngineTests/PerformanceTests.swift`

**Interfaces:**
- Consumes: `QuickLookersEngineFactory`, `HighlightRequest`.

- [ ] **Step 1: Написать бенчмарк-тест**

`Tests/QuickLookersEngineTests/PerformanceTests.swift`:
```swift
import XCTest
@testable import QuickLookersEngine

final class PerformanceTests: XCTestCase {
    func test_warmHighlightWithinBudget() throws {
        let engine = try QuickLookersEngineFactory.makeDefault()
        let code = String(repeating: "let value = compute(x: 1, y: 2)\n", count: 200)
        let req = HighlightRequest(code: code, languageId: "swift", themeId: "dark-plus")

        let coldStart = Date()
        _ = try engine.highlightToHTML(req)              // холодный: грузит грамматику/тему
        let cold = Date().timeIntervalSince(coldStart) * 1000

        let warmStart = Date()
        _ = try engine.highlightToHTML(req)              // тёплый: всё уже загружено
        let warm = Date().timeIntervalSince(warmStart) * 1000

        print(String(format: "cold=%.1fms warm=%.1fms", cold, warm))
        // Ориентир из спецификации; при провале — сигнал к нативному движку (Oniguruma+Swift).
        XCTAssertLessThan(warm, 100.0, "тёплый показ вышел за бюджет ~100мс")
    }
}
```

- [ ] **Step 2: Запустить бенчмарк**

Run: `swift test --filter PerformanceTests`
Expected: PASS; в выводе строка `cold=... warm=...`.

> Если тёплый показ стабильно превышает бюджет — это и есть триггер из дизайн-документа: подключать нативный движок (линковка Oniguruma + Swift-токенизатор) за тем же протоколом `HighlightEngine`, не трогая потребителей. Зафиксировать реальные цифры в отдельной заметке перед таким решением.

- [ ] **Step 3: Коммит**

```bash
git add Tests/QuickLookersEngineTests/PerformanceTests.swift
git commit -m "test(engine): бенчмарк бюджета производительности (холодный/тёплый)"
```

---

## Self-Review (выполнено при написании плана)

- **Покрытие дизайна (часть «Движок»):** Shiki за изолированным интерфейсом — Task 5 (протокол `HighlightEngine`); JS-движок без WASM — Task 2; офлайн-ресурсы — Task 4; готовый HTML — Task 3/5; паритет с VS Code (настоящие грамматики/темы) — Task 4; бюджет производительности и триггер на нативный движок — Task 6. Оптимизации «тёплый контекст» (кэш подсветчиков по паре язык+тема и однократная загрузка грамматик) — Task 2/5.
- **Вне рамок этого плана (другие планы):** кэш готового HTML по хэшу файла, обрезка больших файлов, App Group, WKWebView, иконки, Markdown, импорт `.vsix`, UTI, настройки — относятся к подсистемам 2–4.
- **Плейсхолдеры:** не осталось; две явные «точки сверки версии Shiki» (метод `codeToHtml`, путь к `dist`) — это сверка с установленной библиотекой, а не пропущенная логика.
- **Согласованность типов:** `HighlightRequest(code:languageId:themeId:)`, `highlightToHTML(_:)`, `registerLanguage/registerTheme/highlight`, `grammarJSON(languageId:)`, `themeJSON(themeId:)` — имена едины во всех задачах.

## Дальнейшие планы (отдельные документы)

1. **Расширение QuickLook Preview** — App Group-контейнер, кэш готового HTML (хэш+тема+версия), обрезка/догрузка больших файлов, статичный показ в `WKWebView` (JS off), spike по возврату к родному превью macOS для opt-in UTI.
2. **Расширение Thumbnail** — нативный рендер первых строк через Core Text, без WebView.
3. **Главное приложение + настройки + библиотека** — импорт темы/шрифта из VS Code/Cursor, импорт `.vsix`, управление включёнными языками и перехватом UTI, выбор темы (одна на всё, светлая/тёмная/«за системой»).
