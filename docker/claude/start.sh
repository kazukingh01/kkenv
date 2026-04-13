SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Re-exec with sudo if not root, preserving GH_TOKEN
if [ "$(id -u)" -ne 0 ]; then
    exec sudo GH_TOKEN="$GH_TOKEN" bash "$0" "$@"
fi

docker build -t claude-code "$SCRIPT_DIR"

docker run -itd \
    --name claude-code \
    -e GH_TOKEN=$GH_TOKEN \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "$SCRIPT_DIR/workspace":/workspace \
    -v "$HOME/.claude/skills":/home/claude/.claude/skills:ro \
    claude-code
