# Пересбор вкладки «Просмотр в Finder» — план реализации

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Заменить вкладку сопоставлений «файл→язык» удобным инструментом управления правилами (glob-маски), починить расход памяти и сделать честный статус перехвата.

**Architecture:** Единый упорядоченный список `PreviewRule` в настройках (схема v3) вместо четырёх параллельных структур; разрешение показа — правила пользователя (glob, по убыванию специфичности) поверх датасета-словарей; вкладка по умолчанию показывает только правила пользователя, датасет виден лишь под поиск с потолком; лист добавления показывает текущий дефолт и статус перехвата.

**Tech Stack:** Swift 6.3 / SwiftPM (пакет `QuickLookersSettingsKit`, чистые unit-тесты `swift test`) + SwiftUI-часть в Xcode-таргете `QuickLookers` (XcodeGen), тесты App — через `xcodebuild`. `UniformTypeIdentifiers` для классификации типов.

## Global Constraints

- Отвечать пользователю по-русски; строки интерфейса — по-русски, от лица пользователя (не «перехват», а «просмотр»).
- TDD строго: падающий тест → запуск (падает) → минимальная реализация → запуск (зелёный) → коммит. По одному шагу.
- Тесты прогонять **по доменам** и **с таймаутом**. Полный набор — в конце.
- Коммиты по-русски, формат `feat(settings): …` / `test(settings): …` / `refactor(app): …` / `docs: …`, трейлер `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.
- Пакет `QuickLookersSettingsKit` **не зависит** от движка (URL датасета передаёт вызывающая сторона).
- Не править `.xcodeproj`/`Info.plist`/`*.entitlements` руками — источник `project.yml`, перегенерировать `xcodegen generate`.
- Миграции настроек нет: `schemaVersion < 3` → сброс в `.default` (пользователей ещё нет).
- Точка входа разрешения — та же сигнатура `resolvePreview(fileName:pathExtension:associations:settings:)`; расширение Preview (`PreviewViewController`) не трогаем.
- Список перехвата Слоя A (UTI в `project.yml`) в этой задаче **не расширяем**.

---

### Task 1: `GlobMatcher` — сопоставление имени файла с glob-шаблоном

**Files:**
- Create: `Sources/QuickLookersSettingsKit/GlobMatcher.swift`
- Test: `Tests/QuickLookersSettingsKitTests/GlobMatcherTests.swift`

**Interfaces:**
- Produces:
  - `struct GlobMatcher` с `init(_ pattern: String)`, `func matches(fileName: String) -> Bool`,
    `var specificity: Int`, `var fastExtension: String?`, `var exactFilename: String?`, `var probeExtension: String?`.

- [ ] **Step 1: Написать падающий тест**

```swift
// Tests/QuickLookersSettingsKitTests/GlobMatcherTests.swift
import XCTest
@testable import QuickLookersSettingsKit

final class GlobMatcherTests: XCTestCase {
    func test_extensionPattern_matches() {
        let m = GlobMatcher("*.djhtml")
        XCTAssertTrue(m.matches(fileName: "index.djhtml"))
        XCTAssertFalse(m.matches(fileName: "index.html"))
    }

    func test_matching_isCaseInsensitive() {
        XCTAssertTrue(GlobMatcher("*.djhtml").matches(fileName: "Index.DJHTML"))
    }

    func test_compoundExtension_matches() {
        let m = GlobMatcher("*.config.js")
        XCTAssertTrue(m.matches(fileName: "webpack.config.js"))
        XCTAssertFalse(m.matches(fileName: "webpack.js"))
    }

    func test_filenamePrefix_matches() {
        let m = GlobMatcher("Dockerfile.*")
        XCTAssertTrue(m.matches(fileName: "Dockerfile.dev"))
        XCTAssertFalse(m.matches(fileName: "Dockerfile"))   // '*' требует хотя бы 0 символов после точки, но точка обязательна
    }

    func test_questionMark_matchesSingleChar() {
        let m = GlobMatcher("*.djhtm?")
        XCTAssertTrue(m.matches(fileName: "a.djhtml"))
        XCTAssertTrue(m.matches(fileName: "a.djhtmX"))
        XCTAssertFalse(m.matches(fileName: "a.djhtm"))
    }

    func test_exactFilename_matches() {
        let m = GlobMatcher("Dockerfile")
        XCTAssertTrue(m.matches(fileName: "Dockerfile"))
        XCTAssertFalse(m.matches(fileName: "Dockerfile.dev"))
    }

    func test_specificity_exactBeatsGlob_andLongerLiteralsWin() {
        XCTAssertGreaterThan(GlobMatcher("Dockerfile").specificity, GlobMatcher("*.js").specificity)
        XCTAssertGreaterThan(GlobMatcher("*.config.js").specificity, GlobMatcher("*.js").specificity)
    }

    func test_fastExtension_onlyForSingleTokenStarDot() {
        XCTAssertEqual(GlobMatcher("*.js").fastExtension, "js")
        XCTAssertEqual(GlobMatcher("*.JS").fastExtension, "js")
        XCTAssertNil(GlobMatcher("*.config.js").fastExtension)   // есть точка в остатке
        XCTAssertNil(GlobMatcher("Dockerfile").fastExtension)
    }

    func test_exactFilename_property() {
        XCTAssertEqual(GlobMatcher("Dockerfile").exactFilename, "Dockerfile")
        XCTAssertNil(GlobMatcher("*.js").exactFilename)
    }

    func test_probeExtension_derivesTestableExtension() {
        XCTAssertEqual(GlobMatcher("*.js").probeExtension, "js")
        XCTAssertEqual(GlobMatcher("a.min.js").probeExtension, "js")  // литерал с точкой → хвост
        XCTAssertNil(GlobMatcher("*.config.js").probeExtension)       // wildcard + точка → неопределимо
        XCTAssertNil(GlobMatcher("Dockerfile").probeExtension)        // нет точки
    }
}
```

- [ ] **Step 2: Запустить — убедиться, что падает**

Run: `swift test --filter GlobMatcherTests 2>&1 | tail -20`
Expected: FAIL — «cannot find 'GlobMatcher' in scope».

- [ ] **Step 3: Реализовать**

```swift
// Sources/QuickLookersSettingsKit/GlobMatcher.swift
import Foundation

/// Сопоставление полного имени файла с простым glob-шаблоном (`*` — любая
/// последовательность, `?` — один символ). Классов `[...]` и регулярок нет.
/// Сопоставление регистронезависимо (дружелюбнее для настроек пользователя).
public struct GlobMatcher: Equatable {
    public let pattern: String

    public init(_ pattern: String) { self.pattern = pattern }

    private var hasWildcard: Bool { pattern.contains("*") || pattern.contains("?") }

    public func matches(fileName: String) -> Bool {
        Self.wildcard(Array(pattern.lowercased()), Array(fileName.lowercased()))
    }

    /// Чем больше литералов и меньше wildcard — тем специфичнее. Точное имя
    /// (без wildcard) всегда выше любого glob.
    public var specificity: Int {
        let literals = pattern.reduce(0) { $1 == "*" || $1 == "?" ? $0 : $0 + 1 }
        return hasWildcard ? literals : 1000 + literals
    }

    /// «*.ext» одним сегментом (без точки/wildcard в остатке) → «ext» (lower). Иначе nil.
    public var fastExtension: String? {
        guard pattern.hasPrefix("*.") else { return nil }
        let rest = pattern.dropFirst(2)
        guard !rest.isEmpty, !rest.contains(where: { $0 == "*" || $0 == "?" || $0 == "." })
        else { return nil }
        return rest.lowercased()
    }

    /// Шаблон без wildcard — это точное имя файла.
    public var exactFilename: String? { hasWildcard ? nil : pattern }

