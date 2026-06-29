# Импорт из `.vsix` Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Импортировать темы и грамматики из `.vsix`-файла в общий контейнер так, чтобы движок красил ими наравне со встроенными.

**Architecture:** Чистая логика импорта — в новом пакете `QuickLookersImportKit` (распаковка `.vsix` через системную `libarchive` за C-мостиком `CLibArchive`, парсинг `package.json`, нормализация грамматик/тем). Движок получает композитный провайдер «контейнер старше бандла». Запись артефактов в контейнер App Group и UI — в приложении/`QuickLookersSettingsKit`.

**Tech Stack:** Swift 6.3 / SwiftPM (macOS 13+), системная `libarchive` (через `.systemLibrary`), Foundation (`PropertyListSerialization`/`JSONSerialization`), XCTest, XcodeGen.

## Global Constraints

- **TDD строго:** падающий тест → запуск (падает) → реализация → запуск (зелёный) → коммит, по одному шагу.
- **Без сторонних зависимостей:** распаковка — системная `libarchive` (заголовка `archive.h` в SDK нет → объявляем прототипы сами в `shim.h`; символы есть в SDK `.tbd` для arm64e/x86_64, линкуем `archive`). plist→JSON — Foundation. Только Shiki остаётся как было.
- **Всё офлайн:** импорт не использует сеть (`.vsix` уже скачан пользователем).
- **Запись в групповой контейнер — только приложение.** Расширение Preview контейнер лишь читает.
- **Движок изолирован за протоколом** `HighlightEngine`; `QuickLookersImportKit` не зависит от движка (встроенные грамматики получает как путь к каталогу).
- **Чтение каталога не пустеет** и перекрытие по `id` — через уже готовый сайдкар (`sidecarURLs`, слияние последний-перекрывает).
- **Артефакты XcodeGen** (`.xcodeproj`, `*.entitlements`, `Info.plist`) не править руками — только `project.yml` + `xcodegen generate`.
- Отдельная ветка `feat/vsix-import`, не `main`. Коммиты по-русски, трейлер `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.

## Раскладка контейнера (целевая)

```
<контейнер App Group>/library/grammars/<id>.json
<контейнер App Group>/library/themes/<id>.json
<контейнер App Group>/library/catalog-imported.json   # {languages:[{id,displayName}], themes:[{id,displayName,isDark}]}
```

## Зависимости пакетов (итоговые)

```
CLibArchive (system lib)  ←  QuickLookersImportKit  ←  QuickLookersSettingsKit
QuickLookersEngine (composite providers, без новых зависимостей)
```

---

### Task 1: Мостик `CLibArchive` + `ZipReader`

Системный мостик к `libarchive` и чтение записей `.vsix` из памяти. Фикстуры `.vsix` для тестов.

**Files:**
- Create: `Sources/CLibArchive/module.modulemap`, `Sources/CLibArchive/shim.h`
- Modify: `Package.swift` (добавить `.systemLibrary` + таргет `QuickLookersImportKit` + тест-таргет)
- Create: `Sources/QuickLookersImportKit/ZipReader.swift`
- Create: `Tests/QuickLookersImportKitTests/Fixtures/make-fixtures.sh` и собранные `*.vsix`
- Test: `Tests/QuickLookersImportKitTests/ZipReaderTests.swift`

**Interfaces:**
- Produces: `ZipReader()` с `func entryNames(in data: Data) throws -> [String]` и `func entry(_ name: String, in data: Data) throws -> Data?`; `enum ZipError: Error { case open, read }`.

- [ ] **Step 1: Системный таргет `CLibArchive`**

`Sources/CLibArchive/shim.h` (объявляем только используемые функции; заголовка в SDK нет, ABI стабилен):

```c
#ifndef CLIBARCHIVE_SHIM_H
#define CLIBARCHIVE_SHIM_H
#include <stddef.h>
#include <stdint.h>
#include <sys/types.h>   /* ssize_t */

struct archive;
struct archive_entry;

struct archive *archive_read_new(void);
int archive_read_support_format_all(struct archive *);
int archive_read_support_filter_all(struct archive *);
int archive_read_open_memory(struct archive *, const void *buff, size_t size);
int archive_read_next_header(struct archive *, struct archive_entry **);
const char *archive_entry_pathname(struct archive_entry *);
int64_t archive_entry_size(struct archive_entry *);
ssize_t archive_read_data(struct archive *, void *buff, size_t size);
int archive_read_data_skip(struct archive *);
int archive_read_free(struct archive *);
#endif
```

`Sources/CLibArchive/module.modulemap`:

```
module CLibArchive {
    header "shim.h"
    link "archive"
    export *
}
```

- [ ] **Step 2: Объявить таргеты в `Package.swift`**

Добавить в `targets:` (после существующих):

```swift
        .systemLibrary(name: "CLibArchive", path: "Sources/CLibArchive"),
        .target(
            name: "QuickLookersImportKit",
            dependencies: ["CLibArchive"]
        ),
        .testTarget(
            name: "QuickLookersImportKitTests",
            dependencies: ["QuickLookersImportKit"],
            resources: [.copy("Fixtures")]
        ),
```

И в `products:` добавить библиотеку:

```swift
        .library(name: "QuickLookersImportKit", targets: ["QuickLookersImportKit"]),
```

- [ ] **Step 3: Собрать фикстуры `.vsix`**

`Tests/QuickLookersImportKitTests/Fixtures/make-fixtures.sh` (детерминированно собирает мелкие архивы; запускается один раз, результат коммитится):

```bash
#!/bin/bash
# Собирает минимальные .vsix-фикстуры. Запуск: bash make-fixtures.sh
set -e
cd "$(dirname "$0")"
rm -rf build && mkdir build

# theme-only: один package.json + одна тема
mkdir -p build/theme/extension/theme
cat > build/theme/extension/package.json <<'EOF'
{"name":"t","contributes":{"themes":[{"label":"My Cool Theme","uiTheme":"vs-dark","path":"./theme/cool.json"}]}}
EOF
echo '{"name":"My Cool Theme","type":"dark","tokenColors":[]}' > build/theme/extension/theme/cool.json
(cd build/theme && zip -r -X ../../theme-only.vsix extension >/dev/null)

# grammar-json: JSON-грамматика без вложенных (deflate)
mkdir -p build/gj/extension/syntaxes
cat > build/gj/extension/package.json <<'EOF'
{"name":"g","contributes":{"languages":[{"id":"toy","aliases":["Toy Lang"]}],"grammars":[{"language":"toy","scopeName":"source.toy","path":"./syntaxes/toy.tmLanguage.json"}]}}
EOF
echo '{"name":"toy","scopeName":"source.toy","patterns":[]}' > build/gj/extension/syntaxes/toy.tmLanguage.json
(cd build/gj && zip -r -X ../../grammar-json.vsix extension >/dev/null)

# stored (без сжатия) — проверить путь stored в libarchive
(cd build/gj && zip -r -0 -X ../../grammar-json-stored.vsix extension >/dev/null)

# not-a-vsix: случайные байты
head -c 64 /dev/urandom > not-a-vsix.vsix

