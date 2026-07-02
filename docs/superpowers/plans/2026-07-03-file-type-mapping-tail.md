# Хвост сопоставления файл→язык (Задача 5b) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Довести перехват в Finder до «хвоста» — безрасширенных конфигов (Dockerfile, Makefile) и расширений, которым macOS не даёт полезного листового UTI (kt, kts, graphql, gql, dart, nim, zig, ts, r), — не ломая уже работающий Слой A/B.

**Architecture:** Задача — почти целиком **конфигурация маршрутизации** в `project.yml`, а не новый код: движок и `PreviewViewController` уже маршрутизируют через `resolvePreview` (язык по имени/расширению из `associations.json`) и уже корректно отказываются от бинаря (чтение UTF-8 бросает → системный дженерик). Добавляем три механизма перехвата: (2) невод `public.data` для безрасширенных; (1a) объявление СУЩЕСТВУЮЩИХ системных UTI для расширений с «чужим» листом (ts=видео, r=Rez); (1b) ОДИН собственный экспортируемый UTI на все свободные (`dyn.*`) расширения.

**Tech Stack:** XcodeGen (`project.yml` → Info.plist), macOS UniformTypeIdentifiers, Swift 6 / SwiftPM (SettingsKit/PreviewKit тесты), QuickLook Preview extension.

## Global Constraints

- Отвечать пользователю и писать комментарии/коммиты **по-русски**, простым языком. Коммиты формата `feat(preview): …`/`test(…): …`/`docs: …`, трейлер `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.
- Ветка `feat/file-type-mapping` (не `main` напрямую).
- **XcodeGen-артефакты не править руками** (`.xcodeproj`, `*.entitlements`, `PreviewExtension/Info.plist`, `App/Info.plist`) — источник истины `project.yml`, потом `xcodegen generate`.
- **`QuickLookersSettingsKit` не зависит от движка** — URL ресурсов передаёт вызывающий.
- TDD строго там, где есть чистая логика: падающий тест → запуск (падает) → реализация → зелёный → коммит.
- Не трогать `.mcp.json`, `.code-index/`, `icon/` (предсуществующие, не наши).
- **Точный листовой UTI**: `QLSupportedContentTypes` ловит по точному листу, конформанс вверх не работает. Родителя (`public.source-code`) объявлять бесполезно.
- Живой перехват в Finder регистрируется ТОЛЬКО запуском хоста из Xcode (⌘R), не CLI-сборкой.
- **Отдельный этап (НЕ входит сюда):** переработка вкладки «Просмотр в Finder» и управление полным списком языков (включая импортированный `edwinkofler.vscode-assorted-languages`).

## Железные факты Спайка E (основание плана)

- **Тега UTI на целое имя файла НЕТ** (только `filenameExtension`/`mimeType`) → безрасширенные (`Dockerfile`) ловятся ТОЛЬКО неводом `public.data` + логика по имени внутри расширения.
- **Свой UTI забирает лишь СВОБОДНОЕ расширение** (`dyn.*`). Занятое (системой/чужим приложением) — не отнять; принятое ограничение.
- **Мы побеждаем систему при точном листе** (Спайк B: `public.json`/`public.yaml` показались нашим превью) → для ts/r объявляем ИХ системный UTI, а язык берём по расширению.
- **`public.data` ловит только листовой `public.data`** (безрасширенные + generic), НЕ ловит `dyn.*` (неизвестные расширения — им нужен свой UTI). Бинарь приходит, но не-UTF-8 бросает → системный дженерик (жадность управляемая).

## File Structure

- `Scripts/audit-extension-utis.swift` — **создать**: dev-утилита (не билд-шаг). Читает `associations.json`, резолвит `UTType(filenameExtension:)` по каждому расширению, печатает категорию (специфический системный UTI / `dyn.*` / `public.data`/`public.plain-text`). Даёт данные для Задач 3–4.
- `docs/superpowers/notes/2026-07-03-extension-uti-audit.md` — **создать**: зафиксированный вывод утилиты (категоризация хвоста) на чистой машине.
- `project.yml` — **править**: (Task 2) `public.data` в `QLSupportedContentTypes`; (Task 3) системные UTI для ts/r и др.; (Task 4) хосту `info`-блок с `UTExportedTypeDeclarations` (один тип `com.quicklookers.source-code` со списком свободных расширений) + этот UTI в `QLSupportedContentTypes`.
- `Tests/QuickLookersSettingsKitTests/PreviewResolutionTests.swift` — **править**: явные проверки маршрутизации по имени/расширению для хвоста.
- `Tests/QuickLookersPreviewKitTests/CodeTrimTests.swift` — **править**: проверка, что не-UTF-8 префикс бросает (отказ от бинаря).
- `docs/superpowers/specs/2026-07-02-file-type-language-mapping-design.md` — **править** (Task 5): раздел Слой A дополнить механизмами хвоста, снять «Отложено 5b».
- `CLAUDE.md` — **править** (Task 5): состояние фазы.

Никакого нового рантайм-кода в `PreviewViewController`/`resolvePreview` не требуется — только конфигурация и тесты уже существующей логики.

---

### Task 1: Dev-утилита аудита UTI расширений

Категоризация хвоста нужна фактами, а не на глаз: какие расширения система метит `dyn.*` (→ свой UTI), а каким даёт «чужой» системный лист (→ объявляем его). Утилита переиспользуется в будущем этапе переработки вкладки.

**Files:**
- Create: `Scripts/audit-extension-utis.swift`
- Create: `docs/superpowers/notes/2026-07-03-extension-uti-audit.md`

**Interfaces:**
- Consumes: `Sources/QuickLookersEngine/Resources/associations.json` (`{version, languages:[{id, extensions[], filenames[]}]}`).
- Produces: печать в stdout строк `ext<TAB>leafUTI<TAB>category` и итоговых списков; ручной перенос в заметку.

- [ ] **Step 1: Написать утилиту**

```swift
// Scripts/audit-extension-utis.swift
// Запуск: swift Scripts/audit-extension-utis.swift Sources/QuickLookersEngine/Resources/associations.json
import Foundation
import UniformTypeIdentifiers

