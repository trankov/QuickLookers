import { build } from 'esbuild'

await build({
  entryPoints: ['src/highlight.mjs'],
  bundle: true,
  format: 'iife',
  target: ['safari16'],
  platform: 'neutral',
  outfile: '../Sources/QuickLookersEngine/Resources/shiki-bundle.js',
})

console.log('built shiki-bundle.js')