rm -rf build
echo "fixtures built"
```

Запустить:
```bash
bash Tests/QuickLookersImportKitTests/Fixtures/make-fixtures.sh
```
Expected: `fixtures built`; появились `theme-only.vsix`, `grammar-json.vsix`, `grammar-json-stored.vsix`, `not-a-vsix.vsix`.

- [ ] **Step 4: Написать падающий тест `ZipReader`**

`Tests/QuickLookersImportKitTests/ZipReaderTests.swift`:

```swift
import XCTest
@testable import QuickLookersImportKit

final class ZipReaderTests: XCTestCase {
    private func fixture(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "Fixtures/\(name)", withExtension: nil))
        return try Data(contentsOf: url)
    }

    func test_listsEntryNames() throws {
        let names = try ZipReader().entryNames(in: try fixture("theme-only.vsix"))
        XCTAssertTrue(names.contains("extension/package.json"))
        XCTAssertTrue(names.contains("extension/theme/cool.json"))
    }

    func test_extractsEntryBytes_deflate() throws {
        let data = try XCTUnwrap(try ZipReader().entry("extension/package.json", in: try fixture("grammar-json.vsix")))
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual((obj?["name"] as? String), "g")
    }

    func test_extractsEntryBytes_stored() throws {
        let data = try XCTUnwrap(try ZipReader().entry("extension/syntaxes/toy.tmLanguage.json",
                                                       in: try fixture("grammar-json-stored.vsix")))
        XCTAssertTrue(String(data: data, encoding: .utf8)!.contains("source.toy"))
    }

    func test_missingEntryReturnsNil() throws {
        XCTAssertNil(try ZipReader().entry("extension/nope.json", in: try fixture("theme-only.vsix")))
    }

    func test_notAnArchiveThrows() throws {
        XCTAssertThrowsError(try ZipReader().entryNames(in: try fixture("not-a-vsix.vsix")))
    }
}
```

- [ ] **Step 5: Запустить — падает (нет `ZipReader`)**

Run: `swift test --filter ZipReaderTests`
Expected: ошибка компиляции — нет типа `ZipReader`.

- [ ] **Step 6: Реализовать `ZipReader`**

`Sources/QuickLookersImportKit/ZipReader.swift`:

```swift
import Foundation
import CLibArchive

public enum ZipError: Error { case open, read }

/// Читает записи ZIP (.vsix) из памяти через системную libarchive.
/// Память архива должна жить на время чтения, поэтому всё — внутри withUnsafeBytes.
public struct ZipReader {
    public init() {}

    public func entryNames(in data: Data) throws -> [String] {
        try read(data) { a in
            var names: [String] = []
            var entry: OpaquePointer?
            while archive_read_next_header(a, &entry) == 0 {
                if let e = entry, let p = archive_entry_pathname(e) {
                    names.append(String(cString: p))
                }
                archive_read_data_skip(a)
            }
            return names
        }
    }

    public func entry(_ name: String, in data: Data) throws -> Data? {
        try read(data) { a in
            var entry: OpaquePointer?
            while archive_read_next_header(a, &entry) == 0 {
                guard let e = entry, let p = archive_entry_pathname(e) else {
                    archive_read_data_skip(a); continue
                }
                if String(cString: p) == name {
                    return try readAll(a)
                }
                archive_read_data_skip(a)
            }
            return nil
        }
    }

    /// Открывает архив из памяти и выполняет body, гарантируя освобождение.
    private func read<T>(_ data: Data, _ body: (OpaquePointer) throws -> T) throws -> T {
        try data.withUnsafeBytes { (buf: UnsafeRawBufferPointer) -> T in
            guard let a = archive_read_new() else { throw ZipError.open }
            defer { archive_read_free(a) }
            archive_read_support_format_all(a)
            archive_read_support_filter_all(a)
            guard archive_read_open_memory(a, buf.baseAddress, buf.count) == 0 else { throw ZipError.open }
            return try body(a)
        }
    }

    /// Читает тело текущей записи целиком (размер может быть неизвестен — читаем до 0).
    private func readAll(_ a: OpaquePointer) throws -> Data {
        var out = Data()
        var chunk = [UInt8](repeating: 0, count: 64 * 1024)
        while true {
            let n = chunk.withUnsafeMutableBytes { archive_read_data(a, $0.baseAddress, $0.count) }
            if n == 0 { break }
            if n < 0 { throw ZipError.read }
            out.append(contentsOf: chunk[0..<n])
        }
        return out
    }
}
```

- [ ] **Step 7: Запустить — зелёный**

Run: `swift test --filter ZipReaderTests`
Expected: PASS, 5 тестов.

- [ ] **Step 8: Commit**

```bash
git add Sources/CLibArchive Sources/QuickLookersImportKit/ZipReader.swift Package.swift Tests/QuickLookersImportKitTests
git commit -m "$(cat <<'EOF'
feat(import): мостик CLibArchive + ZipReader (чтение .vsix из памяти)

libarchive за module map (заголовок объявлен сам — в SDK его нет), чтение
записей из памяти. Минимальные .vsix-фикстуры для тестов.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: `VsixManifest` — парсинг `package.json`

**Files:**
- Create: `Sources/QuickLookersImportKit/VsixManifest.swift`
- Test: `Tests/QuickLookersImportKitTests/VsixManifestTests.swift`

**Interfaces:**
- Consumes: ничего из ранних задач.
- Produces:
  ```swift
  public struct VsixManifest: Equatable {
      public struct Grammar: Equatable { public let language: String?; public let path: String; public let embeddedLanguageIds: [String] }
      public struct Theme: Equatable { public let label: String; public let uiTheme: String; public let path: String }
      public let grammars: [Grammar]
      public let themes: [Theme]
      public let languageDisplayNames: [String: String]
      public static func parse(packageJSON data: Data) throws -> VsixManifest
  }
  public enum ManifestError: Error { case badJSON, noContributions }
  ```

- [ ] **Step 1: Падающий тест**

`Tests/QuickLookersImportKitTests/VsixManifestTests.swift`:

```swift
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
}
```

- [ ] **Step 2: Запустить — падает**

Run: `swift test --filter VsixManifestTests`
Expected: ошибка компиляции — нет `VsixManifest`.

- [ ] **Step 3: Реализовать**

`Sources/QuickLookersImportKit/VsixManifest.swift`:

