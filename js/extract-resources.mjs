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

const resourcesDir = '../Sources/QuickLookersEngine/Resources'
const grammarsDir = `${resourcesDir}/grammars`
const themesDir = `${resourcesDir}/themes`
mkdirSync(grammarsDir, { recursive: true })
mkdirSync(themesDir, { recursive: true })

const languages = []
const themes = []

// Грамматика: модуль экспортирует массив [главная + встроенные]. Пишем целиком,
// а в сайдкар — id + displayName главной записи (name == id), как читает фоллбэк.
for (const id of GRAMMARS) {
  const mod = await import(`@shikijs/langs/${id}`)
  const arr = Array.isArray(mod.default) ? mod.default : [mod.default]
  writeFileSync(`${grammarsDir}/${id}.json`, JSON.stringify(arr))
  const main = arr.find((g) => g.name === id)
  languages.push({ id, displayName: main?.displayName ?? id })
  console.log(`grammar ${id} <- entries=${arr.length}`)
}

// Тема: модуль экспортирует один объект.
for (const id of THEMES) {
  const mod = await import(`@shikijs/themes/${id}`)
  const theme = mod.default
  writeFileSync(`${themesDir}/${id}.json`, JSON.stringify(theme))
  themes.push({
    id: theme.name,
    displayName: theme.displayName ?? theme.name,
    isDark: theme.type === 'dark',
  })
  console.log(`theme ${id} <- name=${theme.name}`)
}

// Сайдкар-каталог: маленький индекс метаданных, чтобы окно настроек не читало
// все ~41 МБ грамматик. Артефакт сборки — руками не править.
writeFileSync(`${resourcesDir}/catalog.json`, JSON.stringify({ languages, themes }))

console.log(`resources extracted: languages=${languages.length} themes=${themes.length}`)
