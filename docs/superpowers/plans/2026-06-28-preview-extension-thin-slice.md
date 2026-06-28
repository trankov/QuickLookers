# Расширение Preview — тонкий вертикальный срез (фаза 2) — план реализации

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Пробел в Finder на файле кода → полноразмерное превью, нарисованное `QuickLookersEngine`, визуально один-в-один с VS Code (тема Dark+), плюс снятые показания по трём spike.

**Architecture:** Движок остаётся чистым SwiftPM-пакетом. Тестируемая presentation-логика (язык по расширению, обёртка HTML-страницы) — в новой маленькой библиотеке `QuickLookersPreviewKit` того же пакета. Вокруг XcodeGen собирает Xcode-проект: приложение-хост (заглушка) + расширение QuickLook Preview, которое линкует обе библиотеки и рисует в `WKWebView` с выключенным JavaScript.

**Tech Stack:** Swift 6.3, SwiftPM, XcodeGen, QuickLook (`QLPreviewingController`), WebKit (`WKWebView`), os_log, `QuickLookersEngine` (Shiki в JavaScriptCore).

## Global Constraints

- Платформа: macOS 13+, Xcode 26, Swift 6.3.
- Движок изолирован за протоколом `HighlightEngine`; расширение не знает про Shiki/JSC.
- Тема среза: **`dark-plus`** (эталон для сравнения с VS Code).
- Языки среза: **`swift`, `json`, `javascript`** — ровно те, на которые есть грамматики в пакете.
- UTI в плисте расширения: `public.swift-source`, `public.json`, `com.netscape.javascript-source`.
- `WKWebView` — **JavaScript выключен** (`allowsContentJavaScript = false`); вебвью только верстает статичный HTML.
- **App Group отложен** — расширение рисует из ресурсов, вшитых в `QuickLookersEngine` (`Bundle.module`).
- **XcodeGen**: проект описывается в `project.yml` (в git); `.xcodeproj` генерируется и в git не хранится.
- TDD строго: падающий тест → запуск (падает) → реализация → запуск (зелёный) → коммит, по одному маленькому шагу.
- Коммиты по-русски: `feat(preview): …` / `test(preview): …` / `docs: …`; трейлер `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.
- Ветка: `feat/rendering-engine` (продолжаем в ней; отдельную ветку под фазу 2 не заводим, если пользователь не попросит).

## Карта файлов

- Создать: `Sources/QuickLookersPreviewKit/LanguageMap.swift` — язык по расширению файла.
- Создать: `Sources/QuickLookersPreviewKit/PreviewPage.swift` — обёртка готового фрагмента в полную HTML-страницу.
- Создать: `Tests/QuickLookersPreviewKitTests/LanguageMapTests.swift`, `.../PreviewPageTests.swift`.
- Изменить: `Package.swift` — добавить библиотеку `QuickLookersPreviewKit` и её тест-таргет.
- Создать: `project.yml` — спека XcodeGen (приложение + расширение).
- Создать: `.gitignore` — игнор `*.xcodeproj`, `DerivedData/`.
- Создать: `App/QuickLookersApp.swift` — заглушка-окно хоста.
- Создать: `PreviewExtension/PreviewViewController.swift` — `QLPreviewingController`.
- (Info.plist расширения генерирует XcodeGen из `info:` в `project.yml` — руками не пишем.)

---

### Task 1: PreviewKit — определение языка по расширению файла

**Files:**
- Modify: `Package.swift`
- Create: `Sources/QuickLookersPreviewKit/LanguageMap.swift`
- Test: `Tests/QuickLookersPreviewKitTests/LanguageMapTests.swift`

**Interfaces:**
- Produces: `public func languageId(forPathExtension ext: String) -> String?` — возвращает id грамматики (`"swift"`/`"json"`/`"javascript"`) или `nil` для неизвестного расширения; регистронезависимо.

- [ ] **Step 1: Добавить библиотеку и тест-таргет в Package.swift**

В `Package.swift` в массив `products` добавить:

```swift
.library(name: "QuickLookersPreviewKit", targets: ["QuickLookersPreviewKit"]),
```

В массив `targets` добавить:

```swift
.target(name: "QuickLookersPreviewKit", dependencies: ["QuickLookersEngine"]),
.testTarget(name: "QuickLookersPreviewKitTests", dependencies: ["QuickLookersPreviewKit"]),
```

- [ ] **Step 2: Написать падающий тест**

`Tests/QuickLookersPreviewKitTests/LanguageMapTests.swift`:

```swift
import XCTest
@testable import QuickLookersPreviewKit