```swift
import Foundation

public enum ManifestError: Error { case badJSON, noContributions }

/// Разобранный package.json расширения VS Code (только нужные contributes.*).
public struct VsixManifest: Equatable {
    public struct Grammar: Equatable {
        public let language: String?            // nil = грамматика-инъекция (injectTo)
        public let path: String
        public let embeddedLanguageIds: [String]  // значения contributes.grammars[].embeddedLanguages
        public init(language: String?, path: String, embeddedLanguageIds: [String]) {
            self.language = language; self.path = path; self.embeddedLanguageIds = embeddedLanguageIds
        }
    }
    public struct Theme: Equatable {
        public let label: String; public let uiTheme: String; public let path: String
        public init(label: String, uiTheme: String, path: String) {
            self.label = label; self.uiTheme = uiTheme; self.path = path
        }
    }
    public let grammars: [Grammar]
    public let themes: [Theme]
    public let languageDisplayNames: [String: String]

    public init(grammars: [Grammar], themes: [Theme], languageDisplayNames: [String: String]) {
        self.grammars = grammars; self.themes = themes; self.languageDisplayNames = languageDisplayNames
    }

    public static func parse(packageJSON data: Data) throws -> VsixManifest {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let contributes = root["contributes"] as? [String: Any]
        else {
            // Невалидный JSON — badJSON; валидный, но без contributes — noContributions.
            if (try? JSONSerialization.jsonObject(with: data)) == nil { throw ManifestError.badJSON }
            throw ManifestError.noContributions
        }

        let grammars: [Grammar] = (contributes["grammars"] as? [[String: Any]] ?? []).map { g in
            let embedded = (g["embeddedLanguages"] as? [String: String]).map { Array(Set($0.values)) } ?? []
            return Grammar(language: g["language"] as? String,
                           path: g["path"] as? String ?? "",
                           embeddedLanguageIds: embedded.sorted())
        }
        let themes: [Theme] = (contributes["themes"] as? [[String: Any]] ?? []).compactMap { t in
            guard let label = t["label"] as? String, let path = t["path"] as? String else { return nil }
            return Theme(label: label, uiTheme: t["uiTheme"] as? String ?? "vs-dark", path: path)
        }
        var names: [String: String] = [:]
        for l in (contributes["languages"] as? [[String: Any]] ?? []) {
            if let id = l["id"] as? String {
                names[id] = (l["aliases"] as? [String])?.first ?? id
            }
        }
        guard !grammars.isEmpty || !themes.isEmpty else { throw ManifestError.noContributions }
        return VsixManifest(grammars: grammars, themes: themes, languageDisplayNames: names)
    }
}
```

- [ ] **Step 4: Запустить — зелёный**

Run: `swift test --filter VsixManifestTests`
Expected: PASS, 3 теста.

- [ ] **Step 5: Commit**

```bash
git add Sources/QuickLookersImportKit/VsixManifest.swift Tests/QuickLookersImportKitTests/VsixManifestTests.swift
git commit -m "$(cat <<'EOF'
feat(import): парсинг package.json (.vsix) в VsixManifest

contributes.grammars (language?, path, embeddedLanguages→ids), themes
(label/uiTheme/path), languages (id→displayName). injectTo-грамматики с
language=nil сохраняются как есть (фильтр — на нормализации).

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: `ThemeNormalizer`

**Files:**
- Create: `Sources/QuickLookersImportKit/ThemeNormalizer.swift`
- Test: `Tests/QuickLookersImportKitTests/ThemeNormalizerTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public struct NormalizedTheme: Equatable { public let id: String; public let displayName: String; public let isDark: Bool; public let json: Data }
  public enum ThemeNormalizer {
      public static func slug(_ label: String) -> String
      public static func isDark(uiTheme: String) -> Bool
      public static func normalize(label: String, uiTheme: String, themeJSON: Data, existingSlugs: Set<String>) -> NormalizedTheme
  }
  ```

- [ ] **Step 1: Падающий тест**

`Tests/QuickLookersImportKitTests/ThemeNormalizerTests.swift`:

```swift
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
}
```

- [ ] **Step 2: Запустить — падает**

Run: `swift test --filter ThemeNormalizerTests`
Expected: ошибка компиляции — нет `ThemeNormalizer`.

- [ ] **Step 3: Реализовать**

`Sources/QuickLookersImportKit/ThemeNormalizer.swift`:

```swift
import Foundation

public struct NormalizedTheme: Equatable {
    public let id: String; public let displayName: String; public let isDark: Bool; public let json: Data
    public init(id: String, displayName: String, isDark: Bool, json: Data) {
        self.id = id; self.displayName = displayName; self.isDark = isDark; self.json = json
    }
}

