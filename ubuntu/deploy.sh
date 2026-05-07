#!/usr/bin/env bash
set -euo pipefail

# ubuntu/dot_* をローカル ($HOME) に . プレフィックスへ変換して展開する
# 例: ubuntu/dot_claude/ -> $HOME/.claude/

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${1:-$HOME}"

shopt -s nullglob
found=0
for src in "$SCRIPT_DIR"/dot_*; do
  found=1
  name="$(basename "$src")"
  dst="$TARGET_DIR/.${name#dot_}"
  echo "cp -rT $src -> $dst"
  mkdir -p "$dst"
  cp -rT "$src" "$dst"
done

if [[ $found -eq 0 ]]; then
  echo "No dot_* entries found in $SCRIPT_DIR" >&2
  exit 1
fi

echo "done."
