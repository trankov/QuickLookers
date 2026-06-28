# CLAUDE.md

Руководство для работы над проектом **QuickLookers**. Отвечать пользователю всегда по-русски, простым человеческим языком.

## Что это

macOS-приложение, возвращающее превью кода по пробелу в Finder (взамен сломавшихся старых QuickLook-плагинов `.qlgenerator`). Главное требование — **визуально один-в-один как в VS Code/Cursor**: тот же движок подсветки, те же грамматики и темы.

**Markdown — вне области продукта** (для него есть FluxMarkdown). Мы занимаемся только подсветкой кода.

## Архитектура (целевая)

Две части + общий контейнер:

- **Главное приложение** — GUI с настройками. Имеет сеть, читает конфиг VS Code/Cursor, управляет библиотекой тем/грамматик, импортом (`.vsix`), кэшем. **Менеджер**: скачивает/импортирует/нормализует.
- **Расширение QuickLook Preview** — полноразмерное превью по пробелу. В песочнице, без сети. **Потребитель**: берёт готовое и рисует.
- **App Group** — общий контейнер: темы, грамматики, кэш HTML, настройки. Единственное, что видит песочница расширений.

Третья часть — **расширение Thumbnail** (иконки в Finder) — **отложена** до решения о целесообразности (раздел «Отложено…» в дизайн-документе).

Подробности: `docs/superpowers/specs/2026-06-27-quicklookers-design.md`.

## Текущее состояние

Сделаны три подсистемы (все влиты в `main`: фазы 1–2 — ветка `feat/rendering-engine`, фаза 3 — `feat/manager-app-window`):

**1. Движок рендеринга** (Swift-пакет `QuickLookersEngine`) — **реализован** (план `docs/superpowers/plans/2026-06-27-quicklookers-rendering-engine.md`, все 6 задач + cleanup). Движок: `код + язык + тема → готовый HTML` через **Shiki** в **JavaScriptCore**. Shiki выбран потому, что использует те же TextMate-грамматики и VS Code-темы → совпадение с VS Code, а не «похоже». Точка входа — `QuickLookersEngineFactory.makeDefault() -> HighlightEngine`.

**2. Расширение Preview — тонкий вертикальный срез** — **работает end-to-end** (спека `docs/superpowers/specs/2026-06-28-preview-extension-thin-slice-design.md`, план `docs/superpowers/plans/2026-06-28-preview-extension-thin-slice.md`, все 5 задач). Пробел в Finder на `.swift`/`.json`/`.js` → полноразмерное превью с подсветкой VS Code Dark+. Xcode-проект на **XcodeGen** (`project.yml`): хост-приложение-заглушка + расширение QuickLook Preview, линкующее `QuickLookersEngine` и `QuickLookersPreviewKit`.

**3. Окно приложения-менеджера (фаза 3)** — **реализовано** (спека `docs/superpowers/specs/2026-06-28-manager-app-window-design.md`, все 9 задач). Новый пакетный таргет **`QuickLookersSettingsKit`**: модель настроек (`ManagerSettings`, opt-out по языкам), каталог языков/тем (`Catalog` + `FileCatalogSource`), хранилище `settings.json` (`SettingsStore`, атомарная запись, разрешение темы с откатом). Заведён **App Group** `5FVC5YT2B5.com.quicklookers` (префикс — Team ID, а не `group.`: убирает системный запрос «доступ к данным других приложений» на ненотаризованной сборке) у обоих таргетов; расширение Preview читает язык и тему из общего контейнера (хардкод `dark-plus` убран). Окно приложения — три вкладки SwiftUI: «Форматы подсветки», «Темы», «Сопоставление с типами файлов»; любое изменение сразу пишется в `settings.json`.

**4. Полная библиотека + расширенный перехват (фаза 4)** — **реализовано** (спека `docs/superpowers/specs/2026-06-28-full-library-and-intercept-design.md`, план `docs/superpowers/plans/2026-06-28-full-library-and-intercept.md`). Слой 1: вся библиотека Shiki — **218 языков и 54 темы** в бандле и каталоге. Файл грамматики теперь — **массив** [главная + встроенные грамматики]; движок при показе собирает встроенные языки (`embeddedLangs`, транзитивно) — vue/php красятся со встроенными блоками. **Ограничение:** ленивые встроенные (`embeddedLangsLazy`) не собираются, поэтому редкие вложенные блоки (например yaml-фрагмент внутри vue) могут остаться без подсветки — осознанный предел этой фазы. Слой 2: перехват в Finder расширен — в `QLSupportedContentTypes` объявлены **23 проверенных системных UTI** (резолвер `UTType(filenameExtension:)`, не выдуманные строки), перехватывается ~20 языков. Спайки на macOS 26 (заметка `docs/superpowers/notes/2026-06-28-intercept-spikes.md`): объявленный UTI **побеждает систему**; «не объявлено = остаётся системе»; рантайм-отказ даёт **системный дженерик-превью** (иконка+текст), не виснет. **Отложено (Task 5b):** собственные UTI (`UTExportedTypeDeclarations`) для расширений со сломанным/занятым системным UTI — `ts` (=видео MPEG-2), `r` (=Apple Rez), `kt`/`kts`/`graphql`/`gql` (=`dyn.*`), `dart` (=сторонний sbarex), `dockerfile` (по имени файла). Список и гипотезы по перехвату — в заметке спайков и в docstring `DeclaredTypes.swift`.

