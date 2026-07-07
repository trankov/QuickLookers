# Сторонние компоненты / Third-Party Notices

**[Русский](#русский)** · **[English](#english)**

Само приложение **QuickLookers** распространяется под лицензией **GPL-3.0** (см. [`LICENSE`](LICENSE)). Однако в состав сборки входят сторонние компоненты со **своими** лицензиями, перечисленные ниже. Их авторские права и условия сохраняются за правообладателями.

The **QuickLookers** application itself is distributed under **GPL-3.0** (see [`LICENSE`](LICENSE)). It bundles third-party components under **their own** licenses, listed below. Their copyrights and terms remain with the respective owners.

---

## Русский

### Встроено в приложение (поставляется вместе со сборкой)

| Компонент | Что это | Лицензия |
| --- | --- | --- |
| [Shiki](https://github.com/shikijs/shiki) 1.29.2 | Движок подсветки синтаксиса (JS-бандл `shiki-bundle.js`) | MIT |
| [`@shikijs/langs`](https://github.com/shikijs/textmate-grammars-themes) | 218 TextMate-грамматик (`Resources/grammars/*.json`) | MIT + лицензии исходных грамматик (см. ниже) |
| [`@shikijs/themes`](https://github.com/shikijs/textmate-grammars-themes) | 54 темы VS Code (`Resources/themes/*.json`) | MIT + лицензии исходных тем (см. ниже) |
| [github-linguist](https://github.com/github-linguist/linguist) | Датасет «язык → расширения/имена файлов» (основа `Resources/associations.json`) | MIT |

### Только для сборки (в готовую программу НЕ попадает)

| Компонент | Что это | Лицензия |
| --- | --- | --- |
| [esbuild](https://github.com/evanw/esbuild) 0.20.2 | Сборка JS-бандла | MIT |
| [js-yaml](https://github.com/nodeca/js-yaml) | Чтение датасета linguist при генерации | MIT |

### Важное про грамматики и темы

Грамматики (`@shikijs/langs`) и темы (`@shikijs/themes`) — это агрегатор: пакет собирает **TextMate-грамматики и темы VS Code из множества исходных проектов**, у каждого из которых **своя лицензия** (чаще всего MIT или Apache-2.0, но встречаются и другие). Сам агрегатор — под MIT, но лицензии на конкретную грамматику/тему принадлежат её первоисточнику.

Полный пофайловый список источников и их лицензий ведётся в репозитории [shikijs/textmate-grammars-themes](https://github.com/shikijs/textmate-grammars-themes) — см. каталоги `packages/tm-grammars` и `packages/tm-themes`.

---

## English

### Bundled in the app (shipped with the build)

| Component | What it is | License |
| --- | --- | --- |
| [Shiki](https://github.com/shikijs/shiki) 1.29.2 | Syntax highlighting engine (JS bundle `shiki-bundle.js`) | MIT |
| [`@shikijs/langs`](https://github.com/shikijs/textmate-grammars-themes) | 218 TextMate grammars (`Resources/grammars/*.json`) | MIT + upstream grammar licenses (see below) |
| [`@shikijs/themes`](https://github.com/shikijs/textmate-grammars-themes) | 54 VS Code themes (`Resources/themes/*.json`) | MIT + upstream theme licenses (see below) |
| [github-linguist](https://github.com/github-linguist/linguist) | "language → extensions/filenames" dataset (basis of `Resourcesassociations.json`) | MIT |

### Build-time only (NOT shipped in the final app)

| Component | What it is | License |
| --- | --- | --- |
| [esbuild](https://github.com/evanw/esbuild) 0.20.2 | Builds the JS bundle | MIT |
| [js-yaml](https://github.com/nodeca/js-yaml) | Reads the linguist dataset during generation | MIT |

### Note on grammars and themes

The grammars (`@shikijs/langs`) and themes (`@shikijs/themes`) are an aggregation: the package collects **TextMate grammars and VS Code themes from many upstream projects**, each under **its own license** (most often MIT or Apache-2.0, but others occur). The aggregator itself is MIT, but the license of any individual grammar/theme belongs to its original source.

A full per-file list of sources and their licenses is maintained in [shikijs/textmate-grammars-themes](https://github.com/shikijs/textmate-grammars-themes) — see `packages/tm-grammars` and `packages/tm-themes`.
