#!/usr/bin/env bash
set -euo pipefail

# ubuntu/dot_* をローカル ($HOME) に . プレフィックスへ変換して展開する
# 例: ubuntu/dot_claude/ -> $HOME/.claude/

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${1:-$HOME}"
CODEX_CONFIG="$SCRIPT_DIR/dot_codex/config.toml"

# Codex の設定も必ず dot_codex から配備する。
if [[ ! -f "$CODEX_CONFIG" ]]; then
  echo "Missing Codex config: $CODEX_CONFIG" >&2
  exit 1
fi

shopt -s nullglob
found=0
for src in "$SCRIPT_DIR"/dot_*; do
  found=1
  name="$(basename "$src")"
  dst="$TARGET_DIR/.${name#dot_}"
  mkdir -p "$dst"

  # config.toml や rules を含む各エントリを配備する。
  # 配備先でリンクが切れないよう、ディレクトリへのリンクは
  # リンクそのものではなく、参照先の内容を実ディレクトリとしてコピーする。
  for entry in "$src"/* "$src"/.[!.]* "$src"/..?*; do
    entry_name="$(basename "$entry")"
    entry_dst="$dst/$entry_name"

    # 旧方式の cp -rT は、リンク元と同名の既存ディレクトリがあると
    # skills/skills -> skills のような自己参照リンクを残すことがある。
    legacy_self_link="$entry_dst/$entry_name"
    if [[ -L "$legacy_self_link" && "$(readlink "$legacy_self_link")" == "$entry_name" ]]; then
      echo "remove legacy self-link $legacy_self_link"
      rm -f -- "$legacy_self_link"
    fi

    if [[ -L "$entry" && -d "$entry" ]]; then
      resolved="$(readlink -f "$entry")"
      echo "cp -rT $resolved -> $entry_dst (from $entry)"
      if [[ -L "$entry_dst" || ( -e "$entry_dst" && ! -d "$entry_dst" ) ]]; then
        rm -f -- "$entry_dst"
      fi
      mkdir -p "$entry_dst"
      cp -rT "$resolved" "$entry_dst"
    else
      echo "cp -rT $entry -> $entry_dst"
      cp -rT "$entry" "$entry_dst"
    fi
  done
done

if [[ $found -eq 0 ]]; then
  echo "No dot_* entries found in $SCRIPT_DIR" >&2
  exit 1
fi

echo "done."
