# Оптимизация показа превью — план реализации

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Убрать дефект «длинные строки уезжают за край» и срезать стоимость показа (тёплый вебвью, кэш HTML, защита от гигантских файлов) — без изменений движка.

**Architecture:** Чистая тестируемая логика (перенос/обрезка, ключ и хранилище кэша, сборка страницы) — в SwiftPM-таргете `QuickLookersPreviewKit` под `swift test`. Склейка с WebKit и контейнером App Group — в расширении `PreviewViewController` (проверяется сборкой и лог-спайком в Finder).

**Tech Stack:** Swift 6.3 / SwiftPM, macOS 13+, CryptoKit (SHA-256 для ключа кэша), WebKit/Quartz (расширение).

## Global Constraints

- Swift 6.3 / SwiftPM (tools 5.9), цель macOS 13+. Движок не трогаем.
- TDD строго: падающий тест → запуск (падает) → реализация → запуск (зелёный) → коммит, по одному шагу.
- Вывод — готовая HTML-строка для статичного `WKWebView` с выключенным JS.
- Кэш — ускорение, не источник истины: любая ошибка кэша = промах, показ не ломается.
- Потолок кэша на диске — **5 МБ** (`5 * 1024 * 1024`), вытеснение **LRU** по `mtime` файла.
- Потолок обрезки — **2000 строк**. Порог «гигантского» файла для ограниченного чтения — **2 МБ** (`2 * 1024 * 1024`).
- Перенос строк — **всегда включён**, настройки нет.
- Коммиты по-русски (`feat(preview): …` / `test(preview): …`), трейлер `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`. Ветка `feat/display-optimizations`, не `main`.

## Структура файлов

- Изменить: `Sources/QuickLookersPreviewKit/PreviewPage.swift` — CSS-перенос + параметр `truncatedNotice` с плашкой.
- Создать: `Sources/QuickLookersPreviewKit/CodeTrim.swift` — `trimToFirstLines`, `readBoundedPrefix`.
- Создать: `Sources/QuickLookersPreviewKit/HTMLCache.swift` — `HTMLCacheKey`, `HTMLCache` (lookup/store/evict).
- Изменить: `PreviewExtension/PreviewViewController.swift` — тёплый `sharedWebView`, проводка кэша/обрезки/ограниченного чтения.
- Создать тесты: `Tests/QuickLookersPreviewKitTests/CodeTrimTests.swift`, `Tests/QuickLookersPreviewKitTests/HTMLCacheTests.swift`.
- Изменить тест: `Tests/QuickLookersPreviewKitTests/PreviewPageTests.swift`.

---

### Task 1: Перенос строк в странице показа

**Files:**
- Modify: `Sources/QuickLookersPreviewKit/PreviewPage.swift`
- Test: `Tests/QuickLookersPreviewKitTests/PreviewPageTests.swift`

**Interfaces:**
- Consumes: ничего нового.
- Produces: `previewPageHTML(highlighted:)` теперь содержит CSS-правила переноса в `pre.shiki`.

- [ ] **Step 1: Написать падающий тест**

Добавить в `Tests/QuickLookersPreviewKitTests/PreviewPageTests.swift`:

```swift
    func test_pageWrapsLongLines() {
        let page = previewPageHTML(highlighted: #"<pre class="shiki">x</pre>"#)
        XCTAssertTrue(page.contains("pre-wrap"), "длинные строки должны переноситься")
        XCTAssertTrue(page.contains("overflow-wrap"), "длинные строки без пробелов ломаются")
    }
```

- [ ] **Step 2: Запустить — убедиться, что падает**

Run: `swift test --filter PreviewPageTests/test_pageWrapsLongLines`
Expected: FAIL (страница ещё не содержит `pre-wrap`).

- [ ] **Step 3: Реализация — добавить правила переноса**

В `Sources/QuickLookersPreviewKit/PreviewPage.swift` в стиль `pre.shiki` добавить три строки переноса (после `tab-size: 4;`):

```css
    pre.shiki {
        margin: 0;
        padding: 12px;
        font-family: ui-monospace, "SF Mono", Menlo, monospace;
        font-size: 12px;
        line-height: 1.5;
        tab-size: 4;
        white-space: pre-wrap;
        overflow-wrap: anywhere;
        word-break: break-word;
    }
```

- [ ] **Step 4: Запустить — убедиться, что зелёный**

