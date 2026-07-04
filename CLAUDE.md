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

Дальше: при необходимости — тонкая настройка показа на разнообразных примерах (теперь доступны все 218 языков). Отложено: собственные UTI для длинного хвоста языков (Task 5b фазы 4), расширение **Thumbnail** до решения о целесообразности.

**Сайдкар-каталог** — **реализовано** (спека `docs/superpowers/specs/2026-06-29-sidecar-catalog-design.md`, план `docs/superpowers/plans/2026-06-29-sidecar-catalog.md`). Окно настроек читает маленький `Resources/catalog.json` (генерится `extract-resources.mjs`) вместо обхода всех 218 грамматик (~41 МБ); полный обход остаётся фоллбэком. Сайдкар — расширяемый индекс (список URL, слияние с перекрытием по `id`) под будущий импорт `.vsix`.

**6. Импорт темы и шрифта из редактора + витрина «Темы»** — **реализовано, идёт визуальная полировка** (спека `docs/superpowers/specs/2026-06-30-editor-theme-and-font-import-design.md`, план `docs/superpowers/plans/2026-06-30-editor-theme-and-font-import.md`). Цель — «как в моём редакторе»: одной кнопкой забрать активную тему и шрифт из установленного VS Code / Cursor. Новый пакетный таргет **`QuickLookersEditorKit`**: поиск редакторов (`EditorScanner` — по маркеру `product.json`, не по ненадёжному bundle id), чтение настроек (`EditorSettingsReader`, формат **JSONC** — комментарии/висячие запятые/сырые управляющие символы), разрешение темы (`EditorThemeResolver` → встроенная по id / своя кастомная для импорта / не найдена). **`QuickLookersImportKit` дополнен:** `JSONCParser` (JSONC→строгий JSON) и `ThemeFileLoader` (`.json`/`.jsonc` через парсер, **`.tmTheme`/`.plist`** через `PropertyListSerialization` → форма Shiki `{name,type,tokenColors}` — **tmTheme обязаны работать**). `ThemeNormalizer` теперь пишет `name = id` — **контракт движка:** Shiki регистрирует тему по JSON-полю `name`, ищет по id (раньше — латентный баг и в импорте `.vsix`). **Та же грабля была у ГРАММАТИК и позже починена** (коммит `46e19de`): импортированная из `.vsix` грамматика держала витринное имя VS Code (`name = "Django HTML"` ≠ id `django-html`) → движок бросал `lang not registered` → системный дженерик. Инвариант закреплён в ДВУХ местах: `ShikiEngine.forcingMainName` приводит `name` главной грамматики к id **при регистрации** (чинит уже импортированные грамматики в контейнере без переимпорта; бандловым no-op; вложенные и `scopeName` не трогает), а `GrammarNormalizer` пишет `name = id` при импорте (консистентность на диске). **Доступ:** песочница сохранена; два **ленивых** гранта (`~` для данных редактора, `/Applications` для поиска) через powerbox + **app-scoped security-scoped закладки** (`BookmarkStore`, `com.apple.security.files.bookmarks.app-scope` у хоста). **Настройки переписаны без миграции** (пользователей ещё нет): вместо `ThemeSelection`/«следовать за системой» — единый `activeThemeId` + `FontSettings` (семейство/размер, диапазон 6…48, `clampSize`). **Витрина «Темы»** (вкладка перестроена): сегментный выбор языка-образца → **живое превью** (`CodePreviewView`/WKWebView; `FragmentCache` мемоизирует подсветку — движок гоняется только при смене языка/темы, не на каждый кадр) → шрифт (список моноширинных + **системная панель `NSFontPanel`** через `FontPanelController`) → единый список тем с **галочкой активной** → импорт `.vsix` и «Из редактора…» (поповер `.popover(item:)` с иконками приложений). Шрифт прокинут в превью: `previewPageHTML(fontFamily:fontSize:)`, ключ `HTMLCacheKey` их учитывает.

