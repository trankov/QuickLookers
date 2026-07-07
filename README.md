# QuickLookers

**[Русский](#русский)** · **[English](#english)**

Превью кода по пробелу в Finder на macOS — **визуально как в VS Code / Cursor**.
Тот же движок подсветки ([Shiki](https://shiki.style)), те же грамматики и темы.

Code preview on Space in Finder on macOS — **looking just like VS Code / Cursor**.
The same highlighting engine ([Shiki](https://shiki.style)), the same grammars and themes.

<!-- Скриншоты / Screenshots
     TODO: положить картинки в docs/screenshots/ и раскомментировать:
     ![Превью по пробелу в Finder](docs/screenshots/preview.png)
     ![Окно настроек — Темы](docs/screenshots/settings-themes.png)
-->

> 🖼️ **Скриншоты будут здесь.** _Screenshots go here._

---

## Русский

### Что это

macOS-приложение, возвращающее полноразмерное превью кода по пробелу в Finder — взамен
сломавшихся старых плагинов QuickLook (`.qlgenerator`). Главная цель — **визуально один-в-один
как в VS Code / Cursor**: подсветка построена на настоящих TextMate-грамматиках и темах VS Code
через движок [Shiki](https://shiki.style) в JavaScriptCore, а не на самописных приближениях.
Markdown — вне области продукта (для него есть FluxMarkdown).

- **218 языков** и **54 темы** «из коробки».
- Импорт своих тем и грамматик из `.vsix`, а также темы и шрифта прямо из установленного
  VS Code / Cursor.
- Настройка сопоставления «расширение файла → язык» масками.

### Состояние

Проект в активной разработке.

| Подсистема | Статус |
|---|---|
| Движок рендеринга (`QuickLookersEngine`) | готов; вся библиотека Shiki (218 языков, 54 темы), встроенные грамматики |
| Расширение QuickLook Preview | перехват языков по проверенным UTI, тема из настроек; перенос строк, обрезка, тёплый WebView, кэш HTML |
| Главное приложение + настройки + App Group | три вкладки (Темы / Форматы / Просмотр в Finder), импорт из редактора и `.vsix` |
| Расширение Thumbnail (иконки) | отложено до решения о целесообразности |

### Архитектура

- **Главное приложение** — настройки, импорт тем/грамматик из VS Code / Cursor и `.vsix`,
  управление кэшем. Менеджер библиотеки.
- **Расширение QuickLook Preview** — в песочнице, только рисует готовое.
- **Общий контейнер (App Group)** — темы, грамматики, кэш HTML, настройки.

Подсветка: `код + язык + тема → HTML` через Shiki в JavaScriptCore, затем статичный показ в
WKWebView с выключенным JavaScript. Полный дизайн — `docs/superpowers/specs/2026-06-27-quicklookers-design.md`.

### Требования

- **macOS 13** или новее.
- **Swift 6 / Xcode 26**.
- **[XcodeGen](https://github.com/yonaskolb/XcodeGen)**: `brew install xcodegen`.
- **Apple ID** для подписи (достаточно бесплатного — см. ниже про ограничения).

> Node.js нужен **только** для пересборки JS-бандла Shiki. Готовый бандл уже в ресурсах и
> коммитится, поэтому для обычной сборки Node не требуется.

### Сборка и запуск

**Шаг 1. Сгенерировать проект Xcode (обязательно, первым делом).**

```bash
xcodegen generate
```

`QuickLookers.xcodeproj` **намеренно не хранится в репозитории** (он в `.gitignore` как артефакт
XcodeGen). Пока не выполнишь эту команду — открывать в Xcode будет нечего.

**Шаг 2. Подставить свой Team ID.**

В проекте зашит Team ID автора (`5FVC5YT2B5`). Замени его на **свой** (Xcode → Settings →
Accounts → твой аккаунт → Team ID) в четырёх местах:

- `project.yml` — `DEVELOPMENT_TEAM` (строка ~33);
- `project.yml` — `com.apple.security.application-groups` у **хоста** (строка ~113);
- `project.yml` — `com.apple.security.application-groups` у **расширения** (строка ~146);
- `Sources/QuickLookersSettingsKit/SettingsStore.swift` — `quickLookersAppGroupId` (строка ~40).

Префикс App Group **обязан** совпадать с твоим Team ID — иначе сборка не подпишется. После правки
`project.yml` перегенерируй проект (`xcodegen generate`).

**Шаг 3. Собрать и запустить из Xcode.**

Открой `QuickLookers.xcodeproj`, выбери схему **QuickLookers** и нажми **⌘R**.

> ⚠️ **Важно:** превью в Finder надёжно регистрируется в системе **только запуском хоста из
> Xcode (⌘R)**. Двойной клик по собранному `.app`, `lsregister` или `pluginkit` для регистрации
> расширения QuickLook **недостаточны**. Это ограничение самой macOS, а не проекта.

**Тесты пакета** (чистая логика, без Xcode):

```bash
swift test
```

### Ограничения распространения (важно)

У автора **нет платного аккаунта Apple Developer**, поэтому сборки **не нотаризованы**:

- Готовый скачанный бинарник Gatekeeper по умолчанию заблокирует («не удаётся проверить
  разработчика»). Поэтому **основной способ пользоваться проектом — собрать его самому** по
  инструкции выше, со своим бесплатным Apple ID.
- Из-за требования «регистрация только через ⌘R» (Шаг 3) сборка-из-исходников — не прихоть,
  а единственный надёжный путь, чтобы превью по пробелу заработало.

### Документация

- `docs/superpowers/specs/` — дизайн-документы.
- `docs/superpowers/plans/` — планы реализации по подсистемам.
- `docs/superpowers/notes/` — замеры производительности и показания spike.
- `CLAUDE.md` — рабочее руководство, договорённости и грабли проекта.

### Лицензия

**GPL-3.0** — см. [`LICENSE`](LICENSE). Коротко: бери и меняй свободно, но любой производный
продукт обязан **сохранять авторство** и **оставаться открытым** под той же GPL-3.0.

Встроенные сторонние компоненты (Shiki, грамматики, темы, датасет linguist) — под своими
лицензиями, см. [`THIRD-PARTY-NOTICES.md`](THIRD-PARTY-NOTICES.md).

---

## English

### What it is

A macOS app that brings back full-size code preview on Space in Finder — replacing the broken
legacy `.qlgenerator` QuickLook plugins. The goal is to look **pixel-for-pixel like VS Code /
Cursor**: highlighting is built on real TextMate grammars and VS Code themes via the
[Shiki](https://shiki.style) engine running in JavaScriptCore, not on hand-rolled approximations.
Markdown is out of scope (FluxMarkdown covers that).

- **218 languages** and **54 themes** out of the box.
- Import your own themes and grammars from `.vsix`, or pull the theme and font straight from an
  installed VS Code / Cursor.
- Configurable "file extension → language" mapping with glob patterns.

### Status

The project is under active development.

| Subsystem | Status |
|---|---|
| Rendering engine (`QuickLookersEngine`) | done; full Shiki library (218 languages, 54 themes), embedded grammars |
| QuickLook Preview extension | interception via verified UTIs, theme from settings; line wrap, truncation, warm WebView, HTML cache |
| Main app + settings + App Group | three tabs (Themes / Formats / Finder preview), import from editor and `.vsix` |
| Thumbnail extension (icons) | deferred pending a feasibility decision |

### Architecture

- **Main app** — settings, theme/grammar import from VS Code / Cursor and `.vsix`, cache
  management. The library manager.
- **QuickLook Preview extension** — sandboxed, only renders the prepared HTML.
- **Shared container (App Group)** — themes, grammars, HTML cache, settings.

Highlighting: `code + language + theme → HTML` via Shiki in JavaScriptCore, then a static render
in WKWebView with JavaScript disabled. Full design: `docs/superpowers/specs/2026-06-27-quicklookers-design.md`.

### Requirements

- **macOS 13** or newer.
- **Swift 6 / Xcode 26**.
- **[XcodeGen](https://github.com/yonaskolb/XcodeGen)**: `brew install xcodegen`.
- An **Apple ID** for signing (a free one is enough — see distribution limits below).

> Node.js is needed **only** to rebuild the Shiki JS bundle. The prebuilt bundle is committed to
> the repo, so a normal build does not require Node.

### Build & Run

**Step 1. Generate the Xcode project (mandatory, do this first).**

```bash
xcodegen generate
```

`QuickLookers.xcodeproj` is **deliberately not stored in the repo** (it is `.gitignore`d as an
XcodeGen artifact). Until you run this, there is nothing to open in Xcode.

**Step 2. Set your own Team ID.**

The author's Team ID (`5FVC5YT2B5`) is baked into the project. Replace it with **yours** (Xcode →
Settings → Accounts → your account → Team ID) in four places:

- `project.yml` — `DEVELOPMENT_TEAM` (~line 33);
- `project.yml` — `com.apple.security.application-groups` for the **host** (~line 113);
- `project.yml` — `com.apple.security.application-groups` for the **extension** (~line 146);
- `Sources/QuickLookersSettingsKit/SettingsStore.swift` — `quickLookersAppGroupId` (~line 40).

The App Group prefix **must** match your Team ID, otherwise the build won't sign. After editing
`project.yml`, regenerate the project (`xcodegen generate`).

**Step 3. Build & run from Xcode.**

Open `QuickLookers.xcodeproj`, select the **QuickLookers** scheme and press **⌘R**.

> ⚠️ **Important:** the Finder preview reliably registers with the system **only when the host is
> run from Xcode (⌘R)**. A double-click on the built `.app`, `lsregister`, or `pluginkit` are
> **not enough** to register the QuickLook extension. This is a macOS limitation, not the
> project's.

**Package tests** (pure logic, no Xcode):

```bash
swift test
```

### Distribution limits (important)

The author has **no paid Apple Developer account**, so builds are **not notarized**:

- A prebuilt downloaded binary is blocked by Gatekeeper by default ("cannot verify the
  developer"). So the **primary way to use this project is to build it yourself** using the steps
  above, with your own free Apple ID.
- Because of the "registration only via ⌘R" requirement (Step 3), building from source is not a
  whim — it is the only reliable way to get the Space preview working.

### License

**GPL-3.0** — see [`LICENSE`](LICENSE). In short: use and modify freely, but any derivative
product must **keep attribution** and **stay open source** under the same GPL-3.0.

Bundled third-party components (Shiki, grammars, themes, the linguist dataset) are under their own
licenses, see [`THIRD-PARTY-NOTICES.md`](THIRD-PARTY-NOTICES.md).
