#!/usr/bin/env bash
# coral-lsp — locate coralc and exec it as a language server.
#
# Resolution order (PROTOCOL.md):
#   1. $CORALC
#   2. $CORAL_HOME/coralc
#   3. coralc on PATH
#   4. platform install roots
#
# The compiler speaks LSP over stdio when given `--serve`. If it cannot be
# found this prints why and exits 126, which makes Zed skip the server without
# disturbing highlighting.

set -uo pipefail

die() { echo "coral-lsp: $*" >&2; exit 126; }

exe=coralc
case "$(uname -s 2>/dev/null || echo Linux)" in
  MINGW*|MSYS*|CYGWIN*|Windows_NT) exe=coralc.exe ;;
esac

# 1. explicit override
[ -n "${CORALC:-}" ] && exec "$CORALC" --serve "$@"

# 2. build-provided home
if [ -n "${CORAL_HOME:-}" ] && [ -x "$CORAL_HOME/$exe" ]; then
  exec "$CORAL_HOME/$exe" --serve "$@"
fi

# 3. PATH
if command -v "$exe" >/dev/null 2>&1; then
  exec "$(command -v "$exe")" --serve "$@"
fi

# 4. platform install roots
home="${HOME:-}"
local="${LOCALAPPDATA:-}"
for c in \
  "$home/.coral/bin/$exe" \
  "$home/.local/bin/$exe" \
  "$home/bin/$exe" \
  "/opt/homebrew/bin/$exe" \
  "/usr/local/bin/$exe" \
  "/usr/bin/$exe" \
  "${local:+$local/coral/$exe}" \
  "${local:+$local/Programs/coral/$exe}"
do
  [ -n "$c" ] && [ -x "$c" ] && exec "$c" --serve "$@"
done

die "no coralc found; set CORALC or add coralc to PATH"