**5. Оптимизация показа (фаза 5)** — **реализовано и проверено вживую** (спека `docs/superpowers/specs/2026-06-29-preview-display-optimizations-design.md`, план `docs/superpowers/plans/2026-06-29-preview-display-optimizations.md`, 8 задач + рантайм-фиксы). Рычаги: **перенос длинных строк** (всегда включён — минифицированный JSON больше не уезжает за край); **обрезка** до 2000 строк с плашкой «показаны первые N строк» + защита от гигантских файлов (ограниченное чтение префикса при размере >2 МБ); **пул тёплых `WKWebView`**; **кэш готового HTML** (потолок 5 МБ, LRU по mtime файла). Ключ кэша — из атрибутов файла (путь+mtime+size) + язык+тема+потолок строк+версия бандла, без чтения содержимого; попадание минует чтение и движок (тёплое попадание ~1,4–10 мс). Чистая логика (обрезка, ключ/хранилище кэша, страница) — в `QuickLookersPreviewKit` под `swift test`; склейка с WebKit — в `PreviewViewController`. **Поведение на ошибке:** нечитаемый (не-UTF-8) файл бросает → системный дженерик-превью; ошибка кэша / нет контейнера — показ идёт без кэша, не ломается.

**Три рантайм-находки живых спайков** (детали — `docs/superpowers/notes/2026-06-29-preview-runtime-spikes.md`), их легко сломать обратно:
- **Кэш — в СВОЁМ контейнере расширения, не в App Group.** Песочница превью-расширения запрещает запись в групповой контейнер (kernel: `deny file-write-create`), он доступен расширению только на чтение (так читаются настройки). Кэш пишет/читает только расширение → `FileManager .cachesDirectory` (`~/Library/Containers/…PreviewExtension/Data/Library/Caches/QuickLookersHTML`).
- **`WKPreferences.inactiveSchedulingPolicy = .none`** (macOS 14+) на вебвью. Иначе вне окна WebKit усыпляет WebContent (jetsam 40) и первый показ после простоя ждёт пробуждения (~1,4 с, пустой экран). `.none` держит его тёплым (JS выключен — почти даром).
- **Пул вебвью, НЕ один общий.** Finder показывает превью параллельно (панель «Просмотр» + QuickLook, галерея); один вебвью не обслужит два показа сразу → континуация первого висит (бесконечный спиннер). Пул: каждому показу свой вебвью, освободившиеся переиспользуются.

Дальше: при необходимости — тонкая настройка показа на разнообразных примерах (теперь доступны все 218 языков). Отложено: собственные UTI для длинного хвоста языков (Task 5b фазы 4), расширение **Thumbnail** до решения о целесообразности, follow-up эффективности каталога (сайдкар-каталог, см. ниже).

**Follow-up (эффективность каталога):** после перехода грамматик на формат-массив файлы стали большими (rst ≈4 МБ, twig ≈3,7 МБ), и `FileCatalogSource.loadCatalog()` читает/парсит все 218 (~41 МБ) ради `name`+`displayName` каждого — это не горячий путь превью (превью грузит одну грамматику), а загрузка каталога при открытии окна настроек, и там лишние сотни мс — секунды. Чистый фикс: на шаге `extract-resources.mjs` писать маленький сайдкар-каталог (`{id, displayName}`, ~10 КБ) и читать его в `FileCatalogSource`. Найдено `/simplify` фазы 4.

Группа A (тёплый WebView, перенос по строкам, обрезка) и кэш HTML — **сделаны в фазе 5** (см. п.5). Исходный список рычагов — в `docs/superpowers/notes/2026-06-28-preview-thin-slice-spikes.md`.

**Замеры производительности:**
- Голый движок на 200 строках Swift: холодный ≈440 мс, тёплый ≈190 мс (release ≈ debug — стоимость в JS-слое JSC). Детали — `docs/superpowers/notes/2026-06-28-engine-benchmark.md`.
- Полный конвейер показа в расширении (движок + WKWebView), тёплый: **~85–175 мс** на коротких файлах, около ориентира ~100 мс. Тёплый процесс между показами **подтверждён**. Выбросы 1–2,6 с — холодный старт WebContent (рычаг: держать вебвью тёплым). Детали — `docs/superpowers/notes/2026-06-28-preview-thin-slice-spikes.md`.

