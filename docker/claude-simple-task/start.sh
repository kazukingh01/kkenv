SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

sudo docker build -t claude-code-simple "$SCRIPT_DIR"

sudo docker run -itd \
    --name claude-code-simple \
    --env-file .env \
    -v "$HOME/.claude/skills":/home/claude/.claude/skills:ro \
    -v "$SCRIPT_DIR/CLAUDE.md":/workspace/CLAUDE.md:ro \
    -v "$SCRIPT_DIR/share":/workspace/share \
    -v "$SCRIPT_DIR/share/instruction":/workspace/share/instruction:ro \
    claude-code-simple

sudo docker exec -it  claude-code-simple claude --dangerously-skip-permissions