final class LanguageMapTests: XCTestCase {
    func test_knownExtensions_mapToGrammarIds() {
        XCTAssertEqual(languageId(forPathExtension: "swift"), "swift")
        XCTAssertEqual(languageId(forPathExtension: "json"), "json")
        XCTAssertEqual(languageId(forPathExtension: "js"), "javascript")
    }

    func test_extension_isCaseInsensitive() {
        XCTAssertEqual(languageId(forPathExtension: "SWIFT"), "swift")
        XCTAssertEqual(languageId(forPathExtension: "JS"), "javascript")
    }

    func test_unknownExtension_returnsNil() {
        XCTAssertNil(languageId(forPathExtension: "txt"))
        XCTAssertNil(languageId(forPathExtension: ""))
    }
}
```

- [ ] **Step 3: Запустить тест — убедиться, что падает**

Run: `swift test --filter LanguageMapTests`
Expected: FAIL (нет цели `QuickLookersPreviewKit` / нет функции `languageId`).

- [ ] **Step 4: Реализовать минимум**

`Sources/QuickLookersPreviewKit/LanguageMap.swift`:

```swift
/// Соответствие «расширение файла → id грамматики Shiki».
/// Срез фазы 2: только языки, на которые есть грамматики в пакете.
private let extensionToLanguage: [String: String] = [
    "swift": "swift",
    "json": "json",
    "js": "javascript",
]

/// id грамматики для расширения файла или nil, если язык не поддержан.
public func languageId(forPathExtension ext: String) -> String? {
    extensionToLanguage[ext.lowercased()]
}
```

- [ ] **Step 5: Запустить тест — зелёный**

Run: `swift test --filter LanguageMapTests`
Expected: PASS (3 теста).

- [ ] **Step 6: Коммит**

```bash
git add Package.swift Sources/QuickLookersPreviewKit/LanguageMap.swift Tests/QuickLookersPreviewKitTests/LanguageMapTests.swift
git commit -m "feat(preview): определение языка по расширению файла

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: PreviewKit — обёртка фрагмента в HTML-страницу

**Files:**
- Create: `Sources/QuickLookersPreviewKit/PreviewPage.swift`
- Test: `Tests/QuickLookersPreviewKitTests/PreviewPageTests.swift`

**Interfaces:**
- Consumes: фрагмент HTML от движка (строка вида `<pre class="shiki" style="background-color:#…">…</pre>`).
- Produces: `public func previewPageHTML(highlighted: String) -> String` — полный HTML-документ: сброс полей, моноширинный шрифт, фрагмент вставлен как есть.

- [ ] **Step 1: Написать падающий тест**

`Tests/QuickLookersPreviewKitTests/PreviewPageTests.swift`:

```swift
import XCTest
@testable import QuickLookersPreviewKit

final class PreviewPageTests: XCTestCase {
    func test_pageWrapsFragment_andResetsMargins() {
        let fragment = #"<pre class="shiki" style="background-color:#1e1e1e">code</pre>"#
        let page = previewPageHTML(highlighted: fragment)

        XCTAssertTrue(page.contains("<html"), "должен быть полный документ")
        XCTAssertTrue(page.contains("margin: 0"), "поля сброшены, чтобы фон заполнял окно")
        XCTAssertTrue(page.contains(fragment), "фрагмент вставлен дословно")
    }

    func test_fragmentIsNotDoubleEscaped() {
        let fragment = #"<span style="color:#569cd6">let</span>"#
        let page = previewPageHTML(highlighted: fragment)
        XCTAssertTrue(page.contains(fragment))
    }
}
```

- [ ] **Step 2: Запустить тест — убедиться, что падает**

Run: `swift test --filter PreviewPageTests`
Expected: FAIL (нет функции `previewPageHTML`).

- [ ] **Step 3: Реализовать минимум**

`Sources/QuickLookersPreviewKit/PreviewPage.swift`:

