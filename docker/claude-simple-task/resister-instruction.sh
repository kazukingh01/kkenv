#!/bin/bash
set -euo pipefail

# Register a systemd timer on the host that periodically feeds INPUT.md to
# `claude` running inside an already-launched container via `docker exec`.
#
# Usage: resister-instruction.sh <job_name> --input <INPUT.md> --interval <minutes> \
#                                [--container <name>] [--model <model>] [--max-turns <N>]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SHARE_DIR="${SCRIPT_DIR}/share"
SHARE_DIR_IN_CONTAINER="/workspace/share"

JOB_NAME=""
INPUT_FILE=""
INTERVAL_MIN=""
CONTAINER="claude-code-simple"
MODEL="sonnet"
MAX_TURNS=30

while [ $# -gt 0 ]; do
  case "$1" in
    --input)     INPUT_FILE="$2"; shift 2 ;;
    --interval)  INTERVAL_MIN="$2"; shift 2 ;;
    --container) CONTAINER="$2";   shift 2 ;;
    --model)     MODEL="$2";       shift 2 ;;
    --max-turns) MAX_TURNS="$2";   shift 2 ;;
    -*)          echo "Unknown option: $1" >&2; exit 1 ;;
    *)           JOB_NAME="$1";    shift ;;
  esac
done

if [ -z "${JOB_NAME}" ] || [ -z "${INPUT_FILE}" ] || [ -z "${INTERVAL_MIN}" ]; then
  echo "Usage: resister-instruction.sh <job_name> --input <INPUT.md> --interval <minutes> \\" >&2
  echo "                                [--container <name>] [--model <model>] [--max-turns <N>]" >&2
  echo "" >&2
  echo "  <job_name>          Identifier used for unit names and logs" >&2
  echo "  --input <path>      Path to instruction file (sent as the prompt)" >&2
  echo "  --interval <min>    Run every N minutes (systemd OnCalendar 0/N)" >&2
  echo "  --container <name>  Target container running claude (default: claude-code-simple)" >&2
  echo "  --model <model>     claude --model value (default: sonnet)" >&2
  echo "  --max-turns <N>     claude --max-turns value (default: 30)" >&2
  exit 1
fi

if ! [[ "${INTERVAL_MIN}" =~ ^[0-9]+$ ]] || [ "${INTERVAL_MIN}" -lt 1 ]; then
  echo "--interval must be a positive integer (minutes)" >&2
  exit 1
fi

INPUT_SRC="$(cd "$(dirname "${INPUT_FILE}")" && pwd)/$(basename "${INPUT_FILE}")"
if [ ! -f "${INPUT_SRC}" ]; then
  echo "Input file not found: ${INPUT_SRC}" >&2
  exit 1
fi

mkdir -p "${SHARE_DIR}/logs" "${SHARE_DIR}/instruction"
INPUT_NAME="${JOB_NAME}.md"
INPUT_HOST="${SHARE_DIR}/instruction/${INPUT_NAME}"
INPUT_GUEST="${SHARE_DIR_IN_CONTAINER}/instruction/${INPUT_NAME}"
cp "${INPUT_SRC}" "${INPUT_HOST}"

UNIT_NAME="claude-task-${JOB_NAME}"
RUNNER="${SCRIPT_DIR}/run-${JOB_NAME}.sh"
LOG_DIR_HOST="${SHARE_DIR}/logs"
LOG_DIR_GUEST="${SHARE_DIR_IN_CONTAINER}/logs"

echo "Creating runner ${RUNNER} ..."
cat > "${RUNNER}" <<EOF
#!/bin/bash
set -euo pipefail

CONTAINER="${CONTAINER}"
INPUT_GUEST="${INPUT_GUEST}"
LOG_DIR_HOST="${LOG_DIR_HOST}"
JOB_NAME="${JOB_NAME}"
MODEL="${MODEL}"
MAX_TURNS="${MAX_TURNS}"

TS="\$(date +%Y%m%d-%H%M%S)"
STREAM_LOG="\${LOG_DIR_HOST}/\${JOB_NAME}-\${TS}.jsonl"

PROMPT="Read the instruction file at ${INPUT_GUEST} and execute the instructions written there. The file is read-only; do not attempt to modify it."

docker exec -i "\${CONTAINER}" claude -p "\${PROMPT}" \\
  --model "\${MODEL}" \\
  --dangerously-skip-permissions \\
  --max-turns "\${MAX_TURNS}" \\
  --output-format stream-json \\
  --verbose \\
  > "\${STREAM_LOG}"
EOF
chmod +x "${RUNNER}"

echo "Creating /etc/systemd/system/${UNIT_NAME}.service ..."
sudo tee "/etc/systemd/system/${UNIT_NAME}.service" >/dev/null <<EOF
[Unit]
Description=Claude periodic task (${JOB_NAME})
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
WorkingDirectory=${SCRIPT_DIR}
ExecStart=${RUNNER}
TimeoutStartSec=1800
EOF

echo "Creating /etc/systemd/system/${UNIT_NAME}.timer ..."
sudo tee "/etc/systemd/system/${UNIT_NAME}.timer" >/dev/null <<EOF
[Unit]
Description=Run claude task ${JOB_NAME} every ${INTERVAL_MIN} min

[Timer]
OnCalendar=*-*-* *:0/${INTERVAL_MIN}:00
Persistent=true
RandomizedDelaySec=30

[Install]
WantedBy=timers.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now "${UNIT_NAME}.timer"

echo "Registered: ${UNIT_NAME}.timer (every ${INTERVAL_MIN} min)"
echo "Runner:     ${RUNNER}"
echo "Input:      ${INPUT_HOST}  (guest: ${INPUT_GUEST})"
echo "Logs:       ${LOG_DIR_HOST}/${JOB_NAME}-*.jsonl"
echo "Status:     systemctl list-timers ${UNIT_NAME}*"
