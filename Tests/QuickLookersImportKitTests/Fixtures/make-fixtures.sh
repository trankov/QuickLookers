#!/bin/bash
# Собирает минимальные .vsix-фикстуры. Запуск: bash make-fixtures.sh
set -e
cd "$(dirname "$0")"
rm -rf build && mkdir build

# theme-only: один package.json + одна тема
mkdir -p build/theme/extension/theme
cat > build/theme/extension/package.json <<'EOF'
{"name":"t","contributes":{"themes":[{"label":"My Cool Theme","uiTheme":"vs-dark","path":"./theme/cool.json"}]}}
EOF
echo '{"name":"My Cool Theme","type":"dark","tokenColors":[]}' > build/theme/extension/theme/cool.json
(cd build/theme && zip -r -X ../../theme-only.vsix extension >/dev/null)

# grammar-json: JSON-грамматика без вложенных (deflate)
mkdir -p build/gj/extension/syntaxes
cat > build/gj/extension/package.json <<'EOF'
{"name":"g","contributes":{"languages":[{"id":"toy","aliases":["Toy Lang"]}],"grammars":[{"language":"toy","scopeName":"source.toy","path":"./syntaxes/toy.tmLanguage.json"}]}}
EOF
echo '{"name":"toy","scopeName":"source.toy","patterns":[]}' > build/gj/extension/syntaxes/toy.tmLanguage.json
(cd build/gj && zip -r -X ../../grammar-json.vsix extension >/dev/null)

# stored (без сжатия) — проверить путь stored в libarchive
(cd build/gj && zip -r -0 -X ../../grammar-json-stored.vsix extension >/dev/null)

# not-a-vsix: случайные байты
head -c 64 /dev/urandom > not-a-vsix.vsix

rm -rf build
echo "fixtures built"
