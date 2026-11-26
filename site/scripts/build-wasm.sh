#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."

compiler=${WASM_GHC:-wasm32-wasi-ghc}
for tool in "$compiler" bnfc alex happy; do
  command -v "$tool" >/dev/null || { echo "Missing tool: $tool" >&2; exit 1; }
done

build=$(mktemp -d)
trap 'rm -rf "$build"' EXIT
(
  cd "$build"
  for grammar in CoreLambda PureLambda Ski; do
    bnfc --haskell -d "$OLDPWD/grammar/$grammar.cf"
    alex "$grammar/Lex.x" -o "$grammar/Lex.hs"
    happy "$grammar/Par.y" -o "$grammar/Par.hs"
  done
)

for entry in Compiler Interpreter LanguageService; do
  case "$entry" in
    Compiler) name=lambda-compiler ; source="app/CompilerMain.hs" ;;
    Interpreter) name=ski-interpreter ; source="app/InterpreterMain.hs" ;;
    LanguageService) name=language-service; source=site/wasm/LanguageServiceMain.hs ;;
  esac
  args=(--make "$source" -O1 -i"$build" -isrc -outputdir "$build/$entry")
  # Compile Template Haskell before applying the command's final memory limit.
  "$compiler" "${args[@]}" -no-link
  "$compiler" "${args[@]}" -rtsopts '-with-rtsopts=-M128m -K32m' \
    -optl-Wl,--max-memory=268435456 -o "$build/$name.wasm"
done

mkdir -p site/public/playground
cp "$build"/*.wasm site/public/playground/