Run: `swift test --filter PreviewPageTests`
Expected: PASS (все тесты PreviewPageTests).

- [ ] **Step 5: Коммит**

```bash
git add Sources/QuickLookersPreviewKit/PreviewPage.swift Tests/QuickLookersPreviewKitTests/PreviewPageTests.swift
git commit -m "$(printf 'feat(preview): перенос длинных строк в превью\n\nCo-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>')"
```

---

### Task 2: Обрезка кода до N строк

**Files:**
- Create: `Sources/QuickLookersPreviewKit/CodeTrim.swift`
- Test: `Tests/QuickLookersPreviewKitTests/CodeTrimTests.swift`

**Interfaces:**
- Consumes: ничего.
- Produces: `func trimToFirstLines(_ code: String, max: Int) -> (code: String, truncated: Bool)`.

- [ ] **Step 1: Написать падающий тест**

Создать `Tests/QuickLookersPreviewKitTests/CodeTrimTests.swift`:

```swift
import XCTest
@testable import QuickLookersPreviewKit

final class CodeTrimTests: XCTestCase {
    func test_keepsWhenWithinLimit() {
        let r = trimToFirstLines("a\nb", max: 2)
        XCTAssertEqual(r.code, "a\nb")
        XCTAssertFalse(r.truncated)
    }

    func test_trimsWhenOverLimit() {
        let r = trimToFirstLines("a\nb\nc", max: 2)
        XCTAssertEqual(r.code, "a\nb")
        XCTAssertTrue(r.truncated)
    }

    func test_emptyInput() {
        let r = trimToFirstLines("", max: 2)
        XCTAssertEqual(r.code, "")
        XCTAssertFalse(r.truncated)
    }

    func test_singleLine() {
        let r = trimToFirstLines("a", max: 2)
        XCTAssertEqual(r.code, "a")
        XCTAssertFalse(r.truncated)
    }
}
```

- [ ] **Step 2: Запустить — убедиться, что падает**

Run: `swift test --filter CodeTrimTests`
Expected: FAIL (нет `trimToFirstLines` — ошибка компиляции).

- [ ] **Step 3: Реализация**

Создать `Sources/QuickLookersPreviewKit/CodeTrim.swift`:

```swift
import Foundation

/// Режет код до первых `max` строк. `truncated` = true, если что-то отрезано.
/// Пустой ввод → ("", false). Разделитель строк — `\n`.
public func trimToFirstLines(_ code: String, max: Int) -> (code: String, truncated: Bool) {
    let lines = code.split(separator: "\n", omittingEmptySubsequences: false)
    if lines.count <= max {
        return (code, false)
    }
    let kept = lines.prefix(max).joined(separator: "\n")
    return (kept, true)
}
```

- [ ] **Step 4: Запустить — убедиться, что зелёный**

Run: `swift test --filter CodeTrimTests`
Expected: PASS (4 теста).

- [ ] **Step 5: Коммит**

```bash
git add Sources/QuickLookersPreviewKit/CodeTrim.swift Tests/QuickLookersPreviewKitTests/CodeTrimTests.swift
git commit -m "$(printf 'feat(preview): обрезка кода до N строк\n\nCo-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>')"
```

---

### Task 3: Плашка «показаны первые N строк»

**Files:**
- Modify: `Sources/QuickLookersPreviewKit/PreviewPage.swift`
- Test: `Tests/QuickLookersPreviewKitTests/PreviewPageTests.swift`

**Interfaces:**
- Consumes: ничего.
- Produces: `func previewPageHTML(highlighted: String, truncatedNotice: String? = nil) -> String`. При `truncatedNotice != nil` страница содержит блок `<div class="ql-truncated">…</div>` с этим текстом; при `nil` блока нет (обратная совместимость с текущими вызовами).

- [ ] **Step 1: Написать падающий тест**

Добавить в `Tests/QuickLookersPreviewKitTests/PreviewPageTests.swift`:

```swift
    func test_truncationNoticeShownWhenProvided() {
        let page = previewPageHTML(highlighted: "x", truncatedNotice: "Показаны первые 2000 строк")
        XCTAssertTrue(page.contains("ql-truncated"), "должна быть плашка обрезки")
        XCTAssertTrue(page.contains("Показаны первые 2000 строк"), "текст плашки вставлен")
    }

    func test_noTruncationNoticeByDefault() {
        let page = previewPageHTML(highlighted: "x")
        XCTAssertFalse(page.contains("ql-truncated"), "без обрезки плашки нет")
    }
```