    /// Расширение, по которому можно проверить перехват; nil если неопределимо.
    public var probeExtension: String? {
        if let f = fastExtension { return f }
        if let name = exactFilename, name.contains(".") {
            return name.split(separator: ".").last.map { $0.lowercased() }
        }
        return nil
    }

    /// fnmatch для `*` и `?` с бэктрекингом по `*`.
    private static func wildcard(_ pat: [Character], _ str: [Character]) -> Bool {
        var p = 0, s = 0, star = -1, mark = 0
        while s < str.count {
            if p < pat.count, pat[p] == "?" || pat[p] == str[s] {
                p += 1; s += 1
            } else if p < pat.count, pat[p] == "*" {
                star = p; mark = s; p += 1
            } else if star != -1 {
                p = star + 1; mark += 1; s = mark
            } else {
                return false
            }
        }
        while p < pat.count, pat[p] == "*" { p += 1 }
        return p == pat.count
    }
}
```

- [ ] **Step 4: Запустить — зелёный**

Run: `swift test --filter GlobMatcherTests 2>&1 | tail -20`
Expected: PASS (10 тестов).

- [ ] **Step 5: Коммит**

```bash
git add Sources/QuickLookersSettingsKit/GlobMatcher.swift Tests/QuickLookersSettingsKitTests/GlobMatcherTests.swift
git commit -m "feat(settings): GlobMatcher — glob-сопоставление имени файла (маски *, ?)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: `PreviewRule` — модель правила просмотра

**Files:**
- Create: `Sources/QuickLookersSettingsKit/PreviewRule.swift`
- Test: `Tests/QuickLookersSettingsKitTests/PreviewRuleTests.swift`

**Interfaces:**
- Produces:
  - `enum RuleAction: Codable, Equatable { case assign(languageId: String); case neutral }`
  - `struct PreviewRule: Codable, Equatable, Identifiable { var id: UUID; var pattern: String; var action: RuleAction; var isEnabled: Bool }`
    с `init(id: UUID = UUID(), pattern: String, action: RuleAction, isEnabled: Bool = true)`.

- [ ] **Step 1: Написать падающий тест**

```swift
// Tests/QuickLookersSettingsKitTests/PreviewRuleTests.swift
import XCTest
@testable import QuickLookersSettingsKit

final class PreviewRuleTests: XCTestCase {
    func test_defaultsEnabledWithGeneratedId() {
        let r = PreviewRule(pattern: "*.djhtml", action: .assign(languageId: "django-html"))
        XCTAssertTrue(r.isEnabled)
        XCTAssertEqual(r.pattern, "*.djhtml")
    }

    func test_codableRoundTrip_assign() throws {
        let r = PreviewRule(pattern: "*.config.js", action: .assign(languageId: "json"), isEnabled: false)
        let back = try JSONDecoder().decode(PreviewRule.self, from: JSONEncoder().encode(r))
        XCTAssertEqual(r, back)
    }

    func test_codableRoundTrip_neutral() throws {
        let r = PreviewRule(pattern: "*.log", action: .neutral)
        let back = try JSONDecoder().decode(PreviewRule.self, from: JSONEncoder().encode(r))
        XCTAssertEqual(r, back)
        XCTAssertEqual(back.action, .neutral)
    }
}
```

- [ ] **Step 2: Запустить — падает**

Run: `swift test --filter PreviewRuleTests 2>&1 | tail -20`
Expected: FAIL — «cannot find 'PreviewRule' in scope».

- [ ] **Step 3: Реализовать**

```swift
// Sources/QuickLookersSettingsKit/PreviewRule.swift
import Foundation

/// Что делать с файлом, попавшим под шаблон.
public enum RuleAction: Codable, Equatable {
    /// Красить подсветкой этого языка.
    case assign(languageId: String)
    /// Не подсвечивать (нейтральный показ поверх дефолта).
    case neutral
}

/// Правило просмотра пользователя: «файлы под шаблоном → действие».
public struct PreviewRule: Codable, Equatable, Identifiable {
    public var id: UUID
    public var pattern: String
    public var action: RuleAction
    public var isEnabled: Bool

    public init(id: UUID = UUID(), pattern: String, action: RuleAction, isEnabled: Bool = true) {
        self.id = id
        self.pattern = pattern
        self.action = action
        self.isEnabled = isEnabled
    }
}
```

- [ ] **Step 4: Запустить — зелёный**

Run: `swift test --filter PreviewRuleTests 2>&1 | tail -20`
Expected: PASS (3 теста).

- [ ] **Step 5: Коммит**