let path = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "Sources/QuickLookersEngine/Resources/associations.json"
struct Assoc: Decodable { struct Lang: Decodable { let id: String; let extensions: [String]?; let filenames: [String]? }
                          let languages: [Lang] }
let data = try Data(contentsOf: URL(fileURLWithPath: path))
let assoc = try JSONDecoder().decode(Assoc.self, from: data)

// Уникальные расширения → к какому языку ведут (для отчёта).
var extToLang: [String: String] = [:]
for l in assoc.languages { for e in (l.extensions ?? []) { extToLang[e.lowercased()] = extToLang[e.lowercased()] ?? l.id } }

func category(_ ext: String) -> (uti: String, cat: String) {
    guard let t = UTType(filenameExtension: ext) else { return ("nil", "нет типа") }
    let id = t.identifier
    if id.hasPrefix("dyn.") { return (id, "dyn — свой UTI (1b)") }
    if id == "public.data" { return (id, "public.data — невод (2)") }
    if id == "public.plain-text" { return (id, "public.plain-text — уже в неводе") }
    if id == "public.item" || id == "public.content" { return (id, "generic — невод (2)") }
    return (id, "системный лист — объявить (1a)")
}

var own: [String] = [], declare: [(String, String)] = []
for ext in extToLang.keys.sorted() {
    let (uti, cat) = category(ext)
    print("\(ext)\t\(uti)\t\(cat)\t→\(extToLang[ext] ?? "?")")
    if cat.contains("1b") { own.append(ext) }
    if cat.contains("1a") { declare.append((ext, uti)) }
}
print("\n=== 1b свои UTI (dyn) ===\n" + own.joined(separator: ", "))
print("\n=== 1a объявить системный UTI ===")
for (e, u) in declare { print("  .\(e) → \(u)  (\(extToLang[e] ?? "?"))") }
```

- [ ] **Step 2: Запустить и убедиться, что печатает категории**

Run: `swift Scripts/audit-extension-utis.swift`
Expected: список строк `ext<TAB>uti<TAB>категория`, в конце — блоки «1b свои UTI» и «1a объявить системный UTI». Ключевые ожидания (чистая машина без sbarex): `kt/kts/graphql/gql/dart/nim/zig → dyn` (1b); `ts → public.mpeg-2-transport-stream`, `r → com.apple.rez-source` (1a).

- [ ] **Step 3: Зафиксировать вывод в заметку**

Создать `docs/superpowers/notes/2026-07-03-extension-uti-audit.md` с датой, версией macOS, полной таблицей вывода и явными итоговыми списками для 1a и 1b. Пометить: снимок на чистой машине; на машинах пользователей возможны отличия (занятые расширения — принятое ограничение).

- [ ] **Step 4: Коммит**

```bash
git add Scripts/audit-extension-utis.swift docs/superpowers/notes/2026-07-03-extension-uti-audit.md
git commit -m "feat(tooling): утилита аудита листовых UTI расширений + снимок категоризации хвоста

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Невод `public.data` — безрасширенные конфиги (механизм 2)