- [ ] **Step 2: Запустить — убедиться, что падает**

Run: `swift test --filter PreviewPageTests/test_truncationNoticeShownWhenProvided`
Expected: FAIL (нет параметра `truncatedNotice` / нет класса `ql-truncated`).

- [ ] **Step 3: Реализация**

Заменить тело `Sources/QuickLookersPreviewKit/PreviewPage.swift` целиком (сохранив правила переноса из Task 1):

```swift
/// Оборачивает готовый фрагмент подсветки в самодостаточный HTML-документ.
/// Фон и цвета несёт сам фрагмент (его `<pre>` от Shiki); здесь только сброс
/// полей, моноширинный шрифт и перенос длинных строк, чтобы фон заполнял окно.
/// `truncatedNotice` (если задан) дорисовывает внизу неинтерактивную плашку.
public func previewPageHTML(highlighted: String, truncatedNotice: String? = nil) -> String {
    let notice = truncatedNotice.map { #"<div class="ql-truncated">\#($0)</div>"# } ?? ""
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
        font-family: ui-monospace, "SF Mono", Menlo, monospace;
        font-size: 12px;
        line-height: 1.5;
        tab-size: 4;
        white-space: pre-wrap;
        overflow-wrap: anywhere;
        word-break: break-word;
    }
    .ql-truncated {
        padding: 8px 12px;
        font-family: -apple-system, system-ui, sans-serif;
        font-size: 11px;
        color: #888;
        text-align: center;
    }
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

- [ ] **Step 4: Запустить — убедиться, что зелёный**

Run: `swift test --filter PreviewPageTests`
Expected: PASS (все тесты PreviewPageTests, включая прежние из Task 1).

- [ ] **Step 5: Коммит**

```bash
git add Sources/QuickLookersPreviewKit/PreviewPage.swift Tests/QuickLookersPreviewKitTests/PreviewPageTests.swift
git commit -m "$(printf 'feat(preview): плашка обрезки в странице показа\n\nCo-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>')"
```

---

### Task 4: Ограниченное чтение префикса файла

**Files:**
- Modify: `Sources/QuickLookersPreviewKit/CodeTrim.swift`
- Test: `Tests/QuickLookersPreviewKitTests/CodeTrimTests.swift`

**Interfaces:**
- Consumes: ничего.
- Produces: `func readBoundedPrefix(of url: URL, maxBytes: Int) throws -> String` — читает не более `maxBytes` байт файла как UTF-8, отбрасывая неполный хвостовой многобайтовый символ.

- [ ] **Step 1: Написать падающий тест**

Добавить в `Tests/QuickLookersPreviewKitTests/CodeTrimTests.swift` (и `import Foundation` уже есть через XCTest; добавить хелпер temp-файла):

```swift
    private func writeTemp(_ data: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ql-trim-\(UUID().uuidString)")
        try data.write(to: url)
        return url
    }

    func test_readsWholeSmallFile() throws {
        let url = try writeTemp(Data("hello".utf8))
        let s = try readBoundedPrefix(of: url, maxBytes: 1024)
        XCTAssertEqual(s, "hello")
    }

    func test_readsBoundedPrefixOfLargeFile() throws {
        let url = try writeTemp(Data(String(repeating: "a", count: 10_000).utf8))
        let s = try readBoundedPrefix(of: url, maxBytes: 100)
        XCTAssertLessThanOrEqual(s.utf8.count, 100)
        XCTAssertEqual(s, String(repeating: "a", count: 100))
    }

    func test_doesNotCrashOnMultibyteBoundary() throws {
        // "я" = 2 байта в UTF-8; лимит в 5 байт разрежет на середине символа.
        let url = try writeTemp(Data(String(repeating: "я", count: 10).utf8))
        let s = try readBoundedPrefix(of: url, maxBytes: 5)
        XCTAssertLessThanOrEqual(s.utf8.count, 5)
        XCTAssertTrue(s.allSatisfy { $0 == "я" }, "не должно быть мусорных символов")
    }