public enum ThemeNormalizer {
    /// id из label: нижний регистр, недопустимые символы → '-', схлопывание и обрезка дефисов.
    public static func slug(_ label: String) -> String {
        let lowered = label.lowercased()
        var out = ""
        for ch in lowered {
            if ch.isLetter || ch.isNumber { out.append(ch) }
            else if !out.hasSuffix("-") { out.append("-") }
        }
        return out.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    public static func isDark(uiTheme: String) -> Bool {
        uiTheme == "vs-dark" || uiTheme == "hc-black"
    }

    /// Уникализирует слаг относительно existingSlugs суффиксом -2, -3, …
    public static func normalize(label: String, uiTheme: String, themeJSON: Data,
                                 existingSlugs: Set<String>) -> NormalizedTheme {
        let base = slug(label)
        var id = base
        var n = 2
        while existingSlugs.contains(id) { id = "\(base)-\(n)"; n += 1 }
        return NormalizedTheme(id: id, displayName: label, isDark: isDark(uiTheme: uiTheme), json: themeJSON)
    }
}
```

- [ ] **Step 4: Запустить — зелёный**

Run: `swift test --filter ThemeNormalizerTests`
Expected: PASS, 4 теста.

- [ ] **Step 5: Commit**

```bash
git add Sources/QuickLookersImportKit/ThemeNormalizer.swift Tests/QuickLookersImportKitTests/ThemeNormalizerTests.swift
git commit -m "$(cat <<'EOF'
feat(import): ThemeNormalizer (id-слаг, isDark из uiTheme)

Тема VS Code используется как есть; id — слаг от label с суффиксом при коллизии,
isDark из uiTheme (vs-dark/hc-black).

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: `GrammarNormalizer` — plist→JSON + дособирание вложенных (вариант B)

**Files:**
- Create: `Sources/QuickLookersImportKit/GrammarNormalizer.swift`
- Test: `Tests/QuickLookersImportKitTests/GrammarNormalizerTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public struct GrammarNormalizer {
      public init(bundledGrammarsDir: URL)
      public func toJSON(_ data: Data, path: String) throws -> Data
      public func normalize(languageId: String, grammarJSON: Data,
                            embeddedLanguageIds: [String], siblingGrammars: [String: Data]) throws -> Data
  }
  public enum GrammarError: Error { case badGrammar }
  ```
  `normalize` возвращает JSON-массив `[главная + вложенные]` с внедрённым `embeddedLangs` в главной.

- [ ] **Step 1: Падающий тест**

`Tests/QuickLookersImportKitTests/GrammarNormalizerTests.swift`:

```swift
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
        let css = try XCTUnwrap(arr.first { $0["name"] as? String == "css" })
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
}
```

- [ ] **Step 2: Запустить — падает**

Run: `swift test --filter GrammarNormalizerTests`
Expected: ошибка компиляции — нет `GrammarNormalizer`.

- [ ] **Step 3: Реализовать**

`Sources/QuickLookersImportKit/GrammarNormalizer.swift`:

```swift
import Foundation

public enum GrammarError: Error { case badGrammar }

/// Нормализация грамматики из .vsix: plist→JSON и дособирание вложенных языков
/// в массив [главная + вложенные], как у встроенных грамматик.
public struct GrammarNormalizer {
    private let bundledGrammarsDir: URL
    public init(bundledGrammarsDir: URL) { self.bundledGrammarsDir = bundledGrammarsDir }

    /// XML-plist (.tmLanguage/.plist) → JSON; .json/.tmLanguage.json — как есть.
    public func toJSON(_ data: Data, path: String) throws -> Data {
        if path.hasSuffix(".json") { return data }
        guard let obj = try? PropertyListSerialization.propertyList(from: data, format: nil),
              JSONSerialization.isValidJSONObject(obj),
              let json = try? JSONSerialization.data(withJSONObject: obj)
        else { throw GrammarError.badGrammar }
        return json
    }

    /// Массив [главная + вложенные]. На главную внедряется embeddedLangs;
    /// вложенные берутся из siblingGrammars (тот же .vsix), иначе из встроенной библиотеки.
    public func normalize(languageId: String, grammarJSON: Data,
                          embeddedLanguageIds: [String], siblingGrammars: [String: Data]) throws -> Data {
        guard var main = try? JSONSerialization.jsonObject(with: grammarJSON) as? [String: Any]
        else { throw GrammarError.badGrammar }
        if !embeddedLanguageIds.isEmpty { main["embeddedLangs"] = embeddedLanguageIds }

        var result: [[String: Any]] = [main]
        var seen = Set([main["name"] as? String ?? languageId])

        for embed in embeddedLanguageIds {
            for entry in grammarEntries(for: embed, siblings: siblingGrammars) {
                let name = entry["name"] as? String ?? ""
                if seen.insert(name).inserted { result.append(entry) }
            }
        }
        return try JSONSerialization.data(withJSONObject: result)
    }

    /// Грамматики вложенного языка: сначала из .vsix (один объект), иначе из
    /// встроенного <id>.json (он уже массив с транзитивными вложенными).
    private func grammarEntries(for id: String, siblings: [String: Data]) -> [[String: Any]] {
        if let raw = siblings[id],
           let obj = try? JSONSerialization.jsonObject(with: raw) as? [String: Any] {
            return [obj]
        }
        let url = bundledGrammarsDir.appendingPathComponent("\(id).json")
        guard let data = try? Data(contentsOf: url),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return [] }     // нет нигде → вложенный кусок без подсветки (осознанный край)
        return arr
    }
}
```

- [ ] **Step 4: Запустить — зелёный**

Run: `swift test --filter GrammarNormalizerTests`
Expected: PASS, 5 тестов.

- [ ] **Step 5: Commit**

```bash
git add Sources/QuickLookersImportKit/GrammarNormalizer.swift Tests/QuickLookersImportKitTests/GrammarNormalizerTests.swift
git commit -m "$(cat <<'EOF'
feat(import): GrammarNormalizer (plist→JSON, дособирание вложенных)

Грамматика собирается в массив [главная + вложенные] как у встроенных: на
главную внедряется embeddedLangs, вложенные тянутся из .vsix или из встроенной
библиотеки; отсутствующий вложенный пропускается без падения.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: `VsixImporter` — оркестрация → артефакты + пропуски

**Files:**
- Create: `Sources/QuickLookersImportKit/ImportArtifact.swift`, `Sources/QuickLookersImportKit/VsixImporter.swift`
- Create фикстуры: дополнить `make-fixtures.sh` архивом с битым элементом
- Test: `Tests/QuickLookersImportKitTests/VsixImporterTests.swift`

**Interfaces:**
- Consumes: `ZipReader`, `VsixManifest`, `ThemeNormalizer`, `GrammarNormalizer`.
- Produces:
  ```swift
  public struct ImportArtifact: Equatable {
      public enum Kind: String { case grammar, theme }
      public let kind: Kind; public let id: String; public let displayName: String
      public let isDark: Bool; public let json: Data
  }
  public struct ImportSkip: Equatable { public let item: String; public let reason: String }
  public struct ImportResult: Equatable { public let artifacts: [ImportArtifact]; public let skips: [ImportSkip] }
  public struct VsixImporter {
      public init(bundledGrammarsDir: URL)
      public func callAsFunction(vsixData: Data) throws -> ImportResult
  }
  public enum ImportError: Error { case notArchive, noManifest, noContributions }
  ```

- [ ] **Step 1: Дополнить фикстуры архивом с битым элементом**

Добавить в `Tests/QuickLookersImportKitTests/Fixtures/make-fixtures.sh` перед `rm -rf build`:

```bash
# broken-entry: валидная тема + тема с отсутствующим файлом по path
mkdir -p build/be/extension/theme
cat > build/be/extension/package.json <<'EOF'
{"name":"b","contributes":{"themes":[
  {"label":"Good","uiTheme":"vs-dark","path":"./theme/good.json"},
  {"label":"Missing","uiTheme":"vs","path":"./theme/missing.json"}
]}}
EOF
echo '{"name":"Good"}' > build/be/extension/theme/good.json
(cd build/be && zip -r -X ../../broken-entry.vsix extension >/dev/null)
```

Запустить `bash Tests/QuickLookersImportKitTests/Fixtures/make-fixtures.sh` (Expected: `fixtures built`, появился `broken-entry.vsix`).

- [ ] **Step 2: Падающий тест**

`Tests/QuickLookersImportKitTests/VsixImporterTests.swift`:

```swift
import XCTest
@testable import QuickLookersImportKit

final class VsixImporterTests: XCTestCase {
    private func fixture(_ name: String) throws -> Data {
        try Data(contentsOf: try XCTUnwrap(Bundle.module.url(forResource: "Fixtures/\(name)", withExtension: nil)))
    }
    private func importer() -> VsixImporter {
        // Каталог встроенных грамматик не нужен этим тестам (без вложенных) — пустой временный.
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return VsixImporter(bundledGrammarsDir: dir)
    }

    func test_importsThemeArtifact() throws {
        let r = try importer()(vsixData: try fixture("theme-only.vsix"))
        XCTAssertEqual(r.artifacts.count, 1)
        let a = r.artifacts[0]
        XCTAssertEqual(a.kind, .theme)
        XCTAssertEqual(a.id, "my-cool-theme")
        XCTAssertEqual(a.displayName, "My Cool Theme")
        XCTAssertTrue(a.isDark)
    }

    func test_importsGrammarArtifact() throws {
        let r = try importer()(vsixData: try fixture("grammar-json.vsix"))
        XCTAssertEqual(r.artifacts.map(\.id), ["toy"])
        XCTAssertEqual(r.artifacts[0].kind, .grammar)
        XCTAssertEqual(r.artifacts[0].displayName, "Toy Lang")
    }

    func test_partialSuccessRecordsSkip() throws {
        let r = try importer()(vsixData: try fixture("broken-entry.vsix"))
        XCTAssertEqual(r.artifacts.map(\.id), ["good"])     // валидная импортирована
        XCTAssertEqual(r.skips.count, 1)                    // битая — пропущена
        XCTAssertTrue(r.skips[0].item.contains("Missing"))
    }

