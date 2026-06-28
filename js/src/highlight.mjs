import { createHighlighterCoreSync } from 'shiki/core'
import { createJavaScriptRegexEngine } from 'shiki/engine/javascript'

// Один движок регулярок на всё, без WASM.
const engine = createJavaScriptRegexEngine({ forgiving: true })

// Грамматики/темы регистрируются один раз; подсветчики кэшируются по паре (язык, тема).
const langs = new Map()   // name -> language object
const themes = new Map()  // name -> theme object
const highlighters = new Map() // `${lang} ${theme}` -> HighlighterCore

globalThis.qlRegisterLang = (json) => {
  const lang = JSON.parse(json)
  langs.set(lang.name, lang)
  return lang.name
}

globalThis.qlRegisterTheme = (json) => {
  const theme = JSON.parse(json)
  themes.set(theme.name, theme)
  return theme.name
}

globalThis.qlHighlight = (code, langName, themeName) => {
  const key = langName + ' ' + themeName
  let hl = highlighters.get(key)
  if (!hl) {
    const lang = langs.get(langName)
    const theme = themes.get(themeName)
    if (!lang) throw new Error('lang not registered: ' + langName)
    if (!theme) throw new Error('theme not registered: ' + themeName)
    hl = createHighlighterCoreSync({ themes: [theme], langs: [lang], engine })
    highlighters.set(key, hl)
  }
  return hl.codeToHtml(code, { lang: langName, theme: themeName })
}