**Грабли этой фазы (дорого добыты живыми спайками):**
- **Хосту нужен `network.client`.** Приложение теперь само показывает WKWebView (живое превью); без права вспомогательные процессы падают (`RBSAssertionError`/Jetsam «process does not exist»), вебвью пустой. Право было только у расширения.
- **UA-стиль `code { font-family: monospace }` перебивает шрифт.** Shiki кладёт код в `<pre class="shiki"><code>`; UA-правило бьёт прямо по `<code>` и перебивает унаследованный шрифт (а размер наследуется — отсюда «размер меняется, семейство нет»). Селектор `font-family` накрывает и `<code>`.
- **`List` вместо grouped-`Form` для списков на всю ширину.** grouped-`Form` на macOS центрирует содержимое с предельной шириной и не растёт с окном. В `List` тогл по умолчанию — чекбокс, поэтому возвращаем переключатель: `.toggleStyle(.switch)` + `.controlSize(.small)`.
- **`.popover(item:)`, не `isPresented:` + отдельный `@State`.** Иначе поповер в первый раз пуст (читает захваченный устаревший массив). На `item` система пере-презентует от источника данных. `arrowEdge: .top` — раскрытие вверх (кнопка у нижнего края).

Группа A (тёплый WebView, перенос по строкам, обрезка) и кэш HTML — **сделаны в фазе 5** (см. п.5). Исходный список рычагов — в `docs/superpowers/notes/2026-06-28-preview-thin-slice-spikes.md`.