    func test_notArchiveThrows() throws {
        XCTAssertThrowsError(try importer()(vsixData: try fixture("not-a-vsix.vsix"))) { e in
            XCTAssertEqual(e as? ImportError, .notArchive)
        }
    }
}
```

- [ ] **Step 3: Запустить — падает**

Run: `swift test --filter VsixImporterTests`
Expected: ошибка компиляции — нет `VsixImporter`.

- [ ] **Step 4: Реализовать**

`Sources/QuickLookersImportKit/ImportArtifact.swift`:

```swift
import Foundation

public struct ImportArtifact: Equatable {
    public enum Kind: String { case grammar, theme }
    public let kind: Kind
    public let id: String
    public let displayName: String
    public let isDark: Bool          // значимо для темы; для грамматики false
    public let json: Data
    public init(kind: Kind, id: String, displayName: String, isDark: Bool, json: Data) {
        self.kind = kind; self.id = id; self.displayName = displayName; self.isDark = isDark; self.json = json
    }
}

public struct ImportSkip: Equatable {
    public let item: String; public let reason: String
    public init(item: String, reason: String) { self.item = item; self.reason = reason }
}

public struct ImportResult: Equatable {
    public let artifacts: [ImportArtifact]; public let skips: [ImportSkip]
    public init(artifacts: [ImportArtifact], skips: [ImportSkip]) { self.artifacts = artifacts; self.skips = skips }
}
```

`Sources/QuickLookersImportKit/VsixImporter.swift`:

```swift
import Foundation

public enum ImportError: Error { case notArchive, noManifest, noContributions }

/// Оркестрация импорта: .vsix → артефакты (темы/грамматики) + пропуски с причинами.
public struct VsixImporter {
    private let bundledGrammarsDir: URL
    private let reader = ZipReader()
    public init(bundledGrammarsDir: URL) { self.bundledGrammarsDir = bundledGrammarsDir }

    public func callAsFunction(vsixData: Data) throws -> ImportResult {
        let names: [String]
        do { names = try reader.entryNames(in: vsixData) }
        catch { throw ImportError.notArchive }
        guard names.contains("extension/package.json"),
              let pkg = try reader.entry("extension/package.json", in: vsixData)
        else { throw ImportError.noManifest }

        let manifest: VsixManifest
        do { manifest = try VsixManifest.parse(packageJSON: pkg) }
        catch ManifestError.noContributions { throw ImportError.noContributions }
        catch { throw ImportError.noManifest }

        var artifacts: [ImportArtifact] = []
        var skips: [ImportSkip] = []
        var themeSlugs = Set<String>()

        // Темы.
        for t in manifest.themes {
            guard let raw = try? reader.entry("extension/" + clean(t.path), in: vsixData), let raw else {
                skips.append(.init(item: "тема «\(t.label)»", reason: "нет файла \(t.path)")); continue
            }
            let n = ThemeNormalizer.normalize(label: t.label, uiTheme: t.uiTheme,
                                              themeJSON: raw, existingSlugs: themeSlugs)
            themeSlugs.insert(n.id)
            artifacts.append(.init(kind: .theme, id: n.id, displayName: n.displayName,
                                   isDark: n.isDark, json: n.json))
        }

        // Сырые грамматики по language (для дотягивания вложенных-сиблингов).
        var siblings: [String: Data] = [:]
        let normalizer = GrammarNormalizer(bundledGrammarsDir: bundledGrammarsDir)
        for g in manifest.grammars {
            guard let lang = g.language else { continue }
            if let raw = try? reader.entry("extension/" + clean(g.path), in: vsixData), let raw,
               let json = try? normalizer.toJSON(raw, path: g.path) {
                siblings[lang] = json
            }
        }

        // Грамматики (только с language).
        for g in manifest.grammars {
            guard let lang = g.language else {
                skips.append(.init(item: "грамматика \(g.path)", reason: "инъекция (injectTo) — пропущено"))
                continue
            }
            guard let raw = siblings[lang] else {
                skips.append(.init(item: "грамматика «\(lang)»", reason: "нет/битый файл \(g.path)")); continue
            }
            guard let out = try? normalizer.normalize(languageId: lang, grammarJSON: raw,
                                                      embeddedLanguageIds: g.embeddedLanguageIds,
                                                      siblingGrammars: siblings) else {
                skips.append(.init(item: "грамматика «\(lang)»", reason: "не разобралась")); continue
            }
            let display = manifest.languageDisplayNames[lang] ?? lang
            artifacts.append(.init(kind: .grammar, id: lang, displayName: display, isDark: false, json: out))
        }

        return ImportResult(artifacts: artifacts, skips: skips)
    }

