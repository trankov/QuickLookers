# План: сопоставление файлов с подсветкой (UTI ↔ язык)

> **Для агентов-исполнителей:** ОБЯЗАТЕЛЬНЫЙ САБ-СКИЛЛ — `superpowers:subagent-driven-development` (рекомендуется) либо `superpowers:executing-plans`, задача за задачей. Шаги отмечаются чекбоксами (`- [ ]`).

**Цель:** сделать так, чтобы подсветка работала для сотен форматов, а не для 23 — за счёт data-driven таблицы «расширение/имя файла → язык» из github-linguist и невода `public.plain-text`, с пользовательской настройкой правил и нейтральным текстом для выключенного/неизвестного.

**Архитектура:** два независимых слоя. Слой A (маршрутизация) — статичный список **точных листовых UTI** в `Info.plist` расширения; ключевое добавление — `public.plain-text` как «сборщик хвоста». Слой B (назначение языка) — рантайм-таблица `associations.json` (сгенерирована из linguist на сборке), поверх неё пользовательские правила из `settings.json`; выключенный/неизвестный формат рисуется нейтральным моноширинным текстом.

**Tech Stack:** Swift 6 / SwiftPM (macOS 13+), XcodeGen, Node (шаг сборки JS: shiki + js-yaml + esbuild), XCTest (TDD).

## Global Constraints

- Отвечать пользователю по-русски, простым человеческим языком.
- Строгий TDD: падающий тест → прогон (упал) → минимальная реализация → прогон (зелёный) → коммит. По одному маленькому шагу.
- Ставить **таймаут** на прогон тестов (виснут на краевых случаях). Прогонять **по доменам**, полный набор — только в конце.
- Коммиты по-русски, формат `feat(...)` / `test(...)` / `docs:` / `refactor:`. Трейлер: `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.
- Работа в ветке `feat/file-type-mapping` (уже создана), не в `main`.
- **Артефакты XcodeGen** (`.xcodeproj`, `*.entitlements`, `Info.plist` расширения) — генерируются из `project.yml`, руками не править; правится `project.yml` + `xcodegen generate`.
- **Сгенерированные ресурсы** (`shiki-bundle.js`, `catalog.json`, `associations.json`) — артефакты сборки в `Sources/QuickLookersEngine/Resources/`, руками не править; правится источник в `js/` и пересобирается.
- Markdown и csv — **вне продукта**, их UTI не объявляем (защищены правилом точного листового UTI).
- SettingsKit **не зависит** от движка: типы Слоя B живут в SettingsKit и получают URL ресурса от вызывающей стороны (`QuickLookersEngineResources`), а не тянут `Bundle.module` движка.
- Схему настроек меняем **без миграции** (пользователей ещё нет) — бампаем `currentSchemaVersion`.

## Установленный факт (не переоткрывать)

`QLSupportedContentTypes` ловит по **точному листовому UTI**, конформанс вверх по дереву не работает (спайк 2026-07-02, macOS 26). Обратная сторона правила — **защита**: `.csv` имеет собственный листовой UTI `public.comma-separated-values-text`, `.md` — `net.daringfireball.markdown`; объявив `public.plain-text`, мы их **не** перехватываем. Невод `public.plain-text` ловит только файлы, чей листовой тип — ровно `public.plain-text` (generic-текст, `.txt`, неизвестные расширения и, предположительно, безрасширенный `Dockerfile` — см. Задачу 8).

## Структура файлов

**Создаются:**
- `js/vendor/linguist-languages.yml` — вендоренный снимок github-linguist (источник расширений/имён).
- `js/associations-overrides.json` — ручной словарь: авторитетное разрешение конфликтов и Shiki-специфичные id.
- `js/generate-associations.mjs` — генератор `associations.json` (linguist ∪ fileTypes грамматик ∪ overrides, конфликт-фри).
- `js/test/associations.smoke.mjs` — node-смоук инвариантов датасета.
- `Sources/QuickLookersEngine/Resources/associations.json` — **артефакт** генератора.
- `Sources/QuickLookersSettingsKit/FileTypeAssociations.swift` — модель таблицы (DTO + обратные карты).
- `Sources/QuickLookersSettingsKit/PreviewResolution.swift` — `resolvePreview(...)` + enum `PreviewResolution`.
- `Sources/QuickLookersPreviewKit/NeutralPage.swift` — `neutralPageHTML(...)` + `htmlEscaped`.
- `Tests/QuickLookersSettingsKitTests/FileTypeAssociationsTests.swift`
- `Tests/QuickLookersPreviewKitTests/NeutralPageTests.swift`

**Изменяются:**
- `Sources/QuickLookersEngine/EngineResources.swift` — `associationsURL()`.
- `Sources/QuickLookersSettingsKit/ManagerSettings.swift` — схема v2: правила и опт-аут по правилу вместо `previewDisabledLanguageIds`.
- `PreviewExtension/PreviewViewController.swift` — тёплые associations, ветка нейтрального показа.
- `App/SettingsModel.swift` — строки правил из associations, методы правки правил.
- `App/FileTypesTab.swift` — таблица правил: поиск, язык, тумблер, добавление.
- `project.yml` — `QLSupportedContentTypes` + `public.plain-text`.
- `js/package.json` — devDependency `js-yaml`.
- `Tests/QuickLookersSettingsKitTests/ResolutionTests.swift`, `ManagerSettingsTests.swift` — под новую модель.
- `docs/superpowers/notes/2026-06-28-intercept-spikes.md`, `CLAUDE.md`.

**Удаляется:**
- `Sources/QuickLookersSettingsKit/DeclaredTypes.swift` — заменяется `FileTypeAssociations.swift` + `PreviewResolution.swift`.

---

## Задача 1: Генератор датасета `associations.json` (js)

**Files:**
- Create: `js/vendor/linguist-languages.yml`
- Create: `js/associations-overrides.json`
- Create: `js/generate-associations.mjs`
- Create: `js/test/associations.smoke.mjs`
- Create: `Sources/QuickLookersEngine/Resources/associations.json` (артефакт)
- Modify: `js/package.json`

**Interfaces:**
- Produces: ресурс `associations.json` формы
  `{ "version": 1, "languages": [ { "id": String, "extensions": [String], "filenames": [String] } ] }`,
  где каждый `extensions[i]` — расширение в нижнем регистре без точки, а каждое расширение/имя принадлежит **ровно одному** языку (конфликт-фри). `id` ∈ множеству id грамматик Shiki.

- [ ] **Шаг 1: Вендорим linguist**

Скачать снимок `languages.yml` и положить в `js/vendor/`. Пин на конкретный коммит ради воспроизводимости:

```bash
mkdir -p js/vendor
curl -fsSL \
  https://raw.githubusercontent.com/github-linguist/linguist/v7.30.0/lib/linguist/languages.yml \
  -o js/vendor/linguist-languages.yml
