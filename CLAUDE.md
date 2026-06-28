# CLAUDE.md

Руководство для работы над проектом **QuickLookers**. Отвечать пользователю всегда по-русски, простым человеческим языком.

## Что это

macOS-приложение, возвращающее превью кода и Markdown по пробелу в Finder (взамен сломавшихся старых QuickLook-плагинов `.qlgenerator`). Главное требование — **визуально один-в-один как в VS Code/Cursor**: тот же движок подсветки, те же грамматики и темы.

## Архитектура (целевая)

Три части + общий контейнер:

- **Главное приложение** — GUI с настройками. Имеет сеть, читает конфиг VS Code/Cursor, управляет библиотекой тем/грамматик, импортом (`.vsix`), кэшем. **Менеджер**: скачивает/импортирует/нормализует.
- **Расширение QuickLook Preview** — полноразмерное превью по пробелу. В песочнице, без сети. **Потребитель**: берёт готовое и рисует.
- **Расширение Thumbnail** — иконки в Finder, нативный рендер без WebView. **Потребитель**.
- **App Group** — общий контейнер: темы, грамматики, кэш HTML, настройки. Единственное, что видит песочница расширений.

Подробности: `docs/superpowers/specs/2026-06-27-quicklookers-design.md`.

## Текущее состояние

Первая подсистема — **движок рендеринга** (Swift-пакет `QuickLookersEngine`) — **реализована** (план `docs/superpowers/plans/2026-06-27-quicklookers-rendering-engine.md`, все 6 задач + cleanup, ветка `feat/rendering-engine`). Расширения QuickLook, App Group и приложение — отдельные будущие планы.

Движок: `код + язык + тема → готовый HTML` через **Shiki** в **JavaScriptCore**. Shiki выбран потому, что использует те же TextMate-грамматики и VS Code-темы → совпадение с VS Code, а не «похоже». Точка входа — `QuickLookersEngineFactory.makeDefault() -> HighlightEngine`.

**Замер производительности (важно для следующих подсистем):** голый движок на 200 строках Swift даёт холодный показ ≈440 мс, тёплый ≈190 мс (release ≈ debug — стоимость в JS-слое JSC). Это **над** ориентиром ~100 мс. Бюджет добираем не в движке, а оптимизациями показа в подсистеме Preview: кэш готового HTML, обрезка первого экрана, при необходимости свап на WASM-движок регулярок. Полный нативный порт (Oniguruma + Swift) **отложен**. Детали и решение — `docs/superpowers/notes/2026-06-28-engine-benchmark.md`.

## Структура

```
Package.swift                          # SwiftPM-пакет QuickLookersEngine, macOS 13+
Sources/QuickLookersEngine/
  HighlightEngine.swift                # протокол HighlightEngine + HighlightRequest + EngineError
  JSCoreRuntime.swift                  # обёртка над JavaScriptCore (Task 3)
  Providers.swift                      # GrammarProvider / ThemeProvider (Task 4)
  ShikiEngine.swift                    # реализация HighlightEngine (Task 5)
  EngineFactory.swift                  # сборка из Bundle.module (Task 5)
  Resources/
    shiki-bundle.js                    # СОБИРАЕТСЯ из js/, не править вручную
    grammars/*.json                    # грамматики Shiki (имя файла = id = поле name)
    themes/*.json                      # темы Shiki
js/                                    # шаг сборки JS-бандла (Node, только для сборки)
  src/highlight.mjs                    # точка входа: вешает globalThis.ql*
  build.mjs                            # esbuild → Resources/shiki-bundle.js
  test/smoke.mjs                       # node-смоук готового бандла
Tests/QuickLookersEngineTests/         # XCTest, TDD
docs/superpowers/                      # specs/ (дизайн) и plans/ (планы реализации)
```

## Команды

```bash
# Тесты пакета
swift test
swift test --filter RuntimeTests

# Пересборка JS-бандла Shiki (после правок js/src/*)
cd js && npm install && npm run build && npm test
```

`shiki-bundle.js` — **артефакт сборки**, лежит в ресурсах и коммитится, но руками его не редактируют: меняют `js/src/highlight.mjs` и пересобирают.

## Принципы и договорённости

- **TDD строго:** сначала падающий тест → запуск (убедиться, что падает) → реализация → запуск (зелёный) → коммит. По одному маленькому шагу.
- **Движок изолирован за протоколом** `HighlightEngine`. Потребители (расширения, приложение) не знают про Shiki/JSC. Нативный движок (Oniguruma + Swift-токенизатор) — запасной путь, включаем только если бенчмарк (Task 6) не влезет в бюджет ~100 мс. Решение — по замерам, не заранее.
- **Без WASM:** движок регулярок Shiki — только JS (`createJavaScriptRegexEngine`).
- **Всё офлайн:** бандл, грамматики, темы — в ресурсах пакета.
- **Вывод — готовая HTML-строка** для статичного показа в WKWebView с выключенным JS (WebView не выполняет код).
- **Паритет с VS Code** держится на настоящих грамматиках/темах из `@shikijs/langs` и `@shikijs/themes`, не самописных.

## Версии (зафиксированы)

- Swift 6.3 / SwiftPM (tools 5.9), цель macOS 13+.
- shiki **1.29.2**, esbuild **0.20.2** (см. `js/package-lock.json`).
- Метод `codeToHtml` у `createHighlighterCoreSync` в этой версии **есть** (подтверждено смоук-тестом).

## Коммиты

- Сообщения по-русски, формат `feat(engine): ...` / `test(engine): ...` / `docs: ...`.
- Трейлер: `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.
- Реализация идёт в ветке `feat/rendering-engine`, не в `main`.

## Заметки по окружению

- npm-окружение блокирует postinstall-скрипты (предупреждение про esbuild) — на сборку бандла не влияет.
- Взаимодействие с Xcode (расширения, App Group, права, подписи) начнётся только в планах 2–4; движок (этот план) — чистый SwiftPM.