```bash
git add Sources/QuickLookersSettingsKit/PreviewRule.swift Tests/QuickLookersSettingsKitTests/PreviewRuleTests.swift
git commit -m "feat(settings): модель PreviewRule + RuleAction (Codable)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: `ManagerSettings` v3 + переписанный `resolvePreview`

Это атомарная ломающая правка: меняем структуру настроек и разрешение, сразу
чиним тесты пакета. `swift test` должен снова быть зелёным. App-таргет
(SettingsModel/FileTypesTab) временно перестанет компилироваться — его чиним в
Задачах 6–7; здесь его не собираем (домен — пакет).

**Files:**
- Modify: `Sources/QuickLookersSettingsKit/ManagerSettings.swift` (поля правил, `currentSchemaVersion = 3`)
- Modify: `Sources/QuickLookersSettingsKit/PreviewResolution.swift` (полная переработка `resolvePreview`)
- Modify: `Tests/QuickLookersSettingsKitTests/ManagerSettingsTests.swift` (убрать старые поля, добавить v3)
- Modify: `Tests/QuickLookersSettingsKitTests/ResolutionTests.swift` (перевести правки на `previewRules`)

**Interfaces:**
- Consumes: `GlobMatcher` (Task 1), `PreviewRule`/`RuleAction` (Task 2).
- Produces:
  - `ManagerSettings` с полем `public var previewRules: [PreviewRule]` вместо
    `extensionOverrides`/`filenameOverrides`/`disabledExtensions`/`disabledFilenames`;
    `currentSchemaVersion = 3`.
  - `resolvePreview(fileName:pathExtension:associations:settings:) -> PreviewResolution` (сигнатура неизменна).

- [ ] **Step 1: Обновить тесты `ManagerSettingsTests` (заменить два теста старых полей)**

Заменить `testDefaultHasEmptyRuleMaps` и `testRoundTripEncodesNewFields` (строки 50–67) на:

```swift
    func testDefaultHasEmptyRules() {
        let s = ManagerSettings.default
        XCTAssertEqual(s.schemaVersion, 3)
        XCTAssertTrue(s.previewRules.isEmpty)
    }

    func testRoundTripEncodesPreviewRules() throws {
        var s = ManagerSettings.default
        s.previewRules = [
            PreviewRule(pattern: "*.djhtml", action: .assign(languageId: "django-html")),
            PreviewRule(pattern: "*.log", action: .neutral, isEnabled: false)
        ]
        let back = try JSONDecoder().decode(ManagerSettings.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(back.previewRules, s.previewRules)
    }
```

- [ ] **Step 2: Обновить `ResolutionTests` (перевести правки на `previewRules`)**

Заменить в `Tests/QuickLookersSettingsKitTests/ResolutionTests.swift` тела тестов,
использующих старые поля, на правила. Точечные замены:

`testDisabledExtensionIsNeutral` (было `s.disabledExtensions = ["json"]`):
```swift
    func testDisabledExtensionIsNeutral() {
        var s = ManagerSettings.default
        s.previewRules = [PreviewRule(pattern: "*.json", action: .neutral)]
        XCTAssertEqual(
            resolvePreview(fileName: "a.json", pathExtension: "json", associations: assoc, settings: s),
            .neutral)
    }
```

`testDisabledFilenameIsNeutral` (было `s.disabledFilenames = ["Dockerfile"]`):
```swift
    func testDisabledFilenameIsNeutral() {
        var s = ManagerSettings.default
        s.previewRules = [PreviewRule(pattern: "Dockerfile", action: .neutral)]
        XCTAssertEqual(
            resolvePreview(fileName: "Dockerfile", pathExtension: "", associations: assoc, settings: s),
            .neutral)
    }
```

`testExtensionOverrideWins` (было `s.extensionOverrides = ["json": "javascript"]`):
```swift
    func testExtensionOverrideWins() {
        var s = ManagerSettings.default
        s.previewRules = [PreviewRule(pattern: "*.json", action: .assign(languageId: "javascript"))]
        XCTAssertEqual(
            resolvePreview(fileName: "a.json", pathExtension: "json", associations: assoc, settings: s),
            .highlight(languageId: "javascript"))
    }
```

`testAddedExtensionRuleForUnknown` (было `s.extensionOverrides = ["myext": "python"]`):
```swift
    func testAddedExtensionRuleForUnknown() {
        var s = ManagerSettings.default
        s.previewRules = [PreviewRule(pattern: "*.myext", action: .assign(languageId: "python"))]
        XCTAssertEqual(
            resolvePreview(fileName: "a.myext", pathExtension: "myext", associations: assoc, settings: s),
            .highlight(languageId: "python"))
    }
```

И добавить новые тесты специфичности/маски/тумблера в конец класса (перед закрывающей `}`):
```swift
    func test_userRule_beatsDataset() {
        var s = ManagerSettings.default
        s.previewRules = [PreviewRule(pattern: "*.swift", action: .assign(languageId: "javascript"))]
        XCTAssertEqual(
            resolvePreview(fileName: "a.swift", pathExtension: "swift", associations: assoc, settings: s),
            .highlight(languageId: "javascript"))
    }

    func test_moreSpecificRuleWins() {
        var s = ManagerSettings.default
        s.previewRules = [
            PreviewRule(pattern: "*.js", action: .assign(languageId: "javascript")),
            PreviewRule(pattern: "*.config.js", action: .assign(languageId: "json"))
        ]
        XCTAssertEqual(
            resolvePreview(fileName: "webpack.config.js", pathExtension: "js", associations: assoc, settings: s),
            .highlight(languageId: "json"))
    }

    func test_disabledRule_isIgnored_fallsToDataset() {
        var s = ManagerSettings.default
        s.previewRules = [PreviewRule(pattern: "*.swift", action: .assign(languageId: "javascript"), isEnabled: false)]
        XCTAssertEqual(
            resolvePreview(fileName: "a.swift", pathExtension: "swift", associations: assoc, settings: s),
            .highlight(languageId: "swift"))   // правило выключено → датасет
    }

    func test_ruleAssignsDisabledLayer1Language_isNeutral() {
        var s = ManagerSettings.default
        s.disabledLanguageIds = ["javascript"]
        s.previewRules = [PreviewRule(pattern: "*.swift", action: .assign(languageId: "javascript"))]
        XCTAssertEqual(
            resolvePreview(fileName: "a.swift", pathExtension: "swift", associations: assoc, settings: s),
            .neutral)
    }

    func test_prefixMask_matchesCompoundFilename() {
        var s = ManagerSettings.default
        s.previewRules = [PreviewRule(pattern: "Dockerfile.*", action: .assign(languageId: "docker"))]
        XCTAssertEqual(
            resolvePreview(fileName: "Dockerfile.dev", pathExtension: "dev", associations: assoc, settings: s),
            .highlight(languageId: "docker"))
    }
```

- [ ] **Step 3: Запустить — убедиться, что падает (нет поля `previewRules`)**

Run: `swift test --filter SettingsKit 2>&1 | tail -25`
Expected: FAIL компиляции — «value of type 'ManagerSettings' has no member 'previewRules'».

- [ ] **Step 4: Переписать `ManagerSettings` (поля + версия)**

В `Sources/QuickLookersSettingsKit/ManagerSettings.swift` заменить блок Слоя 2
(строки 30–34 объявления, 38–39 и 45–48 в init, 51 версия, 59–62 в default):

Объявления полей — было четыре, стало одно:
```swift
    public var disabledLanguageIds: Set<String>          // Слой 1: язык выключен в библиотеке
    public var activeThemeId: String
    public var font: FontSettings
    // Слой 2: упорядоченный список правил просмотра поверх датасета.
    public var previewRules: [PreviewRule]
```

Сигнатура и тело `init`:
```swift
    public init(schemaVersion: Int, settingsVersion: Int, disabledLanguageIds: Set<String>,
                activeThemeId: String, font: FontSettings, previewRules: [PreviewRule]) {
        self.schemaVersion = schemaVersion
        self.settingsVersion = settingsVersion
        self.disabledLanguageIds = disabledLanguageIds
        self.activeThemeId = activeThemeId
        self.font = font
        self.previewRules = previewRules
    }

    public static let currentSchemaVersion = 3

    public static let `default` = ManagerSettings(
        schemaVersion: currentSchemaVersion,
        settingsVersion: 0,
        disabledLanguageIds: [],
        activeThemeId: DefaultThemeIds.dark,
        font: FontSettings(family: nil, size: nil),
        previewRules: []
    )
```

- [ ] **Step 5: Переписать `resolvePreview`**

Заменить всё содержимое `Sources/QuickLookersSettingsKit/PreviewResolution.swift` ниже
объявления `enum PreviewResolution` и `isLanguageEnabled` на:

```swift
/// Как показывать файл по пробелу.
/// Порядок: (1) правила пользователя — по убыванию специфичности, первое включённое
/// совпадение решает; (2) датасет — сначала точное имя файла, затем расширение;
/// (3) иначе нейтраль. Язык, выключенный в Слое 1, форсит нейтраль на любом уровне.
public func resolvePreview(fileName: String, pathExtension: String,
                           associations: FileTypeAssociations,
                           settings: ManagerSettings) -> PreviewResolution {
    func resolved(_ languageId: String) -> PreviewResolution {
        isLanguageEnabled(languageId, settings: settings) ? .highlight(languageId: languageId) : .neutral
    }

    // 1) Правила пользователя. Компилируем включённые, берём самое специфичное совпадение.
    let matches: [(rule: PreviewRule, spec: Int)] = settings.previewRules.compactMap { rule in
        guard rule.isEnabled else { return nil }
        let m = GlobMatcher(rule.pattern)
        return m.matches(fileName: fileName) ? (rule, m.specificity) : nil
    }
    if let winner = matches.max(by: { $0.spec < $1.spec })?.rule {
        switch winner.action {
        case .neutral: return .neutral
        case .assign(let lang): return resolved(lang)
        }
    }

    // 2) Датасет: имя файла приоритетнее расширения.
    if let lang = associations.byFilename[fileName] { return resolved(lang) }
    let ext = pathExtension.lowercased()
    if !ext.isEmpty, let lang = associations.byExtension[ext] { return resolved(lang) }

    // 3) Дошло, но неизвестно → нейтраль.
    return .neutral
}
```

- [ ] **Step 6: Запустить — зелёный**

Run: `swift test --filter SettingsKit 2>&1 | tail -25`
Expected: PASS (весь домен SettingsKit, включая обновлённые Resolution/ManagerSettings).

- [ ] **Step 7: Коммит**

```bash
git add Sources/QuickLookersSettingsKit/ManagerSettings.swift Sources/QuickLookersSettingsKit/PreviewResolution.swift Tests/QuickLookersSettingsKitTests/ManagerSettingsTests.swift Tests/QuickLookersSettingsKitTests/ResolutionTests.swift
git commit -m "feat(settings): схема v3 (единый previewRules) + glob-разрешение показа

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: `searchDataset` — поиск по датасету с потолком