**7. Сопоставление файл→язык (фаза сопоставления, ветка `feat/file-type-mapping`)** — **реализовано, хвост закрыт Задачей 5b** (спека `docs/superpowers/specs/2026-07-02-file-type-language-mapping-design.md`, план `docs/superpowers/plans/2026-07-02-file-type-language-mapping.md`). Спайк (`parent-uti-preview`) установил железный факт: `QLSupportedContentTypes` ловит по **точному листовому UTI**, конформанс вверх не работает (родитель `public.source-code` не ловит `public.swift-source` и т. п.) — зонтичная стратегия отвергнута. Взамен — **два слоя**. **Слой A** (маршрутизация, статичный `Info.plist`): список точных UTI, живым Спайком D подтверждено — невод `public.plain-text` ловит только файлы, которые сама система уже типизирует как текст (`.txt`, безрасширенные вроде `README`), а НЕ безрасширенные конфиги (`Dockerfile`/`.gitignore` система метит `public.data`) и НЕ неизвестные расширения (`dyn.*`); `csv`/`md` намеренно не объявлены — у них свой листовой UTI, остаются системе/соседним расширениям. Этот остаточный хвост закрыт Задачей 5b тремя механизмами поверх плюс базового набора `public.*`/вендорных UTI и невода plain-text: **(1)** невод `public.data` — ловит безрасширенные конфиги по имени файла (`Dockerfile`, `.gitignore`); бинарь (не-UTF-8) бросает → системный дженерик; **(2)** ~30 выверенных системных UTI, где системный тип и есть код/текст (Pascal/Fortran/GLSL/Objective-C/HTML/CSS/XML/Assembly/Protobuf/HLSL/шелл-скрипты/…), плюс два намеренных перехвата «ложных друзей» — `.ts`→typescript (система метит видео MPEG-2) и `.r`→R (Apple Rez); другие «ложные друзья» с реальным не-кодом за расширением (`.app`/`.pf`/`.dds`/`.gp`/`.potx`/`.mts`/…) **намеренно не объявлены** (объявить — сломать чужие настоящие файлы); **(3)** собственный экспортируемый UTI `com.quicklookers.source-code` — один тип на все свободные (`dyn.*`) расширения датасета, **652 штуки** (`kt`, `dart`, `graphql`, `nim`, `zig`, `vala`, `gleam`, …), `conformsTo public.source-code + public.plain-text`; экспортёром стал **хост**-таргет (не расширение — тип нужно откуда-то декларировать), поэтому хост перешёл на явный `info:`-блок в `project.yml` (`GENERATE_INFOPLIST_FILE: NO`), артефакт — `App/Info.plist`. Список для (3) генерирует dev-утилита **`Scripts/audit-extension-utis.swift --emit-tags`** (по `associations.json` резолвит листовой UTI каждого расширения и категоризирует; снимок — `docs/superpowers/notes/2026-07-03-extension-uti-audit.md`); **грабля** — после сборки/регистрации собственного UTI в LaunchServices эти расширения на машине разработки резолвятся уже в `com.quicklookers.source-code`, а не в `dyn.*` (самоконтаминация) → повторный аудит `--emit-tags` покажет почти пусто, гнать аудит ДО сборки или на чистой машине. Занятое установленным сторонним QL-приложением расширение (в спайке — `.nim` у sbarex) собственным UTI не отнять — держит сам факт экспорта типа в LaunchServices даже при выключенном чужом QL-расширении; принятое ограничение, ссылаться на чужой UTI конкурента в своём Info.plist намеренно не делаем. Железные факты механики хвоста (нет тега UTI на имя файла целиком — офиц. доки Apple; занятое не отнять; свободное `dyn.*` забирает чисто, подтверждено живым тестом после удаления sbarex) — Спайк E, `docs/superpowers/notes/2026-06-28-intercept-spikes.md`. **Слой B** (назначение языка, рантайм): таблица «расширение/имя файла → язык» из датасета `associations.json`, сгенерированного из `github-linguist` (`js/generate-associations.mjs` + `js/vendor/linguist-languages.yml`, т.к. у Shiki `fileTypes` есть лишь у 91/218 языков), плюс пользовательские правила (`extensionOverrides`/`filenameOverrides`/`disabledExtensions`/`disabledFilenames` в `ManagerSettings`, схема v2) поверх датасета. `resolvePreview` в `PreviewResolution.swift` решает: правило по имени файла приоритетнее правила по расширению; выключенный или неопознанный формат — **нейтральный показ** (`NeutralPage.swift`: моноширинный текст на системном фоне, не системный дженерик-превью) вместо броска. Вкладка «Просмотр в Finder» (`FileTypesTab.swift`) — таблица правил с поиском, выбором языка (именами из каталога, не id), тумблером и добавлением своего правила. **Ждёт живой проверки пользователем:** прогон App-тестов ⌘U и визуальная проверка хвоста (три механизма Задачи 5b) на живой сборке.

**Пересбор вкладки «Просмотр в Finder» (ветка `feat/file-mapping-tab-redesign`)** — **реализовано**. Слой 2 переведён на схему v3: вместо четырёх структур overrides/disabled — единый список `previewRules: [PreviewRule]` с glob-масками (`*`/`?`/`~`, `/`-экранирование, `GlobMatcher`). Починена память вкладки: по умолчанию видны только правила пользователя, весь датасет — под поиск с потолком и ранжированием по релевантности (`searchDataset`). Лист добавления правила (`AddRuleSheet`) показывает «Сейчас так» (текущий дефолт до правила) и статус показа по пробелу для введённого шаблона (`InterceptionStatus` + `InterceptionDeclarations` — чистый классификатор плюс мост к реальному бандлу/UTType).