`Dockerfile`/`Makefile` и прочие безрасширенные приходят с листом `public.data`; ловим их точным объявлением `public.data`, а язык `resolvePreview` берёт по имени файла. Бинарь тоже придёт, но чтение UTF-8 бросит → системный дженерик.

**Files:**
- Modify: `project.yml` (блок `QLSupportedContentTypes` расширения `QuickLookersPreview`, ~стр. 120–150)
- Modify: `Tests/QuickLookersSettingsKitTests/PreviewResolutionTests.swift`
- Modify: `Tests/QuickLookersPreviewKitTests/CodeTrimTests.swift`

**Interfaces:**
- Consumes: `resolvePreview(fileName:pathExtension:associations:settings:) -> PreviewResolution` (`.highlight(languageId:)`/`.neutral`); `readBoundedPrefix(of:maxBytes:) throws -> String`.
- Produces: ничего для последующих задач (изолированное изменение конфигурации + тесты).

- [ ] **Step 1: Написать падающий тест маршрутизации безрасширенных (SettingsKit)**

Добавить в `PreviewResolutionTests.swift` (если таких проверок ещё нет):

```swift
func test_resolve_dockerfile_byName_highlightsDocker() throws {
    let assoc = FileTypeAssociations.loaded(from: associationsTestURL())  // helper уже есть в тестах
    let r = resolvePreview(fileName: "Dockerfile", pathExtension: "",
                           associations: assoc, settings: .default)
    XCTAssertEqual(r, .highlight(languageId: "docker"))
}

func test_resolve_unknownExtensionlessName_isNeutral() throws {
    let assoc = FileTypeAssociations.loaded(from: associationsTestURL())
    let r = resolvePreview(fileName: ".gitignore", pathExtension: "",
                           associations: assoc, settings: .default)
    XCTAssertEqual(r, .neutral)   // .gitignore нет в датасете → нейтральный текст, не бросок
}
```

- [ ] **Step 2: Запустить — убедиться, что падает (или уже проходит)**

Run: `swift test --filter PreviewResolutionTests`
Expected: если тестов ещё не было — FAIL со ссылкой на отсутствующие методы. Если `resolvePreview` уже так себя ведёт — тесты сразу зелёные; тогда это фиксация контракта, переходим дальше.

- [ ] **Step 3: Реализация не требуется (логика уже есть) — при красноте поправить только тест-хелпер**

