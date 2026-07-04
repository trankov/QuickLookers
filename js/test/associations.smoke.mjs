import { readFileSync } from 'fs'
import assert from 'assert'
import { bundledLanguagesInfo } from 'shiki'

const data = JSON.parse(readFileSync('../Sources/QuickLookersEngine/Resources/associations.json', 'utf8'))
assert.equal(data.version, 1, 'version == 1')
assert.ok(Array.isArray(data.languages) && data.languages.length > 50, 'много языков')

const shikiIds = new Set(bundledLanguagesInfo.map((l) => l.id))
const extOwner = new Map()
for (const lang of data.languages) {
  assert.ok(shikiIds.has(lang.id), `id ∈ shiki: ${lang.id}`)
  for (const ext of lang.extensions) {
    assert.ok(!extOwner.has(ext), `расширение уникально: .${ext} у ${extOwner.get(ext)} и ${lang.id}`)
    extOwner.set(ext, lang.id)
  }
}
const fileOwner = new Map()
for (const lang of data.languages) for (const fn of lang.filenames) fileOwner.set(fn, lang.id)

assert.equal(extOwner.get('swift'), 'swift')
assert.equal(extOwner.get('py'), 'python')
assert.equal(extOwner.get('json'), 'json')
assert.equal(extOwner.get('yaml'), 'yaml')
assert.equal(extOwner.get('h'), 'c')          // разрешён override
assert.equal(fileOwner.get('Dockerfile'), 'docker')
assert.equal(extOwner.get('php'), 'php')
assert.equal(extOwner.get('sql'), 'sql')
assert.equal(extOwner.get('pl'), 'perl')
assert.equal(extOwner.get('bib'), 'bibtex')
assert.equal(extOwner.get('rkt'), 'racket')
assert.equal(extOwner.get('fs'), 'fsharp')
assert.equal(extOwner.get('m'), 'objective-c')
assert.equal(extOwner.get('c'), 'c')
assert.equal(extOwner.get('cpp'), 'cpp')
assert.equal(extOwner.get('cs'), 'csharp')

// interceptExtensions: перехват без грамматики (пользователь назначит язык сам).
assert.ok(Array.isArray(data.interceptExtensions) && data.interceptExtensions.length > 100,
  'interceptExtensions присутствует и непуст')
const intercept = new Set(data.interceptExtensions)
assert.ok(intercept.has('agda'), 'agda в перехвате (грамматики нет)')
assert.ok(intercept.has('zig') === false, 'zig не в перехвате — у него уже есть язык')
// intercept и owned не пересекаются
for (const e of intercept) assert.ok(!extOwner.has(e), `intercept .${e} не должен быть owned языком`)
// дефолты Pygments с грамматикой закреплены за языком
assert.equal(extOwner.get('gradle'), 'groovy')
assert.equal(extOwner.get('ndjson'), 'json')
assert.equal(extOwner.get('pom'), 'xml')
console.log('associations smoke OK')