Бюджет добираем не в движке, а оптимизациями показа (кэш HTML, тёплый WebView, обрезка первого экрана). Полный нативный порт (Oniguruma + Swift) **отложен**.

## Структура

```
Package.swift                          # SwiftPM-пакет: QuickLookersEngine + QuickLookersPreviewKit + QuickLookersSettingsKit, macOS 13+
Sources/QuickLookersEngine/
  HighlightEngine.swift                # протокол HighlightEngine + HighlightRequest + EngineError
  JSCoreRuntime.swift                  # обёртка над JavaScriptCore
  Providers.swift                      # GrammarProvider / ThemeProvider
  ShikiEngine.swift                    # реализация HighlightEngine
  EngineFactory.swift                  # сборка из Bundle.module
  EngineResources.swift                 # публичный доступ к каталогам ресурсов (grammars/themes)
  Resources/
    shiki-bundle.js                    # СОБИРАЕТСЯ из js/, не править вручную
    grammars/*.json                    # грамматики Shiki: МАССИВ [главная + встроенные] (имя файла = id языка), 218 шт.
    themes/*.json                      # темы Shiki
Sources/QuickLookersPreviewKit/        # тестируемая presentation-логика расширения
  PreviewPage.swift                    # previewPageHTML(highlighted:truncatedNotice:) — HTML-страница с переносом строк и плашкой обрезки
  CodeTrim.swift                       # trimToFirstLines (обрезка до N строк) + readBoundedPrefix (огранич. чтение больших файлов)
  HTMLCache.swift                      # HTMLCacheKey (ключ из атрибутов файла+тема+язык) + HTMLCache (lookup/store/evict, LRU, потолок 5 МБ)
Sources/QuickLookersSettingsKit/       # настройки, каталог языков/тем, App Group
  ManagerSettings.swift                # модель настроек (opt-out: выключенные языки + выбор темы)
  DeclaredTypes.swift                  # объявленные типы файлов, разрешение языка и признака просмотра
  Catalog.swift                        # каталог языков и тем из JSON-дескрипторов
  CatalogSource.swift                  # FileCatalogSource: читает grammars/ и themes/ из пакета
  SettingsStore.swift                  # атомарная запись settings.json, разрешение темы, App Group
js/                                    # шаг сборки JS-бандла (Node, только для сборки)
  src/highlight.mjs                    # точка входа: вешает globalThis.ql*
  build.mjs                            # esbuild → Resources/shiki-bundle.js
  test/smoke.mjs                       # node-смоук готового бандла
Tests/QuickLookersEngineTests/         # XCTest, TDD (движок)
Tests/QuickLookersPreviewKitTests/     # XCTest, TDD (PreviewKit)
Tests/QuickLookersSettingsKitTests/    # XCTest, TDD (SettingsKit)

# Xcode-часть (генерируется XcodeGen, .xcodeproj в .gitignore)
project.yml                            # спека XcodeGen: хост-приложение + расширение Preview
App/QuickLookersApp.swift              # точка входа SwiftUI-приложения
App/SettingsModel.swift                # @Observable модель, связывающая SettingsStore с UI
App/ContentView.swift                  # три вкладки: Форматы / Темы / Сопоставление
App/FormatsTab.swift                   # вкладка «Форматы подсветки» (Слой 1)
App/ThemesTab.swift                    # вкладка «Темы» (следовать за системой / фиксированная)
App/FileTypesTab.swift                 # вкладка «Сопоставление с типами файлов» (Слой 2)
App/QuickLookers.entitlements          # App Sandbox + App Group хоста
PreviewExtension/
  PreviewViewController.swift          # QLPreviewingController: читает файл → движок → WKWebView
  Info.plist                           # NSExtension + QLSupportedContentTypes (генерит XcodeGen)
  QuickLookersPreview.entitlements     # App Sandbox + network.client

docs/superpowers/                      # specs/ (дизайн), plans/ (планы), notes/ (замеры)
```

## Команды

```bash
# Тесты пакета (движок + PreviewKit)
swift test
swift test --filter RuntimeTests

# Пересборка JS-бандла Shiki (после правок js/src/*)
cd js && npm install && npm run build && npm test

# Xcode-проект: сгенерировать из project.yml (нужен `brew install xcodegen`)
xcodegen generate

# Проверка компиляции приложения + расширения без подписи
xcodebuild -project QuickLookers.xcodeproj -scheme QuickLookers \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build

# Чтобы расширение РЕАЛЬНО заработало в Finder — запустить хост из Xcode (⌘R).
# Только это надёжно регистрирует расширение у демона pkd; CLI-сборки/lsregister
# для регистрации недостаточно.

# Логи расширения (pid, warm, ms показа). ВАЖНО: полный путь — в zsh `log` встроенный!
/usr/bin/log stream --info --predicate 'subsystem == "com.quicklookers.preview"'
```

