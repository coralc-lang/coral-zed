#!/usr/bin/env bash
# Sync the extension source tree into Zed's installed-extensions dir and
# restart Zed so the change takes effect.
#
#   ./install.sh            sync only
set -uo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
DST="${ZED_EXT_DIR:-$HOME/.local/share/zed/extensions/installed/coral}"

mkdir -p "$DST"
rsync -a --delete \
  --exclude 'first.py' \
  --exclude 'analyze.py' \
  --exclude 'check.py' \
  --exclude 'rebuild.sh' \
  --exclude 'install.sh' \
  --exclude '.git/' \
  --exclude 'test/' \
  "$SRC/" "$DST/"

echo "synced -> $DST"
find "$DST" -type f | sed "s|$DST/|  |" | sort
