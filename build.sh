#!/usr/bin/env bash
# Compile the coral tree-sitter grammar to a WebAssembly module and install
# the extension into Zed. Fully offline: no wasi-sdk, no downloads.
#
# The generated parser makes no libc calls, so stub headers stand in for
# stdlib.h / string.h / assert.h / stdio.h and the object is linked
# position-independently so wasm-ld emits the `dylink` section Zed reads.
#
#   ./build.sh [dst]
set -uo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
G="$ROOT/grammars/coral"
DST="${1:-${ZED_EXT_DIR:-$HOME/.local/share/zed/extensions/installed/coral}}"
INC="$(mktemp -d)"
trap 'rm -rf "$INC"' EXIT

printf '#include <stddef.h>\n'  > "$INC/stdlib.h"
printf '#include <stddef.h>\n'  > "$INC/string.h"
printf '#define assert(e) ((void)0)\n' > "$INC/assert.h"
printf '#include <stddef.h>\ntypedef struct _FILE FILE;\n' > "$INC/stdio.h"

# grammar.js -> parser.c
(cd "$G" && tree-sitter generate) || exit 1

echo '== clang -> wasm object'
clang --target=wasm32-unknown-unknown -fPIC -O2 -fno-builtin \
      -I"$INC" -I"$G/src" -c "$G/src/parser.c" -o "$ROOT/coral-wasm.o" || exit 1

echo '== wasm-ld -> coral.wasm (dylink section)'
wasm-ld -shared "$ROOT/coral-wasm.o" -o "$ROOT/grammars/coral.wasm" \
        --export=tree_sitter_coral --strip-all 2>&1 | grep -v 'not yet stable' || true
rm -f "$ROOT/coral-wasm.o"
test -s "$ROOT/grammars/coral.wasm" || { echo 'wasm build failed'; exit 1; }

echo '== install'
mkdir -p "$DST"
rsync -a --delete \
  --exclude '.git/' --exclude 'test/' --exclude 'install.sh' --exclude 'build.sh' \
  --exclude '*.py' --exclude 'grammars/coral/' \
  "$ROOT/" "$DST/"
mkdir -p "$DST/grammars"
cp "$ROOT/grammars/coral.wasm" "$DST/grammars/coral.wasm"

echo "installed to $DST"
ls -la "$DST/grammars/coral.wasm"
