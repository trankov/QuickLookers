import { createRequire } from 'module'
import assert from 'assert'

const require = createRequire(import.meta.url)
// Выполнение iife-файла вешает globalThis.ql*
require('../../Sources/QuickLookersEngine/Resources/shiki-bundle.js')

const minimalLang = JSON.stringify({
  name: 'plaintext', scopeName: 'source.plain', patterns: []
})
const minimalTheme = JSON.stringify({
  name: 't', type: 'dark', colors: { 'editor.foreground': '#ffffff' }, tokenColors: []
})

globalThis.qlRegisterLang(minimalLang)
globalThis.qlRegisterTheme(minimalTheme)
const html = globalThis.qlHighlight('hello', 'plaintext', 't')

assert.ok(html.includes('<pre'), 'ожидался <pre> в выводе')
assert.ok(html.includes('hello'), 'ожидался текст в выводе')
console.log('smoke OK')