```

- [ ] **Step 2: Запустить — убедиться, что падает**

Run: `swift test --filter CodeTrimTests/test_readsWholeSmallFile`
Expected: FAIL (нет `readBoundedPrefix`).

- [ ] **Step 3: Реализация**

Добавить в `Sources/QuickLookersPreviewKit/CodeTrim.swift`:

```swift
/// Читает не более `maxBytes` префикса файла как UTF-8. Если граница попала на
/// середину многобайтового символа — отбрасывает неполный хвост (до 3 байт).
public func readBoundedPrefix(of url: URL, maxBytes: Int) throws -> String {
    let handle = try FileHandle(forReadingFrom: url)
    defer { try? handle.close() }
    let data = try handle.read(upToCount: maxBytes) ?? Data()
    if let s = String(data: data, encoding: .utf8) { return s }
    // UTF-8 символ — до 4 байт; отрезаем хвост по байту, пока не декодируется.
    var trimmed = data
    for _ in 0..<3 {
        guard !trimmed.isEmpty else { break }
        trimmed.removeLast()
        if let s = String(data: trimmed, encoding: .utf8) { return s }
    }
    return ""
}
```

- [ ] **Step 4: Запустить — убедиться, что зелёный**

Run: `swift test --filter CodeTrimTests`
Expected: PASS (7 тестов: 4 из Task 2 + 3 новых).

- [ ] **Step 5: Коммит**

```bash
git add Sources/QuickLookersPreviewKit/CodeTrim.swift Tests/QuickLookersPreviewKitTests/CodeTrimTests.swift
git commit -m "$(printf 'feat(preview): ограниченное чтение префикса больших файлов\n\nCo-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>')"
```

---

### Task 5: Ключ кэша HTML

**Files:**
- Create: `Sources/QuickLookersPreviewKit/HTMLCache.swift`
- Test: `Tests/QuickLookersPreviewKitTests/HTMLCacheTests.swift`

**Interfaces:**
- Consumes: ничего.
- Produces:
  ```swift
  public struct HTMLCacheKey: Equatable {
      public init(path: String, mtime: TimeInterval, size: Int,
                  languageId: String, themeId: String, maxLines: Int, bundleVersion: String)
      public var fileName: String { get }   // короткий стабильный хэш + ".html"
  }
  ```

- [ ] **Step 1: Написать падающий тест**

Создать `Tests/QuickLookersPreviewKitTests/HTMLCacheTests.swift`:

```swift
import XCTest
@testable import QuickLookersPreviewKit

final class HTMLCacheTests: XCTestCase {
    private func sampleKey(
        path: String = "/a/b.swift", mtime: TimeInterval = 100, size: Int = 10,
        languageId: String = "swift", themeId: String = "dark-plus",
        maxLines: Int = 2000, bundleVersion: String = "1"
    ) -> HTMLCacheKey {
        HTMLCacheKey(path: path, mtime: mtime, size: size, languageId: languageId,
                     themeId: themeId, maxLines: maxLines, bundleVersion: bundleVersion)
    }

    func test_fileNameStableForSameInputs() {
        XCTAssertEqual(sampleKey().fileName, sampleKey().fileName)
        XCTAssertTrue(sampleKey().fileName.hasSuffix(".html"))
    }

    func test_fileNameChangesPerField() {
        let base = sampleKey().fileName
        XCTAssertNotEqual(base, sampleKey(path: "/other").fileName)
        XCTAssertNotEqual(base, sampleKey(mtime: 200).fileName)
        XCTAssertNotEqual(base, sampleKey(size: 20).fileName)
        XCTAssertNotEqual(base, sampleKey(languageId: "json").fileName)
        XCTAssertNotEqual(base, sampleKey(themeId: "light-plus").fileName)
        XCTAssertNotEqual(base, sampleKey(maxLines: 1000).fileName)
        XCTAssertNotEqual(base, sampleKey(bundleVersion: "2").fileName)
    }
}
```

- [ ] **Step 2: Запустить — убедиться, что падает**

Run: `swift test --filter HTMLCacheTests`
Expected: FAIL (нет `HTMLCacheKey`).

- [ ] **Step 3: Реализация**

Создать `Sources/QuickLookersPreviewKit/HTMLCache.swift`:

```swift
import Foundation
import CryptoKit

/// Ключ записи кэша. Все поля влияют на готовый HTML; имя файла — их хэш.
/// Поля считаются дёшево из атрибутов файла, без чтения содержимого.
public struct HTMLCacheKey: Equatable {
    public let path: String
    public let mtime: TimeInterval
    public let size: Int
    public let languageId: String
    public let themeId: String
    public let maxLines: Int
    public let bundleVersion: String