```swift
/// Оборачивает готовый фрагмент подсветки в самодостаточный HTML-документ.
/// Фон и цвета несёт сам фрагмент (его `<pre>` от Shiki); здесь только
/// сброс полей и моноширинный шрифт, чтобы фон заполнял всё окно превью.
public func previewPageHTML(highlighted: String) -> String {
    """
    <!DOCTYPE html>
    <html>
    <head>
    <meta charset="utf-8">
    <style>
    html, body { margin: 0; padding: 0; }
    pre.shiki {
        margin: 0;
        padding: 12px;
        font-family: ui-monospace, "SF Mono", Menlo, monospace;
        font-size: 12px;
        line-height: 1.5;
        tab-size: 4;
    }
    </style>
    </head>
    <body>
    \(highlighted)
    </body>
    </html>
    """
}
```

- [ ] **Step 4: Запустить тест — зелёный**

Run: `swift test --filter PreviewPageTests`
Expected: PASS (2 теста).

- [ ] **Step 5: Прогнать весь пакет — ничего не сломали**

Run: `swift test`
Expected: PASS (движок + оба новых набора).

- [ ] **Step 6: Коммит**

```bash
git add Sources/QuickLookersPreviewKit/PreviewPage.swift Tests/QuickLookersPreviewKitTests/PreviewPageTests.swift
git commit -m "feat(preview): обёртка фрагмента подсветки в HTML-страницу

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: Каркас Xcode-проекта (project.yml + хост + пустое расширение)

Цель задачи — чтобы `xcodegen generate` создал проект, а `xcodebuild` собрал оба таргета (подпись отключена для проверки компиляции). Рендеринг подключим в Task 4.

**Files:**
- Create: `project.yml`
- Create: `.gitignore`
- Create: `App/QuickLookersApp.swift`
- Create: `PreviewExtension/PreviewViewController.swift`

**Interfaces:**
- Produces (для Task 4): класс `PreviewViewController: NSViewController, QLPreviewingController` — точка входа расширения, объявленная в `Info.plist` как `NSExtensionPrincipalClass`.

- [ ] **Step 1: Написать `.gitignore`**

`.gitignore`:

```gitignore
*.xcodeproj
DerivedData/
.build/
```

- [ ] **Step 2: Написать `project.yml`**

`project.yml`:

```yaml
name: QuickLookers
options:
  deploymentTarget:
    macOS: "13.0"
  bundleIdPrefix: com.quicklookers

settings:
  base:
    SWIFT_VERSION: "6.0"
    CODE_SIGN_STYLE: Automatic
    # Впиши сюда свой Team ID (Xcode → Settings → Accounts → твой аккаунт → Team).
    # Для ручного запуска в Finder подпись обязательна; для xcodebuild-проверки
    # компиляции подпись отключается флагом в команде (см. шаги ниже).
    DEVELOPMENT_TEAM: ""

packages:
  QuickLookersEngine:
    path: .

targets:
  QuickLookers:
    type: application
    platform: macOS
    sources: [App]
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.quicklookers.QuickLookers
        GENERATE_INFOPLIST_FILE: YES
        MARKETING_VERSION: "0.1"
        CURRENT_PROJECT_VERSION: "1"
    dependencies:
      - target: QuickLookersPreview
        embed: true

  QuickLookersPreview:
    type: app-extension
    platform: macOS
    sources: [PreviewExtension]
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.quicklookers.QuickLookers.PreviewExtension
    info:
      path: PreviewExtension/Info.plist
      properties:
        NSExtension:
          NSExtensionPointIdentifier: com.apple.quicklook.preview
          NSExtensionPrincipalClass: $(PRODUCT_MODULE_NAME).PreviewViewController
          NSExtensionAttributes:
            QLSupportedContentTypes:
              - public.swift-source
              - public.json
              - com.netscape.javascript-source
            QLSupportsSearchableItems: false
    dependencies:
      - package: QuickLookersEngine
        product: QuickLookersEngine
      - package: QuickLookersEngine
        product: QuickLookersPreviewKit
```

- [ ] **Step 3: Написать заглушку хост-приложения**

`App/QuickLookersApp.swift`:

```swift
import SwiftUI

