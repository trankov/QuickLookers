# Импорт темы и шрифта из редактора + витрина тем — дизайн

> Дата: 2026-06-30. Ветка: `feat/editor-theme-font-import`.
> Статус: проектирование (брейншторм завершён, ожидает вычитки пользователем).

## Цель

Дать пользователю одним нажатием получить превью «как в его редакторе»: скопировать
из установленного VS Code-подобного редактора его **активную тему** и **шрифт**, сразу
применить их к превью. Плюс переработать вкладку «Темы» в живую витрину и добавить
ручную настройку шрифта.

Фича делится на три логические части, реализуются именно в этом порядке:
1. **Шрифт** — модель настроек шрифта + применение в превью + контрол в UI.
2. **Импорт из редактора** — обнаружение редакторов, чтение активной темы и шрифта, применение.
3. **Витрина** — переработка вкладки «Темы»: живое превью, единый список, блок импорта.

## Не входит в область

- Markdown (для него FluxMarkdown).
- Импорт грамматик из редактора — **не нужен**: встроенные грамматики у нас уже все есть
  (218 языков). Из редактора берём только тему и шрифт.
- Миграция старых настроек. Продукт ещё не выпущен, реальных пользователей нет —
  пишем новую модель напрямую, без оглядки на прошлый формат `settings.json`.
- Расширение Thumbnail (отложено отдельным решением).

---

## Модель доступа (зафиксировано)

Хост-приложение **остаётся в песочнице** (App Sandbox обязателен — иначе ломается
регистрация расширения у `pkd`; см. грабли в CLAUDE.md). Доступ к данным редакторов —
через **два ленивых гранта** (powerbox + security-scoped bookmarks):

1. **Грант на `~`** (домашняя папка) — даёт `~/Library/Application Support/<Редактор>/User/settings.json`
   (активная тема + шрифт) и `~/<dataFolderName>/extensions` (JSON/`.tmTheme` пользовательских тем).
2. **Грант на `/Applications`** — даёт `…/X.app/Contents/Resources/app/product.json`
   (обнаружение редакторов + иконки + имена).

Оба запрашиваются **лениво**, при первом открытии меню «Из редактора», и сохраняются
как **app-scoped закладки** — повторно не спрашиваем. Это два диалога, пользователь
осознанно нажимает «ОК» дважды ради желаемого результата (решение по UX принято).

Entitlement `com.apple.security.files.bookmarks.app-scope` добавляется в `project.yml`
(оба нужных таргета). Существующий `files.user-selected.read-only` сохраняется.

**`.vsix`-импорт не меняется** и от этих грантов не зависит: он работает через
пофайловый выбор в `NSOpenPanel` (powerbox на один файл), как сейчас.

Почему это безопасно по части системных запросов: `Application Support` и dot-папки
**не** под защитой TCC (это не «Документы/Рабочий стол»), поэтому лишних диалогов
сверх наших двух не возникает.

---

## Находки спайка (вживую, 2026-06-30)

Прочитаны реальные `product.json` и `settings.json` установленных VS Code и Cursor.

### Подтверждено

- `product.json` лежит по фиксированному пути `Contents/Resources/app/product.json`
  и содержит тройку-маркер: `nameShort`, `nameLong`, `dataFolderName` (+ `applicationName`).
  Это манифест сборки Code-OSS — есть у всех форков.
- bundleId **ненадёжен**: у Cursor `darwinBundleIdentifier = com.todesktop.230313mzl4w4u92`.
  Поэтому детект — по `product.json`, а не по идентификатору.
- Папка данных под `~/Library/Application Support` = **`nameShort`** (`Code`, `Cursor`),
  проверено на диске. Папка расширений = `~/<dataFolderName>/extensions`
  (`~/.vscode/extensions`, `~/.cursor/extensions`).

### Подводный камень №1: `settings.json` — это JSONC, не JSON

Реальный `settings.json` Cursor **не парсится строгим JSON**: комментарии, висячие
запятые, сырые управляющие символы в строках. Строгий `JSONDecoder`/`JSONSerialization`
будет падать. Нужен устойчивый разбор JSONC (с учётом строк, не регулярками).