    public init(path: String, mtime: TimeInterval, size: Int,
                languageId: String, themeId: String, maxLines: Int, bundleVersion: String) {
        self.path = path
        self.mtime = mtime
        self.size = size
        self.languageId = languageId
        self.themeId = themeId
        self.maxLines = maxLines
        self.bundleVersion = bundleVersion
    }

    /// Короткий стабильный хэш всех полей — имя файла записи в кэше.
    public var fileName: String {
        let raw = "\(path)|\(mtime)|\(size)|\(languageId)|\(themeId)|\(maxLines)|\(bundleVersion)"
        let digest = SHA256.hash(data: Data(raw.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return hex + ".html"
    }
}
```

- [ ] **Step 4: Запустить — убедиться, что зелёный**

Run: `swift test --filter HTMLCacheTests`
Expected: PASS (2 теста).

- [ ] **Step 5: Коммит**

```bash
git add Sources/QuickLookersPreviewKit/HTMLCache.swift Tests/QuickLookersPreviewKitTests/HTMLCacheTests.swift
git commit -m "$(printf 'feat(preview): ключ кэша HTML\n\nCo-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>')"
```

---

### Task 6: Хранилище кэша — lookup/store

**Files:**
- Modify: `Sources/QuickLookersPreviewKit/HTMLCache.swift`
- Test: `Tests/QuickLookersPreviewKitTests/HTMLCacheTests.swift`

**Interfaces:**
- Consumes: `HTMLCacheKey` (Task 5).
- Produces:
  ```swift
  public struct HTMLCache {
      public init(directory: URL, maxBytes: Int)
      public func lookup(_ key: HTMLCacheKey) -> String?   // nil = промах (нет/битый файл)
      public func store(_ key: HTMLCacheKey, html: String) // атомарно; ошибка проглатывается
  }
  ```

- [ ] **Step 1: Написать падающий тест**

Добавить в `Tests/QuickLookersPreviewKitTests/HTMLCacheTests.swift`:

```swift
    private func makeTempDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ql-htmlcache-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func test_storeThenLookupReturnsSameHtml() throws {
        let dir = try makeTempDir()
        let cache = HTMLCache(directory: dir, maxBytes: 5 * 1024 * 1024)
        let key = sampleKey()
        cache.store(key, html: "<html>hi</html>")
        XCTAssertEqual(cache.lookup(key), "<html>hi</html>")
    }

    func test_lookupMissOnEmptyDir() throws {
        let dir = try makeTempDir()
        let cache = HTMLCache(directory: dir, maxBytes: 5 * 1024 * 1024)
        XCTAssertNil(cache.lookup(sampleKey()))
    }

    func test_corruptEntryIsMiss() throws {
        let dir = try makeTempDir()
        let cache = HTMLCache(directory: dir, maxBytes: 5 * 1024 * 1024)
        let key = sampleKey()
        // Невалидный UTF-8 в файле записи → lookup должен дать nil, не упасть.
        try Data([0xFF, 0xFE]).write(to: dir.appendingPathComponent(key.fileName))
        XCTAssertNil(cache.lookup(key))
    }
```

- [ ] **Step 2: Запустить — убедиться, что падает**

Run: `swift test --filter HTMLCacheTests/test_storeThenLookupReturnsSameHtml`
Expected: FAIL (нет `HTMLCache`).

- [ ] **Step 3: Реализация**

Добавить в `Sources/QuickLookersPreviewKit/HTMLCache.swift`:

```swift
/// Файловый кэш готового HTML в заданной папке. Любая ошибка ввода-вывода
/// трактуется как промах/проглатывается — кэш не источник истины.
public struct HTMLCache {
    private let directory: URL
    private let maxBytes: Int
    private let fm = FileManager.default

    public init(directory: URL, maxBytes: Int) {
        self.directory = directory
        self.maxBytes = maxBytes
    }

    /// HTML записи или nil (нет файла / не читается / не UTF-8).
    /// При попадании обновляет отметку использования (mtime файла) для LRU.
    public func lookup(_ key: HTMLCacheKey) -> String? {
        let url = directory.appendingPathComponent(key.fileName)
        guard let data = try? Data(contentsOf: url),
              let html = String(data: data, encoding: .utf8) else { return nil }
        try? fm.setAttributes([.modificationDate: Date()], ofItemAtPath: url.path)
        return html
    }

    /// Пишет HTML атомарно. Ошибка проглатывается (показ уже идёт).
    public func store(_ key: HTMLCacheKey, html: String) {
        try? fm.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(key.fileName)
        try? Data(html.utf8).write(to: url, options: .atomic)
    }
}
```

- [ ] **Step 4: Запустить — убедиться, что зелёный**

Run: `swift test --filter HTMLCacheTests`
Expected: PASS (5 тестов: 2 из Task 5 + 3 новых).

- [ ] **Step 5: Коммит**

```bash
git add Sources/QuickLookersPreviewKit/HTMLCache.swift Tests/QuickLookersPreviewKitTests/HTMLCacheTests.swift
git commit -m "$(printf 'feat(preview): хранилище кэша HTML (lookup/store)\n\nCo-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>')"
```

---

### Task 7: LRU-вытеснение кэша

**Files:**
- Modify: `Sources/QuickLookersPreviewKit/HTMLCache.swift`
- Test: `Tests/QuickLookersPreviewKitTests/HTMLCacheTests.swift`

**Interfaces:**
- Consumes: `HTMLCache` (Task 6).
- Produces: `public func evictIfNeeded()` — если суммарный размер файлов кэша больше `maxBytes`, удаляет давно не использованные (по возрастанию `mtime`), пока не уложится.

- [ ] **Step 1: Написать падающий тест**

Добавить в `Tests/QuickLookersPreviewKitTests/HTMLCacheTests.swift`:

```swift
    func test_evictKeepsUnderCapAndDropsOldest() throws {
        let dir = try makeTempDir()
        // Потолок мал: вмещает примерно одну запись по 1000 байт.
        let cache = HTMLCache(directory: dir, maxBytes: 1500)
        let oldKey = sampleKey(path: "/old.swift")
        let newKey = sampleKey(path: "/new.swift")
        let html = String(repeating: "x", count: 1000)

        cache.store(oldKey, html: html)
        // Старую запись помечаем давно использованной.
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 1)],
            ofItemAtPath: dir.appendingPathComponent(oldKey.fileName).path)
        cache.store(newKey, html: html)   // свежая отметка — сейчас

        cache.evictIfNeeded()

        XCTAssertNil(cache.lookup(oldKey), "давняя запись вытеснена")
        XCTAssertNotNil(cache.lookup(newKey), "свежая запись осталась")
    }

    func test_evictNoopWhenUnderCap() throws {
        let dir = try makeTempDir()
        let cache = HTMLCache(directory: dir, maxBytes: 5 * 1024 * 1024)
        let key = sampleKey()
        cache.store(key, html: "small")
        cache.evictIfNeeded()
        XCTAssertNotNil(cache.lookup(key), "под потолком ничего не удаляется")
    }