head -5 js/vendor/linguist-languages.yml   # убедиться, что это YAML, а не HTML-ошибка
```

Если сеть недоступна в среде исполнения — вендорится вручную из релиза linguist v7.30.0 (файл `lib/linguist/languages.yml`). Это одноразовый офлайн-снимок.

- [ ] **Шаг 2: Ручной словарь разрешения конфликтов**

Create `js/associations-overrides.json` — авторитетный слой (применяется последним). `languageAlias` чинит сопоставление имени linguist к id Shiki; `extensions`/`filenames` жёстко назначают владельца:

```json
{
  "languageAlias": {
    "C++": "cpp",
    "C#": "csharp",
    "F#": "fsharp",
    "Objective-C": "objective-c",
    "Dockerfile": "docker"
  },
  "extensions": {
    "h": "c",
    "hpp": "cpp",
    "hh": "cpp",
    "cc": "cpp",
    "cxx": "cpp",
    "cjs": "javascript",
    "mjs": "javascript",
    "ts": "typescript",
    "tsx": "tsx",
    "jsx": "jsx"
  },
  "filenames": {
    "Dockerfile": "docker",
    "Makefile": "make",
    "makefile": "make",
    "Gemfile": "ruby",
    "Rakefile": "ruby",
    "CMakeLists.txt": "cmake"
  }
}
```

- [ ] **Шаг 3: Добавляем зависимость js-yaml**

Modify `js/package.json` — в `devDependencies` добавить `"js-yaml": "^4.1.0"`, затем:

```bash
cd js && npm install
```

- [ ] **Шаг 4: Пишем генератор**

Create `js/generate-associations.mjs`:

```js
// Генерирует associations.json: {version, languages:[{id, extensions[], filenames[]}]}.
// Источники: github-linguist languages.yml (вендорен) ∪ fileTypes грамматик Shiki ∪
// associations-overrides.json (авторитетно). Владение расширением/именем разрешается
// в конфликт-фри: каждое расширение/имя принадлежит ровно одному языку Shiki.
// Запуск: cd js && node generate-associations.mjs
import { readFileSync, writeFileSync } from 'fs'
import yaml from 'js-yaml'
import { bundledLanguagesInfo } from 'shiki'

const norm = (s) => String(s).toLowerCase().replace(/[^a-z0-9]/g, '')
const shiki = bundledLanguagesInfo
const shikiIds = new Set(shiki.map((l) => l.id))

// 1) индекс «нормализованное имя/алиас → shikiId»
const nameToShiki = new Map()
for (const l of shiki) {
  for (const key of [l.id, l.name, ...(l.aliases ?? [])]) {
    if (key) nameToShiki.set(norm(key), l.id)
  }
}
const overrides = JSON.parse(readFileSync('./associations-overrides.json', 'utf8'))
for (const [name, id] of Object.entries(overrides.languageAlias ?? {})) nameToShiki.set(norm(name), id)

// 2) кандидаты владельцев по ext/filename
const extCandidates = new Map()
const fileCandidates = new Map()
const addCand = (map, key, id) => {
  if (!map.has(key)) map.set(key, new Set())
  map.get(key).add(id)
}

// 2a) linguist
const linguist = yaml.load(readFileSync('./vendor/linguist-languages.yml', 'utf8'))
for (const [langName, def] of Object.entries(linguist)) {
  const id = nameToShiki.get(norm(langName))
    ?? (def.aliases ?? []).map((a) => nameToShiki.get(norm(a))).find(Boolean)
  if (!id) continue
  for (const ext of def.extensions ?? []) addCand(extCandidates, ext.replace(/^\./, '').toLowerCase(), id)
  for (const fn of def.filenames ?? []) addCand(fileCandidates, fn, id)
}

// 2b) fileTypes самих грамматик Shiki (дополнение + сигнал для тай-брейка)
const shikiClaims = new Set()
for (const id of shikiIds) {
  const mod = await import(`@shikijs/langs/${id}`)
  const arr = Array.isArray(mod.default) ? mod.default : [mod.default]
  const main = arr.find((g) => g.name === id) ?? arr[0]
  for (const ext of main?.fileTypes ?? []) {
    const e = String(ext).replace(/^\./, '').toLowerCase()
    addCand(extCandidates, e, id)
    shikiClaims.add(`${id} ${e}`)
  }
}

// 3) разрешение владения (конфликт-фри). overrides авторитетно; иначе — собственный
// claim грамматики Shiki; иначе — алфавит. Все конфликты логируем (не молчим).
const conflicts = []
const extOwner = new Map()
for (const [ext, cands] of extCandidates) {
  let id
  if (overrides.extensions?.[ext]) {
    id = overrides.extensions[ext]
  } else {
    const list = [...cands]
    if (list.length === 1) { id = list[0] }
    else {
      const owned = list.filter((x) => shikiClaims.has(`${x} ${ext}`))
      id = (owned.length ? owned : list).sort()[0]
      conflicts.push(`ext .${ext}: ${list.sort().join(',')} → ${id}`)
    }
  }
  if (shikiIds.has(id)) extOwner.set(ext, id)
}
const fileOwner = new Map()
for (const [fn, cands] of fileCandidates) {
  let id = overrides.filenames?.[fn]
  if (!id) {
    const list = [...cands]
    id = list.sort()[0]
    if (list.length > 1) conflicts.push(`file ${fn}: ${list.sort().join(',')} → ${id}`)
  }
  if (shikiIds.has(id)) fileOwner.set(fn, id)
}
// overrides могут вводить ext/filename, которых не было в кандидатах
for (const [ext, id] of Object.entries(overrides.extensions ?? {})) if (shikiIds.has(id)) extOwner.set(ext, id)
for (const [fn, id] of Object.entries(overrides.filenames ?? {})) if (shikiIds.has(id)) fileOwner.set(fn, id)

// 4) инверсия в списки по языкам
const byLang = new Map()
const ensure = (id) => {
  if (!byLang.has(id)) byLang.set(id, { id, extensions: [], filenames: [] })
  return byLang.get(id)
}
for (const [ext, id] of extOwner) ensure(id).extensions.push(ext)
for (const [fn, id] of fileOwner) ensure(id).filenames.push(fn)
const languages = [...byLang.values()]
  .map((l) => ({ id: l.id, extensions: l.extensions.sort(), filenames: l.filenames.sort() }))
  .sort((a, b) => a.id.localeCompare(b.id))

writeFileSync('../Sources/QuickLookersEngine/Resources/associations.json',
  JSON.stringify({ version: 1, languages }))
console.log(`associations: languages=${languages.length} ext=${extOwner.size} file=${fileOwner.size} conflicts=${conflicts.length}`)
for (const c of conflicts) console.log('  conflict', c)
```

- [ ] **Шаг 5: Пишем node-смоук (сначала он падает — генератора ещё не гоняли)**

Create `js/test/associations.smoke.mjs`:

```js
import { readFileSync } from 'fs'
import assert from 'assert'
import { bundledLanguagesInfo } from 'shiki'

const data = JSON.parse(readFileSync('../Sources/QuickLookersEngine/Resources/associations.json', 'utf8'))
assert.equal(data.version, 1, 'version == 1')
assert.ok(Array.isArray(data.languages) && data.languages.length > 50, 'много языков')

const shikiIds = new Set(bundledLanguagesInfo.map((l) => l.id))
const extOwner = new Map()
for (const lang of data.languages) {
  assert.ok(shikiIds.has(lang.id), `id ∈ shiki: ${lang.id}`)
  for (const ext of lang.extensions) {
    assert.ok(!extOwner.has(ext), `расширение уникально: .${ext} у ${extOwner.get(ext)} и ${lang.id}`)
    extOwner.set(ext, lang.id)
  }
}
const fileOwner = new Map()
for (const lang of data.languages) for (const fn of lang.filenames) fileOwner.set(fn, lang.id)

assert.equal(extOwner.get('swift'), 'swift')
assert.equal(extOwner.get('py'), 'python')
assert.equal(extOwner.get('json'), 'json')
assert.equal(extOwner.get('yaml'), 'yaml')
assert.equal(extOwner.get('h'), 'c')          // разрешён override
assert.equal(fileOwner.get('Dockerfile'), 'docker')
console.log('associations smoke OK')
```

Run: `cd js && node test/associations.smoke.mjs`
Expected: FAIL — `ENOENT` (файла `associations.json` ещё нет) либо старый файл без нужных пар.

- [ ] **Шаг 6: Генерируем датасет и гоняем смоук (зелёный)**

```bash
cd js && node generate-associations.mjs && node test/associations.smoke.mjs
```
Expected: строка `associations: languages=… conflicts=…`, затем `associations smoke OK`.

- [ ] **Шаг 7: Коммит**

```bash
git add js/vendor js/associations-overrides.json js/generate-associations.mjs \
        js/test/associations.smoke.mjs js/package.json js/package-lock.json \
        Sources/QuickLookersEngine/Resources/associations.json
