# Handoff: вкладка сопоставлений — UAT-фиксы + расширение охвата через Pygments

Дата: 2026-07-04. Ветка: `feat/file-mapping-tab-redesign` (НЕ влита; merge держим до живой проверки).
Контекст будет сжат `/compact` — этот файл + SDD-леджер (`.superpowers/sdd/progress.md`) = карта возобновления.

## Где мы

Пересбор вкладки «Просмотр в Finder» реализован и прошёл финальное ревью (Ready to merge: Yes),
затем пользователь провёл UAT. Спека/план: `docs/superpowers/specs|plans/2026-07-04-file-mapping-tab-redesign*`.
Что уже на ветке (коммиты поверх base `73812b3`):
- Модель `PreviewRule` + схема настроек v3 (единый `previewRules`), glob-маски `* ? ~` + экранирование `/`
  (`GlobMatcher`), `resolvePreview` по специфичности, `searchDataset` с ранжированием (ключ > имя языка) и
  потолком, чистый классификатор перехвата `InterceptionStatus` + мост `InterceptionDeclarations`,
  новая вкладка `FileTypesTab` + `AddRuleSheet`.
- UAT-фиксы: #1 отступы кнопки (HIG 20pt), #6 видимая кнопка удаления правила; #5/#5.1 перехват
  `djhtml`/`djhtm` (dyn → наш экспортный UTI + в датасет→html) и `.as`→actionscript-3 (ложный друг,
  системный тип `com.apple.applesingle-archive`, объявлен в `QLSupportedContentTypes` как `.ts`/`.r`).

## Железный факт про перехват (закрыт документацией Apple)

QuickLook сопоставляет расширение по **ТОЧНОМУ листовому UTI, НЕ по конформансу**. Дословно из дока
QuickLookThumbnailing (механизм тот же у Preview): «It's not sufficient to list a parent UTI to which a
file type may conform.» Следствия:
- «Широкая ловушка» (`public.data`/`public.content` ловят всё) — **невозможна**. Подтверждено живым
  тестом `.djhtml` (не дошёл, крупная иконка).
- Список точных UTI зашит в `Info.plist` при сборке; **штатного рантайм-API дописать нет**
  (`UTType(exportedAs:)` создаёт объект, не регистрирует).
- **Единственная непроверенная лазейка для рантайма:** сгенерировать helper-бандл с
  `UTImportedTypeDeclarations` (расширения юзера → наш `com.quicklookers.source-code`) и позвать
  `LSRegisterURL`. Сработает ТОЛЬКО для dyn-расширений; вероятно упрётся в sandbox + подпись; полу-депрекейт.
  Решает только живой спайк (~час). Пользователь пока выбрал НЕ спайк, а расширять поставочный охват.

## РЕШЕНИЕ пользователя (следующая задача): расширить охват через Pygments

Скрейпинг VS Code отвергнут. Источник — **только Pygments**. Сначала ИЗМЕРИТЬ, потом решать.

### Задача «Pygments coverage measurement»
1. Достать список расширений Pygments: `python3 -c "from pygments.lexers import get_all_lexers; [...]"`
   (каждый лексер даёт `(name, aliases, filenames, mimetypes)`; `filenames` — globs вида `*.ext`,
   а также имена `Dockerfile`, `*.in` и т.п.). Если pygments не установлен — `pip install pygments`
   в venv (npm/python в окружении есть). Извлекать в первую очередь одно-сегментные `*.ext` → `ext`.
2. Текущий охват = расширения в `Sources/QuickLookersEngine/Resources/associations.json`
   (linguist + overrides). Посчитать, сколько Pygments-расширений НЕ покрыто.
3. Отфильтровать кандидаты через `Scripts/audit-extension-utis.swift` / резолв `UTType(filenameExtension:)`:
   - dyn (система не знает) → безопасно добавить в наш экспортный UTI;
   - системный текст/код → и так дойдёт;
   - «ложный друг» (система метит архивом/видео/картинкой) → НЕ добавлять вслепую (как `.as`/`.ts` — только осознанно).
   ГРАБЛЯ самоконтаминации: после сборки наш UTI уже зарегистрирован → аудит на ЭТОЙ машине мискатегоризирует;
   гнать резолв ДО сборки нового или трактовать наши 652 как «уже наши».
4. КЛЮЧЕВОЙ фильтр полезности: добавлять `.ext → язык` есть смысл ТОЛЬКО если для языка есть грамматика Shiki
   в нашем каталоге (218 встроенных + импортированные). Pygments-имя ≠ Shiki-id → нужна карта имён
   (частично покрывает `js/associations-overrides.json:languageAlias`). Расширение без грамматики бесполезно.
5. ИТОГ измерения: цифра «сколько ПОЛЕЗНЫХ (есть грамматика, не ложный друг) расширений добавит Pygments
   сверх linguist» + категоризированный список. По цифре пользователь решает: вливать (в overrides→датасет,
   регенерить `associations.json` + `project.yml` экспортный список) или нет.

Порядок применения (если решим вливать): правки в `js/associations-overrides.json` (ext→shiki-id) →
`cd js && node generate-associations.mjs && node test/associations.smoke.mjs` → добавить dyn-расширения в
экспортный `public.filename-extension` в `project.yml` → `xcodegen generate` → build → **пользователь ⌘R**.

## Открытые пункты (не блокеры кода)

- **⌘R нужен от пользователя** для перерегистрации pkd → живой ре-тест: `.djhtml` (теперь html по умолчанию,
  Django — правилом юзера), `.as`→ActionScript, кнопка/удаление, память вкладки.
- **#4 копирайт/подсказки** — пользователь переписывает сам в коде (не трогать строки).
- **Честный UI для непокрываемых шаблонов**: сейчас на `*.djhtml` лист даёт ⚠️, а на `Dockerfile.*` /
  шаблоны без определимого расширения (`probeExtension == nil`) — МОЛЧИТ и правило тихо не срабатывает.
  Договорённость: писать прямо «такие файлы приложение не показывает по пробелу — правило не сработает».
  (Ждёт реализации; но копирайт — за пользователем.)
- **`.as` как ложный друг** — документированное «намеренно не объявлено» реверснуто; принято (AppleSingle вымер),
  подтвердить живым тестом.

## Как проверять/собирать (напоминание)

`swift test` (пакет), `xcodegen generate && xcodebuild -project QuickLookers.xcodeproj -scheme QuickLookers
-destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build`. Регистрация расширения — ТОЛЬКО ⌘R из Xcode.
SourceKit-диагностика в редакторе — задержка индексатора, не ошибка сборки.