### Подводный камень №2: тема может быть `.tmTheme` (plist), а не JSON

Активная тема VS Code в спайке — «Seti Monokai: Original» из расширения
`smukkekim.theme-setimonokai`, а её файл — `./themes/SetiMonokai.tmTheme`, то есть
**старый TextMate-формат (plist XML)**, а не VS Code-JSON с `tokenColors`.
Наш `ThemeNormalizer` сейчас ждёт JSON. Значит, при чтении темы из расширения надо
различать `.json` (как сейчас) и `.tmTheme` (plist → объект-темы → общий нормализатор).
Это главный технический риск фичи.

Вывод: путь «искать тему в расширениях» — **обычный случай, а не редкий край**.

---

## Архитектура

Шесть узлов, каждый с одной ответственностью. Новые пакетные модули тестируются
`swift test`; склейка с powerbox/SwiftUI — в слое приложения.

### Узел 1 — модель настроек (`QuickLookersSettingsKit`)

`ThemeSelection` **упрощается** до одного активного id (без `followSystem`, без пары
светлая/тёмная). «Следование за системой» убрано осознанно: в VS Code авто-переключение
(`window.autoDetectColorScheme`) по умолчанию выключено, и два варианта выбора + тумблер —
лишняя сложность.

```swift
public struct FontSettings: Codable, Equatable {
    public var family: String?   // nil = шрифт по умолчанию
    public var size: Double?     // nil = размер по умолчанию
    public init(family: String?, size: Double?)
}

public struct ManagerSettings: Codable, Equatable {
    public var schemaVersion: Int
    public var settingsVersion: Int
    public var disabledLanguageIds: Set<String>
    public var activeThemeId: String          // заменяет ThemeSelection
    public var font: FontSettings
    public var previewDisabledLanguageIds: Set<String>
}

// default: activeThemeId = DefaultThemeIds.dark ("dark-plus"), font = FontSettings(nil, nil)
```

Расширению Preview больше не нужно знать про оформление системы — оно читает один
`activeThemeId`. Разрешение темы с откатом (если id нет в каталоге → дефолт) сохраняется
в `SettingsStore`, но упрощается под одно поле.

### Узел 2 — шрифт в превью (`QuickLookersPreviewKit`)

`previewPageHTML(...)` получает шрифт и размер и вшивает их в `<style>`:

```swift
public func previewPageHTML(highlighted: String, font: FontSettings,
                            truncatedNotice: String? = nil) -> String
```

CSS: `pre, code { font-family: <family>, ui-monospace, monospace; font-size: <N>px; }`.
Если `family == nil` — оставляем текущий моноширинный стек; если `size == nil` — текущий размер.

**Та же `PreviewPage`** используется и расширением (Finder), и живым превью приложения —
значит они гарантированно совпадают.

**Санитизация:** строку семейства из редактора чистим под CSS — оставляем только
безопасный набор символов (буквы, цифры, пробел, дефис, подчёркивание, запятая,
одинарная/двойная кавычка), всё прочее (в т. ч. `<`, `{`, `}`, `;`, перевод строки)
вырезаем. Всегда дописываем `monospace`-откат. Размер ограничиваем разумным диапазоном
(например, 6…48), отрицательные/абсурдные значения отбрасываем.

### Узел 3 — устойчивый разбор JSONC (`QuickLookersImportKit`)

```swift
public enum JSONCParser {
    /// JSONC → объект (Any) через нормализацию в строгий JSON.
    public static func object(from data: Data) throws -> Any
    /// JSONC → строгий JSON (Data) — для повторного хранения темы.
    public static func toStrictJSON(_ data: Data) throws -> Data
}
```

Удаляет `//`- и `/* */`-комментарии и висячие запятые **с учётом строковых литералов**
(внутри строк `//` и запятые не трогаем; учитываем экранирование `\"`). Терпимо
относится к управляющим символам внутри строк (экранирует или пропускает).