**Расширение охвата через Pygments (та же ветка)** — **реализовано** (замер — `docs/superpowers/notes/2026-07-04-pygments-coverage-measurement.md`). Цель — не «что красим по умолчанию», а **перехват**: чтобы пара «расширение→грамматика», добавленная пользователем, реально долетала до расширения по пробелу; грамматику приносит пользователь, наличие движка Shiki по умолчанию к перехвату отношения не имеет. Замер (Pygments 2.20.0 против текущего охвата linguist): из 710 расширений Pygments недоставало 436; по `UTType` — **414 dyn** (система не занимает → берём своим экспортным UTI без коллизий), 9 системный текст, 13 «ложных друзей» (RAW-фото/аудио/PostScript/Word-шаблон/Revit-бинарь — не трогаем: объявить = сломать чужие настоящие файлы); санитайзер убрал 11 артефактов лексеров (objdump-дампы, консоли) → **403 чистых dyn**. **Развязка перехвата от маппинга на язык** (это разные заботы; прежде склейка отсекала расширения без грамматики): в `associations-overrides.json` заведён ключ `interceptExtensions` (389 расширений без грамматики — **нейтральный показ**, пока пользователь не назначит правило) + 16 уверенных дефолтов Pygments с существующей грамматикой (`gradle`→groovy, `ndjson`→json, `pom`→xml, `bzl`/`sage`→python, `csh`/`tcsh`→shellscript, …). `generate-associations.mjs` пробрасывает `interceptExtensions` в датасет (исключая owned языком), `audit-extension-utis.swift` учитывает их в `--emit-tags`, потребители (`FileTypeAssociations`/js-смоук) неизвестный ключ игнорируют. Экспортный список `UTExportedTypeDeclarations` хоста вырос **654→1057**. **Грабля (важно):** список влит **объединением** с текущим, а НЕ пересобран аудитом — после сборки уже зарегистрированные расширения резолвятся в наш UTI (самоконтаминация) и `--emit-tags` их бы потерял; новые 403 ещё чистые dyn, потому добавляются к существующему списку. На **чистой** машине регенерация `--emit-tags` воспроизводит полный 1057 (потому и правки в генератор/аудит). 13 «ложных друзей» намеренно не объявлены, их можно брать только поимённо, как `.ts`/`.r`/`.as`. **Ждёт живой проверки:** ⌘R и пробел на файле нового расширения (`.agda`/`.zig`/`.gradle`).

**Замеры производительности:**
- Голый движок на 200 строках Swift: холодный ≈440 мс, тёплый ≈190 мс (release ≈ debug — стоимость в JS-слое JSC). Детали — `docs/superpowers/notes/2026-06-28-engine-benchmark.md`.
- Полный конвейер показа в расширении (движок + WKWebView), тёплый: **~85–175 мс** на коротких файлах, около ориентира ~100 мс. Тёплый процесс между показами **подтверждён**. Выбросы 1–2,6 с — холодный старт WebContent (рычаг: держать вебвью тёплым). Детали — `docs/superpowers/notes/2026-06-28-preview-thin-slice-spikes.md`.

Бюджет добираем не в движке, а оптимизациями показа (кэш HTML, тёплый WebView, обрезка первого экрана). Полный нативный порт (Oniguruma + Swift) **отложен**.

## Структура

