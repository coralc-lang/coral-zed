#!/usr/bin/env bash
# Install the coral-lsp launcher into a directory on PATH.
#
#   ./install.sh              -> ~/.local/bin
#   ./install.sh /usr/local/bin
#
# The launcher is what Zed's language_servers.coral entry execs; it locates
# coralc at run time (see PROTOCOL.md), so this is the only part that needs
# installing.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
DEST="${1:-$HOME/.local/bin}"

mkdir -p "$DEST"
install -m 0755 "$ROOT/coral-lsp.sh" "$DEST/coral-lsp"
echo "installed $DEST/coral-lsp"

case ":$PATH:" in
  *":$DEST:"*) ;;
  *) echo "note: $DEST is not on your PATH; add it or give Zed an absolute path" ;;
esac
