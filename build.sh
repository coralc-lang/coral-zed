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

echo '== verify queries'
# A broken query makes Zed fail to load the language at all, so nothing gets
# highlighted. Validate every query against real coral source before
# installing, and refuse to ship a bad one.
PROBE=/home/cerie/Documents/coralc/lib/std/x86_64/linux/collections/arr.crl
if [ ! -f "$PROBE" ]; then
  PROBE=/tmp/.__coral_probe.crl
  printf 'pub struct S<T> {\n    #[[inline]]\n    T* ptr() const { return (T*)self.data; }\n}\nvar p = S { .data = null };\nfor (usize i = 0; i < 3; i++) { switch (i) { _ => { break }, else => { continue; }, } }\n' > "$PROBE"
fi
for q in brackets highlights indents outline textobjects; do
  printf '   %-16s' "$q.scm"
  # `tree-sitter query` resolves the grammar from the current directory.
  if ( cd "$G" && tree-sitter query "$ROOT/languages/coral/$q.scm" "$PROBE" ) \
       >/dev/null 2>/tmp/.__coral_qerr; then
    echo OK
  else
    echo 'FAIL - refusing to install'
    head -6 /tmp/.__coral_qerr
    exit 1
  fi
done
rm -f /tmp/.__coral_probe.crl /tmp/.__coral_qerr

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