**Files:**
- Create: `Sources/QuickLookersSettingsKit/DatasetSearch.swift`
- Test: `Tests/QuickLookersSettingsKitTests/DatasetSearchTests.swift`

**Interfaces:**
- Consumes: `FileTypeAssociations`.
- Produces:
  - `struct DatasetMatch: Equatable, Identifiable { var id: String; var key: DatasetMatch.Key; var languageId: String }`
    с `enum Key: Equatable { case ext(String); case filename(String) }`.
  - `func searchDataset(query: String, limit: Int, associations: FileTypeAssociations, languageName: (String) -> String?) -> [DatasetMatch]`.

- [ ] **Step 1: Написать падающий тест**

```swift
// Tests/QuickLookersSettingsKitTests/DatasetSearchTests.swift
import XCTest
@testable import QuickLookersSettingsKit

final class DatasetSearchTests: XCTestCase {
    private let assoc = FileTypeAssociations(
        byExtension: ["js": "javascript", "jsx": "javascript", "json": "json", "py": "python"],
        byFilename: ["Dockerfile": "docker", "Makefile": "make"])

    private func name(_ id: String) -> String? {
        ["javascript": "JavaScript", "json": "JSON", "python": "Python",
         "docker": "Docker", "make": "Makefile"][id]
    }

    func test_matchesByExtensionKey() {
        let r = searchDataset(query: "js", limit: 50, associations: assoc, languageName: name)
        XCTAssertTrue(r.contains { $0.key == .ext("js") })
        XCTAssertTrue(r.contains { $0.key == .ext("jsx") })
        XCTAssertTrue(r.contains { $0.key == .ext("json") })   // "js" ⊂ "json"
    }

    func test_matchesByFilenameKey() {
        let r = searchDataset(query: "docker", limit: 50, associations: assoc, languageName: name)
        XCTAssertTrue(r.contains { $0.key == .filename("Dockerfile") })
    }

    func test_matchesByLanguageName() {
        let r = searchDataset(query: "python", limit: 50, associations: assoc, languageName: name)
        XCTAssertTrue(r.contains { $0.key == .ext("py") })
    }

    func test_respectsLimit() {
        let r = searchDataset(query: "j", limit: 2, associations: assoc, languageName: name)
        XCTAssertEqual(r.count, 2)
    }

    func test_emptyQuery_returnsNothing() {
        XCTAssertTrue(searchDataset(query: "", limit: 50, associations: assoc, languageName: name).isEmpty)
    }

    func test_sortedByKey_stable() {
        let r = searchDataset(query: "j", limit: 50, associations: assoc, languageName: name)
        XCTAssertEqual(r.map(\.id), r.map(\.id).sorted())
    }
}
```

- [ ] **Step 2: Запустить — падает**

Run: `swift test --filter DatasetSearchTests 2>&1 | tail -20`
Expected: FAIL — «cannot find 'searchDataset' in scope».

- [ ] **Step 3: Реализовать**

```swift
// Sources/QuickLookersSettingsKit/DatasetSearch.swift
import Foundation

/// Совпадение из датасета для показа во вкладке (секция «По умолчанию»).
public struct DatasetMatch: Equatable, Identifiable {
    public enum Key: Equatable { case ext(String); case filename(String) }
    public let id: String          // "ext:js" / "file:Dockerfile"
    public let key: Key
    public let languageId: String

    public init(key: Key, languageId: String) {
        self.key = key
        self.languageId = languageId
        switch key {
        case .ext(let e):      self.id = "ext:\(e)"
        case .filename(let f): self.id = "file:\(f)"
        }
    }
}

/// Ищет в датасете совпадения по подстроке в ключе (расширение/имя файла) или в
/// имени языка. Фильтрует словари и строит строки ТОЛЬКО для попаданий (до `limit`),
/// отсортированных по id — никакого полного обхода/материализации тысяч строк.
/// Пустой запрос → пусто (вкладка показывает только правила пользователя).
public func searchDataset(query: String, limit: Int, associations: FileTypeAssociations,
                          languageName: (String) -> String?) -> [DatasetMatch] {
    let q = query.lowercased()
    guard !q.isEmpty else { return [] }

    func hit(key: String, lang: String) -> Bool {
        key.lowercased().contains(q) || (languageName(lang)?.lowercased().contains(q) ?? false)
    }

    var out: [DatasetMatch] = []
    for (ext, lang) in associations.byExtension where hit(key: ext, lang: lang) {
        out.append(DatasetMatch(key: .ext(ext), languageId: lang))
    }
    for (file, lang) in associations.byFilename where hit(key: file, lang: lang) {
        out.append(DatasetMatch(key: .filename(file), languageId: lang))
    }
    out.sort { $0.id < $1.id }
    return Array(out.prefix(limit))
}
```

- [ ] **Step 4: Запустить — зелёный**

Run: `swift test --filter DatasetSearchTests 2>&1 | tail -20`
Expected: PASS (6 тестов).

- [ ] **Step 5: Коммит**

```bash
git add Sources/QuickLookersSettingsKit/DatasetSearch.swift Tests/QuickLookersSettingsKitTests/DatasetSearchTests.swift
git commit -m "feat(settings): searchDataset — поиск по датасету с потолком (починка памяти)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: Ядро классификатора перехвата (чистое, в SettingsKit)

**Files:**
- Create: `Sources/QuickLookersSettingsKit/InterceptionStatus.swift`
- Test: `Tests/QuickLookersSettingsKitTests/InterceptionStatusTests.swift`

**Interfaces:**
- Produces:
  - `enum InterceptionStatus: Equatable { case intercepted; case systemNonCode(typeName: String); case unknownNotDeclared }`
  - `struct SystemTypeInfo: Equatable { var identifier: String; var isDynamic: Bool; var conformsToPlainText: Bool; var localizedName: String? }`
  - `struct DeclaredInterceptSet: Equatable { var exportedExtensions: Set<String>; var systemUTIs: Set<String>; var hasPlainTextDragnet: Bool }`
  - `func interceptionStatus(forExtension: String, systemType: SystemTypeInfo?, declared: DeclaredInterceptSet) -> InterceptionStatus`

- [ ] **Step 1: Написать падающий тест**

```swift
// Tests/QuickLookersSettingsKitTests/InterceptionStatusTests.swift
import XCTest
@testable import QuickLookersSettingsKit

final class InterceptionStatusTests: XCTestCase {
    private let declared = DeclaredInterceptSet(
        exportedExtensions: ["kt", "dart", "nim"],
        systemUTIs: ["public.swift-source", "public.mpeg-2-transport-stream", "public.plain-text"],
        hasPlainTextDragnet: true)

    func test_extensionInExportedList_isIntercepted() {
        XCTAssertEqual(
            interceptionStatus(forExtension: "kt", systemType: nil, declared: declared),
            .intercepted)
    }

    func test_unknownToSystem_notDeclared_isUnknown() {
        // .djhtml: система не знает, в списке нет → честно «не перехватим».
        let dyn = SystemTypeInfo(identifier: "dyn.abc", isDynamic: true,
                                 conformsToPlainText: false, localizedName: nil)
        XCTAssertEqual(
            interceptionStatus(forExtension: "djhtml", systemType: dyn, declared: declared),
            .unknownNotDeclared)
    }

    func test_nilSystemType_notDeclared_isUnknown() {
        XCTAssertEqual(
            interceptionStatus(forExtension: "foobar", systemType: nil, declared: declared),
            .unknownNotDeclared)
    }