git commit -m "feat(engine): датасет associations.json (linguist → расширение/имя → язык)"
```

---

## Задача 2: Движок отдаёт URL датасета

**Files:**
- Modify: `Sources/QuickLookersEngine/EngineResources.swift`
- Test: `Tests/QuickLookersEngineTests/EngineResourcesTests.swift` (создать, если нет — иначе добавить метод)

**Interfaces:**
- Produces: `QuickLookersEngineResources.associationsURL() -> URL?` — URL бандл-ресурса `associations.json` (nil, если не собран).

- [ ] **Шаг 1: Падающий тест**

Create/append `Tests/QuickLookersEngineTests/EngineResourcesTests.swift`:

```swift
import XCTest
import Foundation
@testable import QuickLookersEngine

final class EngineResourcesTests: XCTestCase {
    func testAssociationsURLResolvesAndDecodes() throws {
        let url = try XCTUnwrap(QuickLookersEngineResources.associationsURL())
        let data = try Data(contentsOf: url)
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(obj?["version"] as? Int, 1)
        XCTAssertNotNil(obj?["languages"])
    }
}
```

- [ ] **Шаг 2: Прогон — падает**

Run: `swift test --filter EngineResourcesTests`
Expected: FAIL — нет метода `associationsURL`.

- [ ] **Шаг 3: Реализация**

В `EngineResources.swift` добавить в `enum QuickLookersEngineResources`:

```swift
    /// URL встроенного датасета соответствий «расширение/имя файла → язык».
    /// nil, если ресурс не собран (тогда потребитель работает с пустой таблицей).
    public static func associationsURL() -> URL? {
        Bundle.module.url(forResource: "associations", withExtension: "json")
    }
```

- [ ] **Шаг 4: Прогон — зелёный**

Run: `swift test --filter EngineResourcesTests`
Expected: PASS.

- [ ] **Шаг 5: Коммит**

```bash
git add Sources/QuickLookersEngine/EngineResources.swift Tests/QuickLookersEngineTests/EngineResourcesTests.swift
git commit -m "feat(engine): публичный associationsURL для датасета соответствий"
```

---

## Задача 3: Модель `FileTypeAssociations` (SettingsKit)

**Files:**
- Create: `Sources/QuickLookersSettingsKit/FileTypeAssociations.swift`
- Test: `Tests/QuickLookersSettingsKitTests/FileTypeAssociationsTests.swift`

**Interfaces:**
- Consumes: JSON формы `{version, languages:[{id, extensions[], filenames[]}]}`.
- Produces:
  - `struct FileTypeAssociations` с `byExtension: [String:String]`, `byFilename: [String:String]`.
  - `FileTypeAssociations.empty`
  - `init(contentsOf url: URL) throws`
  - `init(byExtension:byFilename:)`

- [ ] **Шаг 1: Падающий тест**

Create `Tests/QuickLookersSettingsKitTests/FileTypeAssociationsTests.swift`:

```swift
import XCTest
import Foundation
import QuickLookersSettingsKit