```

- [ ] **Step 2: Запустить — убедиться, что падает**

Run: `swift test --filter HTMLCacheTests/test_evictKeepsUnderCapAndDropsOldest`
Expected: FAIL (нет `evictIfNeeded`).

- [ ] **Step 3: Реализация**

Добавить метод в `struct HTMLCache` в `Sources/QuickLookersPreviewKit/HTMLCache.swift`:

```swift
    /// Если суммарный размер кэша больше `maxBytes` — удаляет давно не
    /// использованные записи (по возрастанию mtime), пока не уложится.
    public func evictIfNeeded() {
        guard let urls = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]) else { return }

        var files: [(url: URL, size: Int, mtime: Date)] = []
        var total = 0
        for url in urls {
            let vals = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            let size = vals?.fileSize ?? 0
            let mtime = vals?.contentModificationDate ?? .distantPast
            files.append((url, size, mtime))
            total += size
        }
        guard total > maxBytes else { return }

        files.sort { $0.mtime < $1.mtime }   // давно использованные — первыми
        for f in files {
            if total <= maxBytes { break }
            if (try? fm.removeItem(at: f.url)) != nil {
                total -= f.size
            }
        }
    }
```

- [ ] **Step 4: Запустить — убедиться, что зелёный**

Run: `swift test --filter HTMLCacheTests`
Expected: PASS (7 тестов).

- [ ] **Step 5: Коммит**

```bash
git add Sources/QuickLookersPreviewKit/HTMLCache.swift Tests/QuickLookersPreviewKitTests/HTMLCacheTests.swift
git commit -m "$(printf 'feat(preview): LRU-вытеснение кэша HTML по потолку размера\n\nCo-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>')"
```

---

### Task 8: Проводка в расширение — тёплый вебвью, кэш, обрезка

**Files:**
- Modify: `PreviewExtension/PreviewViewController.swift`

**Interfaces:**
- Consumes: `trimToFirstLines`, `readBoundedPrefix`, `previewPageHTML(highlighted:truncatedNotice:)`, `HTMLCacheKey`, `HTMLCache` (PreviewKit); `quickLookersContainerURL()` (SettingsKit); существующие `previewLanguageId`, `resolvedThemeId`, `Self.engine()`, `Self.themeIds()`, `Self.settings()`.
- Produces: ничего для других задач (конечная склейка).

Это единственная задача без юнит-тестов — `PreviewViewController` живёт в Xcode-таргете, не в SwiftPM-пакете. Проверка: пакет по-прежнему зелёный, проект компилируется, и ручной лог-спайк в Finder.

- [ ] **Step 1: Заменить файл целиком**

Заменить `PreviewExtension/PreviewViewController.swift` на:

```swift
import Cocoa
import Quartz
import WebKit
import os
import QuickLookersEngine
import QuickLookersPreviewKit
import QuickLookersSettingsKit

