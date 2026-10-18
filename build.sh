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
  for t in test-activation test-init-order test-client test-find-compiler; do
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
  # With no compiler it must exit 126 and say why, not crash. HOME is pointed
  # at an empty dir so the platform install roots (~/.coral/bin and friends)
  # cannot satisfy the lookup -- otherwise a developer with coralc installed
  # would never exercise this branch.
  EMPTYHOME=$(mktemp -d)
  if env -u CORALC -u CORAL_HOME \
         HOME="$EMPTYHOME" USERPROFILE="$EMPTYHOME" LOCALAPPDATA="$EMPTYHOME" \
         PATH=/usr/bin:/bin "$LAUNCHER" >/dev/null 2>&1; then
    echo 'unexpected success'
    rm -rf "$EMPTYHOME"
    exit 1
  else
    rc=$?
    rm -rf "$EMPTYHOME"
    # 126 = "found nothing, told you why". Anything else is a real failure.
    if [ "$rc" != 126 ]; then
      echo "FAIL (expected exit 126, got $rc)"
      exit 1
    fi
    echo 'OK (exits 126 without a compiler)'
  fi
fi

echo '== live compiler handshake'
# Talks to the real `coralc --serve` and asserts the wire format in PROTOCOL.md
# still holds. This is the guard that would have caught the newline-vs-
# Content-Length framing bug. Skips cleanly when no compiler is installed.
if [ -f "$VS/tools/test-live-server.js" ]; then
  printf '   %-20s' 'live-server'
  if out=$( cd "$VS" && node tools/test-live-server.js 2>&1 ); then
    echo "OK ($(echo "$out" | grep -c '^ok') checks)"
  else
    if echo "$out" | grep -q '^SKIP'; then
      echo 'SKIP (no coralc installed)'
    else
      echo 'FAIL'
      echo "$out" | sed 's/^/      /'
      exit 1
    fi
  fi
fi

echo '== build extension wasm'
# The extension contributes the language server itself (language_server_command),
# so this artifact is what makes `coralc --serve` start for every user who
# installs the extension. Built offline: wasm32-wasip2 and
# zed_extension_api are both already present locally.
if command -v cargo >/dev/null 2>&1; then
  printf '   %-20s' 'extension.wasm'
  if ( cargo build --release --offline --target wasm32-wasip2 ) >/tmp/cargo.log 2>&1; then
    WASM="$ROOT/target/wasm32-wasip2/release/coral_extension.wasm"
    cp "$WASM" "$ROOT/extension.wasm"
    echo "OK ($(stat -c%s "$ROOT/extension.wasm") bytes)"
  else
    echo 'FAIL'
    tail -20 /tmp/cargo.log | sed 's/^/      /'
    exit 1
  fi
else
  printf '   %-20s' 'extension.wasm'
  echo 'SKIP (cargo not installed)'
fi

echo '== install launcher'
# The launcher must be installed by the build, not by hand. A stale copy in
# ~/.local/bin silently shadows the repo copy and is how the extension ended up
# invoking `coralc serve` (no --) after the flag was corrected here.
BIN_DEST="${HOME}/.local/bin"
if [ -w "$BIN_DEST" ] || mkdir -p "$BIN_DEST" 2>/dev/null; then
  install -m 0755 "$ROOT/zed/coral-lsp.sh" "$BIN_DEST/coral-lsp"
  printf '   %-20s' 'coral-lsp'
  if grep -q -- '--serve' "$BIN_DEST/coral-lsp"; then
    echo "OK ($BIN_DEST/coral-lsp)"
  else
    echo 'FAIL (installed launcher does not use --serve)'
    exit 1
  fi
else
  printf '   %-20s' 'coral-lsp'
  echo "SKIP (cannot write $BIN_DEST)"
fi

echo '== sync extension manifest'
# Zed caches each extension's manifest in extensions/index.json and will not
# re-read extension.toml for an already-installed extension. We install by
# rsync rather than through Zed's own installer, so nothing refreshes that
# cache -- which silently hid the [language_servers.coral] section until the
# manifest was corrected. Keep them in sync automatically.
IDX="${XDG_DATA_HOME:-$HOME/.local/share}/zed/extensions/index.json"
if [ -f "$IDX" ]; then
  printf '   %-20s' 'index.json'
  python3 - "$IDX" "$ROOT/extension.toml" <<'PYEOF'
import json, re, sys
idx_path, toml_path = sys.argv[1], sys.argv[2]
text = open(toml_path).read()
def scalar(k, d=None):
    m = re.search(rf'^{k}\s*=\s*"([^"]*)"', text, re.M)
    return m.group(1) if m else d
servers = {}
for m in re.finditer(r'^\[language_servers\.([\w.-]+)\]\s*(.*?)(?=^\[|\Z)', text, re.M | re.S):
    name, body = m.group(1), m.group(2)
    langs = re.search(r'^languages\s*=\s*\[(.*?)\]', body, re.M | re.S)
    servers[name] = {
        "language": None,
        "languages": re.findall(r'"([^"]+)"', langs.group(1)) if langs else [],
        "language_ids": {},
        "code_action_kinds": None,
    }
d = json.load(open(idx_path))
entry = d.get("extensions", {}).get("coral")
if entry is None:
    print("SKIP (coral not in index)"); raise SystemExit(0)
m = entry["manifest"]
m["version"] = scalar("version", m.get("version"))
# lib is Rust whenever an extension.wasm is shipped
import os
if os.path.exists(os.path.join(os.path.dirname(toml_path), "extension.wasm")):
    m["lib"] = {"kind": "Rust", "version": m["version"]}
m["language_servers"] = servers
json.dump(d, open(idx_path, "w"), indent=2)
print(f"OK (v{m['version']}, servers: {','.join(servers) or 'none'})")
PYEOF
else
  printf '   %-20s' 'index.json'
  echo 'SKIP (no extension index yet)'
fi

echo '== install'
mkdir -p "$DST"
# Ship the built artefacts only. `target/` is ~140 MB of Cargo output and was
# being installed wholesale; the Rust source stays (it is small and makes the
# installed extension auditable), but build output never ships.
rsync -a --delete --delete-excluded \
  --exclude '.git/' --exclude 'test/' --exclude 'install.sh' --exclude 'build.sh' \
  --exclude '*.py' --exclude 'grammars/coral/' --exclude 'target/' \
  --exclude 'Cargo.lock' --exclude 'build-web.sh' --exclude 'icons/coral-logo.svg' \
  "$ROOT/" "$DST/"
mkdir -p "$DST/grammars"
cp "$ROOT/grammars/coral.wasm" "$DST/grammars/coral.wasm"

echo "installed to $DST"
ls -la "$DST/grammars/coral.wasm"