```
Package.swift                          # SwiftPM-пакет: Engine + PreviewKit + SettingsKit + ImportKit + EditorKit, macOS 13+
Sources/QuickLookersEngine/
  HighlightEngine.swift                # протокол HighlightEngine + HighlightRequest + EngineError
  JSCoreRuntime.swift                  # обёртка над JavaScriptCore
  Providers.swift                      # GrammarProvider / ThemeProvider
  ShikiEngine.swift                    # реализация HighlightEngine
  EngineFactory.swift                  # сборка из Bundle.module
  EngineResources.swift                 # публичный доступ к каталогам ресурсов (grammars/themes)
  Resources/
    shiki-bundle.js                    # СОБИРАЕТСЯ из js/, не править вручную
    catalog.json                       # СОБИРАЕТСЯ extract-resources.mjs: индекс {languages,themes}, не править вручную
    associations.json                  # СОБИРАЕТСЯ js/generate-associations.mjs: датасет {язык → extensions/filenames} из linguist + interceptExtensions[] (расширения без грамматики, только перехват), не править вручную
    grammars/*.json                    # грамматики Shiki: МАССИВ [главная + встроенные] (имя файла = id языка), 218 шт.
    themes/*.json                      # темы Shiki
Sources/QuickLookersPreviewKit/        # тестируемая presentation-логика расширения
  PreviewPage.swift                    # previewPageHTML(highlighted:fontFamily:fontSize:truncatedNotice:) — HTML-страница; шрифт накрывает и <code>
  CodeTrim.swift                       # trimToFirstLines (обрезка до N строк) + readBoundedPrefix (огранич. чтение больших файлов)
  HTMLCache.swift                      # HTMLCacheKey (ключ из атрибутов файла+тема+язык+ШРИФТ) + HTMLCache (lookup/store/evict, LRU, потолок 5 МБ)
  NeutralPage.swift                    # neutralPageHTML — нейтральный моноширинный показ для выключенного/неопознанного формата
Sources/QuickLookersSettingsKit/       # настройки, каталог языков/тем, App Group
  ManagerSettings.swift                # модель настроек: схема v3 — единый `previewRules: [PreviewRule]` (glob-маски) вместо четырёх структур overrides/disabled
  PreviewRule.swift                    # модель правила просмотра (шаблон/действие/включено)
  GlobMatcher.swift                    # glob-сопоставление имени файла (`*` ноль+, `?` один, `~` ноль-или-один; `/` экранирует)
  DatasetSearch.swift                  # поиск по датасету с потолком, ранжирование по релевантности (ключ впереди имени языка)
  InterceptionStatus.swift             # чистый классификатор перехвата (перехватим / система-не-код / неизвестно-не-объявлено)
  FileTypeAssociations.swift           # датасет «расширение/имя файла → язык» из associations.json (SettingsKit не зависит от движка, URL передаёт вызывающий)
  PreviewResolution.swift              # resolvePreview — правило файла/расширения + пользовательские правки → highlight(language) | neutral
  Catalog.swift                        # каталог языков и тем из JSON-дескрипторов
  CatalogSource.swift                  # FileCatalogSource: читает grammars/ и themes/ из пакета
  SettingsStore.swift                  # атомарная запись settings.json, разрешение темы (resolvedThemeId), App Group
Sources/QuickLookersImportKit/         # импорт тем/грамматик: .vsix и темы из редактора
  JSONCParser.swift                    # JSONC (комментарии/висячие запятые/сырые ctrl-символы) → строгий JSON
  ThemeFileLoader.swift                # .json/.jsonc + .tmTheme/.plist → форма Shiki {name,type,tokenColors}
  ThemeNormalizer.swift                # нормализация темы; пишет name = id (контракт движка Shiki)
  GrammarNormalizer.swift              # нормализация грамматики .vsix; пишет name = id (движок ищет по id) + дособирает embeddedLangs
  VsixImporter.swift / VsixManifest.swift / ImportedLibrary.swift  # распаковка .vsix, манифест, запись в контейнер
Sources/QuickLookersEditorKit/         # обнаружение редактора и чтение его темы/шрифта
  DetectedEditor.swift                 # найденный редактор: URL, имена, имя папки данных
  EditorScanner.swift                  # поиск VS Code-подобных в /Applications по product.json
  EditorSettingsReader.swift           # чтение editor.fontFamily/fontSize/colorTheme из settings.json (JSONC)
  EditorThemeResolver.swift            # тема редактора → встроенная id / своя кастомная / не найдена
js/                                    # шаг сборки JS-бандла и датасета (Node, только для сборки)
  src/highlight.mjs                    # точка входа: вешает globalThis.ql*
  build.mjs                            # esbuild → Resources/shiki-bundle.js
  generate-associations.mjs            # linguist-languages.yml (+associations-overrides.json) → Resources/associations.json
  vendor/linguist-languages.yml        # вендоренный датасет github-linguist (расширения/имена файлов по языкам)
  associations-overrides.json          # точечные правки поверх linguist: extensions/filenames/languageAlias + interceptExtensions[] (перехват без грамматики, охват Pygments)
  test/smoke.mjs                       # node-смоук готового бандла
  test/associations.smoke.mjs          # node-смоук сгенерированного associations.json
Tests/QuickLookersEngineTests/         # XCTest, TDD (движок)
Tests/QuickLookersPreviewKitTests/     # XCTest, TDD (PreviewKit)
Tests/QuickLookersSettingsKitTests/    # XCTest, TDD (SettingsKit)
Tests/QuickLookersImportKitTests/      # XCTest, TDD (ImportKit: JSONC, темы, .vsix)
Tests/QuickLookersEditorKitTests/      # XCTest, TDD (EditorKit: поиск, чтение настроек, разрешение темы)

# Xcode-часть (генерируется XcodeGen, .xcodeproj в .gitignore)
project.yml                            # спека XcodeGen: хост-приложение + расширение Preview
App/Info.plist                         # NSExtension… + UTExportedTypeDeclarations (com.quicklookers.source-code, Задача 5b; генерит XcodeGen)
App/QuickLookersApp.swift              # точка входа SwiftUI-приложения
App/SettingsModel.swift                # модель окна: SettingsStore + каталог; applyEditorResult, FragmentCache
App/ContentView.swift                  # три вкладки: Темы / Форматы / Просмотр; резиновое окно
App/FormatsTab.swift                   # вкладка «Форматы подсветки» (Слой 1) — List + компактные тоглы
App/ThemesTab.swift                    # витрина «Темы»: образец → превью → шрифт → список тем → импорт
App/FileTypesTab.swift                 # вкладка «Просмотр в Finder»: управление правилами маска→подсветка; по умолчанию только правила пользователя, датасет под поиск с потолком
App/AddRuleSheet.swift                 # лист добавления/правки правила (шаблон, «Сейчас так», статус показа, поиск-выбор языка)
App/InterceptionDeclarations.swift     # чтение объявленного набора перехвата из бандла (Info.plist хоста и расширения) + мост к UTType
App/LivePreview.swift                  # SettingsModel.previewHTML + FragmentCache (мемоизация подсветки) + MonospaceFonts
App/CodePreviewView.swift              # NSViewRepresentable WKWebView для живого превью (guard по неизменному HTML)
App/PreviewSnippets.swift              # образцы кода: Python/HTML/CSS/JSON/JS/SQL/PHP
App/FontPanelController.swift          # системная панель NSFontPanel → семейство+размер
App/BookmarkStore.swift                # ленивые app-scoped закладки на ~ и /Applications (powerbox)
App/ImportModel.swift                  # пикер .vsix, scanEditors, importFromEditor
App/QuickLookers.entitlements          # App Sandbox + App Group + network.client + bookmarks.app-scope (артефакт XcodeGen)
PreviewExtension/
  PreviewViewController.swift          # QLPreviewingController: читает файл → движок → WKWebView
  Info.plist                           # NSExtension + QLSupportedContentTypes (генерит XcodeGen)
  QuickLookersPreview.entitlements     # App Sandbox + network.client

Scripts/audit-extension-utis.swift     # dev-утилита (Задача 5b): по associations.json (включая interceptExtensions) резолвит листовой UTI каждого расширения, категоризирует под три механизма хвоста Слоя A; `--emit-tags` печатает список для UTExportedTypeDeclarations. ГОНЯТЬ НА ЧИСТОЙ МАШИНЕ / ДО СБОРКИ (самоконтаминация)

docs/superpowers/                      # specs/ (дизайн), plans/ (планы), notes/ (замеры)
```

## Команды

```bash
# Тесты пакета (движок + PreviewKit)
swift test
swift test --filter RuntimeTests

# Пересборка JS-бандла Shiki (после правок js/src/*)
cd js && npm install && npm run build && npm test

# Пересборка датасета «расширение/имя файла → язык» (после правок js/vendor/*.yml или overrides)
cd js && node generate-associations.mjs && node test/associations.smoke.mjs

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