final class PreviewViewController: NSViewController, QLPreviewingController, WKNavigationDelegate {
    private static let log = Logger(subsystem: "com.quicklookers.preview", category: "preview")

    // Тёплый процесс: движок, набор id тем и сам вебвью строятся один раз на
    // жизнь процесса. Общий вебвью переживает контроллеры — убирает холодный
    // старт WebContent (выбросы 1–2,6 с).
    private static var cachedEngine: HighlightEngine?
    private static var cachedThemeIds: Set<String>?
    private static let sharedWebView: WKWebView = {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = false
        return WKWebView(frame: .zero, configuration: config)
    }()

    // Константы фазы оптимизации (см. спеку 2026-06-29).
    private static let maxLines = 2000
    private static let largeFileThreshold = 2 * 1024 * 1024   // 2 МБ
    private static let cacheMaxBytes = 5 * 1024 * 1024         // 5 МБ
    private static let bundleVersion =
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "0"

    private var loadContinuation: CheckedContinuation<Void, Error>?

    override func loadView() {
        // Общий вебвью переезжает к текущему контроллеру; делегат указываем на себя.
        Self.sharedWebView.navigationDelegate = self
        self.view = Self.sharedWebView
    }

    func preparePreviewOfFile(at url: URL) async throws {
        let start = Date()
        let wasWarm = Self.cachedEngine != nil

        let settings = Self.settings()
        guard let lang = previewLanguageId(forPathExtension: url.pathExtension, settings: settings) else {
            // Не наш тип / язык выключен / убран из просмотра — отдаём системе.
            throw CocoaError(.featureUnsupported)
        }

        let isDark = view.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let themeId = resolvedThemeId(settings.theme,
                                      availableThemeIds: try Self.themeIds(),
                                      appearanceIsDark: isDark)

        // Дешёвый ключ кэша: атрибуты файла без чтения содержимого.
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        let mtime = (attrs[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        let size = (attrs[.size] as? Int) ?? 0
        let key = HTMLCacheKey(path: url.path, mtime: mtime, size: size,
                               languageId: lang, themeId: themeId,
                               maxLines: Self.maxLines, bundleVersion: Self.bundleVersion)

        let cache = Self.cache()
        let page: String
        let cacheHit: Bool
        if let cached = cache?.lookup(key) {
            page = cached
            cacheHit = true
        } else {
            cacheHit = false
            let code = size > Self.largeFileThreshold
                ? try readBoundedPrefix(of: url, maxBytes: Self.largeFileThreshold)
                : try String(contentsOf: url, encoding: .utf8)
            let (trimmed, truncated) = trimToFirstLines(code, max: Self.maxLines)
            let engine = try Self.engine()
            let fragment = try engine.highlightToHTML(
                HighlightRequest(code: trimmed, languageId: lang, themeId: themeId))
            let notice = truncated ? "Показаны первые \(Self.maxLines) строк" : nil
            page = previewPageHTML(highlighted: fragment, truncatedNotice: notice)
            cache?.store(key, html: page)
        }

        Self.sharedWebView.navigationDelegate = self
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            self.loadContinuation = cont
            Self.sharedWebView.loadHTMLString(page, baseURL: nil)
        }

        // Вытеснение — после показа, вне горячего пути.
        if !cacheHit { cache?.evictIfNeeded() }

        let ms = Date().timeIntervalSince(start) * 1000
        Self.log.info("""
            preview pid=\(getpid()) warm=\(wasWarm, privacy: .public) \
            cache=\(cacheHit, privacy: .public) lang=\(lang, privacy: .public) \
            theme=\(themeId, privacy: .public) \
            ms=\(ms, format: .fixed(precision: 1), privacy: .public)
            """)
    }

    private func finishLoad(_ result: Result<Void, Error>) {
        guard let cont = loadContinuation else { return }
        loadContinuation = nil
        cont.resume(with: result)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        finishLoad(.success(()))
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        finishLoad(.failure(error))
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        finishLoad(.failure(error))
    }

    private static func settings() -> ManagerSettings {
        guard let container = quickLookersContainerURL() else { return .default }
        return SettingsStore(fileURL: container.appendingPathComponent("settings.json")).load()
    }

    private static func cache() -> HTMLCache? {
        guard let container = quickLookersContainerURL() else { return nil }
        return HTMLCache(directory: container.appendingPathComponent("Caches/html"),
                         maxBytes: cacheMaxBytes)
    }

    private static func themeIds() throws -> Set<String> {
        if let ids = cachedThemeIds { return ids }
        let source = FileCatalogSource(
            grammarsDirectory: try QuickLookersEngineResources.grammarsDirectory(),
            themesDirectory: try QuickLookersEngineResources.themesDirectory())
        let ids = Set(try source.loadCatalog().themes.map(\.id))
        cachedThemeIds = ids
        return ids
    }

    private static func engine() throws -> HighlightEngine {
        if let engine = cachedEngine { return engine }
        let engine = try QuickLookersEngineFactory.makeDefault()
        cachedEngine = engine
        return engine
    }
}
```

- [ ] **Step 2: Проверить, что пакет по-прежнему зелёный**

Run: `swift test`
Expected: PASS — все тесты пакета (движок + PreviewKit + SettingsKit), включая новые из задач 1–7.

- [ ] **Step 3: Проверить компиляцию проекта**

Run:
```bash
xcodegen generate
xcodebuild -project QuickLookers.xcodeproj -scheme QuickLookers \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```
Expected: `BUILD SUCCEEDED`. Диагностика SourceKit в редакторе («No such module …») — задержка индексатора, не ошибка сборки.

- [ ] **Step 4: Ручной лог-спайк в Finder (проверка тёплого вебвью и кэша)**

Запустить хост из Xcode (⌘R), затем в терминале:
```bash
/usr/bin/log stream --info --predicate 'subsystem == "com.quicklookers.preview"'
```
Нажать пробел на `.swift`/`.json`-файле несколько раз, проверить в логах:
- `warm=true` на показах после первого, `pid` не меняется (тёплый процесс и вебвью);
- `cache=false` на первом показе файла, `cache=true` на повторном показе того же файла;
- нет выбросов `ms` 1000–2600 на повторных показах (холодный WebContent ушёл);
- длинная строка (минифицированный JSON) переносится, не уезжает за край.

- [ ] **Step 5: Коммит**

```bash
git add PreviewExtension/PreviewViewController.swift
git commit -m "$(printf 'feat(preview): тёплый вебвью, кэш HTML и обрезка в расширении\n\nCo-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>')"
```

---

## Заметки по реализации

- **Тёплый вебвью — риск переродительства.** Вид может быть в одной иерархии за раз. QuickLook показывает один файл за раз, прошлый контроллер к новому показу освобождён — конфликта нет. Если всплывёт (два одновременных превью) — видно по логу; откат — вернуть создание вебвью в `loadView` под контроллер.
- **`bundleVersion`** берётся из `CFBundleVersion` бандла расширения (`CURRENT_PROJECT_VERSION` в `project.yml`). При обновлении приложения версия растёт → старый кэш не подхватывается.
- **Папка кэша** `Caches/html` в контейнере App Group создаётся лениво при первой записи (`store`).
- После Task 8 обновить «Текущее состояние» в `CLAUDE.md`/`README.md` — отдельным `docs:`-коммитом вне TDD-цикла (вне области ревью задач).
```