Если упало на `associationsTestURL()`/`.equatable` — убедиться, что `PreviewResolution` уже `Equatable` (он enum со связанным значением; при необходимости добавить `extension PreviewResolution: Equatable {}` В ТЕСТАХ, не в проде, если в проде его нет). Никакой прод-логики не менять.

- [ ] **Step 4: Написать тест отказа от бинаря (PreviewKit)**

Добавить в `CodeTrimTests.swift`:

```swift
func test_readBoundedPrefix_nonUTF8_throws() throws {
    let dir = FileManager.default.temporaryDirectory
    let url = dir.appendingPathComponent("blob-\(UUID().uuidString)")
    let bytes: [UInt8] = [0x00, 0x01, 0xFF, 0xFE, 0x00, 0x42]
    try Data(bytes).write(to: url)
    defer { try? FileManager.default.removeItem(at: url) }
    XCTAssertThrowsError(try readBoundedPrefix(of: url, maxBytes: 1024))
}
```

- [ ] **Step 5: Запустить — зелёный (подтверждает отказ от бинаря)**

Run: `swift test --filter CodeTrimTests`
Expected: PASS. Если `readBoundedPrefix` НЕ бросает на не-UTF-8 (вернул мусор) — это дефект: поправить `readBoundedPrefix`, чтобы декодировал `String(data:encoding:.utf8)` и бросал `EngineError`/`CocoaError` при `nil`. Тогда бинарь по неводу уйдёт в системный дженерик, а не покажет кракозябры.

- [ ] **Step 6: Добавить `public.data` в невод**

В `project.yml`, в массив `QLSupportedContentTypes` расширения, ПОСЛЕ `public.plain-text` вставить:

```yaml
              # Невод безрасширенных конфигов (Dockerfile, Makefile): их точный лист —
              # public.data (проверено URLResourceValues; тега на имя файла нет). Внутри
              # resolvePreview красит по имени (docker/make) или нейтралью; бинарь (не-UTF-8)
              # бросает → системный дженерик. Неизвестные РАСШИРЕНИЯ (dyn.*) сюда НЕ попадают.
              - public.data
```

- [ ] **Step 7: Перегенерировать и собрать без подписи**

```bash
xcodegen generate
xcodebuild -project QuickLookers.xcodeproj -scheme QuickLookers -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 8: Коммит**

```bash
git add project.yml PreviewExtension/Info.plist Tests/QuickLookersSettingsKitTests/PreviewResolutionTests.swift Tests/QuickLookersPreviewKitTests/CodeTrimTests.swift
git commit -m "feat(preview): невод public.data — перехват безрасширенных конфигов (Dockerfile)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

- [ ] **Step 9: Живая проверка (пользователь, ⌘R)**

В Xcode ⌘R. На Рабочем столе создать `Dockerfile` (`FROM alpine`), `Makefile` (`all:\n\techo hi`), `blob` (бинарь). Пробел по каждому. Ожидание: `Dockerfile`/`Makefile` — наше превью с подсветкой (в логе `lang=docker`/`lang=make`); `blob` — системный дженерик (мы отказались). Лог: `/usr/bin/log stream --info --predicate 'subsystem == "com.quicklookers.preview"'`.

---

### Task 3: Объявление системных UTI для «чужетипных» расширений (механизм 1a)

`.ts` система метит как `public.mpeg-2-transport-stream` (видео), `.r` — как `com.apple.rez-source` (Apple Rez). Свой новый UTI на них может проиграть системному; но точный лист **мы** перехватываем (Спайк B). Объявляем ИХ системный UTI, а язык `resolvePreview` берёт по расширению (ts→typescript, r→r). Список UTI — из Task 1.

**Files:**
- Modify: `project.yml` (`QLSupportedContentTypes` расширения)
- Modify: `Tests/QuickLookersSettingsKitTests/PreviewResolutionTests.swift`

**Interfaces:**
- Consumes: точные системные UTI из отчёта Task 1 (`public.mpeg-2-transport-stream`, `com.apple.rez-source`, и любые другие категории «1a»).
- Produces: ничего для последующих задач.

