# Сайдкар-каталог (vsix-aware) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Убрать обход всех 218 грамматик (~41 МБ) при загрузке каталога настроек, читая маленький сайдкар `catalog.json`; полный обход оставить фоллбэком.

**Architecture:** Шаг сборки `extract-resources.mjs` пишет `catalog.json` (`{languages:[{id,displayName}], themes:[{id,displayName,isDark}]}`) из тех же данных, что уже читает при извлечении ресурсов. `FileCatalogSource` принимает список URL сайдкаров: есть валидные — каталог из их слияния, нет — существующий обход директорий. Список сайдкаров — задел под будущий импорт `.vsix` (приложение сегодня передаёт один встроенный).

**Tech Stack:** Swift 6.3 / SwiftPM (macOS 13+), XCTest; Node + esbuild для шага сборки JS.

## Global Constraints

- **TDD строго**: падающий тест → запуск (падает) → реализация → запуск (зелёный) → коммит, по одному маленькому шагу.
- **Каталог/настройки — в `QuickLookersSettingsKit`**, не знают про Shiki/JSC.
- **Всё офлайн**: сайдкар — в ресурсах пакета.
- `catalog.json` — **артефакт сборки**: генерится `extract-resources.mjs`, руками не правят (как `shiki-bundle.js`).
- **Фоллбэк-обход директорий НЕ удаляется** — он страховка.
- Слияние сайдкаров: дедуп по `id`, **последний в списке перекрывает**; итог сортируется по `id`.
- Поведение каталога никогда не пустеет из-за проблем с сайдкаром.
- Коммиты по-русски, формат `feat(...)`/`test(...)`/`docs:`, трейлер `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.

---

### Task 1: `FileCatalogSource` читает сайдкар (слияние + фоллбэк)

Чистая Swift-логика, тестируется `swift test` на временных фикстурах. Не зависит от настоящего артефакта и от `EngineResources`.

**Files:**
- Modify: `Sources/QuickLookersSettingsKit/CatalogSource.swift`
- Test: `Tests/QuickLookersSettingsKitTests/CatalogSourceTests.swift`

**Interfaces:**
- Consumes: `Catalog`, `LanguageInfo`, `ThemeInfo` из `Catalog.swift` (без изменений).
- Produces: `FileCatalogSource.init(grammarsDirectory: URL, themesDirectory: URL, sidecarURLs: [URL] = [])`. Формат сайдкара: JSON-объект `{ "languages": [{"id": String, "displayName": String}], "themes": [{"id": String, "displayName": String, "isDark": Bool}] }`. Метод `loadCatalog() throws -> Catalog` без изменений сигнатуры.

- [ ] **Step 1: Написать падающие тесты сайдкара**

Добавить в `Tests/QuickLookersSettingsKitTests/CatalogSourceTests.swift` (внутри класса, рядом с существующими; хелпер `makeTempDir()` уже есть):

```swift
    private func writeSidecar(_ json: String, to dir: URL) throws -> URL {
        let url = dir.appendingPathComponent("catalog-\(UUID().uuidString).json")
        try json.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func test_sidecarPresent_readsFromSidecarNotDirectories() throws {
        let dir = try makeTempDir()
        // Директории грамматик/тем намеренно пусты — если каталог не пуст,
        // значит данные пришли из сайдкара, а не из обхода.
        let grammars = try makeTempDir()
        let themes = try makeTempDir()
        let sidecar = try writeSidecar(#"""
        {"languages":[{"id":"swift","displayName":"Swift"}],
         "themes":[{"id":"dark-plus","displayName":"Dark Plus","isDark":true}]}
        """#, to: dir)

        let source = FileCatalogSource(grammarsDirectory: grammars, themesDirectory: themes,
                                       sidecarURLs: [sidecar])
        let catalog = try source.loadCatalog()

        XCTAssertEqual(catalog.languages, [LanguageInfo(id: "swift", displayName: "Swift")])
        XCTAssertEqual(catalog.themes, [ThemeInfo(id: "dark-plus", displayName: "Dark Plus", isDark: true)])
    }

    func test_noSidecar_fallsBackToDirectoryScan() throws {
        let grammars = try makeTempDir()
        let themes = try makeTempDir()
        try #"[{"name":"json","displayName":"JSON"}]"#
            .write(to: grammars.appendingPathComponent("json.json"), atomically: true, encoding: .utf8)
        // sidecarURLs пуст → должен сработать обход директорий.
        let source = FileCatalogSource(grammarsDirectory: grammars, themesDirectory: themes,
                                       sidecarURLs: [])
        let catalog = try source.loadCatalog()
        XCTAssertEqual(catalog.languages, [LanguageInfo(id: "json", displayName: "JSON")])
    }

    func test_malformedSidecar_fallsBackToDirectoryScan() throws {
        let dir = try makeTempDir()
        let grammars = try makeTempDir()
        let themes = try makeTempDir()
        try #"[{"name":"json","displayName":"JSON"}]"#
            .write(to: grammars.appendingPathComponent("json.json"), atomically: true, encoding: .utf8)
        let bad = try writeSidecar("{ not valid json", to: dir)

        let source = FileCatalogSource(grammarsDirectory: grammars, themesDirectory: themes,
                                       sidecarURLs: [bad])
        let catalog = try source.loadCatalog()
        // Битый сайдкар проигнорирован → фоллбэк-обход.
        XCTAssertEqual(catalog.languages, [LanguageInfo(id: "json", displayName: "JSON")])
    }

    func test_twoSidecars_lastOverridesByID() throws {
        let dir = try makeTempDir()
        let grammars = try makeTempDir()
        let themes = try makeTempDir()
        let base = try writeSidecar(#"""
        {"languages":[{"id":"swift","displayName":"Swift"},{"id":"json","displayName":"JSON"}],
         "themes":[{"id":"dark-plus","displayName":"Dark Plus","isDark":true}]}
        """#, to: dir)
        let imported = try writeSidecar(#"""
        {"languages":[{"id":"swift","displayName":"Swift (custom)"}],
         "themes":[{"id":"dark-plus","displayName":"Dark Plus (custom)","isDark":true}]}
        """#, to: dir)

        let source = FileCatalogSource(grammarsDirectory: grammars, themesDirectory: themes,
                                       sidecarURLs: [base, imported])
        let catalog = try source.loadCatalog()

        XCTAssertEqual(catalog.languages, [
            LanguageInfo(id: "json", displayName: "JSON"),
            LanguageInfo(id: "swift", displayName: "Swift (custom)"),
        ])
        XCTAssertEqual(catalog.themes,
                       [ThemeInfo(id: "dark-plus", displayName: "Dark Plus (custom)", isDark: true)])
    }
```

- [ ] **Step 2: Запустить — убедиться, что не компилируется/падает**

Run: `swift test --filter CatalogSourceTests`
Expected: ошибка компиляции — у `init` нет параметра `sidecarURLs`.

- [ ] **Step 3: Реализовать сайдкар-чтение в `FileCatalogSource`**

Заменить тело `CatalogSource.swift` (начиная со `struct FileCatalogSource`) на:

```swift
/// Каталог из сайдкаров `catalog.json` или, если их нет/они битые, из обхода
/// директорий грамматик/тем. Сайдкар — расширяемый индекс: список URL сливается
/// (последний перекрывает по `id`), что готовит путь под будущий импорт .vsix.
public struct FileCatalogSource: CatalogSource {
    private let grammarsDirectory: URL
    private let themesDirectory: URL
    private let sidecarURLs: [URL]

    public init(grammarsDirectory: URL, themesDirectory: URL, sidecarURLs: [URL] = []) {
        self.grammarsDirectory = grammarsDirectory
        self.themesDirectory = themesDirectory
        self.sidecarURLs = sidecarURLs
    }

    private struct GrammarEntry: Decodable { let name: String; let displayName: String? }
    private struct ThemeMeta: Decodable { let name: String; let displayName: String?; let type: String? }

    private struct Sidecar: Decodable {
        struct Language: Decodable { let id: String; let displayName: String }
        struct Theme: Decodable { let id: String; let displayName: String; let isDark: Bool }
        let languages: [Language]
        let themes: [Theme]
    }

    public func loadCatalog() throws -> Catalog {
        if let catalog = catalogFromSidecars() { return catalog }
        return try catalogFromDirectories()
    }

    /// Каталог из слияния валидных сайдкаров; nil, если ни одного валидного нет.
    private func catalogFromSidecars() -> Catalog? {
        let sidecars = sidecarURLs.compactMap { url -> Sidecar? in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? JSONDecoder().decode(Sidecar.self, from: data)
        }
        guard !sidecars.isEmpty else { return nil }

        var langs: [String: LanguageInfo] = [:]
        var themes: [String: ThemeInfo] = [:]
        for sidecar in sidecars {   // порядок списка → последний перекрывает по id
            for l in sidecar.languages {
                langs[l.id] = LanguageInfo(id: l.id, displayName: l.displayName)
            }
            for t in sidecar.themes {
                themes[t.id] = ThemeInfo(id: t.id, displayName: t.displayName, isDark: t.isDark)
            }
        }
        return Catalog(languages: langs.values.sorted { $0.id < $1.id },
                       themes: themes.values.sorted { $0.id < $1.id })
    }

    /// Фоллбэк: метаданные из самих файлов грамматик/тем (страховка, если
    /// сайдкара нет). Тот же путь чтения позже использует импортёр .vsix.
    private func catalogFromDirectories() throws -> Catalog {
        let languages = try jsonFiles(in: grammarsDirectory).compactMap { url -> LanguageInfo? in
            let id = url.deletingPathExtension().lastPathComponent
            guard let entries = try? JSONDecoder().decode([GrammarEntry].self,
                                                           from: Data(contentsOf: url))
            else { return nil }
            // Главная грамматика — запись с name == id (в массиве может быть не первой:
            // напр. у vue она идёт последней, после встроенных html/css/js).
            return LanguageInfo(id: id,
                                displayName: entries.first { $0.name == id }?.displayName ?? id)
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

Оставить вверху файла без изменений: `import Foundation`, протокол `CatalogSource` и его docstring.

- [ ] **Step 4: Запустить — зелёный**

Run: `swift test --filter CatalogSourceTests`
Expected: PASS — новые 4 теста + существующие (`testReadsLanguagesAndThemesWithMetadata`, `testDisplayNameFallsBackToName`, `test_grammarDisplayNameFromArrayEntry`, `test_catalogLoadsFullLibrary`) проходят.

- [ ] **Step 5: Commit**

```bash
git add Sources/QuickLookersSettingsKit/CatalogSource.swift Tests/QuickLookersSettingsKitTests/CatalogSourceTests.swift
git commit -m "$(cat <<'EOF'
feat(settings): FileCatalogSource читает сайдкар с фоллбэком на обход

sidecarURLs: список сайдкаров catalog.json; есть валидные — каталог из их
слияния (последний перекрывает по id), нет/битые — прежний обход директорий.
Задел под импорт .vsix.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Шаг сборки генерирует `catalog.json` + доступ к ресурсу

Меняем JS-генератор, регенерируем артефакт, объявляем его ресурсом и даём к нему доступ из движка; интеграционный тест проверяет настоящий сайдкар и его паритет с обходом.

**Files:**
- Modify: `js/extract-resources.mjs`
- Modify: `Package.swift:15-19` (добавить ресурс)
- Modify: `Sources/QuickLookersEngine/EngineResources.swift`
- Create: `Sources/QuickLookersEngine/Resources/catalog.json` (генерится скриптом)
- Test: `Tests/QuickLookersSettingsKitTests/CatalogSourceTests.swift`

**Interfaces:**
- Consumes: `FileCatalogSource.init(grammarsDirectory:themesDirectory:sidecarURLs:)` из Task 1.
- Produces: `QuickLookersEngineResources.catalogSidecarURL() -> URL?` (nil, если файла нет). Артефакт `Resources/catalog.json` формата из Task 1.

- [ ] **Step 1: Добавить генерацию `catalog.json` в скрипт**

В `js/extract-resources.mjs` собрать метаданные в циклах и записать сайдкар. Заменить два цикла и финальный лог на:

```js
const languages = []
const themes = []

// Грамматика: модуль экспортирует массив [главная + встроенные]. Пишем целиком,
// а в сайдкар — id + displayName главной записи (name == id), как читает фоллбэк.
for (const id of GRAMMARS) {
  const mod = await import(`@shikijs/langs/${id}`)
  const arr = Array.isArray(mod.default) ? mod.default : [mod.default]
  writeFileSync(`${grammarsDir}/${id}.json`, JSON.stringify(arr))
  const main = arr.find((g) => g.name === id)
  languages.push({ id, displayName: main?.displayName ?? id })
  console.log(`grammar ${id} <- entries=${arr.length}`)
}

// Тема: модуль экспортирует один объект.
for (const id of THEMES) {
  const mod = await import(`@shikijs/themes/${id}`)
  const theme = mod.default
  writeFileSync(`${themesDir}/${id}.json`, JSON.stringify(theme))
  themes.push({
    id: theme.name,
    displayName: theme.displayName ?? theme.name,
    isDark: theme.type === 'dark',
  })
  console.log(`theme ${id} <- name=${theme.name}`)
}

// Сайдкар-каталог: маленький индекс метаданных, чтобы окно настроек не читало
// все ~41 МБ грамматик. Артефакт сборки — руками не править.
writeFileSync(`${grammarsDir}/../catalog.json`,
  JSON.stringify({ languages, themes }))
console.log(`catalog <- languages=${languages.length} themes=${themes.length}`)

console.log('resources extracted')
```

(`${grammarsDir}/../catalog.json` = `Sources/QuickLookersEngine/Resources/catalog.json`.)

- [ ] **Step 2: Регенерировать ресурсы**

Run:
```bash
cd js && npm install && node extract-resources.mjs && cd ..
```
Expected: в выводе строки `grammar … <- entries=…` (218 шт.), `theme … <- name=…` (54 шт.) и в конце `catalog <- languages=218 themes=54`. Создан файл `Sources/QuickLookersEngine/Resources/catalog.json`. Файлы грамматик/тем перезаписаны идентично (детерминированный `JSON.stringify`) → в `git status` новый только `catalog.json`.

Проверка формата:
```bash
node -e "const c=require('./Sources/QuickLookersEngine/Resources/catalog.json'); console.log(c.languages.length, c.themes.length, JSON.stringify(c.languages.find(l=>l.id==='swift')), JSON.stringify(c.themes.find(t=>t.id==='dark-plus')))"
```
Expected: `218 54 {"id":"swift","displayName":"Swift"} {"id":"dark-plus","displayName":...,"isDark":true}`

- [ ] **Step 3: Объявить `catalog.json` ресурсом пакета**

В `Package.swift` в массив `resources` таргета `QuickLookersEngine` (строки 15–19) добавить строку:

```swift
                .copy("Resources/catalog.json"),
```

Итог:
```swift
            resources: [
                .copy("Resources/shiki-bundle.js"),
                .copy("Resources/grammars"),
                .copy("Resources/themes"),
                .copy("Resources/catalog.json"),
            ]
```

- [ ] **Step 4: Дать доступ к сайдкару из движка**

В `Sources/QuickLookersEngine/EngineResources.swift` добавить метод в `enum QuickLookersEngineResources` (после `themesDirectory()`):

```swift
    /// URL встроенного сайдкар-каталога или nil, если он не собран
    /// (тогда потребитель откатывается на обход директорий).
    public static func catalogSidecarURL() -> URL? {
        Bundle.module.url(forResource: "catalog", withExtension: "json")
    }
```

- [ ] **Step 5: Написать падающий интеграционный тест на настоящий сайдкар**

В `Tests/QuickLookersSettingsKitTests/CatalogSourceTests.swift` добавить хелпер и два теста:

```swift
    /// Каталог из настоящего встроенного сайдкара.
    private func realSidecarCatalog() throws -> Catalog {
        let sidecar = try XCTUnwrap(QuickLookersEngineResources.catalogSidecarURL())
        return try FileCatalogSource(
            grammarsDirectory: QuickLookersEngineResources.grammarsDirectory(),
            themesDirectory: QuickLookersEngineResources.themesDirectory(),
            sidecarURLs: [sidecar]).loadCatalog()
    }

    func test_realSidecar_loadsFullLibrary() throws {
        let catalog = try realSidecarCatalog()
        XCTAssertEqual(catalog.languages.count, 218)
        XCTAssertEqual(catalog.themes.count, 54)
    }

    func test_realSidecar_matchesDirectoryScan() throws {
        // Сайдкар и фоллбэк-обход должны давать идентичный каталог.
        XCTAssertEqual(try realSidecarCatalog(), try realCatalog())
    }
```

- [ ] **Step 6: Запустить — зелёный**

Run: `swift test --filter CatalogSourceTests`
Expected: PASS — все тесты, включая `test_realSidecar_loadsFullLibrary` (218/54) и `test_realSidecar_matchesDirectoryScan` (паритет сайдкара и обхода).

- [ ] **Step 7: Commit**

```bash
git add js/extract-resources.mjs Package.swift Sources/QuickLookersEngine/EngineResources.swift Sources/QuickLookersEngine/Resources/catalog.json Tests/QuickLookersSettingsKitTests/CatalogSourceTests.swift
git commit -m "$(cat <<'EOF'
feat(engine): генерация сайдкар-каталога catalog.json на шаге сборки

extract-resources.mjs пишет маленький catalog.json (id+displayName языков,
id+displayName+isDark тем); объявлен ресурсом, доступен через
catalogSidecarURL(). Интеграционный тест: 218/54 и паритет с обходом.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Подключить сайдкар в приложении + обновить документацию

Окно настроек начинает читать сайдкар; снимаем follow-up про эффективность каталога.

**Files:**
- Modify: `App/SettingsModel.swift:31-35`
- Modify: `CLAUDE.md`
- Modify: `README.md`

**Interfaces:**
- Consumes: `QuickLookersEngineResources.catalogSidecarURL()` и `FileCatalogSource(...sidecarURLs:)` из Task 2.
- Produces: ничего (конечный потребитель).

- [ ] **Step 1: Передать сайдкар в `FileCatalogSource`**

В `App/SettingsModel.swift` заменить блок построения источника (строки 31–35):

```swift
        do {
            let source = FileCatalogSource(
                grammarsDirectory: try QuickLookersEngineResources.grammarsDirectory(),
                themesDirectory: try QuickLookersEngineResources.themesDirectory())
            loadedCatalog = try source.loadCatalog()
        } catch {
```

на:

```swift
        do {
            // Каталог из встроенного сайдкара; если его нет — FileCatalogSource
            // сам откатится на обход директорий.
            let source = FileCatalogSource(
                grammarsDirectory: try QuickLookersEngineResources.grammarsDirectory(),
                themesDirectory: try QuickLookersEngineResources.themesDirectory(),
                sidecarURLs: [QuickLookersEngineResources.catalogSidecarURL()].compactMap { $0 })
            loadedCatalog = try source.loadCatalog()
        } catch {
```

- [ ] **Step 2: Проверить сборку приложения**

Run:
```bash
xcodegen generate && xcodebuild -project QuickLookers.xcodeproj -scheme QuickLookers \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Обновить CLAUDE.md**

В `CLAUDE.md` в разделе «Текущее состояние» убрать абзац-follow-up, начинающийся со слов **«Follow-up (эффективность каталога):»** (он описывал нерешённую проблему обхода 41 МБ). Вместо него добавить короткую строку в описание фазы 5 или отдельным пунктом:

```
**Сайдкар-каталог** — **реализовано** (спека `docs/superpowers/specs/2026-06-29-sidecar-catalog-design.md`, план `docs/superpowers/plans/2026-06-29-sidecar-catalog.md`). Окно настроек читает маленький `Resources/catalog.json` (генерится `extract-resources.mjs`) вместо обхода всех 218 грамматик (~41 МБ); полный обход остаётся фоллбэком. Сайдкар — расширяемый индекс (список URL, слияние с перекрытием по `id`) под будущий импорт `.vsix`.
```

Также в разделе «Структура» в строку `EngineResources.swift` и в блок `Resources/` добавить упоминание `catalog.json` (артефакт сборки):

```
    catalog.json                       # СОБИРАЕТСЯ extract-resources.mjs: индекс {languages,themes}, не править вручную
```

- [ ] **Step 4: Обновить README.md**

В `README.md` в таблице состояния (строки 11–17) в строку про главное приложение добавить, что каталог грузится из сайдкара; и убрать/не оставлять подразумеваемую проблему медленной загрузки, если упомянута. Конкретно — в строке `| Главное приложение + настройки + App Group |` дополнить статус:

```
| Главное приложение + настройки + App Group | три вкладки работают (Форматы / Темы / Сопоставление); каталог из сайдкара catalog.json |
```

- [ ] **Step 5: Commit**

```bash
git add App/SettingsModel.swift CLAUDE.md README.md
git commit -m "$(cat <<'EOF'
feat(app): окно настроек читает сайдкар-каталог; docs

SettingsModel передаёт встроенный catalog.json в FileCatalogSource — каталог
больше не обходит 41 МБ грамматик. Снят follow-up про эффективность каталога.

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
Expected: все тесты пакета зелёные (53 прежних + 6 новых сайдкар-тестов).

Затем — **REQUIRED SUB-SKILL**: `superpowers:finishing-a-development-branch` для влития `feat/sidecar-catalog` в `main`.