    func test_systemCodeType_conformsPlainText_isIntercepted() {
        // .swift → public.swift-source, конформит plain-text → невод ловит.
        let t = SystemTypeInfo(identifier: "public.swift-source", isDynamic: false,
                               conformsToPlainText: true, localizedName: "Swift source")
        XCTAssertEqual(
            interceptionStatus(forExtension: "swift", systemType: t, declared: declared),
            .intercepted)
    }

    func test_declaredSystemUTI_evenIfNotPlainText_isIntercepted() {
        // .ts → public.mpeg-2-transport-stream (не текст), но мы намеренно объявили → перехватим.
        let t = SystemTypeInfo(identifier: "public.mpeg-2-transport-stream", isDynamic: false,
                               conformsToPlainText: false, localizedName: "MPEG-2 video")
        XCTAssertEqual(
            interceptionStatus(forExtension: "ts", systemType: t, declared: declared),
            .intercepted)
    }

    func test_systemNonCode_notDeclared_reportsTypeName() {
        // .mts → видео, не объявляли → не сработает.
        let t = SystemTypeInfo(identifier: "public.mpeg-2-video", isDynamic: false,
                               conformsToPlainText: false, localizedName: "MPEG-2 video")
        XCTAssertEqual(
            interceptionStatus(forExtension: "mts", systemType: t, declared: declared),
            .systemNonCode(typeName: "MPEG-2 video"))
    }
}
```

- [ ] **Step 2: Запустить — падает**

Run: `swift test --filter InterceptionStatusTests 2>&1 | tail -20`
Expected: FAIL — «cannot find 'interceptionStatus' in scope».

- [ ] **Step 3: Реализовать**

```swift
// Sources/QuickLookersSettingsKit/InterceptionStatus.swift
import Foundation

/// Сможет ли Finder вообще позвать нас на файл с таким расширением (Слой A).
public enum InterceptionStatus: Equatable {
    /// Файл дойдёт до нас — правило сработает.
    case intercepted
    /// Система отдала расширение настоящему не-коду (видео/архив/…), мы его не
    /// объявляли — правило не сработает. Имя типа для пояснения пользователю.
    case systemNonCode(typeName: String)
    /// Система расширение не знает и в нашем списке перехвата его нет —
    /// правило не сработает без обновления приложения.
    case unknownNotDeclared
}

/// Что система думает о расширении (мост к UTType — заполняет вызывающая сторона).
public struct SystemTypeInfo: Equatable {
    public var identifier: String
    public var isDynamic: Bool
    public var conformsToPlainText: Bool
    public var localizedName: String?
    public init(identifier: String, isDynamic: Bool, conformsToPlainText: Bool, localizedName: String?) {
        self.identifier = identifier
        self.isDynamic = isDynamic
        self.conformsToPlainText = conformsToPlainText
        self.localizedName = localizedName
    }
}

/// Наш объявленный набор перехвата, прочитанный из бандла.
public struct DeclaredInterceptSet: Equatable {
    /// Свободные (dyn.*) расширения из UTExportedTypeDeclarations хоста (lower).
    public var exportedExtensions: Set<String>
    /// Точные листовые UTI из QLSupportedContentTypes расширения.
    public var systemUTIs: Set<String>
    /// Объявлен ли невод public.plain-text (ловит системно-текстовые типы).
    public var hasPlainTextDragnet: Bool
    public init(exportedExtensions: Set<String>, systemUTIs: Set<String>, hasPlainTextDragnet: Bool) {
        self.exportedExtensions = exportedExtensions
        self.systemUTIs = systemUTIs
        self.hasPlainTextDragnet = hasPlainTextDragnet
    }
}

/// Чистая классификация: перехватим / система-не-код / неизвестно-и-не-объявлено.
public func interceptionStatus(forExtension ext: String,
                               systemType: SystemTypeInfo?,
                               declared: DeclaredInterceptSet) -> InterceptionStatus {
    let e = ext.lowercased()
    if declared.exportedExtensions.contains(e) { return .intercepted }

    guard let t = systemType, !t.isDynamic else { return .unknownNotDeclared }

    if declared.systemUTIs.contains(t.identifier) { return .intercepted }
    if declared.hasPlainTextDragnet && t.conformsToPlainText { return .intercepted }
    return .systemNonCode(typeName: t.localizedName ?? t.identifier)
}
```

- [ ] **Step 4: Запустить — зелёный**

Run: `swift test --filter InterceptionStatusTests 2>&1 | tail -20`
Expected: PASS (6 тестов).

- [ ] **Step 5: Коммит**

```bash
git add Sources/QuickLookersSettingsKit/InterceptionStatus.swift Tests/QuickLookersSettingsKitTests/InterceptionStatusTests.swift
git commit -m "feat(settings): ядро классификатора перехвата (чистая функция)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: `SettingsModel` — правила, поиск, CRUD, дефолт, статус перехвата

Здесь App-таргет снова начинает компилироваться. Убираем старое тяжёлое
`previewRules`-вычисляемое и его API, добавляем новое. Правим `SettingsModelTests`.

**Files:**
- Create: `App/InterceptionDeclarations.swift` (чтение набора перехвата из бандла + мост к UTType)
- Modify: `App/SettingsModel.swift` (убрать `PreviewRuleRow`/`previewRules`/`isRuleOn`/`setRuleOn`/`setRuleLanguage`/`addExtensionRule`; добавить новое API)
- Modify: `Tests/AppTests/SettingsModelTests.swift` (заменить три теста старого API)

**Interfaces:**
- Consumes: `PreviewRule`, `RuleAction`, `DatasetMatch`, `searchDataset`, `GlobMatcher`,
  `InterceptionStatus`, `SystemTypeInfo`, `DeclaredInterceptSet`, `interceptionStatus(...)`, `resolvePreview`.
- Produces (на `SettingsModel`):
  - `var userRules: [PreviewRule]`
  - `enum PatternDefault: Equatable { case language(String); case neutral; case indeterminate }`
  - `struct RuleSearchResults { let mine: [PreviewRule]; let defaults: [DatasetMatch] }`
  - `func searchRules(query: String, limit: Int) -> RuleSearchResults`
  - `func addRule(pattern: String, action: RuleAction)`
  - `func updateRule(_ rule: PreviewRule)`
  - `func deleteRule(_ rule: PreviewRule)`
  - `func toggleRule(_ rule: PreviewRule, on: Bool)`
  - `func draftOverride(for match: DatasetMatch) -> PreviewRule`
  - `func currentDefault(forPattern pattern: String) -> PatternDefault`
  - `func languageDisplayName(_ id: String) -> String`
  - `func interceptionStatus(forPattern pattern: String) -> InterceptionStatus?`

- [ ] **Step 1: Написать `InterceptionDeclarations` (мост к бандлу и UTType)**

