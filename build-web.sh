#!/usr/bin/env bash
# Build a browser-compatible tree-sitter wasm for Coral.
#
# The wasm Zed loads and the wasm a browser loads CANNOT be the same file:
#
#   Zed   needs language ABI 15 (the current tree-sitter default)
#   web   needs ABI 13-14   (web-tree-sitter 0.23.x rejects 15 outright:
#                            "Incompatible language version 15")
#
# Both are side modules (wasm-ld -shared, dylink section), so the same compile
# and link recipe serves both; only the generated parser differs. This script
# regenerates from grammar.js at --abi 14 and leaves the ABI 15 build alone.
#
# No network and no downloads: tree-sitter, clang and wasm-ld are all local.
#
#   ./build-web.sh [output.wasm]

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
G="$ROOT/grammars/coral"
OUT="${1:-$ROOT/coral-web.wasm}"
mkdir -p "$(dirname "$OUT")"
WEB_ABI=14

command -v tree-sitter >/dev/null || { echo "tree-sitter CLI not found" >&2; exit 1; }
command -v clang      >/dev/null || { echo "clang not found" >&2; exit 1; }
command -v wasm-ld    >/dev/null || { echo "wasm-ld not found" >&2; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "== generating parser at ABI $WEB_ABI"
mkdir -p "$WORK/gen"
cp -r "$G" "$WORK/gen/coral"
rm -rf "$WORK/gen/coral/src"
( cd "$WORK/gen/coral" && tree-sitter generate --abi "$WEB_ABI" >/dev/null )
grep -q "#define LANGUAGE_VERSION $WEB_ABI" "$WORK/gen/coral/src/parser.c" \
  || { echo "expected LANGUAGE_VERSION $WEB_ABI" >&2; exit 1; }

# The generated parser makes no libc calls, so stub headers stand in for
# stdlib.h / string.h / assert.h / stdio.h. Same trick build.sh uses.
INC="$WORK/include"; mkdir -p "$INC"
printf '#include <stddef.h>\n'                      > "$INC/stdlib.h"
printf '#include <stddef.h>\n'                      > "$INC/string.h"
printf '#define assert(e) ((void)0)\n'              > "$INC/assert.h"
printf '#include <stddef.h>\ntypedef struct _FILE FILE;\n' > "$INC/stdio.h"

echo "== compiling"
clang --target=wasm32-unknown-unknown -fPIC -O2 -fno-builtin \
      -I"$INC" -I"$WORK/gen/coral/src" \
      -c "$WORK/gen/coral/src/parser.c" -o "$WORK/parser.o"

echo "== linking -> $(basename "$OUT")"
# -fPIC + -shared gives wasm-ld the dylink section that both Zed and
# web-tree-sitter expect from a language module.
wasm-ld -shared "$WORK/parser.o" -o "$OUT" \
        --export=tree_sitter_coral --strip-all 2>&1 | grep -v 'not yet stable' || true

test -s "$OUT" || { echo "wasm build produced nothing" >&2; exit 1; }
printf '   %s: %s bytes\n' "$(basename "$OUT")" "$(stat -c%s "$OUT")"

# Ship the grammar metadata a browser client needs to work with the wasm.
for extra in node-types.json grammar.json; do
  [ -f "$WORK/gen/coral/src/$extra" ] && cp "$WORK/gen/coral/src/$extra" "$WORK/$extra"
done
cp "$WORK/node-types.json" "${OUT%.wasm}.node-types.json" 2>/dev/null || true

echo "done"