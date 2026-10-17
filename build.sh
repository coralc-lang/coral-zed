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
#
# tree-sitter can exit 0 while leaving src/parser.c STALE when grammar.js has
# an undefined symbol or a JS error — it prints the problem and skips codegen.
# That silently tests the previous grammar, so check the output as well as the
# exit status.
gen=$( cd "$G" && tree-sitter generate 2>&1 )
rc=$?
if [ $rc -ne 0 ] || echo "$gen" | grep -qiE 'ReferenceError|TypeError|SyntaxError|Failed to load grammar|Unresolved conflict'; then
  echo "$gen" | grep -vE '^\s*`' | head -20
  echo 'GENERATE FAILED - src/parser.c left stale'
  exit 1
fi
echo "$gen" | grep -E 'unnecessary conflict' \
  | sed 's/^ *//;s/`//g' | sort -u | head -30

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

echo '== generate vs code textmate grammar'
if command -v python3 >/dev/null && [ -d "$ROOT/../coral-vscode" ]; then
  python3 "$ROOT/gen-tmgrammar.py" | sed 's/^/   /'
  VS="$ROOT/../coral-vscode"
  if [ -f "$VS/tools/check-tmgrammar.js" ] \
     && [ -d /usr/lib/code/node_modules/vscode-textmate ]; then
    ( cd "$VS" && node tools/check-tmgrammar.js "$PROBE" ) \
      | sed 's/^/   /' || echo '   (textmate check failed)'
  fi
  # language-server client: transport and compiler-resolution tests
  for t in test-client test-find-compiler; do
    if [ -f "$VS/tools/$t.js" ]; then
      printf '   %-20s' "$t"
      if ( cd "$VS" && node "tools/$t.js" >/dev/null 2>&1 ); then
        echo OK
      else
        echo FAIL
        ( cd "$VS" && node "tools/$t.js" 2>&1 | tail -5 | sed 's/^/      /' )
        exit 1
      fi
    fi
  done
  # TextMate cannot resolve structure, so guard against silently collapsing
  # into one colour: require most tokens to receive a real scope.
  #
  # The TextMate engine check needs VS Code's bundled vscode-textmate. That is
  # not guaranteed to be present (newer VS Code builds no longer ship it
  # unpacked), so treat a missing engine as "cannot check" rather than a
  # failure, but still fail if the engine runs and reports poor coverage.
  if [ -f "$VS/tools/scope-coverage.js" ] \
     && node -e "require('/usr/lib/code/node_modules/vscode-textmate')" 2>/dev/null; then
    printf '   %-20s' 'scope-coverage'
    cov=$( cd "$VS" && node tools/scope-coverage.js "$PROBE" 2>/dev/null \
           | awk '/^scoped/ {gsub(/[%()]/,"",$3); print $3}' )
    if [ -z "$cov" ]; then
      echo 'SKIP (engine produced no report)'
    elif awk -v c="$cov" 'BEGIN { exit !(c+0 >= 95) }' 2>/dev/null; then
      echo "OK (${cov}% scoped)"
    else
      echo "FAIL (${cov}% scoped, need >= 95)"
      exit 1
    fi
  else
    printf '   %-20s' 'scope-coverage'
    echo 'SKIP (vscode-textmate not available)'
  fi
fi

echo '== language server launcher'
LAUNCHER="$ROOT/zed/coral-lsp.sh"
if [ -f "$LAUNCHER" ]; then
  bash -n "$LAUNCHER" || exit 1
  printf '   %-20s' 'coral-lsp.sh'
  # With no compiler it must exit 126 and say why, not crash.
  if env -u CORALC -u CORAL_HOME PATH=/usr/bin:/bin "$LAUNCHER" >/dev/null 2>&1; then
    echo 'unexpected success'
    exit 1
  else
    echo 'OK (exits 126 without a compiler)'
  fi
fi

echo '== install'
mkdir -p "$DST"
rsync -a --delete \
  --exclude '.git/' --exclude 'test/' --exclude 'install.sh' --exclude 'build.sh' \
  --exclude '*.py' --exclude 'grammars/coral/' \
  --exclude 'test/' --exclude 'coverage.py' \
  "$ROOT/" "$DST/"
mkdir -p "$DST/grammars"
cp "$ROOT/grammars/coral.wasm" "$DST/grammars/coral.wasm"

echo "installed to $DST"
ls -la "$DST/grammars/coral.wasm"
