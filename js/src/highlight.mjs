import { createHighlighterCoreSync } from 'shiki/core'
import { createJavaScriptRegexEngine } from 'shiki/engine/javascript'

// Один движок регулярок на всё, без WASM.
const engine = createJavaScriptRegexEngine({ forgiving: true })

const langByName = new Map()   // name -> грамматика (главные и встроенные)
const themes = new Map()       // name -> тема
const highlighters = new Map() // `${lang} ${theme}` -> HighlighterCore

// Грамматика приходит массивом [главная + встроенные зависимости].
globalThis.qlRegisterLang = (json) => {
  const parsed = JSON.parse(json)
  const arr = Array.isArray(parsed) ? parsed : [parsed]
  for (const g of arr) langByName.set(g.name, g)
  return arr.length
}

globalThis.qlRegisterTheme = (json) => {
  const theme = JSON.parse(json)
  themes.set(theme.name, theme)
  return theme.name
}

// Собираем главную грамматику и её встроенные зависимости (транзитивно, без lazy).
function collectLangs(name, acc, seen) {
  if (seen.has(name)) return
  seen.add(name)
  const g = langByName.get(name)
  if (!g) return
  acc.push(g)
  for (const dep of (g.embeddedLangs || [])) collectLangs(dep, acc, seen)
}

globalThis.qlHighlight = (code, langName, themeName) => {
  const key = langName + ' ' + themeName
  let hl = highlighters.get(key)
  if (!hl) {
    const langs = []
    collectLangs(langName, langs, new Set())
    if (langs.length === 0) throw new Error('lang not registered: ' + langName)
    const theme = themes.get(themeName)
    if (!theme) throw new Error('theme not registered: ' + themeName)
    hl = createHighlighterCoreSync({ themes: [theme], langs, engine })
    highlighters.set(key, hl)
  }
  return hl.codeToHtml(code, { lang: langName, theme: themeName })
}