- [ ] **Step 1: Тест — расширения ведут к правильному языку**

Добавить в `PreviewResolutionTests.swift`:

Добавить в `Tests/QuickLookersSettingsKitTests/ResolutionTests.swift` (хелпер URL — `QuickLookersEngineResources.associationsURL()`):

```swift
func test_resolve_1a_extensions_mapToLanguages() throws {
    let assoc = FileTypeAssociations.loaded(from: QuickLookersEngineResources.associationsURL())
    let cases: [(String, String)] = [("app.ts","typescript"), ("model.r","r"),
                                      ("u.pas","pascal"), ("page.html","html"),
                                      ("a.m","objective-c"), ("s.f90","fortran"),
                                      ("v.proto","proto")]
    for (name, lang) in cases {
        let ext = (name as NSString).pathExtension
        XCTAssertEqual(resolvePreview(fileName: name, pathExtension: ext,
                                      associations: assoc, settings: .default),
                       .highlight(languageId: lang), "\(name)")
    }
}
```

- [ ] **Step 2: Запустить**

Run: `swift test --filter ResolutionTests`
Expected: PASS (датасет содержит эти пары). Если какая-то пара упала — язык-id в датасете иной (сверься с `associations.json`: например objective-c/fortran/proto могут иметь другой id); поправь ОЖИДАНИЕ теста под реальный id датасета (не датасет). НЕ добавляй расширения-«ложные друзья».

- [ ] **Step 3: Добавить ВЫВЕРЕННЫЕ системные UTI в невод**

Аудит (Task 1) показал: категория 1a — минное поле. Объявляем ТОЛЬКО системные UTI, где тип и есть код/текст (чистый выигрыш), плюс два намеренных перехвата (`ts`/`r`, подтверждено пользователем). «Ложных друзей» (реальный не-код) и семантические расхождения — НЕ объявляем. В `project.yml`, в `QLSupportedContentTypes` расширения, добавить дословно:

```yaml
              # Выверенные системные UTI (категория 1a аудита): тип = код/текст, объявление —
              # чистый выигрыш; язык берётся по расширению в resolvePreview. Точный лист мы
              # перехватываем (Спайк B: побеждаем систему). Список выверен вручную —
              # docs/.../2026-07-03-extension-uti-audit.md. НЕ добавлять «ложных друзей»
              # (реальный не-код): .app/.pf/.dds/.gp/.pot(x)/.sdc/.mts/.mod/.pls/.as/.url/.exs/
              # .scpt/.storyboard/.xib, а также семантические расхождения (.l/.yy/.i/.cl) и
              # вне-области (markdown/csv).
              - public.ada-source                       # .ada/.adb/.ads → ada
              - com.apple.applescript.text              # .applescript → applescript (НЕ .scpt — бинарь)
              - public.bash-script                      # .bash → shellscript
              - public.ksh-script                       # .ksh → shellscript
              - public.zsh-script                       # .zsh → shellscript
              - public.shell-script                     # .sh → shellscript
              - com.apple.terminal.shell-script         # .command/.tool → shellscript
              - public.css                              # .css → css
              - public.html                             # .html/.htm → html
              - public.xhtml                            # .xhtml/.xht → html
              - public.xml                              # .xml → xml
              - public.patch-file                       # .diff/.patch → diff
              - public.fortran-source                   # .f/.for → fortran
              - public.fortran-77-source                # .f77 → fortran
              - public.fortran-90-source                # .f90 → fortran
              - public.fortran-95-source                # .f95 → fortran
              - public.pascal-source                    # .pas → pascal
              - public.objective-c-source               # .m → objective-c
              - public.objective-c-plus-plus-source     # .mm → objective-cpp
              - public.assembly-source                  # .s → asm
              - public.nasm-assembly-source             # .nasm → asm
              - public.protobuf-source                  # .proto → proto
              - com.microsoft.hlsl                      # .hlsl → hlsl
              - org.khronos.glsl-source                 # .glsl → glsl
              - org.khronos.glsl.fragment-shader        # .frag/.fsh (и .fs=fsharp — по расширению)
              - org.khronos.glsl.vertex-shader          # .vert/.vsh (и .vs)
              - org.khronos.glsl.geometry-shader        # .geom/.gsh (и .gs=genie)
              - com.microsoft.typescript                # .tsx → tsx (public.tsx лист может не совпадать)
              # Два намеренных перехвата «ложных друзей» (подтверждено пользователем):
              # редкие настоящие .ts-видео/.r-Rez деградируют до дженерика — принято.
              - public.mpeg-2-transport-stream          # .ts → typescript
              - com.apple.rez-source                    # .r  → r
```