    /// Путь из package.json часто начинается с "./" — убираем для склейки с "extension/".
    private func clean(_ path: String) -> String {
        path.hasPrefix("./") ? String(path.dropFirst(2)) : path
    }
}
```

- [ ] **Step 5: Запустить — зелёный**

Run: `swift test --filter VsixImporterTests`
Expected: PASS, 4 теста.

- [ ] **Step 6: Полный прогон ImportKit**

Run: `swift test --filter QuickLookersImportKitTests`
Expected: PASS — все тесты ImportKit (ZipReader, Manifest, ThemeNormalizer, GrammarNormalizer, VsixImporter).

- [ ] **Step 7: Commit**

```bash
git add Sources/QuickLookersImportKit/ImportArtifact.swift Sources/QuickLookersImportKit/VsixImporter.swift Tests/QuickLookersImportKitTests/VsixImporterTests.swift Tests/QuickLookersImportKitTests/Fixtures
git commit -m "$(cat <<'EOF'
feat(import): VsixImporter — .vsix → артефакты + пропуски

Оркестрация: распаковка, манифест, нормализация тем и грамматик (с
дособиранием вложенных), частичный успех со сводкой, отказы (не-архив,
нет манифеста/contributes). injectTo-грамматики пропускаются.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: Композитный провайдер движка «контейнер старше бандла»

**Files:**
- Modify: `Sources/QuickLookersEngine/Providers.swift`
- Modify: `Sources/QuickLookersEngine/EngineFactory.swift`
- Test: `Tests/QuickLookersEngineTests/CompositeProviderTests.swift`

**Interfaces:**
- Consumes: существующие `GrammarProvider`/`ThemeProvider`, `BundledGrammarProvider`/`BundledThemeProvider`, `EngineError.resourceNotFound`.
- Produces:
  ```swift
  public struct CompositeGrammarProvider: GrammarProvider { public init(primary: GrammarProvider, fallback: GrammarProvider) }
  public struct CompositeThemeProvider: ThemeProvider { public init(primary: ThemeProvider, fallback: ThemeProvider) }
  // EngineFactory.makeDefault(importedGrammarsDir: URL? = nil, importedThemesDir: URL? = nil)
  ```

- [ ] **Step 1: Падающий тест**

`Tests/QuickLookersEngineTests/CompositeProviderTests.swift`:

```swift
import XCTest
@testable import QuickLookersEngine

final class CompositeProviderTests: XCTestCase {
    private func dirWith(_ file: String, _ content: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try content.write(to: dir.appendingPathComponent(file), atomically: true, encoding: .utf8)
        return dir
    }

    func test_primaryWins() throws {
        let primary = BundledGrammarProvider(directory: try dirWith("swift.json", "PRIMARY"))
        let fallback = BundledGrammarProvider(directory: try dirWith("swift.json", "FALLBACK"))
        let c = CompositeGrammarProvider(primary: primary, fallback: fallback)
        XCTAssertEqual(try c.grammarJSON(languageId: "swift"), "PRIMARY")
    }

    func test_fallbackWhenPrimaryMissing() throws {
        let primary = BundledGrammarProvider(directory: try dirWith("other.json", "X"))
        let fallback = BundledGrammarProvider(directory: try dirWith("swift.json", "FALLBACK"))
        let c = CompositeGrammarProvider(primary: primary, fallback: fallback)
        XCTAssertEqual(try c.grammarJSON(languageId: "swift"), "FALLBACK")
    }

    func test_themeComposite() throws {
        let primary = BundledThemeProvider(directory: try dirWith("nope.json", "X"))
        let fallback = BundledThemeProvider(directory: try dirWith("dark-plus.json", "FB"))
        let c = CompositeThemeProvider(primary: primary, fallback: fallback)
        XCTAssertEqual(try c.themeJSON(themeId: "dark-plus"), "FB")
    }
}
```

- [ ] **Step 2: Запустить — падает**

Run: `swift test --filter CompositeProviderTests`
Expected: ошибка компиляции — нет `CompositeGrammarProvider`.

- [ ] **Step 3: Реализовать провайдеры**

Добавить в конец `Sources/QuickLookersEngine/Providers.swift`:

```swift
/// Провайдер «сначала primary, при отсутствии — fallback».
/// Контейнер импорта (primary) перекрывает бандл (fallback) по id.
public struct CompositeGrammarProvider: GrammarProvider {
    private let primary: GrammarProvider
    private let fallback: GrammarProvider
    public init(primary: GrammarProvider, fallback: GrammarProvider) {
        self.primary = primary; self.fallback = fallback
    }
    public func grammarJSON(languageId: String) throws -> String {
        if let s = try? primary.grammarJSON(languageId: languageId) { return s }
        return try fallback.grammarJSON(languageId: languageId)
    }
}

public struct CompositeThemeProvider: ThemeProvider {
    private let primary: ThemeProvider
    private let fallback: ThemeProvider
    public init(primary: ThemeProvider, fallback: ThemeProvider) {
        self.primary = primary; self.fallback = fallback
    }
    public func themeJSON(themeId: String) throws -> String {
        if let s = try? primary.themeJSON(themeId: themeId) { return s }
        return try fallback.themeJSON(themeId: themeId)
    }
}
```

- [ ] **Step 4: Запустить — зелёный**

Run: `swift test --filter CompositeProviderTests`
Expected: PASS, 3 теста.

- [ ] **Step 5: Добавить параметры в фабрику**

Заменить `Sources/QuickLookersEngine/EngineFactory.swift` целиком:

```swift
import Foundation

public enum QuickLookersEngineFactory {
    /// Собирает движок. Если переданы каталоги импорта — они перекрывают бандл по id.
    public static func makeDefault(importedGrammarsDir: URL? = nil,
                                   importedThemesDir: URL? = nil) throws -> HighlightEngine {
        let runtime = try JSCoreRuntime(bundleScript: JSCoreRuntime.loadBundledScript())
        guard let grammarsDir = Bundle.module.url(forResource: "grammars", withExtension: nil) else {
            throw EngineError.resourceNotFound("grammars")
        }
        guard let themesDir = Bundle.module.url(forResource: "themes", withExtension: nil) else {
            throw EngineError.resourceNotFound("themes")
        }
        let bundledGrammars = BundledGrammarProvider(directory: grammarsDir)
        let bundledThemes = BundledThemeProvider(directory: themesDir)

        let grammars: GrammarProvider = importedGrammarsDir.map {
            CompositeGrammarProvider(primary: BundledGrammarProvider(directory: $0), fallback: bundledGrammars)
        } ?? bundledGrammars
        let themes: ThemeProvider = importedThemesDir.map {
            CompositeThemeProvider(primary: BundledThemeProvider(directory: $0), fallback: bundledThemes)
        } ?? bundledThemes

        return ShikiEngine(runtime: runtime, grammars: grammars, themes: themes)
    }
}
```

- [ ] **Step 6: Прогон движка**

Run: `swift test --filter QuickLookersEngineTests`
Expected: PASS — новые композитные тесты + существующие (фабрика по-прежнему собирается без параметров).

- [ ] **Step 7: Commit**

```bash
git add Sources/QuickLookersEngine/Providers.swift Sources/QuickLookersEngine/EngineFactory.swift Tests/QuickLookersEngineTests/CompositeProviderTests.swift
git commit -m "$(cat <<'EOF'
feat(engine): композитный провайдер «контейнер старше бандла»

makeDefault(importedGrammarsDir:importedThemesDir:) — опциональные каталоги
импорта перекрывают бандл по id; нет файла в импорте → фоллбэк на бандл.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: `ImportedLibrary` — запись/удаление артефактов + сайдкар

**Files:**
- Modify: `Package.swift` (`QuickLookersSettingsKit` зависит от `QuickLookersImportKit`)
- Create: `Sources/QuickLookersSettingsKit/ImportedLibrary.swift`
- Test: `Tests/QuickLookersSettingsKitTests/ImportedLibraryTests.swift`

**Interfaces:**
- Consumes: `ImportArtifact`, `ImportResult` из `QuickLookersImportKit`.
- Produces:
  ```swift
  public struct ImportedLibrary {
      public init(containerURL: URL)
      public var grammarsDir: URL { get }     // containerURL/library/grammars
      public var themesDir: URL { get }       // containerURL/library/themes
      public var sidecarURL: URL { get }      // containerURL/library/catalog-imported.json
      public func write(_ result: ImportResult) throws
      public func remove(kind: ImportArtifact.Kind, id: String) throws
      public func sidecarURLsForCatalog() -> [URL]   // [sidecarURL] если существует, иначе []
  }
  ```
  Сайдкар — формат `FileCatalogSource.Sidecar`: `{ "languages":[{"id","displayName"}], "themes":[{"id","displayName","isDark"}] }`.

- [ ] **Step 1: Зависимость пакета**

В `Package.swift` у таргета `QuickLookersSettingsKit` добавить зависимость:

```swift
        .target(
            name: "QuickLookersSettingsKit",
            dependencies: ["QuickLookersImportKit"]
        ),
```

- [ ] **Step 2: Падающий тест**

`Tests/QuickLookersSettingsKitTests/ImportedLibraryTests.swift`:

```swift
import XCTest
@testable import QuickLookersSettingsKit
import QuickLookersImportKit

final class ImportedLibraryTests: XCTestCase {
    private func tempContainer() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ql-imp-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func test_writeStoresFilesAndSidecar() throws {
        let lib = ImportedLibrary(containerURL: try tempContainer())
        let result = ImportResult(artifacts: [
            .init(kind: .theme, id: "cool", displayName: "Cool", isDark: true, json: Data("{}".utf8)),
            .init(kind: .grammar, id: "toy", displayName: "Toy", isDark: false, json: Data("[]".utf8)),
        ], skips: [])
        try lib.write(result)

        XCTAssertTrue(FileManager.default.fileExists(atPath: lib.themesDir.appendingPathComponent("cool.json").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: lib.grammarsDir.appendingPathComponent("toy.json").path))
        let sidecar = try JSONSerialization.jsonObject(with: Data(contentsOf: lib.sidecarURL)) as? [String: Any]
        let themes = sidecar?["themes"] as? [[String: Any]]
        XCTAssertEqual(themes?.first?["id"] as? String, "cool")
        XCTAssertEqual(themes?.first?["isDark"] as? Bool, true)
        XCTAssertEqual(lib.sidecarURLsForCatalog(), [lib.sidecarURL])
    }