```swift
// App/InterceptionDeclarations.swift
import Foundation
import UniformTypeIdentifiers
import QuickLookersSettingsKit

/// Мост между чистым классификатором перехвата и реальным бандлом/системой.
enum InterceptionDeclarations {
    /// Набор перехвата из Info.plist хоста (экспортные расширения) и расширения
    /// Preview (системные UTI). При недоступности части — деградируем к пустому.
    static func load() -> DeclaredInterceptSet {
        DeclaredInterceptSet(
            exportedExtensions: exportedExtensions(),
            systemUTIs: systemUTIs(),
            hasPlainTextDragnet: systemUTIs().contains("public.plain-text"))
    }

    /// UTType-вердикт системы по расширению.
    static func systemType(forExtension ext: String) -> SystemTypeInfo? {
        guard let t = UTType(filenameExtension: ext) else { return nil }
        return SystemTypeInfo(identifier: t.identifier, isDynamic: t.isDynamic,
                              conformsToPlainText: t.conforms(to: .plainText),
                              localizedName: t.localizedDescription)
    }

    // MARK: - Private

    /// Расширения из UTExportedTypeDeclarations хоста (тип com.quicklookers.source-code).
    private static func exportedExtensions() -> Set<String> {
        guard let decls = Bundle.main.object(forInfoDictionaryKey: "UTExportedTypeDeclarations") as? [[String: Any]]
        else { return [] }
        var out: Set<String> = []
        for decl in decls {
            guard let tags = decl["UTTypeTagSpecification"] as? [String: Any],
                  let exts = tags["public.filename-extension"] as? [String] else { continue }
            for e in exts { out.insert(e.lowercased()) }
        }
        return out
    }

    /// QLSupportedContentTypes из Info.plist расширения Preview (в PlugIns).
    private static func systemUTIs() -> Set<String> {
        guard let plugins = Bundle.main.builtInPlugInsURL,
              let items = try? FileManager.default.contentsOfDirectory(
                  at: plugins, includingPropertiesForKeys: nil)
        else { return [] }
        for appex in items where appex.pathExtension == "appex" {
            let plist = appex.appendingPathComponent("Contents/Info.plist")
            guard let dict = NSDictionary(contentsOf: plist),
                  let ext = dict["NSExtension"] as? [String: Any],
                  let attrs = ext["NSExtensionAttributes"] as? [String: Any],
                  let types = attrs["QLSupportedContentTypes"] as? [String] else { continue }
            return Set(types)
        }
        return []
    }
}
```

- [ ] **Step 2: Обновить `SettingsModelTests` (заменить три теста старого API)**

Заменить `testRuleToggleWritesDisabledExtension`, `testSetRuleLanguageWritesOverride`,
`testAddExtensionRule` (строки 44–69) на:

```swift
    func test_addRule_appendsEnabledRule() throws {
        let model = SettingsModel(containerURL: try makeTempContainer())
        model.addRule(pattern: "*.djhtml", action: .assign(languageId: "python"))
        let rule = try XCTUnwrap(model.userRules.first { $0.pattern == "*.djhtml" })
        XCTAssertEqual(rule.action, .assign(languageId: "python"))
        XCTAssertTrue(rule.isEnabled)
    }

    func test_addRule_samePattern_updatesInsteadOfDuplicating() throws {
        let model = SettingsModel(containerURL: try makeTempContainer())
        model.addRule(pattern: "*.log", action: .assign(languageId: "python"))
        model.addRule(pattern: "*.log", action: .neutral)
        XCTAssertEqual(model.userRules.filter { $0.pattern == "*.log" }.count, 1)
        XCTAssertEqual(model.userRules.first { $0.pattern == "*.log" }?.action, .neutral)
    }

    func test_toggleRule_off_persists() throws {
        let model = SettingsModel(containerURL: try makeTempContainer())
        model.addRule(pattern: "*.swift", action: .assign(languageId: "javascript"))
        let rule = try XCTUnwrap(model.userRules.first)
        model.toggleRule(rule, on: false)
        XCTAssertFalse(try XCTUnwrap(model.userRules.first).isEnabled)
    }

    func test_deleteRule_removesIt() throws {
        let model = SettingsModel(containerURL: try makeTempContainer())
        model.addRule(pattern: "*.swift", action: .neutral)
        let rule = try XCTUnwrap(model.userRules.first)
        model.deleteRule(rule)
        XCTAssertTrue(model.userRules.isEmpty)
    }

    func test_searchRules_returnsDatasetDefaultsCapped() throws {
        let model = SettingsModel(containerURL: try makeTempContainer())
        let results = model.searchRules(query: "json", limit: 5)
        XCTAssertLessThanOrEqual(results.defaults.count, 5)
        XCTAssertTrue(results.defaults.contains { $0.key == .ext("json") })
    }

    func test_currentDefault_knownExtension_reportsLanguage() throws {
        let model = SettingsModel(containerURL: try makeTempContainer())
        // .json есть в боевом датасете.
        if case .language(let id) = model.currentDefault(forPattern: "*.json") {
            XCTAssertEqual(id, "json")
        } else {
            XCTFail("ожидался .language для *.json")
        }
    }
```

- [ ] **Step 3: Запустить сборку App-таргета — убедиться, что падает**

Run: `xcodegen generate && xcodebuild -project QuickLookers.xcodeproj -scheme QuickLookers -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -25`
Expected: FAIL — `FileTypesTab`/`SettingsModel` ссылаются на убранные поля/несуществующее API.

- [ ] **Step 4: Переписать `SettingsModel` (убрать старое, добавить новое)**

В `App/SettingsModel.swift` удалить: `struct PreviewRuleRow` (строки 11–18),
вычисляемое `previewRules` (32–51), методы `isRuleOn`/`setRuleOn`/`setRuleLanguage`/`addExtensionRule` (146–176).
Добавить вместо них (импорты `QuickLookersSettingsKit` уже есть):

```swift
    // MARK: - Правила просмотра (Слой 2)

    var userRules: [PreviewRule] { settings.previewRules }

    /// Во что шаблон разрешается сейчас в датасете (без учёта самого правила).
    enum PatternDefault: Equatable { case language(String); case neutral; case indeterminate }

    struct RuleSearchResults { let mine: [PreviewRule]; let defaults: [DatasetMatch] }

    func languageDisplayName(_ id: String) -> String {
        catalog.languages.first { $0.id == id }?.displayName ?? id
    }

    /// Поиск: свои правила (по шаблону/языку) + совпадения датасета (капнутые).
    /// Пустой запрос → только свои правила, датасет пуст.
    func searchRules(query: String, limit: Int) -> RuleSearchResults {
        let q = query.lowercased()
        let mine = q.isEmpty ? userRules : userRules.filter { rule in
            rule.pattern.lowercased().contains(q)
                || ruleLanguageName(rule).lowercased().contains(q)
        }
        let defaults = searchDataset(query: query, limit: limit, associations: associations,
                                     languageName: { [weak self] in self?.languageDisplayName($0) })
        return RuleSearchResults(mine: mine, defaults: defaults)
    }

    private func ruleLanguageName(_ rule: PreviewRule) -> String {
        switch rule.action {
        case .assign(let id): return languageDisplayName(id)
        case .neutral:        return "не подсвечивать"
        }
    }

    /// Добавить правило; шаблон-дубль обновляет существующее, а не плодит второе.
    func addRule(pattern: String, action: RuleAction) {
        let p = pattern.trimmingCharacters(in: .whitespaces)
        guard !p.isEmpty else { return }
        update { s in
            if let i = s.previewRules.firstIndex(where: { $0.pattern == p }) {
                s.previewRules[i].action = action
                s.previewRules[i].isEnabled = true
            } else {
                s.previewRules.append(PreviewRule(pattern: p, action: action))
            }
        }
    }

    func updateRule(_ rule: PreviewRule) {
        update { s in
            if let i = s.previewRules.firstIndex(where: { $0.id == rule.id }) { s.previewRules[i] = rule }
        }
    }

    func deleteRule(_ rule: PreviewRule) {
        update { s in s.previewRules.removeAll { $0.id == rule.id } }
    }

    func toggleRule(_ rule: PreviewRule, on: Bool) {
        update { s in
            if let i = s.previewRules.firstIndex(where: { $0.id == rule.id }) { s.previewRules[i].isEnabled = on }
        }
    }

    /// Черновик правила-перекрытия для дефолтного совпадения (для листа правки).
    func draftOverride(for match: DatasetMatch) -> PreviewRule {
        let pattern: String
        switch match.key {
        case .ext(let e):      pattern = "*.\(e)"
        case .filename(let f): pattern = f
        }
        return PreviewRule(pattern: pattern, action: .assign(languageId: match.languageId))
    }

    /// Что шаблон значит сейчас по датасету — для строки «Сейчас так».
    func currentDefault(forPattern pattern: String) -> PatternDefault {
        let m = GlobMatcher(pattern)
        if let name = m.exactFilename, let lang = associations.byFilename[name] { return .language(lang) }
        if let ext = m.fastExtension, let lang = associations.byExtension[ext] { return .language(lang) }
        if m.exactFilename != nil || m.fastExtension != nil { return .neutral }
        return .indeterminate
    }

    /// Статус перехвата для шаблона; nil если расширение неопределимо (строку прячем).
    func interceptionStatus(forPattern pattern: String) -> InterceptionStatus? {
        guard let ext = GlobMatcher(pattern).probeExtension else { return nil }
        return QuickLookersSettingsKit.interceptionStatus(
            forExtension: ext,
            systemType: InterceptionDeclarations.systemType(forExtension: ext),
            declared: Self.declaredInterceptSet)
    }

    /// Набор перехвата читаем один раз (не меняется в рантайме).
    private static let declaredInterceptSet: DeclaredInterceptSet = InterceptionDeclarations.load()
```