- [ ] **Step 4: Перегенерировать и собрать**

```bash
xcodegen generate
xcodebuild -project QuickLookers.xcodeproj -scheme QuickLookers -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Коммит**

```bash
git add project.yml PreviewExtension/Info.plist Tests/QuickLookersSettingsKitTests/ResolutionTests.swift
git commit -m "feat(preview): выверенные системные UTI (Pascal/Fortran/GLSL/Obj-C/HTML/… + ts/r) — язык по расширению

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

- [ ] **Step 6: Живая проверка (пользователь, ⌘R)**

⌘R. Создать `app.ts` (`const x: number = 1`) и `model.r` (`x <- 1`). Пробел. Ожидание: наше превью, лог `lang=typescript`/`lang=r`. Если `.ts` показал видео-иконку/системное — значит система на этой машине держит лист жёстче: зафиксировать как ограничение конкретной машины, не блокировать.

---

### Task 4: Один собственный UTI на все свободные (`dyn.*`) расширения (механизм 1b)

`kt/kts/graphql/gql/dart/nim/zig/…` система метит `dyn.*` (свободны). Объявляем в хосте ОДИН экспортируемый тип `com.quicklookers.source-code` со списком этих расширений (тег `public.filename-extension`), конформный к `public.source-code`+`public.plain-text`, и вписываем его в невод. Лист свободных расширений станет нашим (Спайк E, подтверждено вживую на `.nim`). Список — из Task 1.

**Files:**
- Modify: `project.yml` (у хоста `QuickLookers`: `GENERATE_INFOPLIST_FILE: NO` + `info`-блок с `UTExportedTypeDeclarations`; у расширения — UTI в `QLSupportedContentTypes`)
- Modify: `Tests/QuickLookersSettingsKitTests/PreviewResolutionTests.swift`

**Interfaces:**
- Consumes: список `dyn.*`-расширений из отчёта Task 1.
- Produces: зарегистрированный UTI `com.quicklookers.source-code` (тег = свободные расширения). Дальше не используется другими задачами.

- [ ] **Step 1: Тест — свободные расширения ведут к своим языкам**

Добавить в `Tests/QuickLookersSettingsKitTests/ResolutionTests.swift` (реальное имя файла; хелпер URL — `QuickLookersEngineResources.associationsURL()`, как уже принято в этом файле после Task 2):

```swift
func test_resolve_freeExtensions_mapToLanguages() throws {
    let assoc = FileTypeAssociations.loaded(from: QuickLookersEngineResources.associationsURL())
    let cases: [(String, String)] = [("a.kt","kotlin"), ("a.kts","kotlin"),
                                      ("a.graphql","graphql"), ("a.gql","graphql"),
                                      ("a.dart","dart"), ("a.nim","nim"), ("a.zig","zig")]
    for (name, lang) in cases {
        let ext = (name as NSString).pathExtension
        XCTAssertEqual(resolvePreview(fileName: name, pathExtension: ext,
                                      associations: assoc, settings: .default),
                       .highlight(languageId: lang), "\(name)")
    }
}
```