Применение:
- чтение `settings.json` редактора;
- чтение JSON-тем (`.json`/`.jsonc`) из расширений — и заодно закрывает латентную дыру
  существующего `.vsix`-пути (там тема хранится как есть и сейчас обломалась бы на JSONC).

### Узел 4 — загрузчик файла темы (`QuickLookersImportKit`)

```swift
public enum ThemeFileLoader {
    /// По расширению файла выбирает путь и возвращает СТРОГИЙ VS Code-JSON темы (Data),
    /// пригодный для ThemeNormalizer и движка.
    /// - .json/.jsonc → JSONCParser.toStrictJSON
    /// - .tmTheme/.plist → разбор plist (PropertyListSerialization) → объект-темы
    ///   { name, settings: [...] } → строгий JSON
    public static func loadStrictThemeJSON(fileURL: URL, fileExtension: String) throws -> Data
}
```

`.tmTheme` — plist XML с массивом `<settings>` (TextMate). Конвертируем в форму, которую
понимает Shiki: объект `{ "name": <...>, "settings": [ ... ] }` (Shiki принимает `settings`
как алиас `tokenColors`). Поле `colors` у tmTheme отсутствует — Shiki берёт фон/передний
план из первого `settings`-элемента без `scope`.

**Поддержка `.tmTheme` обязательна** — это не «по возможности», а требование: активные
темы редакторов реально приходят в этом формате (спайк это показал на «Seti Monokai»).
Цель первой задачи плана — короткий спайк, чтобы **зафиксировать рабочий способ
конвертации** (plist→объект→движок рисует), а не решить, поддерживать ли формат.
Если прямая форма `{ name, settings }` движку не подойдёт — подбираем правильное
преобразование (например, дораскладку `settings[0]` в `colors`), но `.tmTheme` должна
рисоваться. Молчаливого пропуска формата быть не должно.

### Узел 5 — обнаружение и чтение редакторов (новый модуль `QuickLookersEditorKit`, только хост)

Чистый, тестируемый модуль (на вход — пути/данные, powerbox-доступ обеспечивает слой
приложения). Три компонента:

```swift
public struct DetectedEditor: Equatable {
    public let appURL: URL
    public let nameShort: String       // папка под Application Support
    public let nameLong: String        // показываемое имя
    public let dataFolderName: String  // ".vscode", ".cursor" → ~/<...>/extensions
}

public enum EditorScanner {
    /// Обходит *.app в каталоге, читает product.json, оставляет VS Code-подобные.
    /// Маркер: product.json парсится и содержит nameShort+nameLong+dataFolderName.
    public static func scan(applicationsDir: URL) -> [DetectedEditor]
}

public struct EditorPreferences: Equatable {
    public let colorThemeLabel: String?   // workbench.colorTheme
    public let fontFamily: String?        // editor.fontFamily
    public let fontSize: Double?          // editor.fontSize
}

public enum EditorSettingsReader {
    /// Читает <appSupport>/<nameShort>/User/settings.json (JSONC) → нужные ключи.
    /// Папку проверяет по факту на диске (nameShort, при отсутствии — nameLong).
    public static func read(editor: DetectedEditor, appSupportDir: URL) -> EditorPreferences
}

public enum EditorThemeResolver {
    public enum Resolution: Equatable {
        case bundled(themeId: String)          // нашли в каталоге по displayName
        case custom(label: String, uiTheme: String, fileURL: URL)  // нашли в расширениях
        case notFound
    }
    /// 1) ищет тему по colorThemeLabel в нашем каталоге (по displayName);
    /// 2) иначе сканирует ~/<dataFolderName>/extensions: package.json →
    ///    contributes.themes[] (label/uiTheme/path) → совпадение по label.
    public static func resolve(label: String, catalog: ThemeCatalogLookup,
                               extensionsDir: URL) -> Resolution
}
```

Имена иконок/изображений берёт слой приложения (`NSWorkspace.icon(forFile:)` по `appURL`).
`product.json` — строгий JSON (это манифест сборки, не пользовательский файл), но читаем
через тот же терпимый путь на всякий случай.