- [ ] **Step 5: Собрать App-таргет — компиляция проходит (FileTypesTab ещё старый — временно закомментировать использование)**

Примечание: `FileTypesTab` пока ссылается на убранное API и не скомпилируется.
Чтобы Задача 6 имела самостоятельный зелёный тест, временно замените тело
`App/FileTypesTab.swift` на заглушку (полноценно перепишем в Задаче 7):

```swift
// App/FileTypesTab.swift
import SwiftUI

struct FileTypesTab: View {
    @ObservedObject var model: SettingsModel
    var body: some View { Text("…").frame(maxWidth: .infinity, maxHeight: .infinity) }
}
```

- [ ] **Step 6: Запустить тесты App-таргета — зелёные**

Run: `xcodebuild -project QuickLookers.xcodeproj -scheme QuickLookers -destination 'platform=macOS' test 2>&1 | tail -30`
Expected: PASS для `SettingsModelTests` (новые тесты правил/поиска/дефолта).
Если локальная среда требует подписи для `test` — как фоллбэк собрать
`... CODE_SIGNING_ALLOWED=NO build` (проверка компиляции) и прогнать App-тесты
позже через ⌘U на живом этапе.

- [ ] **Step 7: Коммит**

```bash
git add App/InterceptionDeclarations.swift App/SettingsModel.swift App/FileTypesTab.swift Tests/AppTests/SettingsModelTests.swift
git commit -m "refactor(app): SettingsModel на previewRules — CRUD, поиск, дефолт, статус перехвата

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 7: Вкладка `FileTypesTab` + лист `AddRuleSheet`

UI-задача: пишем экран целиком. Юнит-тестами SwiftUI не покрываем — проверка
компиляцией (`xcodebuild build`) и живьём (⌘R). Копирайт — по-русски, от лица
пользователя.

**Files:**
- Create: `App/AddRuleSheet.swift`
- Modify: `App/FileTypesTab.swift` (полная реализация вместо заглушки Задачи 6)

**Interfaces:**
- Consumes: `SettingsModel` (Task 6: `userRules`, `searchRules`, `addRule`, `updateRule`,
  `deleteRule`, `toggleRule`, `draftOverride`, `currentDefault`, `languageDisplayName`,
  `interceptionStatus`, `catalog`), `PreviewRule`/`RuleAction`, `DatasetMatch`,
  `PatternDefault`, `InterceptionStatus`.

- [ ] **Step 1: Написать `AddRuleSheet`**

```swift
// App/AddRuleSheet.swift
import SwiftUI
import QuickLookersSettingsKit

/// Лист добавления/правки правила просмотра: шаблон, справка о дефолте, статус
/// перехвата, выбор «язык / не подсвечивать» и поиск-выбор языка по живому каталогу.
struct AddRuleSheet: View {
    @ObservedObject var model: SettingsModel
    /// Правило для правки (черновик или существующее). id сохраняется при обновлении.
    @State var draft: PreviewRule
    let onSave: (PreviewRule) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var highlight: Bool
    @State private var languageId: String
    @State private var languageQuery = ""

    init(model: SettingsModel, draft: PreviewRule, onSave: @escaping (PreviewRule) -> Void) {
        self.model = model
        self._draft = State(initialValue: draft)
        self.onSave = onSave
        if case .assign(let id) = draft.action {
            self._highlight = State(initialValue: true)
            self._languageId = State(initialValue: id)
        } else {
            self._highlight = State(initialValue: false)
            self._languageId = State(initialValue: "")
        }
    }

    private var languages: [(id: String, name: String)] {
        let all = model.catalog.languages
            .map { (id: $0.id, name: $0.displayName) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        guard !languageQuery.isEmpty else { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(languageQuery)
            || $0.id.localizedCaseInsensitiveContains(languageQuery) }
    }

    private var canSave: Bool {
        !draft.pattern.trimmingCharacters(in: .whitespaces).isEmpty && (!highlight || !languageId.isEmpty)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Правило просмотра").font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                TextField("Шаблон, например *.djhtml или Dockerfile.*", text: $draft.pattern)
                    .textFieldStyle(.roundedBorder)
                Text(defaultHint).font(.caption).foregroundStyle(.secondary)
                if let status = statusHint {
                    Label(status.text, systemImage: status.icon)
                        .font(.caption).foregroundStyle(status.color)
                }
            }

            Picker("", selection: $highlight) {
                Text("Красить языком").tag(true)
                Text("Не подсвечивать").tag(false)
            }
            .pickerStyle(.segmented).labelsHidden()

            if highlight {
                VStack(spacing: 4) {
                    TextField("Найти язык…", text: $languageQuery)
                        .textFieldStyle(.roundedBorder)
                    List(languages, id: \.id, selection: Binding(
                        get: { languageId },
                        set: { languageId = $0 ?? "" })) { lang in
                        Text(lang.name).tag(lang.id)
                    }
                    .frame(height: 160)
                }
            }

            HStack {
                Spacer()
                Button("Отмена", role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Сохранить") {
                    draft.action = highlight ? .assign(languageId: languageId) : .neutral
                    onSave(draft)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
        }
        .padding(20)
        .frame(width: 420)
    }

    private var defaultHint: String {
        switch model.currentDefault(forPattern: draft.pattern) {
        case .language(let id): return "Сейчас так: \(model.languageDisplayName(id))"
        case .neutral:          return "Сейчас так: нейтрально (правила нет)"
        case .indeterminate:    return " "
        }
    }

    private var statusHint: (text: String, icon: String, color: Color)? {
        guard let status = model.interceptionStatus(forPattern: draft.pattern) else { return nil }
        switch status {
        case .intercepted:
            return ("Такие файлы мы перехватим.", "checkmark.circle", .secondary)
        case .systemNonCode(let name):
            return ("Система считает это «\(name)» — перехватить нельзя, правило не сработает.",
                    "exclamationmark.triangle", .orange)
        case .unknownNotDeclared:
            return ("Это расширение приложение пока не перехватывает — правило не сработает.",
                    "exclamationmark.triangle", .orange)
        }
    }
}
```

- [ ] **Step 2: Написать `FileTypesTab` (полная реализация)**

```swift
// App/FileTypesTab.swift
import SwiftUI
import QuickLookersSettingsKit

/// Слой 2 — управление правилами «маска файла → подсветка».
/// По умолчанию видны только правила пользователя; датасет — под поиск, с потолком.
struct FileTypesTab: View {
    @ObservedObject var model: SettingsModel
    @State private var query = ""
    @State private var editing: PreviewRule?
    @State private var addingNew = false

    private let datasetLimit = 50

