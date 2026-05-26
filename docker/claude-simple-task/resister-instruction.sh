#!/bin/bash
set -euo pipefail

# Register a systemd timer on the host that periodically feeds INPUT.md to
# `claude` running inside an already-launched container via `docker exec`.
#
# Usage: resister-instruction.sh <job_name> --input <INPUT.md> (--interval <minutes> | --at <H[,H...]>) \
#                                [--container <name>] [--model <model>] [--max-turns <N>]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SHARE_DIR="${SCRIPT_DIR}/share"
SHARE_DIR_IN_CONTAINER="/workspace/share"

JOB_NAME=""
INPUT_FILE=""
INTERVAL_MIN=""
AT_HOURS=""
CONTAINER="claude-code-simple"
MODEL="sonnet"
MAX_TURNS=30
DELETE=0

usage() {
  cat >&2 <<EOF
Usage: resister-instruction.sh <job_name> --input <INPUT.md> (--interval <minutes> | --at <H[,H...]>) \\
                                [--container <name>] [--model <model>] [--max-turns <N>]
       resister-instruction.sh <job_name> --delete

Register a systemd timer on the host that periodically feeds an instruction
file to \`claude\` running inside an already-launched container via docker exec.

  <job_name>          Identifier used for unit names and logs
  --input <path>      Path to instruction file (sent as the prompt)
  --interval <min>    Run every N minutes (mutually exclusive with --at)
  --at <H[,H...]>     Run daily at given hours (0-23, comma-separated; minute fixed to :00)
  --container <name>  Target container running claude (default: ${CONTAINER})
  --model <model>     claude --model value (default: ${MODEL})
  --max-turns <N>     claude --max-turns value (default: ${MAX_TURNS})
  --delete            Tear down a previously registered job (logs/memo kept)
  -h, --help          Show this help
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --input)     INPUT_FILE="$2"; shift 2 ;;
    --interval)  INTERVAL_MIN="$2"; shift 2 ;;
    --at)        AT_HOURS="$2";    shift 2 ;;
    --container) CONTAINER="$2";   shift 2 ;;
    --model)     MODEL="$2";       shift 2 ;;
    --max-turns) MAX_TURNS="$2";   shift 2 ;;
    --delete)    DELETE=1;         shift ;;
    -h|--help)   usage; exit 0 ;;
    -*)          echo "Unknown option: $1" >&2; usage; exit 1 ;;
    *)           JOB_NAME="$1";    shift ;;
  esac
done

if [ -n "${INTERVAL_MIN}" ] && [ -n "${AT_HOURS}" ]; then
  echo "--interval and --at are mutually exclusive" >&2
  exit 1
fi

# --delete: tear down a previously registered job (timer/service/runner/input).
# Logs are intentionally preserved so post-mortem inspection remains possible.
if [ "${DELETE}" -eq 1 ]; then
  if [ -z "${JOB_NAME}" ]; then
    usage
    exit 1
  fi
  UNIT_NAME="claude-task-${JOB_NAME}"
  echo "Disabling ${UNIT_NAME}.timer ..."
  sudo systemctl disable --now "${UNIT_NAME}.timer" 2>/dev/null || true
  sudo systemctl stop "${UNIT_NAME}.service" 2>/dev/null || true
  sudo rm -f "/etc/systemd/system/${UNIT_NAME}.timer" \
             "/etc/systemd/system/${UNIT_NAME}.service"
  sudo systemctl daemon-reload
  sudo systemctl reset-failed "${UNIT_NAME}.service" 2>/dev/null || true
  rm -f "${SCRIPT_DIR}/run-${JOB_NAME}.sh"
  rm -f "${SHARE_DIR}/instruction/${JOB_NAME}.md"
  echo "Deleted job: ${JOB_NAME}"
  echo "(Logs under ${SHARE_DIR}/logs/${JOB_NAME}-*.jsonl kept)"
  echo "(Carry-over memo ${SHARE_DIR}/memo/${JOB_NAME}.md kept; rm manually for a fresh start)"
  exit 0
fi

if [ -z "${JOB_NAME}" ] || [ -z "${INPUT_FILE}" ] || { [ -z "${INTERVAL_MIN}" ] && [ -z "${AT_HOURS}" ]; }; then
  usage
  exit 1
fi

if [ -n "${INTERVAL_MIN}" ]; then
  if ! [[ "${INTERVAL_MIN}" =~ ^[0-9]+$ ]] || [ "${INTERVAL_MIN}" -lt 1 ]; then
    echo "--interval must be a positive integer (minutes)" >&2
    exit 1
  fi
fi

if [ -n "${AT_HOURS}" ]; then
  if ! [[ "${AT_HOURS}" =~ ^[0-9]+(,[0-9]+)*$ ]]; then
    echo "--at must be comma-separated hours (e.g. 1,13)" >&2
    exit 1
  fi
  IFS=',' read -ra _AT_PARTS <<< "${AT_HOURS}"
  for _h in "${_AT_PARTS[@]}"; do
    if [ "${_h}" -lt 0 ] || [ "${_h}" -gt 23 ]; then
      echo "--at hours must be in 0-23 (got: ${_h})" >&2
      exit 1
    fi
  done
fi

INPUT_SRC="$(cd "$(dirname "${INPUT_FILE}")" && pwd)/$(basename "${INPUT_FILE}")"
if [ ! -f "${INPUT_SRC}" ]; then
  echo "Input file not found: ${INPUT_SRC}" >&2
  exit 1
fi

mkdir -p "${SHARE_DIR}/logs" "${SHARE_DIR}/instruction" "${SHARE_DIR}/memo"
INPUT_NAME="${JOB_NAME}.md"
INPUT_HOST="${SHARE_DIR}/instruction/${INPUT_NAME}"
INPUT_GUEST="${SHARE_DIR_IN_CONTAINER}/instruction/${INPUT_NAME}"
cp "${INPUT_SRC}" "${INPUT_HOST}"

MEMO_HOST="${SHARE_DIR}/memo/${JOB_NAME}.md"
MEMO_GUEST="${SHARE_DIR_IN_CONTAINER}/memo/${JOB_NAME}.md"
if [ ! -f "${MEMO_HOST}" ]; then
  : > "${MEMO_HOST}"
fi

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

# Retain only the last 3 days of stream logs for this job.
find "\${LOG_DIR_HOST}" -maxdepth 1 -type f -name "\${JOB_NAME}-*.jsonl" -mtime +3 -delete 2>/dev/null || true

PROMPT="You are running as one scheduled trial of a recurring simple task.

1. FIRST, read the carry-over memo at ${MEMO_GUEST}. It is writable and holds learnings from previous trials (it may be empty on the first run). Apply any relevant guidance from it before acting.

2. Read the instruction file at ${INPUT_GUEST} and execute it. This instruction file is READ-ONLY; do not attempt to modify it.

3. LAST, update ${MEMO_GUEST} with concise carry-over notes for the next trial: facts discovered, failures and their causes, what to avoid, what worked, and open questions. Keep the entire file under 1500 English tokens (roughly 1000 English words, ~6KB). If it would exceed that budget, compress: merge duplicates, drop resolved/stale items, prefer the most recent and most actionable learnings. Use Markdown bullet points."

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
if [ -n "${AT_HOURS}" ]; then
  TIMER_DESC="Run claude task ${JOB_NAME} daily at ${AT_HOURS}:00"
  TIMER_SCHEDULE="OnCalendar=*-*-* ${AT_HOURS}:00:00"
else
  TIMER_DESC="Run claude task ${JOB_NAME} every ${INTERVAL_MIN} min"
  TIMER_SCHEDULE="OnBootSec=1min
OnUnitActiveSec=${INTERVAL_MIN}min"
fi
sudo tee "/etc/systemd/system/${UNIT_NAME}.timer" >/dev/null <<EOF
[Unit]
Description=${TIMER_DESC}

[Timer]
${TIMER_SCHEDULE}
Persistent=true
RandomizedDelaySec=30

[Install]
WantedBy=timers.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now "${UNIT_NAME}.timer"

if [ -n "${AT_HOURS}" ]; then
  echo "Registered: ${UNIT_NAME}.timer (daily at ${AT_HOURS}:00)"
else
  echo "Registered: ${UNIT_NAME}.timer (every ${INTERVAL_MIN} min)"
fi
echo "Runner:     ${RUNNER}"
echo "Input:      ${INPUT_HOST}  (guest: ${INPUT_GUEST})"
echo "Memo:       ${MEMO_HOST}  (guest: ${MEMO_GUEST}, rw, budget 1500 tok)"
echo "Logs:       ${LOG_DIR_HOST}/${JOB_NAME}-*.jsonl"
echo "Status:     systemctl list-timers ${UNIT_NAME}*"