### Узел 6 — гранты и закладки (слой приложения, хост)

```swift
@MainActor final class BookmarkStore {
    /// Возвращает URL с доступом; при отсутствии закладки — запрашивает через NSOpenPanel
    /// (preselect нужного каталога), сохраняет app-scoped закладку.
    func accessURL(for scope: AccessScope) -> URL?   // .home, .applications
    /// Обёртка start/stopAccessingSecurityScopedResource на время чтения.
    func withAccess<T>(_ scope: AccessScope, _ body: (URL) throws -> T) rethrows -> T?
}
```

Закладки храним в `UserDefaults`/файле приложения. При резолве «устаревшей» закладки
(`bookmarkDataIsStale`) — перезапрашиваем.

---

## Поток данных: «Из редактора»

1. Пользователь открывает меню **«Из редактора ▾»**.
2. `BookmarkStore` обеспечивает доступ к `/Applications` (грант при первом разе).
3. `EditorScanner.scan` → список `DetectedEditor` (пересканируем каждый раз — редакторы
   ставят/удаляют). Меню показывает имена + иконки.
4. Пользователь выбирает редактор.
5. `BookmarkStore` обеспечивает доступ к `~` (грант при первом разе).
6. `EditorSettingsReader.read` → активная тема (label) + шрифт/размер.
7. `EditorThemeResolver.resolve`:
   - `.bundled(themeId)` → просто выбираем эту тему;
   - `.custom(label, uiTheme, fileURL)` → `ThemeFileLoader.loadStrictThemeJSON` →
     `ThemeNormalizer.normalize` → сохраняем как импортированную тему (тот же путь и
     хранилище, что у `.vsix`: `ImportModel`/`ImportedLibrary`/сайдкар), получаем её id;
   - `.notFound` → понятное сообщение, шрифт всё равно применяем.
8. **Сразу применяем:** `model.update { $0.activeThemeId = id; $0.font = FontSettings(family, size) }`,
   `model.reloadCatalog()`. Превью моментально обновляется.
9. Меню возвращается в плейсхолдер «Из редактора…» (это действие, а не индикатор состояния;
   активное видно в списке тем).

Ошибки на любом шаге (нет доступа, битый файл, формат не поддержан) — мягкое сообщение
рядом с блоком импорта, без падения; уже применённое (например, шрифт) не откатываем.

---

## UI: вкладка «Темы» (по macos-design-guidelines)

Раскладка сверху вниз:

```
[Swift][JS][TS][JSON][Python][HTML][CSS]   ← Picker(.segmented), выбор языка запоминаем
┌─────────────────────────────────────────┐
│  ЖИВОЕ ПРЕВЬЮ (WKWebView, тот же движок)  │  тянется с окном
│  выбранная тема + выбранный шрифт/размер  │
└─────────────────────────────────────────┘
Шрифт: [SF Mono ▾]      Размер: [13 ⊟⊞]     ← Picker(моноширинные) + Stepper с полем
┌─────────────────────────────────────────┐
│ ○ Dark+ (default)                        │
│ ● GitHub Dark        импортирована   ✕   │  List(selection:), стрелки/Delete
│ ○ Monokai                                │
└─────────────────────────────────────────┘
[Импортировать .vsix…]      [Из редактора ▾]  ← кнопка + pop-up-меню
```

- **Языки** — `Picker(.segmented)` (HIG 3.3), выбор образца запоминается.
- **Превью** — `WKWebView` с реальным выводом движка (тема + шрифт); тянется по
  высоте/ширине (HIG 2.1). 5–7 показательных сниппетов кладём в ресурсы приложения,
  по одному на язык переключателя.
- **Шрифт** — `Picker` (pop-up) из установленных моноширинных семейств
  (`NSFontManager.availableFontFamilies`, отфильтровать моноширинные) + `Stepper`
  с числовым полем для размера. Шрифт из редактора, которого нет в системе, показываем
  как выбранный помеченный пункт (значение храним; превью откатится на monospace).
