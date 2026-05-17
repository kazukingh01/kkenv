# Build and start the claude-code-simple container.
# Options:
#   --label <name>   Suffix the container name as "<base>-<name>" so multiple
#                    instances can coexist.
#   --delete         Stop and remove the existing container of the same name
#                    before starting a new one.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

BASE_NAME="claude-code-simple"
LABEL=""
DELETE=0

while [ $# -gt 0 ]; do
    case "$1" in
        --label)
            LABEL="$2"
            shift 2
            ;;
        --delete)
            DELETE=1
            shift
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

if [ -n "$LABEL" ]; then
    CONTAINER_NAME="${BASE_NAME}-${LABEL}"
else
    CONTAINER_NAME="${BASE_NAME}"
fi

if [ "$DELETE" -eq 1 ]; then
    sudo docker stop "$CONTAINER_NAME" 2>/dev/null
    sudo docker rm "$CONTAINER_NAME" 2>/dev/null
fi

sudo docker build -t ${BASE_NAME} "$SCRIPT_DIR"

sudo docker run -itd \
    --name "$CONTAINER_NAME" \
    --env-file .env \
    -e TZ=Asia/Tokyo \
    -v "$HOME/.claude/skills":/home/claude/.claude/skills:ro \
    -v "$SCRIPT_DIR/CLAUDE.md":/workspace/CLAUDE.md:ro \
    -v "$SCRIPT_DIR/share":/workspace/share \
    -v "$SCRIPT_DIR/share/instruction":/workspace/share/instruction:ro \
    ${BASE_NAME}

sudo docker exec -it "$CONTAINER_NAME" claude --dangerously-skip-permissions
