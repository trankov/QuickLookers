// Генерирует associations.json: {version, languages:[{id, extensions[], filenames[]}]}.
// Источники: github-linguist languages.yml (вендорен) ∪ fileTypes грамматик Shiki ∪
// associations-overrides.json (авторитетно). Владение расширением/именем разрешается
// в конфликт-фри: каждое расширение/имя принадлежит ровно одному языку Shiki.
// Запуск: cd js && node generate-associations.mjs
import { readFileSync, writeFileSync } from 'fs'
import yaml from 'js-yaml'
import { bundledLanguagesInfo } from 'shiki'

const norm = (s) => String(s).toLowerCase().replace(/[^a-z0-9]/g, '')
const shiki = bundledLanguagesInfo
const shikiIds = new Set(shiki.map((l) => l.id))

// 1) индекс «нормализованное имя/алиас → shikiId»
const nameToShiki = new Map()
for (const l of shiki) {
  for (const key of [l.id, l.name, ...(l.aliases ?? [])]) {
    if (key) nameToShiki.set(norm(key), l.id)
  }
}
const overrides = JSON.parse(readFileSync('./associations-overrides.json', 'utf8'))
for (const [name, id] of Object.entries(overrides.languageAlias ?? {})) nameToShiki.set(norm(name), id)

// 2) кандидаты владельцев по ext/filename
const extCandidates = new Map()
const fileCandidates = new Map()
const addCand = (map, key, id) => {
  if (!map.has(key)) map.set(key, new Set())
  map.get(key).add(id)
}

// 2a) linguist
const linguist = yaml.load(readFileSync('./vendor/linguist-languages.yml', 'utf8'))
for (const [langName, def] of Object.entries(linguist)) {
  const id = nameToShiki.get(norm(langName))
    ?? (def.aliases ?? []).map((a) => nameToShiki.get(norm(a))).find(Boolean)
  if (!id) continue
  for (const ext of def.extensions ?? []) addCand(extCandidates, ext.replace(/^\./, '').toLowerCase(), id)
  for (const fn of def.filenames ?? []) addCand(fileCandidates, fn, id)
}

// 2b) fileTypes самих грамматик Shiki (дополнение + сигнал для тай-брейка)
const shikiClaims = new Set()
for (const id of shikiIds) {
  const mod = await import(`@shikijs/langs/${id}`)
  const arr = Array.isArray(mod.default) ? mod.default : [mod.default]
  const main = arr.find((g) => g.name === id) ?? arr[0]
  for (const ext of main?.fileTypes ?? []) {
    const e = String(ext).replace(/^\./, '').toLowerCase()
    addCand(extCandidates, e, id)
    shikiClaims.add(`${id}:${e}`)
  }
}

// 3) разрешение владения (конфликт-фри). overrides авторитетно; иначе — собственный
// claim грамматики Shiki; иначе — алфавит. Все конфликты логируем (не молчим).
const conflicts = []
const extOwner = new Map()
for (const [ext, cands] of extCandidates) {
  let id
  if (overrides.extensions?.[ext]) {
    id = overrides.extensions[ext]
  } else {
    const list = [...cands]
    if (list.length === 1) { id = list[0] }
    else {
      const owned = list.filter((x) => shikiClaims.has(`${x}:${ext}`))
      id = (owned.length ? owned : list).sort()[0]
      conflicts.push(`ext .${ext}: ${list.sort().join(',')} → ${id}`)
    }
  }
  if (shikiIds.has(id)) extOwner.set(ext, id)
}
const fileOwner = new Map()
for (const [fn, cands] of fileCandidates) {
  let id = overrides.filenames?.[fn]
  if (!id) {
    const list = [...cands]
    id = list.sort()[0]
    if (list.length > 1) conflicts.push(`file ${fn}: ${list.sort().join(',')} → ${id}`)
  }
  if (shikiIds.has(id)) fileOwner.set(fn, id)
}
// overrides могут вводить ext/filename, которых не было в кандидатах
for (const [ext, id] of Object.entries(overrides.extensions ?? {})) if (shikiIds.has(id)) extOwner.set(ext, id)
for (const [fn, id] of Object.entries(overrides.filenames ?? {})) if (shikiIds.has(id)) fileOwner.set(fn, id)

// 4) инверсия в списки по языкам
const byLang = new Map()
const ensure = (id) => {
  if (!byLang.has(id)) byLang.set(id, { id, extensions: [], filenames: [] })
  return byLang.get(id)
}
for (const [ext, id] of extOwner) ensure(id).extensions.push(ext)
for (const [fn, id] of fileOwner) ensure(id).filenames.push(fn)
const languages = [...byLang.values()]
  .map((l) => ({ id: l.id, extensions: l.extensions.sort(), filenames: l.filenames.sort() }))
  .sort((a, b) => a.id.localeCompare(b.id))

writeFileSync('../Sources/QuickLookersEngine/Resources/associations.json',
  JSON.stringify({ version: 1, languages }))
console.log(`associations: languages=${languages.length} ext=${extOwner.size} file=${fileOwner.size} conflicts=${conflicts.length}`)
for (const c of conflicts) console.log('  conflict', c)