- **Список тем** — единый `List(selection:)` всех тем (встроенные + импортированные),
  одиночный выбор, навигация стрелками (HIG 5.7, 6.6). Строка импортированной темы —
  бейдж «импортирована» + удаление по наведению (HIG 6.1), через контекстное меню (6.2)
  и клавишу **Delete** (5.5). Встроенные темы не удаляются.
  **Это единый список → баг двойного появления импортированной темы исчезает по конструкции.**
- **Импорт** — слева кнопка `.vsix` (как сейчас), справа pop-up-меню «Из редактора»
  (ленивый запрос грантов + пересканирование при открытии).

### Окно

Сейчас `ContentView` фиксирован `.frame(width: 620, height: 420)` — это нарушает HIG 2.1
(окно должно быть изменяемым). Меняем на изменяемое под вертикальную раскладку:

- по умолчанию ≈ **580 × 680**;
- минимум ≈ **480 × 560**, максимума нет; превью растёт с окном.

Общий фрейм для всех трёх вкладок (спискам «Форматы»/«Просмотр» повышение тоже на пользу).

---

## Обработка ошибок (сводка)

- Нет грантов / отказ в диалоге → меню «Из редактора» без эффекта + подсказка.
- `settings.json` не читается/битый → пропускаем редактор с сообщением.
- Тема не найдена (`.notFound`) → сообщение, шрифт всё равно применяем.
- `.tmTheme` обязана конвертироваться и рисоваться (см. Узел 4) — это требование, не край;
  непредвиденно битый plist конкретного файла → сообщение по этому файлу, но формат в целом
  поддержан.
- Нет контейнера App Group (как и сейчас) → окно работает, предупреждение, без сохранения.

---

## Тестирование (TDD, по узлам)

- **JSONCParser** — комментарии (`//`, `/* */`), висячие запятые, `//` и запятые внутри
  строк (не трогать), экранированные кавычки, управляющие символы; на выходе — валидный
  строгий JSON. Фикстуры — урезанные куски реального `settings.json`.
- **ThemeFileLoader** — `.json` (чистый и JSONC) и `.tmTheme` (plist) → строгий JSON
  с `settings`/`name`; битый plist → ошибка.
- **EditorScanner** — каталог с фейковым `*.app/Contents/Resources/app/product.json`
  (валидный VS Code-подобный, не-VS Code, битый) → правильный отбор и поля.
- **EditorSettingsReader** — `settings.json` с/без нужных ключей, JSONC → корректные значения.
- **EditorThemeResolver** — bundled (по displayName), custom (через extensions/package.json),
  notFound.
- **FontSettings/ManagerSettings** — Codable round-trip, дефолты, разрешение темы с откатом.
- **previewPageHTML** — вшивание/санитизация семейства и размера, откаты при nil.

Слой приложения (BookmarkStore, меню, живое превью на WKWebView) проверяется вживую
запуском хоста из Xcode (⌘R) — как и прочая Xcode-обвязка.

---

## План реализации (порядок задач)

Соответствует выбранному порядку **шрифт → редакторы → витрина**:

1. **Спайк `.tmTheme`** — зафиксировать рабочую конвертацию plist→объект→движок рисует
   (формат обязателен; спайк ищет КАК, а не ЕСЛИ).
2. **Шрифт:** `FontSettings` в модели; `previewPageHTML(font:)` + санитизация; контрол
   шрифта в UI; расширение применяет шрифт.
3. **Модель темы:** `ThemeSelection` → `activeThemeId`; обновить `SettingsStore`,
   расширение, тесты.
4. **JSONCParser** + подключение к чтению тем (закрыть латентную дыру `.vsix`).
5. **ThemeFileLoader** (`.json` + `.tmTheme`).
6. **EditorKit:** Scanner / SettingsReader / ThemeResolver.
7. **BookmarkStore** + entitlement `bookmarks.app-scope` в `project.yml`.
8. **Витрина:** живое превью с сниппетами, единый список (фикс дубля), блок импорта
   с меню «Из редактора», размеры окна.

Детальный пошаговый план — отдельным документом через writing-plans после вычитки спеки.