@main
struct QuickLookersApp: App {
    var body: some Scene {
        WindowGroup("QuickLookers") {
            VStack(spacing: 8) {
                Text("QuickLookers")
                    .font(.title2)
                Text("Расширение Preview зарегистрировано.\nНажми пробел на файле кода в Finder.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 360, height: 160)
        }
    }
}
```

- [ ] **Step 4: Написать скелет расширения (пока без рендеринга)**

`PreviewExtension/PreviewViewController.swift`:

```swift
import Cocoa
import Quartz
import os

final class PreviewViewController: NSViewController, QLPreviewingController {
    private static let log = Logger(subsystem: "com.quicklookers.preview", category: "preview")

    override func loadView() {
        self.view = NSView()
    }

    func preparePreviewOfFile(at url: URL) async throws {
        Self.log.info("preparePreviewOfFile pid=\(getpid()) url=\(url.lastPathComponent, privacy: .public)")
    }
}
```

- [ ] **Step 5: Сгенерировать проект**

Run: `xcodegen generate`
Expected: `Created project at .../QuickLookers.xcodeproj`.

- [ ] **Step 6: Собрать оба таргета без подписи (проверка компиляции)**

Run:
```bash
xcodebuild -project QuickLookers.xcodeproj -scheme QuickLookers \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO build
```
Expected: `** BUILD SUCCEEDED **` (компилируются и приложение, и расширение, и оба пакета).

- [ ] **Step 7: Коммит**

```bash
git add .gitignore project.yml App PreviewExtension
git commit -m "feat(preview): каркас Xcode-проекта (хост + расширение QuickLook)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: Подключить движок и нарисовать превью

**Files:**
- Modify: `PreviewExtension/PreviewViewController.swift`

**Interfaces:**
- Consumes: `QuickLookersEngineFactory.makeDefault() throws -> HighlightEngine`; `HighlightEngine.highlightToHTML(_ request: HighlightRequest) throws -> String`; `HighlightRequest(code:languageId:themeId:)`; `languageId(forPathExtension:)`, `previewPageHTML(highlighted:)` из `QuickLookersPreviewKit`.

- [ ] **Step 1: Реализовать рендеринг в `preparePreviewOfFile`**

Заменить содержимое `PreviewExtension/PreviewViewController.swift` целиком:

```swift
import Cocoa
import Quartz
import WebKit
import os
import QuickLookersEngine
import QuickLookersPreviewKit

final class PreviewViewController: NSViewController, QLPreviewingController {
    private static let log = Logger(subsystem: "com.quicklookers.preview", category: "preview")

    // Тёплый процесс: движок строится один раз на жизнь процесса расширения.
    // На втором показе он уже горячий — это и проверяет spike 1.
    private static var cachedEngine: HighlightEngine?

    private var webView: WKWebView!

    override func loadView() {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = false
        webView = WKWebView(frame: .zero, configuration: config)
        self.view = webView
    }

    func preparePreviewOfFile(at url: URL) async throws {
        let start = Date()
        let wasWarm = Self.cachedEngine != nil

        guard let lang = languageId(forPathExtension: url.pathExtension) else {
            // Тип не из нашего набора — отдаём системе (spike 3, лёгкая версия).
            throw CocoaError(.featureUnsupported)
        }

        let code = try String(contentsOf: url, encoding: .utf8)
        let engine = try Self.engine()
        let fragment = try engine.highlightToHTML(
            HighlightRequest(code: code, languageId: lang, themeId: "dark-plus")
        )
        let page = previewPageHTML(highlighted: fragment)
        webView.loadHTMLString(page, baseURL: nil)

        let ms = Date().timeIntervalSince(start) * 1000
        Self.log.info("""
            preview pid=\(getpid()) warm=\(wasWarm, privacy: .public) \
            lang=\(lang, privacy: .public) ms=\(ms, format: .fixed(precision: 1), privacy: .public)
            """)
    }

    private static func engine() throws -> HighlightEngine {
        if let engine = cachedEngine { return engine }
        let engine = try QuickLookersEngineFactory.makeDefault()
        cachedEngine = engine
        return engine
    }
}
```

- [ ] **Step 2: Перегенерировать проект (исходники расширения не менялись по составу, но на всякий случай)**

Run: `xcodegen generate`
Expected: проект пересоздан без ошибок.

- [ ] **Step 3: Собрать без подписи — проверка компиляции рендеринга**

Run:
```bash
xcodebuild -project QuickLookers.xcodeproj -scheme QuickLookers \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO build
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Прогнать пакет — движок и PreviewKit по-прежнему зелёные**

Run: `swift test`
Expected: PASS.

- [ ] **Step 5: Коммит**

```bash
git add PreviewExtension/PreviewViewController.swift
git commit -m "feat(preview): рендеринг превью движком в WKWebView с замером spike

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 5: Ручная проверка end-to-end и снятие показаний spike

Это checkpoint с ручными шагами пользователя (только он может запускать Finder на своей машине) и документированием результатов. Кода нет — есть инструкция и заметка с цифрами.

**Files:**
- Create: `docs/superpowers/notes/2026-06-28-preview-thin-slice-spikes.md`

- [ ] **Step 1: Вписать Team ID и собрать подписанную версию**

Пользователь: открыть `project.yml`, в `settings.base.DEVELOPMENT_TEAM` вписать свой Team ID
(Xcode → Settings → Accounts → выбрать аккаунт → значение «Team ID»), затем:

```bash
xcodegen generate
open QuickLookers.xcodeproj
```

В Xcode выбрать схему `QuickLookers`, нажать Run (⌘R). Откроется окно-заглушка — это регистрирует расширение в системе.

- [ ] **Step 2: Проверить регистрацию расширения**

Run: `pluginkit -m -p com.apple.quicklook.preview | grep -i quicklookers`
Expected: в выводе строка с `com.quicklookers.QuickLookers.PreviewExtension`.

Если пусто — расширение не зарегистрировалось: убедиться, что приложение реально запускалось из Xcode и собралось с подписью.

- [ ] **Step 3: Превью по пробелу**

Пользователь: в Finder выбрать файл `.swift` (или `.json`, `.js`), нажать **пробел**.
Ожидается: полноразмерное превью с подсветкой в теме Dark+. Сравнить картинку с тем же файлом в VS Code на теме Dark+.

- [ ] **Step 4: Снять показания spike из логов**

Run: `log stream --predicate 'subsystem == "com.quicklookers.preview"' --info`
(оставить запущенным, нажать пробел на нескольких файлах подряд).
Смотрим в строках `preview …`:
- **spike 1 (тёплый процесс):** на первом показе `warm=false`, на последующих — `warm=true` и тот же `pid`. Если `pid` каждый раз новый и `warm=false` — процесс не переиспользуется.
- **spike 2 (бюджет):** значение `ms=` на тёплом показе — реальное время конвейера в расширении.

- [ ] **Step 5: Записать результаты в заметку**

Создать `docs/superpowers/notes/2026-06-28-preview-thin-slice-spikes.md` со структурой:

```markdown
# Расширение Preview, тонкий срез — показания spike

**Дата:** 2026-06-28

## spike 1 — тёплый процесс
- pid между показами: <тот же / меняется>
- warm на 2-м+ показе: <true / false>
- Вывод: <процесс живёт между показами / нет>

## spike 2 — бюджет на реальном конвейере
- cold ms: <…>
- warm ms: <…>
- Против ориентира ~100 мс: <вывод>

## spike 3 — поведение на неподдержанном типе
- <не падает / поведение>

## Картинка против VS Code
- <совпадает / расхождения>

## Что это меняет для следующих фаз
- <кэш HTML / обрезка первого экрана / свап на WASM — что включать первым>
```

- [ ] **Step 6: Коммит заметки**

```bash
git add docs/superpowers/notes/2026-06-28-preview-thin-slice-spikes.md
git commit -m "docs: показания spike тонкого среза расширения Preview

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Самопроверка плана

**Покрытие спеки:**
- Цель «пробел → превью как в VS Code» → Tasks 3–5.
- spike 1 (тёплый процесс) → Task 4 (ленивый статический движок) + Task 5 (замер).
- spike 2 (бюджет на конвейере) → Task 4 (замер ms) + Task 5 (чтение).
- spike 3 (необъявленный тип не падает) → Task 4 (guard + throw) + Task 5.
- Тема dark-plus, языки swift/json/js, UTI → Tasks 1, 3 (Global Constraints).
- JS выключен в WKWebView → Task 4.
- App Group отложен, ресурсы из Bundle.module → Task 4 (через `makeDefault()`).
- XcodeGen, `.xcodeproj` в .gitignore → Task 3.

**Заглушки:** нет — весь код приведён дословно.

**Согласованность типов:** `languageId(forPathExtension:)` и `previewPageHTML(highlighted:)` определены в Tasks 1–2 и вызываются в Task 4 с теми же сигнатурами. `HighlightRequest(code:languageId:themeId:)`, `highlightToHTML(_:)`, `QuickLookersEngineFactory.makeDefault()` — существующий API движка из фазы 1.
