# Полная библиотека языков/тем + расширенный перехват — план реализации

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Подключить всю библиотеку Shiki (≈218 языков, 54 темы) в бандл и каталог и расширить перехват в Finder явными точными UTI, чтобы оптимизацию показа можно было проверять на разном материале.

**Architecture:** Слой 1 — обобщить extract-скрипт на весь набор Shiki, научить движок собирать встроенные грамматики, каталог наполняется сам из файлов. Слой 2 — курируемый набор языков, UTI добываются из системы через `UTType`, объявляются в `QLSupportedContentTypes`; что не объявлено — остаётся за системой. Спайки проверяют непроверенное до того, как на него полагаться.

**Tech Stack:** SwiftPM (Swift 6.3, tools 5.9), JavaScriptCore + Shiki 1.29.2, esbuild 0.20.2, Node (только сборка), XcodeGen, UniformTypeIdentifiers.

## Global Constraints

- Отвечать пользователю и писать сообщения коммитов **по-русски**; формат `feat(scope): …` / `fix(scope): …` / `test(scope): …` / `docs: …`; трейлер `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.
- **TDD строго:** падающий тест → запуск (падает) → реализация → запуск (зелёный) → коммит.
- Движок изолирован за протоколом `HighlightEngine`; потребители про Shiki/JSC не знают.
- **Без WASM** (`createJavaScriptRegexEngine`); всё офлайн (бандл, грамматики, темы — в ресурсах).
- `shiki-bundle.js` — артефакт сборки: правят `js/src/highlight.mjs` и пересобирают, руками бандл не трогают.
- `.xcodeproj` / entitlements / Info.plist расширения — артефакты XcodeGen: правят `project.yml` и перегенерируют.
- **Строки UTI не выдумывать** — добывать через `UTType(filenameExtension:)`; где нет — объявлять свой через `UTExportedTypeDeclarations`.
- App Group: `5FVC5YT2B5.com.quicklookers` (Team-ID-префикс, не `group.`).

## Проверенные факты о Shiki (осмотр установленного пакета)

- `shiki.bundledLanguagesInfo` — массив `{id, name, aliases?}`, 218 элементов (`name` — человекочитаемое имя).
- `shiki.bundledThemesInfo` — массив `{id, displayName, type}`, 54 элемента (`type` = `dark`/`light`).
- Модуль `@shikijs/langs/<id>` `default` — **массив** грамматик: главная (`name === id`) + встроенные зависимости. Грамматика несёт поля `name`, `displayName`, `scopeName`, `patterns`, `repository`, опц. `embeddedLangs` (всегда нужны), `embeddedLangsLazy` (по требованию), `aliases`.
- Модуль `@shikijs/themes/<id>` `default` — объект с `name`, `displayName`, `type`, `colors`, `tokenColors`…
- Расширений файлов в данных Shiki **нет** — для Слоя 2 берём из своей конфигурации.

## Структура файлов

- `js/extract-resources.mjs` — перечисляет весь набор, пишет грамматики массивами, темы объектами.
- `js/src/highlight.mjs` — регистрация массива грамматик + сборка встроенных при показе.
- `Sources/QuickLookersEngine/Resources/grammars/*.json` — по файлу на язык, содержимое — массив грамматик.
- `Sources/QuickLookersEngine/Resources/themes/*.json` — по файлу на тему, объект.
- `Sources/QuickLookersSettingsKit/CatalogSource.swift` — чтение метаданных грамматики из массива.
- `Sources/QuickLookersSettingsKit/DeclaredTypes.swift` — расширенный набор `DeclaredType` (UTI → расширение → язык).
- `project.yml` — `QLSupportedContentTypes` + `UTExportedTypeDeclarations`.
- `docs/superpowers/notes/2026-06-28-intercept-spikes.md` — итоги спайков (создаётся в Task 3).

---

### Task 1: Движок собирает встроенные грамматики (на наборе из 3 языков)

Цель: переключить формат файла грамматики на массив и научить `highlight.mjs` регистрировать массив и собирать встроенные языки. Пока на текущих 3 языках/2 темах — без расширения набора, чтобы правка была маленькой и проверяемой.

**Files:**
- Modify: `js/src/highlight.mjs`
- Modify: `js/extract-resources.mjs:18-25` (запись грамматики массивом)
- Modify: `Sources/QuickLookersSettingsKit/CatalogSource.swift:18-26`
- Modify: `js/test/smoke.mjs` (смоук массива)
- Test: `Tests/QuickLookersSettingsKitTests/CatalogSourceTests.swift`

**Interfaces:**
- Produces: грамматика в ресурсах — JSON-массив объектов `{name, displayName, …}`; `qlRegisterLang` принимает массив; `FileCatalogSource` берёт id из имени файла, `displayName` — из записи с `name == id`.

- [ ] **Step 1: Переписать `js/src/highlight.mjs` на регистрацию массива и сборку встроенных**

```js
import { createHighlighterCoreSync } from 'shiki/core'
import { createJavaScriptRegexEngine } from 'shiki/engine/javascript'

// Один движок регулярок на всё, без WASM.
const engine = createJavaScriptRegexEngine({ forgiving: true })

const langByName = new Map()   // name -> грамматика (главные и встроенные)
const themes = new Map()       // name -> тема
const highlighters = new Map() // `${lang} ${theme}` -> HighlighterCore

// Грамматика приходит массивом [главная + встроенные зависимости].
globalThis.qlRegisterLang = (json) => {
  const parsed = JSON.parse(json)
  const arr = Array.isArray(parsed) ? parsed : [parsed]
  for (const g of arr) langByName.set(g.name, g)
  return arr.length
}

globalThis.qlRegisterTheme = (json) => {
  const theme = JSON.parse(json)
  themes.set(theme.name, theme)
  return theme.name
}

// Собираем главную грамматику и её встроенные зависимости (транзитивно, без lazy).
function collectLangs(name, acc, seen) {
  if (seen.has(name)) return
  seen.add(name)
  const g = langByName.get(name)
  if (!g) return
  acc.push(g)
  for (const dep of (g.embeddedLangs || [])) collectLangs(dep, acc, seen)
}

globalThis.qlHighlight = (code, langName, themeName) => {
  const key = langName + ' ' + themeName
  let hl = highlighters.get(key)
  if (!hl) {
    const langs = []
    collectLangs(langName, langs, new Set())
    if (langs.length === 0) throw new Error('lang not registered: ' + langName)
    const theme = themes.get(themeName)
    if (!theme) throw new Error('theme not registered: ' + themeName)
    hl = createHighlighterCoreSync({ themes: [theme], langs, engine })
    highlighters.set(key, hl)
  }
  return hl.codeToHtml(code, { lang: langName, theme: themeName })
}
```

- [ ] **Step 2: Записывать грамматику массивом в `js/extract-resources.mjs`**

Заменить тело цикла грамматик (строки 18–25) на запись всего массива:

```js
// Грамматика: модуль экспортирует массив [главная + встроенные]. Пишем целиком.
for (const id of GRAMMARS) {
  const mod = await import(`@shikijs/langs/${id}`)
  const arr = Array.isArray(mod.default) ? mod.default : [mod.default]
  writeFileSync(`${grammarsDir}/${id}.json`, JSON.stringify(arr))
  console.log(`grammar ${id} <- entries=${arr.length}`)
}
```

- [ ] **Step 3: Перегенерировать ресурсы и бандл для текущих 3 языков**

Run:
```bash
cd js && node extract-resources.mjs && npm run build
```
Expected: `grammar javascript <- entries=…`, `built shiki-bundle.js`. Файлы `Resources/grammars/{javascript,swift,json}.json` теперь массивы.

- [ ] **Step 4: Обновить смоук `js/test/smoke.mjs` под массив и запустить**

В смоуке грамматика читается из ресурса и передаётся в `qlRegisterLang`. Убедиться, что тест читает файл как есть (массив) и подсветка swift/json/js по-прежнему даёт непустой HTML. Запустить:
```bash
cd js && npm test
```
Expected: смоук зелёный, HTML непустой для всех трёх языков.

- [ ] **Step 5: Падающий тест каталога на чтение массива**

В `Tests/QuickLookersSettingsKitTests/CatalogSourceTests.swift` добавить тест: язык `javascript` присутствует и `displayName == "JavaScript"`, прочитанный из массива.

```swift
func test_grammarDisplayNameFromArrayEntry() throws {
    let catalog = try FileCatalogSource(
        grammarsDirectory: EngineResources.grammarsDirectory,
        themesDirectory: EngineResources.themesDirectory).loadCatalog()
    let js = try XCTUnwrap(catalog.languages.first { $0.id == "javascript" })
    XCTAssertEqual(js.displayName, "JavaScript")
}
```

- [ ] **Step 6: Запустить — убедиться, что падает**

Run: `swift test --filter CatalogSourceTests/test_grammarDisplayNameFromArrayEntry`
Expected: FAIL — текущий `GrammarMeta` декодирует объект, на массиве вернёт nil → языка нет.

- [ ] **Step 7: Чтение метаданных грамматики из массива в `CatalogSource.swift`**

Заменить `GrammarMeta` и блок разбора грамматик:

```swift
private struct GrammarEntry: Decodable { let name: String; let displayName: String? }
private struct ThemeMeta: Decodable { let name: String; let displayName: String?; let type: String? }

public func loadCatalog() throws -> Catalog {
    let languages = try jsonFiles(in: grammarsDirectory).compactMap { url -> LanguageInfo? in
        let id = url.deletingPathExtension().lastPathComponent
        guard let entries = try? JSONDecoder().decode([GrammarEntry].self,
                                                       from: Data(contentsOf: url))
        else { return nil }
        let main = entries.first { $0.name == id }
        return LanguageInfo(id: id, displayName: main?.displayName ?? id)
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
```

- [ ] **Step 8: Запустить — зелёный**

Run: `swift test --filter QuickLookersSettingsKitTests`
Expected: PASS, включая новый тест.

- [ ] **Step 9: Коммит**

```bash
git add js/src/highlight.mjs js/extract-resources.mjs js/test/smoke.mjs \
  Sources/QuickLookersEngine/Resources/grammars Sources/QuickLookersEngine/Resources/shiki-bundle.js \
  Sources/QuickLookersSettingsKit/CatalogSource.swift \
  Tests/QuickLookersSettingsKitTests/CatalogSourceTests.swift
git commit -m "feat(engine): грамматика массивом + сборка встроенных языков при показе"
```

---

### Task 2: Подключить весь набор языков и тем

Цель: перечислить весь набор Shiki в extract-скрипте, перегенерировать ресурсы, доказать, что встроенные грамматики реально красятся (vue), и замерить влияние на старт.

**Files:**
- Modify: `js/extract-resources.mjs:10-11` (перечисление всего набора)
- Modify: `js/test/smoke.mjs` (смоук встроенной подсветки vue)
- Modify: `Tests/QuickLookersSettingsKitTests/CatalogSourceTests.swift` (счётчики набора)
- Create: множество файлов в `Resources/grammars/` и `Resources/themes/`

**Interfaces:**
- Consumes: формат массива и `collectLangs` из Task 1.
- Produces: ≈218 файлов грамматик, 54 файла тем; каталог отдаёт их все.

- [ ] **Step 1: Перечислять весь набор в `js/extract-resources.mjs`**

Заменить захардкоженные списки (строки 10–11) на перечисление из Shiki:

```js
import { bundledLanguagesInfo, bundledThemesInfo } from 'shiki'

const GRAMMARS = bundledLanguagesInfo.map((l) => l.id)
const THEMES = bundledThemesInfo.map((t) => t.id)
```

- [ ] **Step 2: Перегенерировать ресурсы и бандл**

Run:
```bash
cd js && node extract-resources.mjs && npm run build
```
Expected: ~218 строк `grammar … <- entries=…`, 54 строки `theme …`, `built shiki-bundle.js`.

- [ ] **Step 3: Смоук встроенной подсветки в `js/test/smoke.mjs`**

Добавить проверку: зарегистрировать `vue.json` (массив с html/css/js внутри) и `dark-plus`, подсветить SFC со `<template>` и `<script>`; убедиться, что в HTML есть токены и из шаблона, и из скрипта (не одна сплошная строка). Запустить:
```bash
cd js && npm test
```
Expected: PASS — vue даёт раскрашенные встроенные блоки.

- [ ] **Step 4: Падающий тест счётчиков каталога**

В `CatalogSourceTests.swift`:

```swift
func test_catalogLoadsFullLibrary() throws {
    let catalog = try FileCatalogSource(
        grammarsDirectory: EngineResources.grammarsDirectory,
        themesDirectory: EngineResources.themesDirectory).loadCatalog()
    XCTAssertGreaterThan(catalog.languages.count, 200)
    XCTAssertGreaterThan(catalog.themes.count, 50)
}
```

- [ ] **Step 5: Запустить — убедиться, что падает (до перегенерации набора в ресурсах коммита)**

Run: `swift test --filter CatalogSourceTests/test_catalogLoadsFullLibrary`
Expected: FAIL до шага 2 (на 3 языках), PASS после. Если шаг 2 уже выполнен — тест сразу зелёный; тогда зафиксировать как проверку, а не TDD-падение.

- [ ] **Step 6: Запустить весь набор тестов пакета**

Run: `swift test`
Expected: PASS. Бенчмарк в конце выведет `cold=…ms warm=…ms` — записать значения для сравнения.

- [ ] **Step 7: Замер старта до/после (заметка)**

Сравнить `cold`/`warm` из бенчмарка с зафиксированными в `docs/superpowers/notes/2026-06-28-engine-benchmark.md` (3 языка). Если холодный старт вырос значимо — отметить в заметке; ленивость уже на месте (грузим грамматику по требованию), вывод по факту.

- [ ] **Step 8: Коммит**

```bash
git add js/extract-resources.mjs js/test/smoke.mjs \
  Sources/QuickLookersEngine/Resources/grammars Sources/QuickLookersEngine/Resources/themes \
  Sources/QuickLookersEngine/Resources/shiki-bundle.js \
  Tests/QuickLookersSettingsKitTests/CatalogSourceTests.swift
git commit -m "feat(engine): подключить весь набор языков и тем Shiki"
```

---

### Task 3: Спайки перехвата (С1, С2, поведение отказа)

Цель: до того как полагаться на перехват, эмпирически проверить непроверенное на macOS 26. Это исследовательская задача — её «тест» это наблюдаемое поведение Finder, а результат — заметка с фактами.

**Files:**
- Create: `docs/superpowers/notes/2026-06-28-intercept-spikes.md`
- Временные правки `project.yml` (откатить после спайков)

- [ ] **Step 1: Спайк A — нужен ли точный UTI (С1)**

Временно добавить в `QLSupportedContentTypes` расширения родительский `public.source-code` (и убрать конкретные), перегенерировать, запустить хост из Xcode (⌘R), нажать пробел на `.swift`/`.py`. Записать: перехватывается ли по родителю или нет. Откатить правку.

- [ ] **Step 2: Спайк B — победа над системой (С2)**

Поочерёдно добавить точные UTI для типов, которые превьюит сама система: `public.json` (у нас работает — контроль), и спорный, который резолвится `UTType(filenameExtension: "csv")`. Для каждого: пробел в Finder → показывает наше превью или системное. Записать таблицу «тип → кто победил».

- [ ] **Step 3: Спайк C — поведение отказа**

Для объявленного типа заставить `previewLanguageId(...)` вернуть nil (например, выключив язык в настройках) и в `PreviewViewController` вернуть отказ. Пробел в Finder: родное превью macOS или пустота/спиннер. Записать вывод — от него зависит, возможен ли рантайм-«отдать ОС».

- [ ] **Step 4: Зафиксировать заметку и откатить временные правки**

Заполнить `docs/superpowers/notes/2026-06-28-intercept-spikes.md` итогами A/B/C. Убедиться, что `project.yml` вернулся к состоянию из Task 2 (только 3 типа). Run: `git diff --stat project.yml` → пусто.

- [ ] **Step 5: Коммит заметки**

```bash
git add docs/superpowers/notes/2026-06-28-intercept-spikes.md
git commit -m "docs: итоги спайков перехвата (точный UTI, precedence, отказ) на macOS 26"
```

---

### Task 4: Набор языков перехвата и добыча UTI → `DeclaredTypes`

Цель: задать курируемый код-набор Слоя 2 (язык → расширения), добыть для расширений системные UTI через `UTType`, собрать расширенный `DeclaredTypes.all`. Языки без системного UTI пометить для своего UTI (Task 5).

**Files:**
- Modify: `Sources/QuickLookersSettingsKit/DeclaredTypes.swift`
- Test: `Tests/QuickLookersSettingsKitTests/ResolutionTests.swift`
- Create: `scratchpad/resolve-utis.swift` (одноразовый резолвер, не коммитим)

**Interfaces:**
- Consumes: `previewLanguageId(forPathExtension:settings:)`, `DeclaredTypes.languageId(forPathExtension:)` (уже есть).
- Produces: расширенный `DeclaredTypes.all`; язык по расширению для всего код-набора.

- [ ] **Step 1: Зафиксировать код-набор (язык → расширения) и сверить id с библиотекой**

Стартовый код-набор (id языка должен существовать в `bundledLanguagesInfo`; сверить по каталогу из Task 2):

```
python: py        javascript: js, mjs, cjs   typescript: ts
tsx: tsx          jsx: jsx                    c: c, h
cpp: cpp, cc, cxx, hpp, hh                    java: java
go: go            rust: rs                    swift: swift
csharp: cs        php: php                    ruby: rb
kotlin: kt, kts   dart: dart                  scala: scala, sc
r: r              perl: pl, pm                vue: vue
yaml: yaml, yml   toml: toml                  json: json
docker: dockerfile (по имени файла — отдельно) sql: sql
graphql: graphql, gql
```

Сверить каждый id: `swift run`-проверкой или по `catalog.languages`. Несуществующие id (напр. если в Shiki не `docker`, а другой) — поправить по факту из библиотеки, не угадывать.

- [ ] **Step 2: Добыть системные UTI для расширений (одноразовый резолвер)**

Создать `scratchpad/resolve-utis.swift`:

```swift
import UniformTypeIdentifiers
let exts = ["py","js","mjs","cjs","ts","tsx","jsx","c","h","cpp","cc","cxx","hpp","hh",
            "java","go","rs","swift","cs","php","rb","kt","kts","dart","scala","sc",
            "r","pl","pm","vue","yaml","yml","toml","json","sql","graphql","gql"]
for e in exts { print(e, UTType(filenameExtension: e)?.identifier ?? "NONE") }
```

Run: `swift scratchpad/resolve-utis.swift`
Expected: для каждого расширения — строка системного UTI или `NONE`. Эти строки — источник правды для `DeclaredType.uti`; в код подставляем их, не выдумываем.

- [ ] **Step 3: Падающий тест разрешения языка по новым расширениям**

В `ResolutionTests.swift`:

```swift
func test_previewLanguageForExpandedExtensions() {
    let s = ManagerSettings.default
    XCTAssertEqual(previewLanguageId(forPathExtension: "py", settings: s), "python")
    XCTAssertEqual(previewLanguageId(forPathExtension: "rs", settings: s), "rust")
    XCTAssertEqual(previewLanguageId(forPathExtension: "yml", settings: s), "yaml")
    XCTAssertEqual(previewLanguageId(forPathExtension: "tsx", settings: s), "tsx")
}
```

- [ ] **Step 4: Запустить — убедиться, что падает**

Run: `swift test --filter ResolutionTests/test_previewLanguageForExpandedExtensions`
Expected: FAIL — текущий `DeclaredTypes.all` знает только swift/json/js.

- [ ] **Step 5: Заполнить `DeclaredTypes.all` добытыми UTI**

Подставить из вывода шага 2 (пример — реальные строки берутся из резолвера; `public.python-script` здесь как иллюстрация формата, не как факт):

```swift
public static let all: [DeclaredType] = [
    DeclaredType(uti: "<из резолвера для py>",  pathExtension: "py",  languageId: "python"),
    DeclaredType(uti: "<из резолвера для rs>",  pathExtension: "rs",  languageId: "rust"),
    DeclaredType(uti: "<из резолвера для yml>", pathExtension: "yml", languageId: "yaml"),
    DeclaredType(uti: "<из резолвера для tsx>", pathExtension: "tsx", languageId: "tsx"),
    // … все расширения код-набора; по строке на расширение, UTI — из резолвера
    DeclaredType(uti: "public.swift-source", pathExtension: "swift", languageId: "swift"),
    DeclaredType(uti: "public.json", pathExtension: "json", languageId: "json"),
    DeclaredType(uti: "com.netscape.javascript-source", pathExtension: "js", languageId: "javascript"),
]
```

Расширения с `NONE` из резолвера — **не добавлять как системные**; они пойдут собственным UTI в Task 5 (пометить списком в комментарии).

- [ ] **Step 6: Запустить — зелёный**

Run: `swift test --filter QuickLookersSettingsKitTests`
Expected: PASS.

- [ ] **Step 7: Коммит**

```bash
git add Sources/QuickLookersSettingsKit/DeclaredTypes.swift \
  Tests/QuickLookersSettingsKitTests/ResolutionTests.swift
git commit -m "feat(settings): код-набор перехвата и системные UTI из UTType"
```

---

### Task 5: Объявить типы в расширении (`QLSupportedContentTypes` + свои UTI)

Цель: внести добытые системные UTI в `QLSupportedContentTypes`, а для расширений без системного UTI объявить свои через `UTExportedTypeDeclarations`; учесть итоги спайков (исключить типы, которые система не отдаёт).

**Files:**
- Modify: `project.yml` (блок `QuickLookersPreview.info` + хостовые `UTExportedTypeDeclarations`)

**Interfaces:**
- Consumes: список UTI из `DeclaredTypes.all` (Task 4) и итоги спайков (Task 3).

- [ ] **Step 1: Внести системные UTI в `QLSupportedContentTypes`**

В `project.yml`, в `QuickLookersPreview` → `info` → `NSExtension` → `NSExtensionAttributes` → `QLSupportedContentTypes`, перечислить **точные** системные UTI из `DeclaredTypes.all`, **исключив** типы, которые по Спайку B система удерживает за собой.

- [ ] **Step 2: Объявить свои UTI для расширений без системного типа**

Для каждого расширения с `NONE` (из Task 4 шаг 2) добавить в **хост-таргет** `UTExportedTypeDeclarations` (П6): `UTTypeIdentifier` (`com.quicklookers.<lang>-source`), `UTTypeConformsTo` (`public.source-code` или `public.plain-text`), `UTTypeTagSpecification` → `public.filename-extension` → расширение. Эти же `UTTypeIdentifier` добавить в `QLSupportedContentTypes` расширения и в `DeclaredTypes.all` (вернуться в Task 4-файл и дописать строки с этими UTI).

- [ ] **Step 3: Перегенерировать и собрать**

Run:
```bash
xcodegen generate
xcodebuild -project QuickLookers.xcodeproj -scheme QuickLookers \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Коммит**

```bash
git add project.yml Sources/QuickLookersSettingsKit/DeclaredTypes.swift
git commit -m "feat(preview): объявить расширенный набор UTI (системные + свои)"
```

---

### Task 6: Сквозная проверка перехвата и обновление документации

Цель: убедиться, что пробел в Finder реально перехватывает расширенный набор, и привести документацию в соответствие.

**Files:**
- Modify: `CLAUDE.md` (текущее состояние), `README.md` (статус)
- Modify: `docs/superpowers/specs/2026-06-27-quicklookers-design.md` (отметить выполненное по Слою 1/2, если уместно)

- [ ] **Step 1: Запустить хост из Xcode (⌘R)**

Это регистрирует расширение у `pkd` (CLI-сборки недостаточно).

- [ ] **Step 2: Проверить перехват на наборе файлов**

Нажать пробел в Finder на файлах нескольких языков из код-набора (например `.py`, `.rs`, `.go`, `.ts`, `.vue`, `.yml`). Убедиться: показывается наше превью с подсветкой; для vue встроенные блоки раскрашены. Зафиксировать в логе расширения тёплый/холодный показ (`/usr/bin/log stream --info --predicate 'subsystem == "com.quicklookers.preview"'`).

- [ ] **Step 3: Проверить «отдать ОС»**

Нажать пробел на типе, который мы **не** объявляли (например `.pdf`, `.png`) — показывается родное превью macOS. Подтверждает, что необъявленное остаётся за системой.

- [ ] **Step 4: Обновить документацию**

В `CLAUDE.md` (раздел «Текущее состояние») и `README.md` (таблица статуса): отметить, что подключена полная библиотека (≈218 языков, 54 темы) и расширен перехват в Finder код-набором. Указать на заметку спайков.

- [ ] **Step 5: Прогнать тесты пакета напоследок**

Run: `swift test`
Expected: PASS (31+ тестов).

- [ ] **Step 6: Коммит**

```bash
git add CLAUDE.md README.md docs/superpowers/specs/2026-06-27-quicklookers-design.md
git commit -m "docs: полная библиотека и расширенный перехват — состояние и статус"
```

---

## Self-review (проведён)

**Покрытие спеки:** Слой 1 → Task 1–2; Слой 2 (UTI, добыча, свои UTI) → Task 4–5; спайки A/B/C → Task 3; тестирование/замеры → Task 2 (бенчмарк), Task 6 (end-to-end); «что не входит» — не затронуто. Все разделы спеки имеют задачу.

**Плейсхолдеры:** строки UTI намеренно добываются резолвером (Task 4 шаг 2) и подставляются в Task 4 шаг 5 / Task 5 — это не «TODO», а защита от выдумывания; в спеке это зафиксировано как принцип (С3). Имена id языков сверяются с библиотекой (Task 4 шаг 1). Спайки — исследовательские по природе, шаги конкретны.

**Согласованность типов:** `qlRegisterLang`(массив) ↔ `extract` пишет массив ↔ `FileCatalogSource` читает массив (id из имени файла) — согласованы (Task 1). `collectLangs` использует `embeddedLangs` — поле подтверждено осмотром. `DeclaredType(uti:pathExtension:languageId:)` — существующая сигнатура, не меняется. `previewLanguageId`/`languageId(forPathExtension:)` — существующие, расширяется только данные.