final class FileTypeAssociationsTests: XCTestCase {
    private func write(_ json: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".json")
        try Data(json.utf8).write(to: url)
        return url
    }

    func testDecodesReverseMaps() throws {
        let url = try write(#"""
        {"version":1,"languages":[
          {"id":"python","extensions":["py","pyi"],"filenames":[]},
          {"id":"docker","extensions":[],"filenames":["Dockerfile"]}
        ]}
        """#)
        let a = try FileTypeAssociations(contentsOf: url)
        XCTAssertEqual(a.byExtension["py"], "python")
        XCTAssertEqual(a.byExtension["pyi"], "python")
        XCTAssertEqual(a.byFilename["Dockerfile"], "docker")
        XCTAssertNil(a.byExtension["docx"])
    }

    func testExtensionsLowercased() throws {
        let url = try write(#"{"version":1,"languages":[{"id":"swift","extensions":["swift"],"filenames":[]}]}"#)
        let a = try FileTypeAssociations(contentsOf: url)
        XCTAssertEqual(a.byExtension["swift"], "swift")
    }

    func testEmpty() {
        XCTAssertTrue(FileTypeAssociations.empty.byExtension.isEmpty)
        XCTAssertTrue(FileTypeAssociations.empty.byFilename.isEmpty)
    }
}
```

- [ ] **Шаг 2: Прогон — падает**

Run: `swift test --filter FileTypeAssociationsTests`
Expected: FAIL — нет типа `FileTypeAssociations`.

- [ ] **Шаг 3: Реализация**

Create `Sources/QuickLookersSettingsKit/FileTypeAssociations.swift`:

```swift
import Foundation

/// Таблица соответствий «расширение/имя файла → язык подсветки».
/// Данные приходят из сгенерированного датасета движка (associations.json);
/// SettingsKit не зависит от движка — URL передаёт вызывающая сторона.
public struct FileTypeAssociations: Equatable {
    /// Ключ — расширение в нижнем регистре без точки. Значение — id языка Shiki.
    public let byExtension: [String: String]
    /// Ключ — точное имя файла (Dockerfile, Makefile). Значение — id языка Shiki.
    public let byFilename: [String: String]

    public init(byExtension: [String: String], byFilename: [String: String]) {
        self.byExtension = byExtension
        self.byFilename = byFilename
    }

    public static let empty = FileTypeAssociations(byExtension: [:], byFilename: [:])

    // DTO отделён от домена: во внешнем JSON — списки по языкам, внутри — обратные карты.
    private struct DTO: Decodable {
        struct Language: Decodable { let id: String; let extensions: [String]; let filenames: [String] }
        let version: Int
        let languages: [Language]
    }

    public init(contentsOf url: URL) throws {
        let dto = try JSONDecoder().decode(DTO.self, from: Data(contentsOf: url))
        var ext: [String: String] = [:]
        var file: [String: String] = [:]
        for lang in dto.languages {
            for e in lang.extensions { ext[e.lowercased()] = lang.id }
            for f in lang.filenames { file[f] = lang.id }
        }
        self.byExtension = ext
        self.byFilename = file
    }
}
```

- [ ] **Шаг 4: Прогон — зелёный**

Run: `swift test --filter FileTypeAssociationsTests`
Expected: PASS.

- [ ] **Шаг 5: Коммит**

```bash
git add Sources/QuickLookersSettingsKit/FileTypeAssociations.swift Tests/QuickLookersSettingsKitTests/FileTypeAssociationsTests.swift
git commit -m "feat(settings): модель FileTypeAssociations (расширение/имя → язык)"
```

---

## Задача 4: Схема настроек v2 — правила и опт-аут по правилу

**Files:**
- Modify: `Sources/QuickLookersSettingsKit/ManagerSettings.swift`
- Modify: `Tests/QuickLookersSettingsKitTests/ManagerSettingsTests.swift`

**Interfaces:**
- Produces (новые поля `ManagerSettings`):
  - `extensionOverrides: [String: String]` — ext(lower) → languageId (пользователь сменил/добавил).
  - `filenameOverrides: [String: String]` — filename → languageId.
  - `disabledExtensions: Set<String>` — ext(lower), убранные из просмотра.
  - `disabledFilenames: Set<String>` — имена файлов, убранные из просмотра.
  - `currentSchemaVersion = 2`.
- Удаляется: `previewDisabledLanguageIds`.
- Остаются без изменений: `disabledLanguageIds` (Слой 1), `activeThemeId`, `font`.

- [ ] **Шаг 1: Падающий тест**

В `Tests/QuickLookersSettingsKitTests/ManagerSettingsTests.swift` **удалить** любые обращения к `previewDisabledLanguageIds` и добавить:

```swift
    func testDefaultHasEmptyRuleMaps() {
        let s = ManagerSettings.default
        XCTAssertEqual(s.schemaVersion, 2)
        XCTAssertTrue(s.extensionOverrides.isEmpty)
        XCTAssertTrue(s.filenameOverrides.isEmpty)
        XCTAssertTrue(s.disabledExtensions.isEmpty)
        XCTAssertTrue(s.disabledFilenames.isEmpty)
    }

    func testRoundTripEncodesNewFields() throws {
        var s = ManagerSettings.default
        s.extensionOverrides = ["conf": "ini"]
        s.disabledExtensions = ["log"]
        let data = try JSONEncoder().encode(s)
        let back = try JSONDecoder().decode(ManagerSettings.self, from: data)
        XCTAssertEqual(back.extensionOverrides["conf"], "ini")
        XCTAssertTrue(back.disabledExtensions.contains("log"))
    }
```

- [ ] **Шаг 2: Прогон — падает**

Run: `swift test --filter ManagerSettingsTests`
Expected: FAIL — нет новых полей / `schemaVersion` == 1.

- [ ] **Шаг 3: Реализация**

Заменить `struct ManagerSettings` и его `default`/`currentSchemaVersion` в `ManagerSettings.swift`:

```swift
/// Настройки менеджера. Модель opt-out: храним выключенное/переопределённое,
/// пусто = поведение по умолчанию (из сгенерированного датасета).
public struct ManagerSettings: Codable, Equatable {
    public var schemaVersion: Int
    public var settingsVersion: Int
    public var disabledLanguageIds: Set<String>          // Слой 1: язык выключен в библиотеке
    public var activeThemeId: String
    public var font: FontSettings
    // Слой 2: правила просмотра поверх датасета.
    public var extensionOverrides: [String: String]      // ext(lower) → languageId
    public var filenameOverrides: [String: String]       // filename → languageId
    public var disabledExtensions: Set<String>           // ext(lower), убран из просмотра
    public var disabledFilenames: Set<String>            // filename, убран из просмотра

    public init(schemaVersion: Int, settingsVersion: Int, disabledLanguageIds: Set<String>,
                activeThemeId: String, font: FontSettings,
                extensionOverrides: [String: String], filenameOverrides: [String: String],
                disabledExtensions: Set<String>, disabledFilenames: Set<String>) {
        self.schemaVersion = schemaVersion
        self.settingsVersion = settingsVersion
        self.disabledLanguageIds = disabledLanguageIds
        self.activeThemeId = activeThemeId
        self.font = font
        self.extensionOverrides = extensionOverrides
        self.filenameOverrides = filenameOverrides
        self.disabledExtensions = disabledExtensions
        self.disabledFilenames = disabledFilenames
    }

    public static let currentSchemaVersion = 2

    public static let `default` = ManagerSettings(
        schemaVersion: currentSchemaVersion,
        settingsVersion: 0,
        disabledLanguageIds: [],
        activeThemeId: DefaultThemeIds.dark,
        font: FontSettings(family: nil, size: nil),
        extensionOverrides: [:],
        filenameOverrides: [:],
        disabledExtensions: [],
        disabledFilenames: []
    )
}
```

- [ ] **Шаг 4: Прогон — зелёный**

Run: `swift test --filter ManagerSettingsTests`
Expected: PASS. (Остальные таргеты пока могут не собираться — исправим в Задачах 5/9.)

- [ ] **Шаг 5: Коммит**

```bash
git add Sources/QuickLookersSettingsKit/ManagerSettings.swift Tests/QuickLookersSettingsKitTests/ManagerSettingsTests.swift
git commit -m "feat(settings): схема v2 — правила просмотра и опт-аут по правилу"
```

---

## Задача 5: Разрешение показа `resolvePreview` + удаление DeclaredTypes

**Files:**
- Create: `Sources/QuickLookersSettingsKit/PreviewResolution.swift`
- Delete: `Sources/QuickLookersSettingsKit/DeclaredTypes.swift`
- Modify: `Tests/QuickLookersSettingsKitTests/ResolutionTests.swift`

**Interfaces:**
- Consumes: `FileTypeAssociations` (Задача 3), `ManagerSettings` v2 (Задача 4).
- Produces:
  - `enum PreviewResolution: Equatable { case highlight(languageId: String); case neutral }`
  - `func resolvePreview(fileName: String, pathExtension: String, associations: FileTypeAssociations, settings: ManagerSettings) -> PreviewResolution`
  - `func isLanguageEnabled(_ id: String, settings: ManagerSettings) -> Bool` (перенести из DeclaredTypes.swift без изменений).
- Удаляется: `DeclaredType`, `DeclaredTypes`, `isPreviewEnabled`, `previewLanguageId`.

- [ ] **Шаг 1: Переписать тесты (падающий набор)**

Заменить содержимое `Tests/QuickLookersSettingsKitTests/ResolutionTests.swift`:

```swift
import XCTest
import QuickLookersSettingsKit

final class ResolutionTests: XCTestCase {
    private let assoc = FileTypeAssociations(
        byExtension: ["swift": "swift", "py": "python", "json": "json"],
        byFilename: ["Dockerfile": "docker"])

    func testHighlightByExtension() {
        XCTAssertEqual(
            resolvePreview(fileName: "a.swift", pathExtension: "swift", associations: assoc, settings: .default),
            .highlight(languageId: "swift"))
    }

    func testExtensionCaseInsensitive() {
        XCTAssertEqual(
            resolvePreview(fileName: "A.SWIFT", pathExtension: "SWIFT", associations: assoc, settings: .default),
            .highlight(languageId: "swift"))
    }

    func testHighlightByFilename() {
        XCTAssertEqual(
            resolvePreview(fileName: "Dockerfile", pathExtension: "", associations: assoc, settings: .default),
            .highlight(languageId: "docker"))
    }

    func testUnknownExtensionIsNeutral() {
        XCTAssertEqual(
            resolvePreview(fileName: "a.docx", pathExtension: "docx", associations: assoc, settings: .default),
            .neutral)
    }

    func testDisabledExtensionIsNeutral() {
        var s = ManagerSettings.default
        s.disabledExtensions = ["json"]
        XCTAssertEqual(
            resolvePreview(fileName: "a.json", pathExtension: "json", associations: assoc, settings: s),
            .neutral)
    }

    func testDisabledFilenameIsNeutral() {
        var s = ManagerSettings.default
        s.disabledFilenames = ["Dockerfile"]
        XCTAssertEqual(
            resolvePreview(fileName: "Dockerfile", pathExtension: "", associations: assoc, settings: s),
            .neutral)
    }

    func testDisabledLanguageLayer1IsNeutral() {
        var s = ManagerSettings.default
        s.disabledLanguageIds = ["swift"]
        XCTAssertEqual(
            resolvePreview(fileName: "a.swift", pathExtension: "swift", associations: assoc, settings: s),
            .neutral)
    }

    func testExtensionOverrideWins() {
        var s = ManagerSettings.default
        s.extensionOverrides = ["json": "javascript"]
        XCTAssertEqual(
            resolvePreview(fileName: "a.json", pathExtension: "json", associations: assoc, settings: s),
            .highlight(languageId: "javascript"))
    }

    func testFilenameRuleWinsOverExtension() {
        // Файл с именем из карты имён и одновременно расширением — имя приоритетнее.
        let a = FileTypeAssociations(byExtension: ["txt": "plaintext"],
                                     byFilename: ["CMakeLists.txt": "cmake"])
        XCTAssertEqual(
            resolvePreview(fileName: "CMakeLists.txt", pathExtension: "txt", associations: a, settings: .default),
            .highlight(languageId: "cmake"))
    }

    func testAddedExtensionRuleForUnknown() {
        var s = ManagerSettings.default
        s.extensionOverrides = ["myext": "python"]
        XCTAssertEqual(
            resolvePreview(fileName: "a.myext", pathExtension: "myext", associations: assoc, settings: s),
            .highlight(languageId: "python"))
    }

    func testEmptyExtensionNoFilenameIsNeutral() {
        XCTAssertEqual(
            resolvePreview(fileName: "README", pathExtension: "", associations: assoc, settings: .default),
            .neutral)
    }

    func testIsLanguageEnabled() {
        var s = ManagerSettings.default
        s.disabledLanguageIds = ["json"]
        XCTAssertFalse(isLanguageEnabled("json", settings: s))
        XCTAssertTrue(isLanguageEnabled("swift", settings: s))
    }
}
```

- [ ] **Шаг 2: Удалить DeclaredTypes.swift и прогнать (падает компиляцией)**

```bash
git rm Sources/QuickLookersSettingsKit/DeclaredTypes.swift
swift test --filter ResolutionTests
```
Expected: FAIL — нет `resolvePreview`/`PreviewResolution`/`isLanguageEnabled`.

- [ ] **Шаг 3: Реализация**

Create `Sources/QuickLookersSettingsKit/PreviewResolution.swift`:

```swift
/// Итог разрешения показа для файла.
public enum PreviewResolution: Equatable {
    /// Красить подсветкой указанным языком.
    case highlight(languageId: String)
    /// Рисовать нейтральным моноширинным текстом (выключено/неизвестно).
    case neutral
}

/// Язык включён в библиотеке (Слой 1), если он не в множестве выключенных.
public func isLanguageEnabled(_ id: String, settings: ManagerSettings) -> Bool {
    !settings.disabledLanguageIds.contains(id)
}

/// Как показывать файл по пробелу. Порядок: правило по имени файла (приоритетнее),
/// затем по расширению; пользовательские правки перекрывают датасет.
/// Всё, что дошло до расширения, но выключено/неизвестно → нейтральный текст
/// (не бросок): бросок оставлен только для нечитаемого файла на стороне расширения.
public func resolvePreview(fileName: String, pathExtension: String,
                           associations: FileTypeAssociations,
                           settings: ManagerSettings) -> PreviewResolution {
    // 1) правило по имени файла (Dockerfile, CMakeLists.txt …)
    if let lang = settings.filenameOverrides[fileName] ?? associations.byFilename[fileName] {
        if settings.disabledFilenames.contains(fileName) { return .neutral }
        return isLanguageEnabled(lang, settings: settings) ? .highlight(languageId: lang) : .neutral
    }
    // 2) правило по расширению
    let ext = pathExtension.lowercased()
    if !ext.isEmpty, let lang = settings.extensionOverrides[ext] ?? associations.byExtension[ext] {
        if settings.disabledExtensions.contains(ext) { return .neutral }
        return isLanguageEnabled(lang, settings: settings) ? .highlight(languageId: lang) : .neutral
    }
    // 3) дошло (напр. по public.plain-text), но неизвестно → нейтральный текст
    return .neutral
}
```

- [ ] **Шаг 4: Прогон — зелёный**

Run: `swift test --filter ResolutionTests`
Expected: PASS.

- [ ] **Шаг 5: Коммит**

```bash
git add Sources/QuickLookersSettingsKit/PreviewResolution.swift Tests/QuickLookersSettingsKitTests/ResolutionTests.swift
git rm --cached Sources/QuickLookersSettingsKit/DeclaredTypes.swift 2>/dev/null; true
git commit -m "feat(settings): resolvePreview на датасете + нейтральный текст; удалить DeclaredTypes"
```

---

## Задача 6: Нейтральная HTML-страница (PreviewKit)

**Files:**
- Create: `Sources/QuickLookersPreviewKit/NeutralPage.swift`
- Test: `Tests/QuickLookersPreviewKitTests/NeutralPageTests.swift`

**Interfaces:**
- Consumes: `sanitizedFontFamily(_:)` из `PreviewPage.swift` (внутренний для модуля).
- Produces:
  - `func htmlEscaped(_ s: String) -> String`
  - `func neutralPageHTML(code: String, fontFamily: String? = nil, fontSize: Double? = nil, truncatedNotice: String? = nil) -> String`

- [ ] **Шаг 1: Падающий тест**

Create `Tests/QuickLookersPreviewKitTests/NeutralPageTests.swift`:

```swift
import XCTest
@testable import QuickLookersPreviewKit

final class NeutralPageTests: XCTestCase {
    func testEscapesHTML() {
        XCTAssertEqual(htmlEscaped("a < b && c > d \"q\""),
                       "a &lt; b &amp;&amp; c &gt; d &quot;q&quot;")
    }

    func testNeutralPageHasNoShikiMarkupAndEscapes() {
        let html = neutralPageHTML(code: "<script>x</script>")
        XCTAssertFalse(html.contains("class=\"shiki\""))
        XCTAssertTrue(html.contains("&lt;script&gt;"))
        XCTAssertFalse(html.contains("<script>x</script>")) // сырой код не попал в DOM
    }

    func testNeutralPageFullHeightAndMonospace() {
        let html = neutralPageHTML(code: "x")
        XCTAssertTrue(html.contains("min-height: 100vh"))
        XCTAssertTrue(html.contains("monospace"))
    }

    func testNeutralPageAppliesFontFamily() {
        let html = neutralPageHTML(code: "x", fontFamily: "Fira Code")
        XCTAssertTrue(html.contains("Fira Code"))
    }

    func testNeutralNoticeRendered() {
        let html = neutralPageHTML(code: "x", truncatedNotice: "Показаны первые 2000 строк")
        XCTAssertTrue(html.contains("Показаны первые 2000 строк"))
    }
}
```

- [ ] **Шаг 2: Прогон — падает**

Run: `swift test --filter NeutralPageTests`
Expected: FAIL — нет `htmlEscaped`/`neutralPageHTML`.

- [ ] **Шаг 3: Реализация**

Create `Sources/QuickLookersPreviewKit/NeutralPage.swift`:

```swift
/// Нейтральный показ: код без подсветки, моноширинным текстом, на нейтральном
/// системном фоне. Для выключенного/неизвестного формата — ближе к родному
/// текстовому превью, чем системный дженерик. Фон/цвет — от системной темы вебвью
/// (prefers-color-scheme), поэтому здесь без жёстких цветов.

import Foundation

/// Экранирует спецсимволы HTML (порядок важен: `&` первым).
public func htmlEscaped(_ s: String) -> String {
    s.replacingOccurrences(of: "&", with: "&amp;")
     .replacingOccurrences(of: "<", with: "&lt;")
     .replacingOccurrences(of: ">", with: "&gt;")
     .replacingOccurrences(of: "\"", with: "&quot;")
}

public func neutralPageHTML(code: String, fontFamily: String? = nil, fontSize: Double? = nil,
                            truncatedNotice: String? = nil) -> String {
    let family = sanitizedFontFamily(fontFamily)
    let familyCSS = family.map { "\($0), ui-monospace, monospace" } ?? "ui-monospace, \"SF Mono\", Menlo, monospace"
    let size = (fontSize.flatMap { (6...48).contains(Int($0)) ? Int($0) : nil }) ?? 12
    let notice = truncatedNotice.map { #"<div class="ql-truncated">\#(htmlEscaped($0))</div>"# } ?? ""
    let truncatedStyle = truncatedNotice != nil ? """
        .ql-truncated { padding: 8px 12px; font-family: -apple-system, system-ui, sans-serif;
            font-size: 11px; color: #888; text-align: center; }
        """ : ""
    return """
    <!DOCTYPE html>
    <html>
    <head>
    <meta charset="utf-8">
    <style>
    html, body { margin: 0; padding: 0; }
    body { background: Canvas; color: CanvasText; }
    pre.ql-neutral {
        margin: 0; padding: 12px;
        box-sizing: border-box; min-height: 100vh;
        font-family: \(familyCSS);
        font-size: \(size)px; line-height: 1.5; tab-size: 4;
        white-space: pre-wrap; overflow-wrap: anywhere; word-break: break-word;
    }
    \(truncatedStyle)
    </style>
    </head>
    <body>
    <pre class="ql-neutral">\(htmlEscaped(code))</pre>
    \(notice)
    </body>
    </html>
    """
}
```

- [ ] **Шаг 4: Прогон — зелёный**

Run: `swift test --filter NeutralPageTests`
Expected: PASS.

- [ ] **Шаг 5: Коммит**

```bash
git add Sources/QuickLookersPreviewKit/NeutralPage.swift Tests/QuickLookersPreviewKitTests/NeutralPageTests.swift
git commit -m "feat(preview): нейтральная HTML-страница для выключенного/неизвестного формата"
```

---

## Задача 7: Склейка расширения — associations, разрешение, ветка нейтрали

**Files:**
- Modify: `PreviewExtension/PreviewViewController.swift`

**Interfaces:**
- Consumes: `FileTypeAssociations` + `resolvePreview` (Задачи 3, 5), `neutralPageHTML` (Задача 6), `QuickLookersEngineResources.associationsURL()` (Задача 2).

Это склейка с WebKit; чистая логика уже покрыта юнит-тестами Задач 3/5/6. Проверка — сборкой Xcode + живым показом (как принято в проекте для расширения).

- [ ] **Шаг 1: Тёплая таблица associations**

В `PreviewViewController` рядом с `cachedEngine`/`cachedThemeIds` добавить:

```swift
    // Таблица соответствий строится один раз на процесс (тёплый рантайм).
    private static let associations: FileTypeAssociations = {
        guard let url = QuickLookersEngineResources.associationsURL(),
              let a = try? FileTypeAssociations(contentsOf: url) else { return .empty }
        return a
    }()
```

- [ ] **Шаг 2: Вынести чтение+обрезку в помощник**

Добавить в класс приватный метод (устраняет дублирование между ветками):

```swift
    /// Читает файл (с ограничением префикса для больших) и режет до maxLines.
    /// Бросает на нечитаемом/не-UTF-8 файле → системный дженерик.
    private static func loadTrimmed(_ url: URL, size: Int) throws -> (code: String, truncated: Bool) {
        let code = size > largeFileThreshold
            ? try readBoundedPrefix(of: url, maxBytes: largeFileThreshold)
            : try String(contentsOf: url, encoding: .utf8)
        return trimToFirstLines(code, max: maxLines)
    }
```

- [ ] **Шаг 3: Переписать тело `preparePreviewOfFile`**

Заменить участок от `let settings = Self.settings()` до `cache?.store(...)`/формирования `page` на разбор по `resolvePreview`. Итоговое тело (сохранён тёплый лог, кэш только на ветке подсветки, чтение файла на попадании в кэш по-прежнему пропускается):

```swift
    func preparePreviewOfFile(at url: URL) async throws {
        let start = Date()
        let wasWarm = Self.cachedEngine != nil
        let settings = Self.settings()

        let resolution = resolvePreview(fileName: url.lastPathComponent,
                                        pathExtension: url.pathExtension,
                                        associations: Self.associations,
                                        settings: settings)

        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        let mtime = (attrs[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        let size = (attrs[.size] as? Int) ?? 0

        let page: String
        let cacheHit: Bool
        let logLang: String

        switch resolution {
        case .highlight(let lang):
            logLang = lang
            let themeId = resolvedThemeId(activeThemeId: settings.activeThemeId,
                                          availableThemeIds: try Self.themeIds())
            let key = HTMLCacheKey(path: url.path, mtime: mtime, size: size,
                                   languageId: lang, themeId: themeId,
                                   fontFamily: settings.font.family, fontSize: settings.font.size,
                                   maxLines: Self.maxLines, bundleVersion: Self.bundleVersion)
            let cache = Self.sharedCache
            if let cached = cache?.lookup(key) {
                page = cached; cacheHit = true
            } else {
                cacheHit = false
                let (trimmed, truncated) = try Self.loadTrimmed(url, size: size)
                let fragment = try Self.engine().highlightToHTML(
                    HighlightRequest(code: trimmed, languageId: lang, themeId: themeId))
                let notice = truncated ? "Показаны первые \(Self.maxLines) строк" : nil
                page = previewPageHTML(highlighted: fragment,
                                       fontFamily: settings.font.family, fontSize: settings.font.size,
                                       truncatedNotice: notice)
                cache?.store(key, html: page)
            }
            if !cacheHit { cache?.evictIfNeeded() }

        case .neutral:
            logLang = "neutral"
            cacheHit = false
            let (trimmed, truncated) = try Self.loadTrimmed(url, size: size)
            let notice = truncated ? "Показаны первые \(Self.maxLines) строк" : nil
            page = neutralPageHTML(code: trimmed,
                                   fontFamily: settings.font.family, fontSize: settings.font.size,
                                   truncatedNotice: notice)
        }

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            self.loadContinuation = cont
            self.webView.loadHTMLString(page, baseURL: nil)
        }

        let ms = Date().timeIntervalSince(start) * 1000
        Self.log.info("""
            preview pid=\(getpid()) warm=\(wasWarm, privacy: .public) \
            cache=\(cacheHit, privacy: .public) lang=\(logLang, privacy: .public) \
            ms=\(ms, format: .fixed(precision: 1), privacy: .public)
            """)
    }
```

Импорт `QuickLookersPreviewKit` уже есть (для `previewPageHTML`); `neutralPageHTML` из того же модуля.

- [ ] **Шаг 4: Сборка**

```bash
xcodegen generate
xcodebuild -project QuickLookers.xcodeproj -scheme QuickLookers \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -20
```
Expected: `BUILD SUCCEEDED`.

- [ ] **Шаг 5: Коммит**

```bash
git add PreviewExtension/PreviewViewController.swift
git commit -m "feat(preview): расширение — associations + нейтральный показ для выключенного/неизвестного"
```

---

## Задача 8: Слой A — невод `public.plain-text` + живой спайк хвоста

**Files:**
- Modify: `project.yml`
- Modify: `docs/superpowers/notes/2026-06-28-intercept-spikes.md`

Слой A — маршрутизация; проверяется **живым спайком** (не юнит-тестом). UTI — маленький машинно-верифицированный набор, поэтому объявляем его прямо в `project.yml` (источник XcodeGen) с комментарием, а не текстовым генератором: список стабилен и не тянется за датасетом linguist.

- [ ] **Шаг 1: Добавить `public.plain-text` первой строкой списка**

В `project.yml`, в `QLSupportedContentTypes` (сейчас начинается с `- public.python-script`) добавить сверху комментарий и `public.plain-text`:

```yaml
            QLSupportedContentTypes:
              # Невод «хвоста»: файлы, чей ТОЧНЫЙ листовой UTI — public.plain-text
              # (generic-текст, .txt, неизвестные расширения, безрасширенные вроде
              # Dockerfile). csv/md сюда НЕ попадают — у них собственные листовые
              # UTI (public.comma-separated-values-text / net.daringfireball.markdown),
              # а сопоставление идёт по точному листу. Незнакомое красится нейтральным
              # текстом (Слой B), csv/md остаются системе/соседу.
              - public.plain-text
              - public.python-script
```

(остальные 22 UTI — без изменений).

- [ ] **Шаг 2: Перегенерировать и собрать**

```bash
xcodegen generate
xcodebuild -project QuickLookers.xcodeproj -scheme QuickLookers \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -5
```
Expected: `BUILD SUCCEEDED`.

- [ ] **Шаг 3: Живой спайк (запускает пользователь)**

Протокол для проверки открытого эмпирического вопроса «ловит ли plain-text хвост»:

1. В Xcode ⌘R (регистрирует расширение у `pkd`).
2. На Рабочем столе создать: безрасширенный `Dockerfile` (с текстом `FROM alpine`), `foo.неизвестное` (произвольный текст), контрольные `note.txt`, `data.csv`, `readme.md`.
3. По каждому — пробел в Finder. Ожидание/фиксация:
   - `Dockerfile` → **наше** превью (нейтральный текст или подсветка `docker`, если resolvePreview нашёл имя) = plain-text ловит безрасширенные.
   - `foo.неизвестное`, `note.txt` → **наше** нейтральное превью = plain-text ловит хвост.
   - `data.csv`, `readme.md` → **системное** превью (не наше) = точный лист защитил.
4. Проверить логи: `/usr/bin/log stream --info --predicate 'subsystem == "com.quicklookers.preview"'` — строки `lang=neutral`/`lang=docker`.

- [ ] **Шаг 4: Записать исход спайка в заметку**

В `docs/superpowers/notes/2026-06-28-intercept-spikes.md` добавить раздел «Спайк D — невод public.plain-text (2026-07-02)» с фактическим результатом по каждому пункту Шага 3 (что поймалось нами, что осталось системе). Если `Dockerfile`/неизвестные **не** ловятся plain-text (система дала им `dyn.*`/`public.data`) — зафиксировать это как ограничение и кандидата на собственный UTI (Task 5b), не блокируя фазу.

- [ ] **Шаг 5: Коммит**

```bash
git add project.yml docs/superpowers/notes/2026-06-28-intercept-spikes.md
git commit -m "feat(preview): Слой A — невод public.plain-text; спайк D по хвосту"
```

---

## Задача 9: UI — таблица правил на вкладке «Просмотр в Finder»

**Files:**
- Modify: `App/SettingsModel.swift`
- Modify: `App/FileTypesTab.swift`
- Modify: `Tests/AppTests/SettingsModelTests.swift`

**Interfaces:**
- Consumes: `FileTypeAssociations`, `resolvePreview`, `ManagerSettings` v2, `catalog`.
- Produces (в `SettingsModel`):
  - `struct PreviewRuleRow: Identifiable { id, key, isFilename, languageId, languageName }`
  - `var previewRules: [PreviewRuleRow]`
  - `func isRuleOn(_ row) -> Bool`, `func setRuleOn(_ row, _ on)`
  - `func setRuleLanguage(_ row, _ languageId)`
  - `func addExtensionRule(ext:languageId:)`

- [ ] **Шаг 1: Падающий тест логики модели**

В `Tests/AppTests/SettingsModelTests.swift` добавить (модель конструируется с временным контейнером — см. существующие тесты этого файла):

```swift
    @MainActor
    func testRuleToggleWritesDisabledExtension() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let model = SettingsModel(containerURL: dir)
        guard let row = model.previewRules.first(where: { $0.key == "swift" && !$0.isFilename }) else {
            return XCTFail("нет правила для .swift")
        }
        XCTAssertTrue(model.isRuleOn(row))
        model.setRuleOn(row, false)
        XCTAssertTrue(model.settings.disabledExtensions.contains("swift"))
        XCTAssertFalse(model.isRuleOn(row))
    }

    @MainActor
    func testSetRuleLanguageWritesOverride() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let model = SettingsModel(containerURL: dir)
        guard let row = model.previewRules.first(where: { $0.key == "json" && !$0.isFilename }) else {
            return XCTFail("нет правила для .json")
        }
        model.setRuleLanguage(row, "javascript")
        XCTAssertEqual(model.settings.extensionOverrides["json"], "javascript")
    }

    @MainActor
    func testAddExtensionRule() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let model = SettingsModel(containerURL: dir)
        model.addExtensionRule(ext: ".myext", languageId: "python")
        XCTAssertEqual(model.settings.extensionOverrides["myext"], "python")
        XCTAssertTrue(model.previewRules.contains { $0.key == "myext" && $0.languageId == "python" })
    }
```

- [ ] **Шаг 2: Прогон — падает**

Run: `xcodegen generate && xcodebuild -project QuickLookers.xcodeproj -scheme QuickLookers -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test 2>&1 | tail -20`
Expected: FAIL — нет `previewRules`/`isRuleOn`/… (или ошибки компиляции старых обращений к `DeclaredTypes`/`FileTypeRow`).

- [ ] **Шаг 3: Реализация в SettingsModel**

В `App/SettingsModel.swift`:

(1) добавить поле associations и грузить его в `init`:

```swift
    let associations: FileTypeAssociations
```
В `init(containerURL:)` перед созданием store:
```swift
        self.associations = {
            guard let url = QuickLookersEngineResources.associationsURL(),
                  let a = try? FileTypeAssociations(contentsOf: url) else { return .empty }
            return a
        }()
```

(2) заменить `struct FileTypeRow`/`fileTypeRows`/`makeFileTypeRows` на правила:

```swift
    /// Строка таблицы правил Слоя 2.
    struct PreviewRuleRow: Identifiable {
        let id: String          // "ext:py" / "file:Dockerfile"
        let key: String         // "py" / "Dockerfile"
        let isFilename: Bool
        let languageId: String
        let languageName: String
    }

    var previewRules: [PreviewRuleRow] {
        let names = Dictionary(uniqueKeysWithValues: catalog.languages.map { ($0.id, $0.displayName) })
        func name(_ id: String) -> String { names[id] ?? id }

        // База: датасет + пользовательские override/добавления.
        var exts = associations.byExtension
        for (k, v) in settings.extensionOverrides { exts[k] = v }
        var files = associations.byFilename
        for (k, v) in settings.filenameOverrides { files[k] = v }

        let extRows = exts.map { (ext, lang) in
            PreviewRuleRow(id: "ext:\(ext)", key: ext, isFilename: false,
                           languageId: lang, languageName: name(lang))
        }
        let fileRows = files.map { (fn, lang) in
            PreviewRuleRow(id: "file:\(fn)", key: fn, isFilename: true,
                           languageId: lang, languageName: name(lang))
        }
        return (extRows + fileRows).sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
    }
```

(3) заменить `isPreviewOn`/`setPreviewOn` на методы правил:

```swift
    func isRuleOn(_ row: PreviewRuleRow) -> Bool {
        guard isLanguageEnabled(row.languageId, settings: settings) else { return false }
        return row.isFilename
            ? !settings.disabledFilenames.contains(row.key)
            : !settings.disabledExtensions.contains(row.key)
    }

    func setRuleOn(_ row: PreviewRuleRow, _ on: Bool) {
        update { s in
            if row.isFilename {
                if on { s.disabledFilenames.remove(row.key) } else { s.disabledFilenames.insert(row.key) }
            } else {
                if on { s.disabledExtensions.remove(row.key) } else { s.disabledExtensions.insert(row.key) }
            }
        }
    }

    func setRuleLanguage(_ row: PreviewRuleRow, _ languageId: String) {
        update { s in
            if row.isFilename { s.filenameOverrides[row.key] = languageId }
            else { s.extensionOverrides[row.key] = languageId }
        }
    }

    /// Добавить/переопределить правило по расширению (ведущая точка допускается).
    func addExtensionRule(ext: String, languageId: String) {
        let key = ext.hasPrefix(".") ? String(ext.dropFirst()) : ext
        let norm = key.lowercased()
        guard !norm.isEmpty else { return }
        update { s in s.extensionOverrides[norm] = languageId }
    }
```

Удалить старые `isPreviewOn`/`setPreviewOn` и `struct FileTypeRow`/`makeFileTypeRows` (заменены выше).

- [ ] **Шаг 4: Реализация вида FileTypesTab**

Заменить `App/FileTypesTab.swift` целиком:

```swift
import SwiftUI

/// Слой 2 — таблица правил «расширение/имя файла → язык» с поиском, выбором
/// языка, тумблером просмотра и добавлением своего правила.
struct FileTypesTab: View {
    @ObservedObject var model: SettingsModel
    @State private var query = ""
    @State private var newExt = ""
    @State private var newLang = ""

    private var rows: [SettingsModel.PreviewRuleRow] {
        let all = model.previewRules
        guard !query.isEmpty else { return all }
        return all.filter {
            $0.key.localizedCaseInsensitiveContains(query)
                || $0.languageName.localizedCaseInsensitiveContains(query)
        }
    }

    private var languageIds: [String] { model.catalog.languages.map(\.id) }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Поиск по расширению или языку", text: $query)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(8)

            List {
                Section("Правила просмотра") {
                    ForEach(rows) { row in
                        HStack {
                            Text(row.isFilename ? row.key : ".\(row.key)")
                                .frame(width: 140, alignment: .leading)
                            Picker("", selection: Binding(
                                get: { row.languageId },
                                set: { model.setRuleLanguage(row, $0) })) {
                                ForEach(languageIds, id: \.self) { Text($0).tag($0) }
                            }
                            .labelsHidden()
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { model.isRuleOn(row) },
                                set: { model.setRuleOn(row, $0) }))
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .controlSize(.mini)
                                .disabled(!model.isLanguageOn(row.languageId))
                        }
                    }
                }

                Section("Добавить своё правило") {
                    HStack {
                        TextField(".расширение", text: $newExt)
                            .frame(width: 140)
                        Picker("", selection: $newLang) {
                            Text("— язык —").tag("")
                            ForEach(languageIds, id: \.self) { Text($0).tag($0) }
                        }
                        .labelsHidden()
                        Spacer()
                        Button("Добавить") {
                            model.addExtensionRule(ext: newExt, languageId: newLang)
                            newExt = ""; newLang = ""
                        }
                        .disabled(newExt.isEmpty || newLang.isEmpty)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

- [ ] **Шаг 5: Прогон — зелёный**

Run: `xcodebuild -project QuickLookers.xcodeproj -scheme QuickLookers -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test 2>&1 | tail -20`
Expected: `TEST SUCCEEDED` (в т.ч. новые тесты SettingsModel).

- [ ] **Шаг 6: Коммит**

```bash
git add App/SettingsModel.swift App/FileTypesTab.swift Tests/AppTests/SettingsModelTests.swift
git commit -m "feat(app): таблица правил Слоя 2 — поиск, язык, тумблер, добавление"
```

---

## Задача 10: Документация, упрощение, полный прогон

**Files:**
- Modify: `CLAUDE.md`
- Modify: память проекта `file-type-mapping-strategy.md` (отметить «реализовано»)

- [ ] **Шаг 1: Обновить CLAUDE.md**

В разделе «Текущее состояние» добавить пункт о фазе сопоставления файл→язык: два слоя, `associations.json` из linguist, невод `public.plain-text`, нейтральный текст, таблица правил. В «Структуре» отразить новые файлы (`FileTypeAssociations.swift`, `PreviewResolution.swift`, `NeutralPage.swift`, `js/generate-associations.mjs`, `js/vendor/…`) и удаление `DeclaredTypes.swift`. В «Командах» добавить генерацию датасета:

```bash
cd js && node generate-associations.mjs && node test/associations.smoke.mjs
```

- [ ] **Шаг 2: /simplify**

Запустить `/simplify` по изменённому коду (договорённость playbook). Учесть замечания, прогнать затронутые тесты.

- [ ] **Шаг 3: Полный прогон пакета**

```bash
swift test 2>&1 | tail -20
```
Expected: все зелёные. При зависании — таймаут и локализовать домен.

- [ ] **Шаг 4: Полная сборка приложения+расширения**

```bash
xcodegen generate
xcodebuild -project QuickLookers.xcodeproj -scheme QuickLookers \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -5
```
Expected: `BUILD SUCCEEDED`.

- [ ] **Шаг 5: Живая проверка в Finder (пользователь, ⌘R)**

Пробел по: `.py`, `.rs`, `.rb`, `.kt` (если ловится plain-text), `Dockerfile`, `.txt`, `.csv`, `.md`. Убедиться: разнообразные языки красятся; `.txt`/неизвестное — нейтральный текст; `.csv`/`.md` — системное превью. Тумблер и смена языка на вкладке «Просмотр в Finder» отражаются на показе.

- [ ] **Шаг 6: Обновить память и финальный коммит**

Отметить в памяти проекта фазу реализованной. Коммит:

```bash
git add CLAUDE.md
git commit -m "docs: фаза сопоставления файл→язык — итоги и структура"
```

---

## Самопроверка плана (сверка со спекой)

- **Слой A (невод + csv/md исключены)** → Задача 8 (добавляет `public.plain-text`; защита csv/md документирована фактом точного листа). ✔
- **Слой B датасет из linguist, вендорится, генерируется** → Задача 1 (vendor + generator + smoke). ✔
- **Shiki непригоден как источник расширений** → учтено: linguist основной, fileTypes грамматик лишь дополнение. ✔
- **Рантайм-разрешение с оверлеем настроек, нейтральный текст** → Задачи 5 (resolvePreview), 6 (neutralPageHTML), 7 (склейка). ✔
- **Имя файла (Dockerfile) матчится по имени** → byFilename + приоритет имени в resolvePreview (Задача 5, тест `testFilenameRuleWinsOverExtension`). ✔
- **UI — эволюция вкладки в таблицу правил (столбцы, поиск, добавление)** → Задача 9. ✔
- **Модель настроек: правила + опт-аут по правилу, без миграции** → Задача 4 (схема v2). ✔
- **Затрагиваемый код (DeclaredTypes расцепить, PreviewViewController, FileTypesTab, js/)** → Задачи 5/7/9/1. ✔
- **Открытый эмпирический вопрос (plain-text ловит Dockerfile/неизвестное)** → Задача 8, живой спайк D. ✔
- **Тестирование слоями (генерация, разрешение, нейтральная страница, Слой A спайком)** → Задачи 1/3/5/6/9 (юнит) + 8 (спайк). ✔
- **Вне области (собственные UTI Task 5b, определение по содержимому)** → не входят в задачи, зафиксированы как отложенное в Задаче 8. ✔

Согласованность типов: `PreviewResolution`/`resolvePreview` (З.5) ↔ ветки контроллера (З.7); `FileTypeAssociations.byExtension/byFilename` (З.3) ↔ использование в резолвере (З.5), модели (З.9), контроллере (З.7); поля `ManagerSettings` v2 (З.4) ↔ чтение/запись в резолвере (З.5) и модели (З.9). Имена совпадают.
