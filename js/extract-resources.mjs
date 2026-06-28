// Достаёт грамматики и темы Shiki из ESM-модулей @shikijs/* и кладёт их
// в ресурсы пакета как обычный JSON (имя файла = id = поле name).
// В shiki 1.x грамматики/темы поставляются как .mjs, а не .json,
// поэтому простой cp не годится — импортируем и сериализуем.
//
// Запуск: cd js && npm install && node extract-resources.mjs

import { writeFileSync, mkdirSync } from 'fs'
import { bundledLanguagesInfo, bundledThemesInfo } from 'shiki'

const GRAMMARS = bundledLanguagesInfo.map((l) => l.id)
const THEMES = bundledThemesInfo.map((t) => t.id)

const grammarsDir = '../Sources/QuickLookersEngine/Resources/grammars'
const themesDir = '../Sources/QuickLookersEngine/Resources/themes'
mkdirSync(grammarsDir, { recursive: true })
mkdirSync(themesDir, { recursive: true })

// Грамматика: модуль экспортирует массив [главная + встроенные]. Пишем целиком.
for (const id of GRAMMARS) {
  const mod = await import(`@shikijs/langs/${id}`)
  const arr = Array.isArray(mod.default) ? mod.default : [mod.default]
  writeFileSync(`${grammarsDir}/${id}.json`, JSON.stringify(arr))
  console.log(`grammar ${id} <- entries=${arr.length}`)
}

// Тема: модуль экспортирует один объект.
for (const id of THEMES) {
  const mod = await import(`@shikijs/themes/${id}`)
  const theme = mod.default
  writeFileSync(`${themesDir}/${id}.json`, JSON.stringify(theme))
  console.log(`theme ${id} <- name=${theme.name}`)
}

console.log('resources extracted')