    private var results: SettingsModel.RuleSearchResults {
        model.searchRules(query: query, limit: datasetLimit)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Найти расширение, имя файла или язык…", text: $query)
                    .textFieldStyle(.plain)
                if !query.isEmpty {
                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.borderless).foregroundStyle(.secondary)
                }
            }
            .padding(8)

            List {
                if model.userRules.isEmpty && query.isEmpty {
                    emptyState
                } else {
                    mineSection
                    if !query.isEmpty { defaultsSection }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Spacer()
                Button {
                    editing = PreviewRule(pattern: "", action: .assign(languageId: ""))
                    addingNew = true
                } label: { Label("Добавить правило", systemImage: "plus") }
                .padding(8)
            }
            .background(.bar)
        }
        .sheet(item: $editing) { rule in
            AddRuleSheet(model: model, draft: rule) { saved in
                if addingNew { model.addRule(pattern: saved.pattern, action: saved.action) }
                else { model.updateRule(saved) }
                addingNew = false
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Своих правил пока нет.").font(.headline)
            Text("Сотни форматов подсвечиваются по умолчанию. Начните вводить в поиск, "
               + "чтобы найти формат и изменить его, — или добавьте своё правило.")
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }

    private var mineSection: some View {
        Section("Мои правила") {
            ForEach(results.mine) { rule in
                HStack {
                    Text(rule.pattern).frame(width: 160, alignment: .leading)
                    Image(systemName: "arrow.right").foregroundStyle(.tertiary)
                    Text(ruleTarget(rule)).foregroundStyle(.secondary)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { rule.isEnabled },
                        set: { model.toggleRule(rule, on: $0) }))
                        .labelsHidden().toggleStyle(.switch).controlSize(.mini)
                }
                .contextMenu {
                    Button("Изменить") { editing = rule; addingNew = false }
                    Button("Удалить", role: .destructive) { model.deleteRule(rule) }
                }
            }
        }
    }

    private var defaultsSection: some View {
        Section("По умолчанию (показаны первые \(datasetLimit))") {
            ForEach(results.defaults) { match in
                HStack {
                    Text(matchLabel(match)).frame(width: 160, alignment: .leading)
                    Image(systemName: "arrow.right").foregroundStyle(.tertiary)
                    Text(model.languageDisplayName(match.languageId)).foregroundStyle(.secondary)
                    Spacer()
                    Button("Изменить") { editing = model.draftOverride(for: match); addingNew = true }
                        .buttonStyle(.borderless)
                }
            }
        }
    }

    private func ruleTarget(_ rule: PreviewRule) -> String {
        switch rule.action {
        case .assign(let id): return model.languageDisplayName(id)
        case .neutral:        return "не подсвечивать"
        }
    }

    private func matchLabel(_ match: DatasetMatch) -> String {
        switch match.key {
        case .ext(let e):      return ".\(e)"
        case .filename(let f): return f
        }
    }
}
```

- [ ] **Step 3: Собрать App-таргет — компиляция проходит**

Run: `xcodegen generate && xcodebuild -project QuickLookers.xcodeproj -scheme QuickLookers -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -25`
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Коммит**

```bash
git add App/AddRuleSheet.swift App/FileTypesTab.swift
git commit -m "feat(app): новая вкладка просмотра — правила, поиск датасета, лист добавления

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 8: Документация, полная проверка, /simplify

**Files:**
- Modify: `CLAUDE.md` (структура: новые файлы SettingsKit/App, схема настроек v3, суть фазы)

**Interfaces:** —

- [ ] **Step 1: Обновить `CLAUDE.md`**

В разделе «Структура» добавить строки для новых файлов:
- `Sources/QuickLookersSettingsKit/PreviewRule.swift` — модель правила (шаблон/действие/включено).
- `Sources/QuickLookersSettingsKit/GlobMatcher.swift` — glob-сопоставление имени файла (`*`, `?`).
- `Sources/QuickLookersSettingsKit/DatasetSearch.swift` — поиск по датасету с потолком.
- `Sources/QuickLookersSettingsKit/InterceptionStatus.swift` — чистый классификатор перехвата.
- `App/AddRuleSheet.swift` — лист добавления/правки правила.
- `App/InterceptionDeclarations.swift` — чтение набора перехвата из бандла + мост к UTType.

В описании `ManagerSettings.swift` заменить перечисление полей Слоя 2 на: «схема **v3**:
единый `previewRules: [PreviewRule]` (glob-маски) вместо четырёх структур overrides/disabled».
В описании `FileTypesTab.swift` — «управление правилами маска→подсветка; по умолчанию только
правила пользователя, датасет под поиск с потолком».
Добавить в «Текущее состояние» краткий пункт про пересбор вкладки (маски + починка памяти + статус перехвата).

- [ ] **Step 2: Коммит документации**

```bash
git add CLAUDE.md
git commit -m "docs: структура и состояние после пересбора вкладки сопоставлений

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

- [ ] **Step 3: Полный прогон тестов пакета**

Run: `swift test 2>&1 | tail -15`
Expected: PASS (все домены SettingsKit/PreviewKit/… зелёные).

- [ ] **Step 4: Сборка App-таргета**

Run: `xcodegen generate && xcodebuild -project QuickLookers.xcodeproj -scheme QuickLookers -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -15`
Expected: BUILD SUCCEEDED.

- [ ] **Step 5: /simplify**

Запустить `/simplify` по изменённому коду (вычистить дубли/лишнее), применить правки,
перепрогнать затронутые тесты, закоммитить при наличии изменений.

- [ ] **Step 6: Живой этап (пользователь)**

Отдать пользователю на живую проверку (⌘R):
- вкладка «Просмотр в Finder»: пусто → подсказка; прокрутка/поиск **не** уводят в «ожидание ответа»;
- добавить `*.djhtml` → Django-грамматика (сторонняя), проверить строку статуса перехвата
  (ожидается ⚠️ «пока не перехватывает», т.к. `djhtml` нет в испечённом списке — решить,
  добавлять ли расширение в Слой A);
- App-тесты ⌘U зелёные.

---

## Самопроверка плана

**Покрытие спеки:**
- Модель единым списком правил → Task 2, 3. ✓
- glob-маски (`*`, `?`), быстрый путь `*.ext`, специфичность → Task 1, 3. ✓
- Вкладка «только мои правки» + поиск-с-потолком (починка памяти) → Task 4, 6, 7. ✓
- Лист добавления: справка о дефолте + статус перехвата → Task 5, 6, 7. ✓
- Живой каталог языков в выборе → Task 7 (`model.catalog.languages`). ✓
- Схема v3 без миграции (сброс `< 3`) → Task 3 (`currentSchemaVersion = 3`) + существующий `SettingsStore.load`. ✓
- Точка входа `resolvePreview` неизменна, расширение не трогаем → Task 3. ✓
- Тесты слоями → Tasks 1,2,3,4,5 (unit SettingsKit), 6 (App). ✓
- Стена перехвата честно показана → Task 5 (классификатор) + Task 7 (строки статуса). ✓

**Согласованность имён:** `previewRules`, `PreviewRule`, `RuleAction.assign/.neutral`,
`GlobMatcher(_:).matches/specificity/fastExtension/exactFilename/probeExtension`,
`searchDataset(query:limit:associations:languageName:)`, `DatasetMatch.Key.ext/.filename`,
`interceptionStatus(forExtension:systemType:declared:)`, `SettingsModel.searchRules/addRule/
updateRule/deleteRule/toggleRule/draftOverride/currentDefault/languageDisplayName/
interceptionStatus(forPattern:)` — использованы одинаково во всех задачах. ✓

**Плейсхолдеры:** нет TBD/«добавить обработку ошибок»; весь код и тесты приведены. ✓