    func test_removeDeletesFileAndSidecarEntry() throws {
        let lib = ImportedLibrary(containerURL: try tempContainer())
        try lib.write(ImportResult(artifacts: [
            .init(kind: .theme, id: "cool", displayName: "Cool", isDark: true, json: Data("{}".utf8)),
        ], skips: []))
        try lib.remove(kind: .theme, id: "cool")

        XCTAssertFalse(FileManager.default.fileExists(atPath: lib.themesDir.appendingPathComponent("cool.json").path))
        let sidecar = try JSONSerialization.jsonObject(with: Data(contentsOf: lib.sidecarURL)) as? [String: Any]
        XCTAssertEqual((sidecar?["themes"] as? [[String: Any]])?.count, 0)
    }

    func test_writeMergesWithExisting() throws {
        let lib = ImportedLibrary(containerURL: try tempContainer())
        try lib.write(ImportResult(artifacts: [
            .init(kind: .theme, id: "a", displayName: "A", isDark: true, json: Data("{}".utf8)),
        ], skips: []))
        try lib.write(ImportResult(artifacts: [
            .init(kind: .theme, id: "b", displayName: "B", isDark: false, json: Data("{}".utf8)),
        ], skips: []))
        let sidecar = try JSONSerialization.jsonObject(with: Data(contentsOf: lib.sidecarURL)) as? [String: Any]
        XCTAssertEqual(Set((sidecar?["themes"] as? [[String: Any]] ?? []).compactMap { $0["id"] as? String }),
                       ["a", "b"])
    }
}
```

- [ ] **Step 3: Запустить — падает**

Run: `swift test --filter ImportedLibraryTests`
Expected: ошибка компиляции — нет `ImportedLibrary`.

- [ ] **Step 4: Реализовать**

`Sources/QuickLookersSettingsKit/ImportedLibrary.swift`:

```swift
import Foundation
import QuickLookersImportKit

/// Запись/удаление импортированных грамматик и тем в контейнере App Group и
/// поддержка сайдкара catalog-imported.json (формат FileCatalogSource.Sidecar).
public struct ImportedLibrary {
    private let containerURL: URL
    public init(containerURL: URL) { self.containerURL = containerURL }

    private var libraryDir: URL { containerURL.appendingPathComponent("library") }
    public var grammarsDir: URL { libraryDir.appendingPathComponent("grammars") }
    public var themesDir: URL { libraryDir.appendingPathComponent("themes") }
    public var sidecarURL: URL { libraryDir.appendingPathComponent("catalog-imported.json") }

    public func sidecarURLsForCatalog() -> [URL] {
        FileManager.default.fileExists(atPath: sidecarURL.path) ? [sidecarURL] : []
    }

    /// Пишет файлы артефактов и доливает их записи в сайдкар (слияние по id).
    public func write(_ result: ImportResult) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: grammarsDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: themesDir, withIntermediateDirectories: true)

        var sidecar = loadSidecar()
        for a in result.artifacts {
            switch a.kind {
            case .grammar:
                try a.json.write(to: grammarsDir.appendingPathComponent("\(a.id).json"), options: .atomic)
                sidecar.languages[a.id] = ["id": a.id, "displayName": a.displayName]
            case .theme:
                try a.json.write(to: themesDir.appendingPathComponent("\(a.id).json"), options: .atomic)
                sidecar.themes[a.id] = ["id": a.id, "displayName": a.displayName, "isDark": a.isDark]
            }
        }
        try saveSidecar(sidecar)
    }

    public func remove(kind: ImportArtifact.Kind, id: String) throws {
        let fm = FileManager.default
        var sidecar = loadSidecar()
        switch kind {
        case .grammar:
            try? fm.removeItem(at: grammarsDir.appendingPathComponent("\(id).json"))
            sidecar.languages[id] = nil
        case .theme:
            try? fm.removeItem(at: themesDir.appendingPathComponent("\(id).json"))
            sidecar.themes[id] = nil
        }
        try saveSidecar(sidecar)
    }

    // Сайдкар как словари по id (для слияния и удаления), сериализуем в формат FileCatalogSource.
    private struct Sidecar { var languages: [String: [String: Any]] = [:]; var themes: [String: [String: Any]] = [:] }

    private func loadSidecar() -> Sidecar {
        guard let data = try? Data(contentsOf: sidecarURL),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return Sidecar() }
        var s = Sidecar()
        for l in (obj["languages"] as? [[String: Any]] ?? []) { if let id = l["id"] as? String { s.languages[id] = l } }
        for t in (obj["themes"] as? [[String: Any]] ?? []) { if let id = t["id"] as? String { s.themes[id] = t } }
        return s
    }

    private func saveSidecar(_ s: Sidecar) throws {
        let obj: [String: Any] = [
            "languages": s.languages.values.sorted { ($0["id"] as! String) < ($1["id"] as! String) },
            "themes": s.themes.values.sorted { ($0["id"] as! String) < ($1["id"] as! String) },
        ]
        try JSONSerialization.data(withJSONObject: obj).write(to: sidecarURL, options: .atomic)
    }
}
```

- [ ] **Step 5: Запустить — зелёный**

Run: `swift test --filter ImportedLibraryTests`
Expected: PASS, 3 теста.

- [ ] **Step 6: Commit**

```bash
git add Package.swift Sources/QuickLookersSettingsKit/ImportedLibrary.swift Tests/QuickLookersSettingsKitTests/ImportedLibraryTests.swift
git commit -m "$(cat <<'EOF'
feat(settings): ImportedLibrary — запись/удаление артефактов + сайдкар

Пишет грамматики/темы в library/ контейнера, доливает catalog-imported.json
(слияние по id), удаление убирает файл и запись. Формат сайдкара — как читает
FileCatalogSource.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

### Task 8: Сборка приложения — пикер, запись, UI-метки, чтение движком из контейнера

Связывает всё в работающую фичу. UI-таргет, проверяется сборкой (`xcodebuild`), не `swift test`.

**Files:**
- Create: `App/ImportModel.swift`
- Modify: `App/SettingsModel.swift` (передать импортированный сайдкар в каталог; путь к контейнеру)
- Modify: `App/ThemesTab.swift`, `App/FormatsTab.swift` (кнопка «Импортировать…», метка + удаление)
- Modify: `PreviewExtension/PreviewViewController.swift` (движок с каталогами импорта из контейнера)
- Modify: `App/QuickLookersApp.swift` или место сборки движка приложения (каталоги импорта)
- Modify: `project.yml` (линковать `libarchive` к app-таргету; зависимости пакетов)

**Interfaces:**
- Consumes: `VsixImporter`, `ImportResult` (ImportKit); `ImportedLibrary`, `quickLookersContainerURL()`, `FileCatalogSource` (SettingsKit); `QuickLookersEngineResources.grammarsDirectory()`, `QuickLookersEngineFactory.makeDefault(importedGrammarsDir:importedThemesDir:)` (Engine).
- Produces: рабочий импорт в приложении.