- [ ] **Step 2: Запустить**

Run: `swift test --filter ResolutionTests`
Expected: PASS (датасет содержит все эти пары — подтверждено grep'ом).

- [ ] **Step 3: Расширить утилиту аудита — выдавать список свободных расширений в виде YAML-тегов**

Свободных (`dyn.*`) расширений — **652** (пользователь подтвердил: берём ВЕСЬ свободный список, не подмножество). Вручную такой список не набирают — пусть утилита из Task 1 его печатает. Добавить в `Scripts/audit-extension-utis.swift` в самый конец режим по флагу `--emit-tags`: если он есть, печатать ТОЛЬКО отсортированный список свободных (категория 1b) расширений как YAML-элементы для flow-массива (через запятую, в квадратных скобках) — плюс `.nim` (артефакт среды, но целевое 1b). Вставить после существующего вывода:

```swift
if CommandLine.arguments.contains("--emit-tags") {
    // Только свободные (dyn.*) расширения — готовый flow-массив для public.filename-extension.
    let tags = own.sorted()
    print("[" + tags.joined(separator: ", ") + "]")
}
```

(`own` уже собран выше по категории 1b. `.nim` на этой машине попал в 1a как артефакт старой сборки — добавь его в `own` явной строкой перед печатью, если его там нет: `var tags = own; if !tags.contains("nim") { tags.append("nim") }; tags.sort()`.)

- [ ] **Step 4: Хосту — явный `info`-блок с экспортом типа (полный список из утилиты)**

Получить список: `swift Scripts/audit-extension-utis.swift --emit-tags` — он печатает flow-массив всех свободных расширений. В `project.yml` у таргета `QuickLookers`: в `settings.base` заменить `GENERATE_INFOPLIST_FILE: YES` на `NO`; после блока `settings:` добавить `info:` (генерируемый plist так расширить нельзя — нужен явный; проверено спайком: `CFBundlePackageType=APPL` и запуск сохраняются). В `public.filename-extension` вставить ВЫВОД утилиты дословно (flow-массив; НЕ набирать руками):

```yaml
        GENERATE_INFOPLIST_FILE: NO   # был YES; нужен явный Info.plist для UTExportedTypeDeclarations
    info:
      path: App/Info.plist
      properties:
        CFBundleShortVersionString: "$(MARKETING_VERSION)"
        CFBundleVersion: "$(CURRENT_PROJECT_VERSION)"
        # Один экспортируемый тип на ВСЕ СВОБОДНЫЕ (dyn.*) расширения (652 шт., пользователь
        # подтвердил полный список). Лист свободного расширения становится нашим (Спайк E).
        # Язык внутри берётся по расширению из associations.json — один UTI на много языков
        # норм (это маршрутизация, не семантика). Список ГЕНЕРИТСЯ:
        # `swift Scripts/audit-extension-utis.swift --emit-tags` (снимок в
        # docs/.../2026-07-03-extension-uti-audit.md, категория 1b). Руками не редактировать.
        UTExportedTypeDeclarations:
          - UTTypeIdentifier: com.quicklookers.source-code
            UTTypeDescription: Source code (QuickLookers)
            UTTypeConformsTo: [public.source-code, public.plain-text]
            UTTypeTagSpecification:
              public.filename-extension: [<ВЫВОД `--emit-tags` ДОСЛОВНО — 652 расширения>]
```

- [ ] **Step 5: Расширению — объявить наш UTI в неводе**

В `project.yml`, в `QLSupportedContentTypes` расширения, добавить:

```yaml
              # Наш экспортируемый тип на свободные (dyn.*) расширения — см. UTExportedTypeDeclarations хоста.
              - com.quicklookers.source-code
```

- [ ] **Step 6: Перегенерировать и проверить, что хост-плист корректен**

```bash
xcodegen generate
/usr/libexec/PlistBuddy -c "Print :CFBundlePackageType" App/Info.plist    # ждём APPL
/usr/libexec/PlistBuddy -c "Print :UTExportedTypeDeclarations:0:UTTypeIdentifier" App/Info.plist  # com.quicklookers.source-code
xcodebuild -project QuickLookers.xcodeproj -scheme QuickLookers -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```
Expected: `APPL`, `com.quicklookers.source-code`, `** BUILD SUCCEEDED **`.

- [ ] **Step 7: Коммит**

```bash
git add project.yml PreviewExtension/Info.plist App/Info.plist Scripts/audit-extension-utis.swift Tests/QuickLookersSettingsKitTests/ResolutionTests.swift
git commit -m "feat(preview): свой UTI com.quicklookers.source-code на все свободные расширения (652)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

- [ ] **Step 8: Живая проверка (пользователь, ⌘R)**

⌘R (регистрирует и тип, и расширение). Создать `a.kt` (`fun main() {}`), `a.graphql` (`type Q { a: Int }`), `a.dart`, `a.nim`, `a.zig`. Пробел. Ожидание: наше превью с подсветкой (лог `lang=kotlin`/`graphql`/`dart`/`nim`/`zig`). Если какое-то расширение занято сторонним просмотрщиком на этой машине — оно спорное (принятое ограничение), зафиксировать.

---

### Task 5: Документация

**Files:**
- Modify: `docs/superpowers/specs/2026-07-02-file-type-language-mapping-design.md`
- Modify: `CLAUDE.md`

- [ ] **Step 1: Обновить спеку**

В разделе про Слой A: описать три механизма хвоста (невод `public.data`; системные UTI для ts/r; собственный `com.quicklookers.source-code` на свободные) и железные факты Спайка E (нет тега на имя файла; занятое расширение не отнять; побеждаем систему при точном листе). Снять статус «Отложено (Task 5b)».

- [ ] **Step 2: Обновить CLAUDE.md**

В блоке фазы 7 (сопоставление файл→язык) дописать: хвост закрыт Задачей 5b — механизмы 1a/1b/2; хост получил явный `info`-блок с `UTExportedTypeDeclarations` (артефакт XcodeGen `App/Info.plist`); ссылка на заметку аудита и Спайк E. В «Структуре» упомянуть `Scripts/audit-extension-utis.swift`.

- [ ] **Step 3: Коммит**

```bash
git add docs/superpowers/specs/2026-07-02-file-type-language-mapping-design.md CLAUDE.md
git commit -m "docs: хвост сопоставления (Задача 5b) — механизмы перехвата и итоги Спайка E

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Self-Review

**Spec coverage:** Спека требовала два слоя + отложенный хвост (5b). План закрывает хвост тремя механизмами (Tasks 2–4), аудит даёт категоризацию (Task 1), доки синхронизируются (Task 5). Переработка вкладки — намеренно вне плана (отдельный этап, по слову пользователя).

**Placeholder scan:** Точные UTI-строки для 1a/1b помечены как «из отчёта Task 1» с базовым минимумом прямо в YAML — не заглушки, а данные, которые Task 1 подтверждает фактически перед Tasks 3–4. Тестовый код и YAML приведены целиком.

**Type consistency:** `resolvePreview(fileName:pathExtension:associations:settings:) -> PreviewResolution` (`.highlight(languageId:)`/`.neutral`) — единая сигнатура во всех тестах (сверено с `PreviewViewController.swift`). `readBoundedPrefix(of:maxBytes:)` — из `CodeTrim.swift`. `FileTypeAssociations.loaded(from:)` — из `FileTypeAssociations.swift`.

**Риск-заметка:** Tasks 3–4 подтверждаются в основном ЖИВОЙ проверкой (перехват — поведение macOS, юнитом не берётся); чистая логика (`resolvePreview`) покрыта тестами. Порядок: Task 1 даёт факты → 2 (нейтральнее всего) → 3 → 4 (правит хост-плист) → 5.