`shiki-bundle.js` — **артефакт сборки**, лежит в ресурсах и коммитится, но руками его не редактируют: меняют `js/src/highlight.mjs` и пересобирают. `.xcodeproj` и `*.entitlements`/`Info.plist` расширения — тоже артефакты XcodeGen, правят `project.yml` и перегенерируют.

## Принципы и договорённости

- **TDD строго:** сначала падающий тест → запуск (убедиться, что падает) → реализация → запуск (зелёный) → коммит. По одному маленькому шагу.
- **Движок изолирован за протоколом** `HighlightEngine`. Потребители (расширения, приложение) не знают про Shiki/JSC. Нативный движок (Oniguruma + Swift-токенизатор) — запасной путь, включаем только если бенчмарк (Task 6) не влезет в бюджет ~100 мс. Решение — по замерам, не заранее.
- **Без WASM:** движок регулярок Shiki — только JS (`createJavaScriptRegexEngine`).
- **Всё офлайн:** бандл, грамматики, темы — в ресурсах пакета.
- **Вывод — готовая HTML-строка** для статичного показа в WKWebView с выключенным JS (WebView не выполняет код).
- **Паритет с VS Code** держится на настоящих грамматиках/темах из `@shikijs/langs` и `@shikijs/themes`, не самописных.

## QuickLook-расширение: грабли (дорого добыты, см. заметку spike)

Если расширение не показывается или показывает пустоту — почти всегда одно из:

1. **App Sandbox обязателен.** Без `com.apple.security.app-sandbox` демон `pkd` молча не берёт расширение в провайдеры. Бандл виден в «Системных настройках», но не вызывается. Отказавшись от App Group, песочницу выкидывать нельзя.
2. **WKWebView в песочнице требует `com.apple.security.network.client`** — даже для HTML из строки. Иначе WebContent/GPU падают (`errno=34`), показ вешается спиннером.
3. **`ENABLE_DEBUG_DYLIB = NO`** в `project.yml`: стуб-загрузчик Xcode 16+ ломает загрузку app-расширения.
4. **Ждать `didFinish` навигации WKWebView** перед возвратом из `preparePreviewOfFile`, иначе QuickLook снимает пустой вебвью.
5. **Регистрация — запуском хоста из Xcode** (⌘R), не из командной строки.
6. **Конфликт провайдеров:** несколько расширений (sbarex, FluxMarkdown) могут объявлять один UTI; выбор — только галочками в «Системных настройках → Быстрый просмотр».
7. **App Group — префикс Team ID, не `group.`.** Идентификатор `group.com.quicklookers` на ненотаризованной dev-сборке вызывает системный запрос «доступ к данным других приложений» на каждое обращение к контейнеру. Префикс Team ID (`5FVC5YT2B5.com.quicklookers`) macOS сверяет с подписью кода → доступ без провижн-профиля и без запроса. Так в `project.yml` (оба таргета) и в `quickLookersAppGroupId`. Подтверждено доками Apple («Use app groups that you don't provision»).

## Версии (зафиксированы)

- Swift 6.3 / SwiftPM (tools 5.9), цель macOS 13+. Xcode 26, XcodeGen 2.45.
- shiki **1.29.2**, esbuild **0.20.2** (см. `js/package-lock.json`).
- Метод `codeToHtml` у `createHighlighterCoreSync` в этой версии **есть** (подтверждено смоук-тестом).

## Коммиты

- Сообщения по-русски, формат `feat(engine): ...` / `feat(preview): ...` / `test(...): ...` / `docs: ...`.
- Трейлер: `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.
- Каждая подсистема — в своей ветке, не в `main` напрямую. Фазы 1–2 влиты в `main`; следующая фаза начинается с новой ветки.

## Заметки по окружению

- npm-окружение блокирует postinstall-скрипты (предупреждение про esbuild) — на сборку бандла не влияет.
- Движок (`QuickLookersEngine`, `QuickLookersPreviewKit`) — чистый SwiftPM, тестируется `swift test`. Xcode-обвязка (приложение + расширение) — поверх, через XcodeGen.
- Диагностика SourceKt в редакторе («No such module …», «@main …») при правках Xcode-таргетов — это **задержка индексатора**, а не ошибка сборки; `swift test` / `xcodebuild` собирают нормально.
- В **zsh** есть встроенная команда `log` — для системных логов всегда полный путь `/usr/bin/log`.