- [ ] **Step 1: Модель импорта**

`App/ImportModel.swift`:

```swift
import Foundation
import AppKit
import UniformTypeIdentifiers
import QuickLookersEngine
import QuickLookersImportKit
import QuickLookersSettingsKit

/// Логика импорта в приложении: пикер .vsix → ImportKit → запись в контейнер → сводка.
@MainActor
final class ImportModel: ObservableObject {
    @Published var summary: String?

    /// Открывает .vsix, импортирует, пишет в контейнер. Возвращает true при успехе.
    func runImport() -> Bool {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "vsix") ?? .data]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        return importFile(url)
    }

    func importFile(_ url: URL) -> Bool {
        guard let container = quickLookersContainerURL() else {
            summary = "Нет общего контейнера — импорт недоступен."; return false
        }
        do {
            let data = try Data(contentsOf: url)
            let importer = VsixImporter(bundledGrammarsDir: try QuickLookersEngineResources.grammarsDirectory())
            let result = try importer(vsixData: data)
            try ImportedLibrary(containerURL: container).write(result)
            let n = result.artifacts.count, m = result.skips.count
            summary = m == 0 ? "Импортировано: \(n)." : "Импортировано: \(n), пропущено: \(m)."
            return true
        } catch {
            summary = "Не удалось импортировать: \(error)"
            return false
        }
    }

    func remove(kind: ImportArtifact.Kind, id: String) {
        guard let container = quickLookersContainerURL() else { return }
        try? ImportedLibrary(containerURL: container).remove(kind: kind, id: id)
    }
}
```

- [ ] **Step 2: Каталог настроек читает импортированный сайдкар**

В `App/SettingsModel.swift`, в `init()`, заменить построение `sidecarURLs`, добавив импортированный сайдкар из контейнера. Найти строку с `sidecarURLs: QuickLookersEngineResources.catalogSidecarURLs()` и заменить блок построения источника на:

```swift
            // Встроенный сайдкар + импортированный из контейнера (если есть).
            var sidecars = QuickLookersEngineResources.catalogSidecarURLs()
            if let container = quickLookersContainerURL() {
                sidecars += ImportedLibrary(containerURL: container).sidecarURLsForCatalog()
            }
            let source = FileCatalogSource(
                grammarsDirectory: try QuickLookersEngineResources.grammarsDirectory(),
                themesDirectory: try QuickLookersEngineResources.themesDirectory(),
                sidecarURLs: sidecars)
            loadedCatalog = try source.loadCatalog()
```

Добавить `import QuickLookersImportKit` в начало файла, если его нет (для типа `ImportArtifact.Kind`, используемого ниже в UI; в этом файле может не понадобиться — добавить там, где используется).

- [ ] **Step 3: Кнопка импорта и метка в `ThemesTab` / `FormatsTab`**

В `App/ThemesTab.swift` добавить кнопку «Импортировать…» и для каждой темы — признак импортированной (id присутствует в импортированном сайдкаре) с кнопкой удаления. Минимально: `@StateObject private var importModel = ImportModel()`; кнопка `Button("Импортировать…") { if importModel.runImport() { /* перечитать каталог */ } }`; рядом с импортированной темой — `Button(role: .destructive) { importModel.remove(kind: .theme, id: theme.id); /* перечитать */ }`. Признак «импортированная» брать из множества id импортированного сайдкара (прочитать `ImportedLibrary(...).sidecarURLsForCatalog()` → распарсить, или хранить множество в `SettingsModel`). Аналогично `App/FormatsTab.swift` для языков (`kind: .grammar`). Перечитывание каталога — пересоздать `SettingsModel`/перевызвать его загрузку (как уже делается при изменении настроек).

Конкретный паттерн перечитывания и хранения множества импортированных id — следовать существующему стилю `SettingsModel`/вкладок; добавить в `SettingsModel` свойство `importedIds: Set<String>`, заполняемое из импортированного сайдкара при загрузке каталога, и метод перезагрузки, дёргаемый после импорта/удаления.

- [ ] **Step 4: Движок приложения и расширения читает из контейнера**

Везде, где собирается движок (`QuickLookersEngineFactory.makeDefault()`), передать каталоги импорта из контейнера.

В `PreviewExtension/PreviewViewController.swift`, в `engine()`:

```swift
    private static func engine() throws -> HighlightEngine {
        if let engine = cachedEngine { return engine }
        var importedGrammars: URL?, importedThemes: URL?
        if let container = quickLookersContainerURL() {
            let lib = ImportedLibrary(containerURL: container)
            importedGrammars = lib.grammarsDir
            importedThemes = lib.themesDir
        }
        let engine = try QuickLookersEngineFactory.makeDefault(importedGrammarsDir: importedGrammars,
                                                               importedThemesDir: importedThemes)
        cachedEngine = engine
        return engine
    }
```

Добавить `import QuickLookersSettingsKit` в `PreviewViewController.swift`, если его нет. Если приложение само рисует превью где-то — там тоже передать каталоги импорта тем же способом.

- [ ] **Step 5: XcodeGen — линковка libarchive и зависимости**

В `project.yml` убедиться, что app-таргет и расширение зависят от нужных пакетных продуктов (`QuickLookersImportKit` где используется; `QuickLookersSettingsKit` уже подключён). Линковка `libarchive` приходит транзитивно от `.systemLibrary` пакета; если линкер её не подхватит, добавить app-таргету флаг линковки `-larchive` через `settings: OTHER_LDFLAGS: -larchive` (libarchive.tbd есть в SDK). Перегенерировать проект:

```bash
xcodegen generate
```

- [ ] **Step 6: Сборка приложения + расширения**

Run:
```bash
xcodebuild -project QuickLookers.xcodeproj -scheme QuickLookers \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 7: Commit**

```bash
git add App PreviewExtension/PreviewViewController.swift project.yml
git commit -m "$(cat <<'EOF'
feat(app): импорт .vsix в приложении + движок читает из контейнера

Пикер .vsix → VsixImporter → ImportedLibrary пишет в контейнер; каталог
настроек видит импортированный сайдкар; метка/удаление в вкладках; движок
приложения и расширения собирается с каталогами импорта (контейнер старше
бандла). project.yml: линковка libarchive.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Финал

После всех задач — полный прогон и завершение ветки:

```bash
swift test
```
Expected: все тесты пакета зелёные (60 прежних + новые ImportKit/Engine/SettingsKit).

```bash
xcodebuild -project QuickLookers.xcodeproj -scheme QuickLookers -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```
Expected: `BUILD SUCCEEDED`.

**Живая проверка руками** (готовые `.vsix` в `test-vsix/`): запустить хост из Xcode (⌘R), в настройках «Темы» → «Импортировать…» → `test-vsix/theme-dracula.vsix`; выбрать тему Dracula; пробел в Finder на файле кода — подсветка темой Dracula. Грамматика: `test-vsix/grammar-zig.vsix`, открыть `.zig`. Составной: `test-vsix/composite-astro.vsix`, открыть `.astro` — вложенные css/js покрашены (дособраны из библиотеки).

Затем — **REQUIRED SUB-SKILL**: `superpowers:finishing-a-development-branch` для влития `feat/vsix-import` в `main`.
