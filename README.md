# QuickLookers

Превью кода по пробелу в Finder на macOS — **визуально как в VS Code/Cursor**.

После того как Apple вытеснила старую архитектуру QuickLook-плагинов (`.qlgenerator`), часть нужных плагинов перестала работать. QuickLookers возвращает эту возможность современным поддерживаемым способом и красит код **теми же грамматиками и темами, что использует VS Code** (через [Shiki](https://shiki.style)). Markdown — вне области продукта (для него есть FluxMarkdown).

## Состояние

Проект в активной разработке. Движок готов; расширение Preview доведено до рабочего сквозного среза — пробел в Finder на `.swift`/`.json`/`.js` уже даёт подсветку как в VS Code (тема Dark+).

| Подсистема | Статус |
|---|---|
| Движок рендеринга (`QuickLookersEngine`) | готов |
| Расширение QuickLook Preview | тонкий срез работает (swift/json/js, Dark+) |
| Расширение Thumbnail | запланировано |
| Главное приложение + настройки + App Group | запланировано |

## Архитектура

- **Главное приложение** — настройки, импорт тем/грамматик из VS Code/Cursor и `.vsix`, управление кэшем. Менеджер библиотеки.
- **Расширения QuickLook (Preview + Thumbnail)** — в песочнице, только рисуют готовое.
- **Общий контейнер (App Group)** — темы, грамматики, кэш HTML, настройки.

Подсветка: `код + язык + тема → HTML` через Shiki в JavaScriptCore, затем статичный показ в WKWebView с выключенным JavaScript.

Полный дизайн — `docs/superpowers/specs/2026-06-27-quicklookers-design.md`.

## Сборка и тесты

Требуется macOS 13+, Swift 6 / Xcode 26, XcodeGen (`brew install xcodegen`), Node (только для пересборки JS-бандла).

```bash
# Тесты движка и PreviewKit
swift test

# Пересобрать JS-бандл Shiki (после правок js/src/*)
cd js && npm install && npm run build && npm test

# Сгенерировать Xcode-проект (приложение + расширение Preview)
xcodegen generate

# Запустить хост-приложение из Xcode (⌘R) — это регистрирует расширение,
# после чего пробел в Finder на файле кода даёт превью.
```

Подробности про настройку расширения (App Sandbox, network.client и прочие грабли) — в `CLAUDE.md` и `docs/superpowers/notes/2026-06-28-preview-thin-slice-spikes.md`.

## Документация

- `docs/superpowers/specs/` — дизайн-документы.
- `docs/superpowers/plans/` — планы реализации по подсистемам.
- `docs/superpowers/notes/` — замеры производительности и показания spike.
- `CLAUDE.md` — рабочее руководство, договорённости и грабли проекта.

## Лицензия

Грамматики и темы поставляются из коллекции Shiki (`@shikijs/langs`, `@shikijs/themes`). Расширения VS Code (`.vsix`) пользователь скачивает себе сам — приложение их не раздаёт.
