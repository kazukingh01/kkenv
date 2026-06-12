SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Rootless docker: run as the rootless user (e.g. aiagent), not root
export DOCKER_HOST="unix:///run/user/$(id -u)/docker.sock"

docker build -t claude-code "$SCRIPT_DIR"

docker run -itd \
    --name claude-code \
    -e GH_TOKEN=$GH_TOKEN \
    -v "/run/user/$(id -u)/docker.sock":/var/run/docker.sock \
    -v "$SCRIPT_DIR/workspace":/workspace \
    -v "$HOME/.claude/skills":/home/claude/.claude/skills:ro \
    claude-code
