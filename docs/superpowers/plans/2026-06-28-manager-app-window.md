# Окно приложения-менеджера (три вкладки) — план реализации

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Дать менеджеру окно с тремя вкладками (форматы подсветки, темы, сопоставление с типами файлов) и завести App Group-контейнер, чтобы выбор в окне сразу менял показ по пробелу в Finder.

**Architecture:** Вся логика — в новом чистом SwiftPM-таргете `QuickLookersSettingsKit` (модель настроек, каталог, источник каталога, хранилище `settings.json`, разрешение языка/темы), покрытом `swift test`. Приложение (SwiftUI) и расширение Preview — тонкие потребители: приложение пишет `settings.json` в общий контейнер, расширение читает его на каждом показе. Связь — только через файлы в контейнере App Group.

**Tech Stack:** Swift 6.3 / SwiftPM (tools 5.9), SwiftUI, XcodeGen, App Group, движок `QuickLookersEngine` (Shiki в JavaScriptCore).

## Global Constraints

- Цель платформы: macOS 13+. Swift-tools 5.9. Xcode 26, XcodeGen 2.45. (verbatim из спеки)
- **TDD строго** для логики `SettingsKit`: падающий тест → запуск (падает) → реализация → запуск (зелёный) → коммит. UI-таргеты (приложение/расширение) проверяются сборкой `xcodebuild` и ручным прогоном, юнит-тестами не покрываются.
- **Движок изолирован за протоколом `HighlightEngine`.** `SettingsKit` не зависит ни от движка, ни от UI. Приложение/расширение получают URL ресурсов из движка и передают их в `SettingsKit`.
- **Терминология для пользователя — «просмотр», не «перехват».** Внутренние имена в коде могут быть техническими.
- **Модель настроек — opt-out:** храним множества выключенных языков (`disabledLanguageIds`, `previewDisabledLanguageIds`). Пусто = всё включено.
- **App Group id:** `group.com.quicklookers` — одинаковый для приложения и расширения.
- Коммиты по-русски: `feat(settings): …` / `feat(app): …` / `feat(preview): …` / `test(…): …` / `refactor(…): …` / `docs: …`. Трейлер `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.
- `shiki-bundle.js`, `.xcodeproj`, `*.entitlements`/`Info.plist` расширения — артефакты сборки/XcodeGen; правят `project.yml` и пересобирают, не руками.
- Регистрация расширения — запуском хоста из Xcode (⌘R); CLI-сборки недостаточно (это ручной шаг пользователя).

---

## Карта файлов

**Создаются (пакет, чистая логика):**
- `Sources/QuickLookersSettingsKit/ManagerSettings.swift` — модель настроек, `ThemeSelection`, умолчания, константы id тем.
- `Sources/QuickLookersSettingsKit/DeclaredTypes.swift` — таблица объявленных типов (UTI/расширение/язык) + разрешение языка/просмотра по расширению файла.
- `Sources/QuickLookersSettingsKit/Catalog.swift` — `LanguageInfo`/`ThemeInfo`/`Catalog`.
- `Sources/QuickLookersSettingsKit/CatalogSource.swift` — протокол источника + `FileCatalogSource` (чтение метаданных из JSON-файлов).
- `Sources/QuickLookersSettingsKit/SettingsStore.swift` — чтение/запись `settings.json`, разрешение темы, контейнер App Group.
- `Tests/QuickLookersSettingsKitTests/*` — XCTest для всего выше.

**Создаются (движок):**
- `Sources/QuickLookersEngine/EngineResources.swift` — публичный доступ к каталогам ресурсов (`grammars`/`themes`).

**Создаются (приложение):**
- `App/SettingsModel.swift` — `ObservableObject` поверх `SettingsStore` + каталог.
- `App/ContentView.swift` — окно с `TabView`.
- `App/FormatsTab.swift`, `App/ThemesTab.swift`, `App/FileTypesTab.swift` — три вкладки.

**Изменяются:**
- `Package.swift` — добавить таргет/продукт `QuickLookersSettingsKit` + тест-таргет.
- `PreviewExtension/PreviewViewController.swift` — читать настройки из контейнера, брать язык/тему из них.
- `App/QuickLookersApp.swift` — показывать `ContentView`, собрать `SettingsModel`.
- `project.yml` — entitlement App Group обоим таргетам; расширение линкует `QuickLookersSettingsKit`.

**Удаляются:**
- `Sources/QuickLookersPreviewKit/LanguageMap.swift` и `Tests/QuickLookersPreviewKitTests/LanguageMapTests.swift` — логика переехала в `SettingsKit`.

---

## Task 1: Модель настроек `ManagerSettings`

**Files:**
- Modify: `Package.swift`
- Create: `Sources/QuickLookersSettingsKit/ManagerSettings.swift`
- Test: `Tests/QuickLookersSettingsKitTests/ManagerSettingsTests.swift`

**Interfaces:**
- Produces:
  - `public struct ThemeSelection: Codable, Equatable` с полями `followSystem: Bool`, `lightThemeId: String`, `darkThemeId: String`, `fixedThemeId: String` и методом `func resolvedThemeId(appearanceIsDark: Bool) -> String`.
  - `public enum DefaultThemeIds { static let light = "light-plus"; static let dark = "dark-plus" }`.
  - `public struct ManagerSettings: Codable, Equatable` с полями `schemaVersion: Int`, `settingsVersion: Int`, `disabledLanguageIds: Set<String>`, `theme: ThemeSelection`, `previewDisabledLanguageIds: Set<String>`; статикой `static let currentSchemaVersion = 1`, `static let \`default\`: ManagerSettings`.

- [ ] **Step 1: Добавить таргет в Package.swift**

В `products` добавить строку после `QuickLookersPreviewKit`:

```swift
        .library(name: "QuickLookersSettingsKit", targets: ["QuickLookersSettingsKit"]),
```

В `targets` добавить (после тест-таргета PreviewKit):

```swift
        .target(
            name: "QuickLookersSettingsKit"
        ),
        .testTarget(
            name: "QuickLookersSettingsKitTests",
            dependencies: ["QuickLookersSettingsKit"]
        ),
```

- [ ] **Step 2: Написать падающий тест**

Создать `Tests/QuickLookersSettingsKitTests/ManagerSettingsTests.swift`:

```swift
import XCTest
@testable import QuickLookersSettingsKit

final class ManagerSettingsTests: XCTestCase {
    func testDefaultHasEmptyDisabledSetsAndFollowSystem() {
        let s = ManagerSettings.default
        XCTAssertTrue(s.disabledLanguageIds.isEmpty)
        XCTAssertTrue(s.previewDisabledLanguageIds.isEmpty)
        XCTAssertTrue(s.theme.followSystem)
        XCTAssertEqual(s.schemaVersion, ManagerSettings.currentSchemaVersion)
        XCTAssertEqual(s.settingsVersion, 0)
    }

    func testCodableRoundTrip() throws {
        var s = ManagerSettings.default
        s.disabledLanguageIds = ["javascript"]
        s.previewDisabledLanguageIds = ["json"]
        s.settingsVersion = 7
        let data = try JSONEncoder().encode(s)
        let back = try JSONDecoder().decode(ManagerSettings.self, from: data)
        XCTAssertEqual(s, back)
    }

    func testResolvedThemeFollowSystem() {
        let t = ThemeSelection(followSystem: true, lightThemeId: "light-plus",
                               darkThemeId: "dark-plus", fixedThemeId: "dark-plus")
        XCTAssertEqual(t.resolvedThemeId(appearanceIsDark: true), "dark-plus")
        XCTAssertEqual(t.resolvedThemeId(appearanceIsDark: false), "light-plus")
    }

    func testResolvedThemeFixedWhenNotFollowing() {
        let t = ThemeSelection(followSystem: false, lightThemeId: "light-plus",
                               darkThemeId: "dark-plus", fixedThemeId: "light-plus")
        XCTAssertEqual(t.resolvedThemeId(appearanceIsDark: true), "light-plus")
        XCTAssertEqual(t.resolvedThemeId(appearanceIsDark: false), "light-plus")
    }
}
```

- [ ] **Step 3: Запустить тест — убедиться, что не компилируется/падает**

Run: `swift test --filter ManagerSettingsTests`
Expected: FAIL — `cannot find 'ManagerSettings' in scope` (тип ещё не создан).

- [ ] **Step 4: Реализовать модель**

Создать `Sources/QuickLookersSettingsKit/ManagerSettings.swift`:

```swift
import Foundation

/// Дефолтные id встроенных тем VS Code.
public enum DefaultThemeIds {
    public static let light = "light-plus"
    public static let dark = "dark-plus"
}

/// Выбор темы: «следовать за системой» (светлая+тёмная) либо фиксированная.
public struct ThemeSelection: Codable, Equatable {
    public var followSystem: Bool
    public var lightThemeId: String
    public var darkThemeId: String
    public var fixedThemeId: String

    public init(followSystem: Bool, lightThemeId: String, darkThemeId: String, fixedThemeId: String) {
        self.followSystem = followSystem
        self.lightThemeId = lightThemeId
        self.darkThemeId = darkThemeId
        self.fixedThemeId = fixedThemeId
    }

    /// Кандидат темы по текущему оформлению (без проверки наличия в каталоге).
    public func resolvedThemeId(appearanceIsDark: Bool) -> String {
        guard followSystem else { return fixedThemeId }
        return appearanceIsDark ? darkThemeId : lightThemeId
    }
}

/// Настройки менеджера. Модель opt-out: храним выключенное, пусто = всё включено.
public struct ManagerSettings: Codable, Equatable {
    public var schemaVersion: Int
    public var settingsVersion: Int
    public var disabledLanguageIds: Set<String>
    public var theme: ThemeSelection
    public var previewDisabledLanguageIds: Set<String>

    public init(schemaVersion: Int, settingsVersion: Int, disabledLanguageIds: Set<String>,
                theme: ThemeSelection, previewDisabledLanguageIds: Set<String>) {
        self.schemaVersion = schemaVersion
        self.settingsVersion = settingsVersion
        self.disabledLanguageIds = disabledLanguageIds
        self.theme = theme
        self.previewDisabledLanguageIds = previewDisabledLanguageIds
    }

    public static let currentSchemaVersion = 1

    public static let `default` = ManagerSettings(
        schemaVersion: currentSchemaVersion,
        settingsVersion: 0,
        disabledLanguageIds: [],
        theme: ThemeSelection(followSystem: true,
                              lightThemeId: DefaultThemeIds.light,
                              darkThemeId: DefaultThemeIds.dark,
                              fixedThemeId: DefaultThemeIds.dark),
        previewDisabledLanguageIds: []
    )
}
```

- [ ] **Step 5: Запустить тест — зелёный**

Run: `swift test --filter ManagerSettingsTests`
Expected: PASS (4 теста).

- [ ] **Step 6: Коммит**

```bash
git add Package.swift Sources/QuickLookersSettingsKit/ManagerSettings.swift Tests/QuickLookersSettingsKitTests/ManagerSettingsTests.swift
git commit -m "feat(settings): модель ManagerSettings (opt-out) и выбор темы"
```

---

## Task 2: Объявленные типы и разрешение языка/просмотра

**Files:**
- Create: `Sources/QuickLookersSettingsKit/DeclaredTypes.swift`
- Test: `Tests/QuickLookersSettingsKitTests/ResolutionTests.swift`

**Interfaces:**
- Consumes: `ManagerSettings` (Task 1).
- Produces:
  - `public struct DeclaredType: Equatable { let uti: String; let pathExtension: String; let languageId: String }`.
  - `public enum DeclaredTypes { static let all: [DeclaredType]; static func languageId(forPathExtension: String) -> String? }`.
  - `public func isLanguageEnabled(_ id: String, settings: ManagerSettings) -> Bool`.
  - `public func isPreviewEnabled(_ id: String, settings: ManagerSettings) -> Bool`.
  - `public func previewLanguageId(forPathExtension ext: String, settings: ManagerSettings) -> String?`.

- [ ] **Step 1: Написать падающий тест**

Создать `Tests/QuickLookersSettingsKitTests/ResolutionTests.swift`:

```swift
import XCTest
@testable import QuickLookersSettingsKit

final class ResolutionTests: XCTestCase {
    func testDeclaredLanguageByExtension() {
        XCTAssertEqual(DeclaredTypes.languageId(forPathExtension: "swift"), "swift")
        XCTAssertEqual(DeclaredTypes.languageId(forPathExtension: "JSON"), "json") // регистронезависимо
        XCTAssertEqual(DeclaredTypes.languageId(forPathExtension: "js"), "javascript")
        XCTAssertNil(DeclaredTypes.languageId(forPathExtension: "py"))
    }

    func testPreviewHappyPath() {
        let s = ManagerSettings.default
        XCTAssertEqual(previewLanguageId(forPathExtension: "swift", settings: s), "swift")
    }

    func testUnknownExtensionGivesNil() {
        XCTAssertNil(previewLanguageId(forPathExtension: "py", settings: .default))
    }

    func testDisabledLanguageGivesNil() {
        var s = ManagerSettings.default
        s.disabledLanguageIds = ["json"]
        XCTAssertNil(previewLanguageId(forPathExtension: "json", settings: s))
    }

    func testPreviewDisabledLanguageGivesNil() {
        var s = ManagerSettings.default
        s.previewDisabledLanguageIds = ["json"]
        XCTAssertNil(previewLanguageId(forPathExtension: "json", settings: s))
        // но красить (Слой 1) язык по-прежнему можно
        XCTAssertTrue(isLanguageEnabled("json", settings: s))
    }

    func testDisabledLanguageAlsoDisablesPreview() {
        var s = ManagerSettings.default
        s.disabledLanguageIds = ["swift"]
        XCTAssertFalse(isPreviewEnabled("swift", settings: s))
    }

    func testUnknownDisabledIdIsHarmless() {
        var s = ManagerSettings.default
        s.disabledLanguageIds = ["ruby"] // нет в каталоге
        XCTAssertTrue(isLanguageEnabled("swift", settings: s))
    }
}
```

- [ ] **Step 2: Запустить — убедиться, что падает**

Run: `swift test --filter ResolutionTests`
Expected: FAIL — `cannot find 'DeclaredTypes' in scope`.

- [ ] **Step 3: Реализовать**

Создать `Sources/QuickLookersSettingsKit/DeclaredTypes.swift`:

```swift
import Foundation

/// Один объявленный тип: UTI в Info.plist, расширение файла, целевой язык.
public struct DeclaredType: Equatable {
    public let uti: String
    public let pathExtension: String
    public let languageId: String

    public init(uti: String, pathExtension: String, languageId: String) {
        self.uti = uti
        self.pathExtension = pathExtension
        self.languageId = languageId
    }
}

/// Граница Слоя 2: что объявлено в QLSupportedContentTypes расширения.
/// В этом срезе статично; позже — из конфигурации.
public enum DeclaredTypes {
    public static let all: [DeclaredType] = [
        DeclaredType(uti: "public.swift-source", pathExtension: "swift", languageId: "swift"),
        DeclaredType(uti: "public.json", pathExtension: "json", languageId: "json"),
        DeclaredType(uti: "com.netscape.javascript-source", pathExtension: "js", languageId: "javascript"),
    ]

    /// Язык для расширения файла среди объявленных типов (или nil).
    public static func languageId(forPathExtension ext: String) -> String? {
        let lower = ext.lowercased()
        return all.first { $0.pathExtension == lower }?.languageId
    }
}

/// Язык включён в библиотеке (Слой 1), если он не в множестве выключенных.
public func isLanguageEnabled(_ id: String, settings: ManagerSettings) -> Bool {
    !settings.disabledLanguageIds.contains(id)
}

/// Язык показывается в Finder, если он включён и не убран из просмотра.
public func isPreviewEnabled(_ id: String, settings: ManagerSettings) -> Bool {
    isLanguageEnabled(id, settings: settings)
        && !settings.previewDisabledLanguageIds.contains(id)
}

/// Язык, которым красить файл по пробелу, или nil → отдать системе.
public func previewLanguageId(forPathExtension ext: String, settings: ManagerSettings) -> String? {
    guard let lang = DeclaredTypes.languageId(forPathExtension: ext) else { return nil }
    guard isPreviewEnabled(lang, settings: settings) else { return nil }
    return lang
}
```

- [ ] **Step 4: Запустить — зелёный**

Run: `swift test --filter ResolutionTests`
Expected: PASS (7 тестов).

- [ ] **Step 5: Коммит**

```bash
git add Sources/QuickLookersSettingsKit/DeclaredTypes.swift Tests/QuickLookersSettingsKitTests/ResolutionTests.swift
git commit -m "feat(settings): объявленные типы и разрешение языка/просмотра"
```

---

## Task 3: Каталог и файловый источник

**Files:**
- Create: `Sources/QuickLookersSettingsKit/Catalog.swift`
- Create: `Sources/QuickLookersSettingsKit/CatalogSource.swift`
- Test: `Tests/QuickLookersSettingsKitTests/CatalogSourceTests.swift`

**Interfaces:**
- Produces:
  - `public struct LanguageInfo: Equatable, Identifiable { let id: String; let displayName: String }`.
  - `public struct ThemeInfo: Equatable, Identifiable { let id: String; let displayName: String; let isDark: Bool }`.
  - `public struct Catalog: Equatable { let languages: [LanguageInfo]; let themes: [ThemeInfo] }`.
  - `public protocol CatalogSource { func loadCatalog() throws -> Catalog }`.
  - `public struct FileCatalogSource: CatalogSource { init(grammarsDirectory: URL, themesDirectory: URL) }`.

- [ ] **Step 1: Написать падающий тест**

Создать `Tests/QuickLookersSettingsKitTests/CatalogSourceTests.swift`:

```swift
import XCTest
@testable import QuickLookersSettingsKit

final class CatalogSourceTests: XCTestCase {
    private func makeTempDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ql-catalog-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func testReadsLanguagesAndThemesWithMetadata() throws {
        let grammars = try makeTempDir()
        let themes = try makeTempDir()
        try #"{"name":"swift","displayName":"Swift","scopeName":"source.swift"}"#
            .write(to: grammars.appendingPathComponent("swift.json"), atomically: true, encoding: .utf8)
        try #"{"name":"dark-plus","displayName":"Dark Plus","type":"dark"}"#
            .write(to: themes.appendingPathComponent("dark-plus.json"), atomically: true, encoding: .utf8)
        try #"{"name":"light-plus","displayName":"Light Plus","type":"light"}"#
            .write(to: themes.appendingPathComponent("light-plus.json"), atomically: true, encoding: .utf8)

        let source = FileCatalogSource(grammarsDirectory: grammars, themesDirectory: themes)
        let catalog = try source.loadCatalog()

        XCTAssertEqual(catalog.languages, [LanguageInfo(id: "swift", displayName: "Swift")])
        XCTAssertEqual(catalog.themes.sorted { $0.id < $1.id }, [
            ThemeInfo(id: "dark-plus", displayName: "Dark Plus", isDark: true),
            ThemeInfo(id: "light-plus", displayName: "Light Plus", isDark: false),
        ])
    }

    func testDisplayNameFallsBackToName() throws {
        let grammars = try makeTempDir()
        let themes = try makeTempDir()
        try #"{"name":"json"}"#
            .write(to: grammars.appendingPathComponent("json.json"), atomically: true, encoding: .utf8)
        let source = FileCatalogSource(grammarsDirectory: grammars, themesDirectory: themes)
        let catalog = try source.loadCatalog()
        XCTAssertEqual(catalog.languages, [LanguageInfo(id: "json", displayName: "json")])
    }
}
```

- [ ] **Step 2: Запустить — падает**

Run: `swift test --filter CatalogSourceTests`
Expected: FAIL — `cannot find 'FileCatalogSource' in scope`.

- [ ] **Step 3: Реализовать модель каталога**

Создать `Sources/QuickLookersSettingsKit/Catalog.swift`:

```swift
import Foundation

public struct LanguageInfo: Equatable, Identifiable {
    public let id: String
    public let displayName: String
    public init(id: String, displayName: String) {
        self.id = id
        self.displayName = displayName
    }
}

public struct ThemeInfo: Equatable, Identifiable {
    public let id: String
    public let displayName: String
    public let isDark: Bool
    public init(id: String, displayName: String, isDark: Bool) {
        self.id = id
        self.displayName = displayName
        self.isDark = isDark
    }
}

public struct Catalog: Equatable {
    public let languages: [LanguageInfo]
    public let themes: [ThemeInfo]
    public init(languages: [LanguageInfo], themes: [ThemeInfo]) {
        self.languages = languages
        self.themes = themes
    }
}
```

- [ ] **Step 4: Реализовать источник**

Создать `Sources/QuickLookersSettingsKit/CatalogSource.swift`:

```swift
import Foundation

public protocol CatalogSource {
    func loadCatalog() throws -> Catalog
}

/// Каталог из JSON-файлов библиотеки. Метаданные берём из самих дескрипторов,
/// чтобы тот же путь чтения позже использовал импортёр .vsix.
public struct FileCatalogSource: CatalogSource {
    private let grammarsDirectory: URL
    private let themesDirectory: URL

    public init(grammarsDirectory: URL, themesDirectory: URL) {
        self.grammarsDirectory = grammarsDirectory
        self.themesDirectory = themesDirectory
    }

    private struct GrammarMeta: Decodable { let name: String; let displayName: String? }
    private struct ThemeMeta: Decodable { let name: String; let displayName: String?; let type: String? }

    public func loadCatalog() throws -> Catalog {
        let languages = try jsonFiles(in: grammarsDirectory).compactMap { url -> LanguageInfo? in
            guard let meta = try? JSONDecoder().decode(GrammarMeta.self, from: Data(contentsOf: url))
            else { return nil }
            return LanguageInfo(id: meta.name, displayName: meta.displayName ?? meta.name)
        }
        let themes = try jsonFiles(in: themesDirectory).compactMap { url -> ThemeInfo? in
            guard let meta = try? JSONDecoder().decode(ThemeMeta.self, from: Data(contentsOf: url))
            else { return nil }
            return ThemeInfo(id: meta.name,
                             displayName: meta.displayName ?? meta.name,
                             isDark: meta.type == "dark")
        }
        return Catalog(languages: languages.sorted { $0.id < $1.id },
                       themes: themes.sorted { $0.id < $1.id })
    }

    private func jsonFiles(in directory: URL) throws -> [URL] {
        let all = try FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil)
        return all.filter { $0.pathExtension == "json" }
    }
}
```

- [ ] **Step 5: Запустить — зелёный**

Run: `swift test --filter CatalogSourceTests`
Expected: PASS (2 теста).

- [ ] **Step 6: Коммит**

```bash
git add Sources/QuickLookersSettingsKit/Catalog.swift Sources/QuickLookersSettingsKit/CatalogSource.swift Tests/QuickLookersSettingsKitTests/CatalogSourceTests.swift
git commit -m "feat(settings): каталог языков/тем из файлов-дескрипторов"
```

---

## Task 4: Хранилище `settings.json` и разрешение темы

**Files:**
- Create: `Sources/QuickLookersSettingsKit/SettingsStore.swift`
- Test: `Tests/QuickLookersSettingsKitTests/SettingsStoreTests.swift`

**Interfaces:**
- Consumes: `ManagerSettings` (Task 1), `ThemeSelection` (Task 1).
- Produces:
  - `public struct SettingsStore { init(fileURL: URL); func load() -> ManagerSettings; func save(_ settings: ManagerSettings) throws -> ManagerSettings }`. `save` атомарно пишет файл, увеличив `settingsVersion` на 1, и возвращает сохранённое значение.
  - `public func resolvedThemeId(_ theme: ThemeSelection, availableThemeIds: Set<String>, appearanceIsDark: Bool) -> String`.
  - `public let quickLookersAppGroupId = "group.com.quicklookers"`.
  - `public func quickLookersContainerURL() -> URL?`.

- [ ] **Step 1: Написать падающий тест**

Создать `Tests/QuickLookersSettingsKitTests/SettingsStoreTests.swift`:

```swift
import XCTest
@testable import QuickLookersSettingsKit

final class SettingsStoreTests: XCTestCase {
    private func tempFile() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("ql-settings-\(UUID().uuidString).json")
    }

    func testLoadMissingFileReturnsDefault() {
        let store = SettingsStore(fileURL: tempFile())
        XCTAssertEqual(store.load(), .default)
    }

    func testSaveThenLoadRoundTrip() throws {
        let store = SettingsStore(fileURL: tempFile())
        var s = ManagerSettings.default
        s.disabledLanguageIds = ["javascript"]
        let saved = try store.save(s)
        let loaded = store.load()
        XCTAssertEqual(loaded.disabledLanguageIds, ["javascript"])
        XCTAssertEqual(loaded, saved)
    }

    func testSaveBumpsSettingsVersion() throws {
        let store = SettingsStore(fileURL: tempFile())
        let saved = try store.save(ManagerSettings.default) // version 0 -> 1
        XCTAssertEqual(saved.settingsVersion, 1)
        let saved2 = try store.save(saved) // 1 -> 2
        XCTAssertEqual(saved2.settingsVersion, 2)
    }

    func testCorruptFileReturnsDefault() throws {
        let url = tempFile()
        try "{ not json".write(to: url, atomically: true, encoding: .utf8)
        let store = SettingsStore(fileURL: url)
        XCTAssertEqual(store.load(), .default)
    }

    func testUnknownSchemaVersionReturnsDefault() throws {
        let url = tempFile()
        var s = ManagerSettings.default
        s.schemaVersion = 999
        try JSONEncoder().encode(s).write(to: url)
        let store = SettingsStore(fileURL: url)
        XCTAssertEqual(store.load(), .default)
    }

    func testResolvedThemePresentIdUsedAsIs() {
        let t = ThemeSelection(followSystem: true, lightThemeId: "light-plus",
                               darkThemeId: "dark-plus", fixedThemeId: "dark-plus")
        let id = resolvedThemeId(t, availableThemeIds: ["light-plus", "dark-plus"], appearanceIsDark: true)
        XCTAssertEqual(id, "dark-plus")
    }

    func testResolvedThemeMissingIdFallsBackByAppearance() {
        let t = ThemeSelection(followSystem: false, lightThemeId: "light-plus",
                               darkThemeId: "dark-plus", fixedThemeId: "monokai") // нет в каталоге
        let dark = resolvedThemeId(t, availableThemeIds: ["light-plus", "dark-plus"], appearanceIsDark: true)
        let light = resolvedThemeId(t, availableThemeIds: ["light-plus", "dark-plus"], appearanceIsDark: false)
        XCTAssertEqual(dark, "dark-plus")
        XCTAssertEqual(light, "light-plus")
    }
}
```

- [ ] **Step 2: Запустить — падает**

Run: `swift test --filter SettingsStoreTests`
Expected: FAIL — `cannot find 'SettingsStore' in scope`.

- [ ] **Step 3: Реализовать**

Создать `Sources/QuickLookersSettingsKit/SettingsStore.swift`:

```swift
import Foundation

/// Чтение/запись настроек как файла settings.json. Запись атомарна.
public struct SettingsStore {
    private let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// Возвращает настройки из файла; при отсутствии/порче/чужой схеме — умолчания.
    public func load() -> ManagerSettings {
        guard
            let data = try? Data(contentsOf: fileURL),
            let decoded = try? JSONDecoder().decode(ManagerSettings.self, from: data),
            decoded.schemaVersion == ManagerSettings.currentSchemaVersion
        else { return .default }
        return decoded
    }

    /// Пишет настройки, увеличив settingsVersion. Возвращает сохранённое значение.
    @discardableResult
    public func save(_ settings: ManagerSettings) throws -> ManagerSettings {
        var next = settings
        next.settingsVersion += 1
        let data = try JSONEncoder().encode(next)
        try data.write(to: fileURL, options: .atomic) // temp-файл + переименование
        return next
    }
}

/// Кандидат темы с откатом, если выбранного id нет в каталоге.
public func resolvedThemeId(_ theme: ThemeSelection,
                            availableThemeIds: Set<String>,
                            appearanceIsDark: Bool) -> String {
    let candidate = theme.resolvedThemeId(appearanceIsDark: appearanceIsDark)
    if availableThemeIds.contains(candidate) { return candidate }
    return appearanceIsDark ? DefaultThemeIds.dark : DefaultThemeIds.light
}

/// Идентификатор общего контейнера App Group.
public let quickLookersAppGroupId = "group.com.quicklookers"

/// URL общего контейнера App Group (nil, если entitlement не настроен).
public func quickLookersContainerURL() -> URL? {
    FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: quickLookersAppGroupId)
}
```

- [ ] **Step 4: Запустить — зелёный**

Run: `swift test --filter SettingsStoreTests`
Expected: PASS (7 тестов).

- [ ] **Step 5: Прогнать весь пакет**

Run: `swift test`
Expected: PASS — все таргеты (Engine, PreviewKit, SettingsKit) зелёные.

- [ ] **Step 6: Коммит**

```bash
git add Sources/QuickLookersSettingsKit/SettingsStore.swift Tests/QuickLookersSettingsKitTests/SettingsStoreTests.swift
git commit -m "feat(settings): хранилище settings.json и разрешение темы"
```

---

## Task 5: Движок отдаёт каталоги ресурсов наружу

**Files:**
- Create: `Sources/QuickLookersEngine/EngineResources.swift`
- Test: `Tests/QuickLookersEngineTests/EngineResourcesTests.swift`

**Interfaces:**
- Produces: `public enum QuickLookersEngineResources { static func grammarsDirectory() throws -> URL; static func themesDirectory() throws -> URL }`. Используется приложением и расширением для постройки `FileCatalogSource`.

- [ ] **Step 1: Написать падающий тест**

Создать `Tests/QuickLookersEngineTests/EngineResourcesTests.swift`:

```swift
import XCTest
@testable import QuickLookersEngine

final class EngineResourcesTests: XCTestCase {
    func testGrammarsDirectoryContainsSwift() throws {
        let dir = try QuickLookersEngineResources.grammarsDirectory()
        let swift = dir.appendingPathComponent("swift.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: swift.path))
    }

    func testThemesDirectoryContainsDarkPlus() throws {
        let dir = try QuickLookersEngineResources.themesDirectory()
        let dark = dir.appendingPathComponent("dark-plus.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: dark.path))
    }
}
```

- [ ] **Step 2: Запустить — падает**

Run: `swift test --filter EngineResourcesTests`
Expected: FAIL — `cannot find 'QuickLookersEngineResources' in scope`.

- [ ] **Step 3: Реализовать**

Создать `Sources/QuickLookersEngine/EngineResources.swift`:

```swift
import Foundation

/// Публичный доступ к каталогам встроенных ресурсов движка.
/// Потребители (приложение, расширение) строят из них каталог настроек,
/// не завися от внутренней структуры Bundle.module.
public enum QuickLookersEngineResources {
    public static func grammarsDirectory() throws -> URL {
        guard let url = Bundle.module.url(forResource: "grammars", withExtension: nil) else {
            throw EngineError.resourceNotFound("grammars")
        }
        return url
    }

    public static func themesDirectory() throws -> URL {
        guard let url = Bundle.module.url(forResource: "themes", withExtension: nil) else {
            throw EngineError.resourceNotFound("themes")
        }
        return url
    }
}
```

- [ ] **Step 4: Запустить — зелёный**

Run: `swift test --filter EngineResourcesTests`
Expected: PASS (2 теста).

- [ ] **Step 5: Коммит**

```bash
git add Sources/QuickLookersEngine/EngineResources.swift Tests/QuickLookersEngineTests/EngineResourcesTests.swift
git commit -m "feat(engine): публичный доступ к каталогам ресурсов"
```

---

## Task 6: App Group в проекте

**Files:**
- Modify: `project.yml`

**Interfaces:**
- Consumes: `QuickLookersSettingsKit` как пакетный продукт (для линковки в расширение в Task 7).
- Produces: оба таргета подписаны с entitlement `com.apple.security.application-groups: [group.com.quicklookers]`; расширение линкует `QuickLookersSettingsKit`.

- [ ] **Step 1: Добавить App Group хост-приложению**

В `project.yml`, в таргете `QuickLookers`, в блок `entitlements.properties` добавить строку:

```yaml
        com.apple.security.application-groups: [group.com.quicklookers]
```

(рядом с существующими `com.apple.security.app-sandbox` и `com.apple.security.files.user-selected.read-only`).

- [ ] **Step 2: Добавить App Group расширению и линковку SettingsKit**

В таргете `QuickLookersPreview`, в `entitlements.properties` добавить:

```yaml
        com.apple.security.application-groups: [group.com.quicklookers]
```

И в его `dependencies` добавить третью запись:

```yaml
      - package: QuickLookersEngine
        product: QuickLookersSettingsKit
```

- [ ] **Step 3: Подключить пакетные продукты к хост-приложению**

Приложению (Task 9) понадобятся движок (URL ресурсов) и `SettingsKit`. В таргете `QuickLookers`, в блок `dependencies` (где уже есть `- target: QuickLookersPreview / embed: true`) добавить две записи:

```yaml
      - package: QuickLookersEngine
        product: QuickLookersEngine
      - package: QuickLookersEngine
        product: QuickLookersSettingsKit
```

- [ ] **Step 4: Перегенерировать проект**

Run: `xcodegen generate`
Expected: `Created project at .../QuickLookers.xcodeproj` без ошибок.

- [ ] **Step 5: Проверить сборку без подписи**

Run:
```bash
xcodebuild -project QuickLookers.xcodeproj -scheme QuickLookers \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```
Expected: `** BUILD SUCCEEDED **`. (Изменений в коде ещё нет — проверяем, что entitlements и новые зависимости не ломают сборку.)

- [ ] **Step 6: Коммит**

```bash
git add project.yml
git commit -m "feat(app): App Group обоим таргетам, пакетные продукты в приложение и расширение"
```

---

## Task 7: Расширение читает настройки из контейнера

**Files:**
- Modify: `PreviewExtension/PreviewViewController.swift`

**Interfaces:**
- Consumes: `previewLanguageId(forPathExtension:settings:)`, `SettingsStore`, `quickLookersContainerURL()`, `resolvedThemeId(_:availableThemeIds:appearanceIsDark:)`, `FileCatalogSource` (Tasks 2–4), `QuickLookersEngineResources` (Task 5).

- [ ] **Step 1: Переписать `PreviewViewController.swift`**

Полностью заменить содержимое `PreviewExtension/PreviewViewController.swift`:

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

    // Тёплый процесс: движок и набор id тем строятся один раз на жизнь процесса.
    private static var cachedEngine: HighlightEngine?
    private static var cachedThemeIds: Set<String>?

    private var webView: WKWebView!
    private var loadContinuation: CheckedContinuation<Void, Error>?

    override func loadView() {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = false
        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        self.view = webView
    }

    func preparePreviewOfFile(at url: URL) async throws {
        let start = Date()
        let wasWarm = Self.cachedEngine != nil

        // Настройки из общего контейнера; нет/битый файл — умолчания.
        let settings = Self.settings()

        guard let lang = previewLanguageId(forPathExtension: url.pathExtension, settings: settings) else {
            // Не наш тип / язык выключен / убран из просмотра — отдаём системе.
            throw CocoaError(.featureUnsupported)
        }

        // Тема по текущему оформлению системы, с откатом если id пропал.
        let isDark = view.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let themeId = resolvedThemeId(settings.theme,
                                      availableThemeIds: try Self.themeIds(),
                                      appearanceIsDark: isDark)

        let code = try String(contentsOf: url, encoding: .utf8)
        let engine = try Self.engine()
        let fragment = try engine.highlightToHTML(
            HighlightRequest(code: code, languageId: lang, themeId: themeId)
        )
        let page = previewPageHTML(highlighted: fragment)

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            self.loadContinuation = cont
            webView.loadHTMLString(page, baseURL: nil)
        }

        let ms = Date().timeIntervalSince(start) * 1000
        Self.log.info("""
            preview pid=\(getpid()) warm=\(wasWarm, privacy: .public) \
            lang=\(lang, privacy: .public) theme=\(themeId, privacy: .public) \
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

- [ ] **Step 2: Перегенерировать и собрать**

Run:
```bash
xcodegen generate
xcodebuild -project QuickLookers.xcodeproj -scheme QuickLookers \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```
Expected: `** BUILD SUCCEEDED **`. Если SourceKit в редакторе ругается на `import QuickLookersSettingsKit` — это задержка индексатора, сборка важнее.

- [ ] **Step 3: Коммит**

```bash
git add PreviewExtension/PreviewViewController.swift
git commit -m "feat(preview): язык и тема из настроек общего контейнера"
```

---

## Task 8: Убрать `LanguageMap` из PreviewKit

**Files:**
- Delete: `Sources/QuickLookersPreviewKit/LanguageMap.swift`
- Delete: `Tests/QuickLookersPreviewKitTests/LanguageMapTests.swift`

**Interfaces:**
- Никаких новых. Логика «расширение → язык» уже в `SettingsKit` (Task 2), расширение на неё переведено (Task 7).

- [ ] **Step 1: Убедиться, что `languageId(forPathExtension:)` больше нигде не используется**

Run: `grep -rn "languageId(forPathExtension" Sources App PreviewExtension`
Expected: единственное определение — в `Sources/QuickLookersSettingsKit/DeclaredTypes.swift`. Вызовов из `PreviewKit` нет (расширение переведено на `previewLanguageId`).

- [ ] **Step 2: Удалить файлы**

Run:
```bash
git rm Sources/QuickLookersPreviewKit/LanguageMap.swift Tests/QuickLookersPreviewKitTests/LanguageMapTests.swift
```

- [ ] **Step 3: Прогнать пакет**

Run: `swift test`
Expected: PASS. PreviewKit-таргет компилируется (остаётся `previewPageHTML`), его тесты страницы зелёные.

- [ ] **Step 4: Пересобрать Xcode-проект**

Run:
```bash
xcodebuild -project QuickLookers.xcodeproj -scheme QuickLookers \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Коммит**

```bash
git commit -m "refactor(preview-kit): убрать LanguageMap — логика языка в SettingsKit"
```

---

## Task 9: Окно с тремя вкладками

**Files:**
- Create: `App/SettingsModel.swift`
- Create: `App/ContentView.swift`
- Create: `App/FormatsTab.swift`
- Create: `App/ThemesTab.swift`
- Create: `App/FileTypesTab.swift`
- Modify: `App/QuickLookersApp.swift`

**Interfaces:**
- Consumes: `ManagerSettings`, `SettingsStore`, `Catalog`/`FileCatalogSource`, `LanguageInfo`/`ThemeInfo`, `DeclaredTypes`, `isLanguageEnabled`, `quickLookersContainerURL` (Tasks 1–4), `QuickLookersEngineResources` (Task 5).

- [ ] **Step 1: Модель окна `SettingsModel`**

Создать `App/SettingsModel.swift`:

```swift
import Foundation
import SwiftUI
import QuickLookersEngine
import QuickLookersSettingsKit

/// Состояние окна: настройки в памяти + каталог доступного.
/// Любое изменение сразу пишется в settings.json (с ростом settingsVersion).
@MainActor
final class SettingsModel: ObservableObject {
    @Published var settings: ManagerSettings
    @Published private(set) var warning: String?
    let catalog: Catalog

    private let store: SettingsStore?

    init() {
        // Каталог из ресурсов движка.
        let loadedCatalog: Catalog
        do {
            let source = FileCatalogSource(
                grammarsDirectory: try QuickLookersEngineResources.grammarsDirectory(),
                themesDirectory: try QuickLookersEngineResources.themesDirectory())
            loadedCatalog = try source.loadCatalog()
        } catch {
            loadedCatalog = Catalog(languages: [], themes: [])
        }
        self.catalog = loadedCatalog

        // Хранилище — в общем контейнере. Нет контейнера → окно работает,
        // но предупреждаем: подпись/entitlement не настроены.
        if let container = quickLookersContainerURL() {
            let store = SettingsStore(fileURL: container.appendingPathComponent("settings.json"))
            self.store = store
            self.settings = store.load()
            self.warning = nil
        } else {
            self.store = nil
            self.settings = .default
            self.warning = "Контейнер App Group недоступен — изменения не сохраняются. Проверь подпись и entitlement."
        }
    }

    /// Изменить настройки и сразу сохранить.
    func update(_ mutate: (inout ManagerSettings) -> Void) {
        mutate(&settings)
        guard let store else { return }
        if let saved = try? store.save(settings) {
            settings = saved
        }
    }

    // Удобные производные для вкладок.
    func isLanguageOn(_ id: String) -> Bool { isLanguageEnabled(id, settings: settings) }
    func isPreviewOn(_ id: String) -> Bool { isPreviewEnabled(id, settings: settings) }
}
```

- [ ] **Step 2: Вкладка «Форматы подсветки»**

Создать `App/FormatsTab.swift`:

```swift
import SwiftUI

/// Слой 1 — библиотека: какие языки умеем красить (opt-out).
struct FormatsTab: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        Form {
            Section("Языки") {
                ForEach(model.catalog.languages) { lang in
                    Toggle(lang.displayName, isOn: Binding(
                        get: { model.isLanguageOn(lang.id) },
                        set: { on in
                            model.update { s in
                                if on { s.disabledLanguageIds.remove(lang.id) }
                                else { s.disabledLanguageIds.insert(lang.id) }
                            }
                        }))
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
```

- [ ] **Step 3: Вкладка «Темы»**

Создать `App/ThemesTab.swift`:

```swift
import SwiftUI
import QuickLookersSettingsKit

/// Выбор темы: следовать за системой (светлая+тёмная) либо фиксированная.
struct ThemesTab: View {
    @ObservedObject var model: SettingsModel

    private var lightThemes: [ThemeInfo] { model.catalog.themes.filter { !$0.isDark } }
    private var darkThemes: [ThemeInfo] { model.catalog.themes.filter { $0.isDark } }

    var body: some View {
        Form {
            Toggle("Следовать за системой", isOn: Binding(
                get: { model.settings.theme.followSystem },
                set: { on in model.update { $0.theme.followSystem = on } }))

            if model.settings.theme.followSystem {
                themePicker("Светлая тема", themes: lightThemes, keyPath: \.theme.lightThemeId)
                themePicker("Тёмная тема", themes: darkThemes, keyPath: \.theme.darkThemeId)
            } else {
                themePicker("Активная тема", themes: model.catalog.themes, keyPath: \.theme.fixedThemeId)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func themePicker(_ title: String, themes: [ThemeInfo],
                             keyPath: WritableKeyPath<ManagerSettings, String>) -> some View {
        Picker(title, selection: Binding(
            get: { model.settings[keyPath: keyPath] },
            set: { id in model.update { $0[keyPath: keyPath] = id } })) {
            ForEach(themes) { theme in
                Text(theme.displayName).tag(theme.id)
            }
        }
    }
}
```

- [ ] **Step 4: Вкладка «Сопоставление с типами файлов»**

Создать `App/FileTypesTab.swift`:

```swift
import SwiftUI
import QuickLookersSettingsKit

/// Слой 2 — просмотр в Finder, тумблер на язык. Список — из объявленных типов.
struct FileTypesTab: View {
    @ObservedObject var model: SettingsModel

    /// Языки с объявленным типом + их расширения (для пояснения).
    private struct Row: Identifiable {
        let id: String          // languageId
        let displayName: String
        let extensions: String  // ".swift", ".json" …
    }

    private var rows: [Row] {
        let byLanguage = Dictionary(grouping: DeclaredTypes.all, by: { $0.languageId })
        return byLanguage.keys.sorted().map { lang in
            let exts = byLanguage[lang]!.map { ".\($0.pathExtension)" }.joined(separator: ", ")
            let name = model.catalog.languages.first { $0.id == lang }?.displayName ?? lang
            return Row(id: lang, displayName: name, extensions: exts)
        }
    }

    var body: some View {
        Form {
            Section("Просмотр в Finder") {
                ForEach(rows) { row in
                    Toggle(isOn: Binding(
                        get: { model.isPreviewOn(row.id) },
                        set: { on in
                            model.update { s in
                                if on { s.previewDisabledLanguageIds.remove(row.id) }
                                else { s.previewDisabledLanguageIds.insert(row.id) }
                            }
                        })) {
                        VStack(alignment: .leading) {
                            Text(row.displayName)
                            Text(row.extensions).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .disabled(!model.isLanguageOn(row.id)) // выключенный на вкладке 1 язык неактивен
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
```

- [ ] **Step 5: Окно с вкладками**

Создать `App/ContentView.swift`:

```swift
import SwiftUI

struct ContentView: View {
    @StateObject private var model = SettingsModel()

    var body: some View {
        VStack(spacing: 0) {
            if let warning = model.warning {
                Text(warning)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            TabView {
                FormatsTab(model: model)
                    .tabItem { Label("Форматы подсветки", systemImage: "paintbrush") }
                ThemesTab(model: model)
                    .tabItem { Label("Темы", systemImage: "circle.lefthalf.filled") }
                FileTypesTab(model: model)
                    .tabItem { Label("Сопоставление", systemImage: "doc.text") }
            }
        }
        .frame(width: 460, height: 360)
    }
}
```

- [ ] **Step 6: Подключить окно в приложении**

Заменить содержимое `App/QuickLookersApp.swift`:

```swift
import SwiftUI

@main
struct QuickLookersApp: App {
    var body: some Scene {
        WindowGroup("QuickLookers") {
            ContentView()
        }
        .windowResizability(.contentSize)
    }
}
```

- [ ] **Step 7: Перегенерировать и собрать**

Run:
```bash
xcodegen generate
xcodebuild -project QuickLookers.xcodeproj -scheme QuickLookers \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 8: Коммит**

```bash
git add App/SettingsModel.swift App/ContentView.swift App/FormatsTab.swift App/ThemesTab.swift App/FileTypesTab.swift App/QuickLookersApp.swift
git commit -m "feat(app): окно настроек с тремя вкладками"
```

- [ ] **Step 9: Ручная сквозная проверка (на машине пользователя)**

Это шаг пользователя — выполняется в Xcode, не из CLI:
1. Открыть проект, запустить хост (⌘R) — регистрирует расширение и создаёт контейнер.
2. В окне переключить «Темы» → выбрать другую тему (или выключить «следовать за системой» и взять светлую).
3. Пробел в Finder на `.swift` → подсветка в выбранной теме.
4. На вкладке «Сопоставление» выключить просмотр JSON → пробел на `.json` → системный показ; включить обратно → снова наш.
5. Логи: `/usr/bin/log stream --info --predicate 'subsystem == "com.quicklookers.preview"'` — видно `theme=…` в строке показа.

---

## Task 10: Обновить документацию

**Files:**
- Modify: `CLAUDE.md`
- Modify: `README.md`
- Modify: `docs/superpowers/specs/2026-06-28-manager-app-window-design.md` (статус)

- [ ] **Step 1: Обновить статус спеки**

В шапке `docs/superpowers/specs/2026-06-28-manager-app-window-design.md` поменять `**Статус:** утверждён, готов к написанию плана реализации` на `**Статус:** реализован (фаза 3)`.

- [ ] **Step 2: Обновить `CLAUDE.md`**

В разделе «Текущее состояние» добавить пункт о фазе 3 (окно менеджера, App Group, `QuickLookersSettingsKit`), в «Структуру» — новый таргет и файлы `App/*`, в команды при необходимости — ничего нового (всё те же `swift test` / `xcodegen` / `xcodebuild`). Описать кратко, человеческим языком, как в остальном файле.

- [ ] **Step 3: Обновить `README.md`**

В таблице статуса отметить фазу 3 как сделанную; упомянуть три вкладки и App Group.

- [ ] **Step 4: Прогнать пакет напоследок**

Run: `swift test`
Expected: PASS — все таргеты зелёные.

- [ ] **Step 5: Коммит**

```bash
git add CLAUDE.md README.md docs/superpowers/specs/2026-06-28-manager-app-window-design.md
git commit -m "docs: актуализировать состояние — фаза 3 (окно менеджера)"
```

---

## Завершение

После всех задач — **REQUIRED SUB-SKILL:** `superpowers:finishing-a-development-branch`: прогнать `swift test`, предложить варианты (влить в `main` / PR / оставить), выполнить выбранное.
