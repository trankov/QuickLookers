import { createRequire } from 'module'
import { readFileSync } from 'fs'
import { fileURLToPath } from 'url'
import { join, dirname } from 'path'
import assert from 'assert'

const require = createRequire(import.meta.url)
// Выполнение iife-файла вешает globalThis.ql*
require('../../Sources/QuickLookersEngine/Resources/shiki-bundle.js')

// Пути относительно этого файла (js/test/smoke.mjs), а не CWD
const __dirname = dirname(fileURLToPath(import.meta.url))
const grammarsDir = join(__dirname, '../../Sources/QuickLookersEngine/Resources/grammars')
const themesDir = join(__dirname, '../../Sources/QuickLookersEngine/Resources/themes')

// --- регистрируем реальные грамматики (теперь массивы) и тему из ресурсов ---
for (const lang of ['swift', 'javascript', 'json']) {
  const json = readFileSync(join(grammarsDir, `${lang}.json`), 'utf8')
  const count = globalThis.qlRegisterLang(json)
  assert.ok(count >= 1, `qlRegisterLang(${lang}) должен вернуть >= 1`)
}

const themeJson = readFileSync(join(themesDir, 'dark-plus.json'), 'utf8')
const themeName = globalThis.qlRegisterTheme(themeJson)
assert.strictEqual(themeName, 'dark-plus', 'тема должна называться dark-plus')

// --- проверяем подсветку для всех трёх языков ---
const cases = [
  { lang: 'swift', code: 'let x: Int = 42' },
  { lang: 'javascript', code: 'const x = 42' },
  { lang: 'json', code: '{"key": 1}' },
]

for (const { lang, code } of cases) {
  const html = globalThis.qlHighlight(code, lang, 'dark-plus')
  assert.ok(html.includes('<pre'), `${lang}: ожидался <pre> в выводе`)
  assert.ok(html.length > 50, `${lang}: HTML слишком короткий`)
  console.log(`smoke ${lang}: OK (${html.length} bytes)`)
}

// --- проверяем встроенную подсветку vue (html + css + js внутри одного файла) ---
const vueJson = readFileSync(join(grammarsDir, 'vue.json'), 'utf8')
const vueCount = globalThis.qlRegisterLang(vueJson)
assert.ok(vueCount >= 1, `qlRegisterLang(vue) должен вернуть >= 1`)

const vueSfc = `<template>
  <div class="hello">{{ msg }}</div>
</template>
<script>
export default { data() { return { msg: 'Hello' } } }
</script>`

const vueHtml = globalThis.qlHighlight(vueSfc, 'vue', 'dark-plus')
assert.ok(vueHtml.includes('<pre'), 'vue: ожидался <pre> в выводе')
// В шаблоне: тег div или атрибут class → span с color-стилем
assert.ok(
  vueHtml.includes('class="hello"') || vueHtml.includes('style="color:'),
  'vue: ожидаются раскрашенные токены из <template>'
)
// В скрипте: export или default → отдельные span
const spanMatches = (vueHtml.match(/<span[^>]*>/g) || []).length
assert.ok(spanMatches >= 4, `vue: ожидается >= 4 span-токенов, получено ${spanMatches}`)
console.log(`smoke vue: OK (${vueHtml.length} bytes, ${spanMatches} spans)`)

console.log('smoke OK')
