#!/usr/bin/env bash
set -euo pipefail

# Convert text to speech via edge-tts. Output format is decided by OUTPUT's
# extension: .mp3 (native) or .wav (transcoded with ffmpeg).
#
# Usage:
#   tts.sh [-v VOICE] [-r RATE] [-p PITCH] TEXT OUTPUT
#   tts.sh [-v VOICE] [-r RATE] [-p PITCH] -f INPUT_FILE OUTPUT
#
# Options:
#   -v VOICE   Voice name (default: ja-JP-NanamiNeural)
#   -r RATE    Rate, e.g. "+10%" or "-20%" (default: edge-tts default)
#   -p PITCH   Pitch, e.g. "+5Hz" or "-10Hz" (default: edge-tts default)
#   -f FILE    Read text from FILE instead of positional TEXT
#   -h         Show this help

VOICE="ja-JP-NanamiNeural"
RATE=""
PITCH=""
INPUT_FILE=""

usage() { sed -n '4,17p' "$0" >&2; }

while getopts ":v:r:p:f:h" opt; do
  case "$opt" in
    v) VOICE="$OPTARG" ;;
    r) RATE="$OPTARG" ;;
    p) PITCH="$OPTARG" ;;
    f) INPUT_FILE="$OPTARG" ;;
    h) usage; exit 0 ;;
    \?) echo "Unknown option: -$OPTARG" >&2; usage; exit 1 ;;
    :)  echo "Option -$OPTARG requires an argument" >&2; usage; exit 1 ;;
  esac
done
shift $((OPTIND - 1))

if [ -n "$INPUT_FILE" ]; then
  [ "$#" -ge 1 ] || { echo "OUTPUT path required" >&2; usage; exit 1; }
  TEXT=""
  OUTPUT="$1"
else
  [ "$#" -ge 2 ] || { echo "TEXT and OUTPUT required" >&2; usage; exit 1; }
  TEXT="$1"
  OUTPUT="$2"
fi

ext_lower="$(printf '%s' "${OUTPUT##*.}" | tr '[:upper:]' '[:lower:]')"
case "$ext_lower" in
  mp3|wav) ;;
  *) echo "OUTPUT must end in .mp3 or .wav (got .${ext_lower})" >&2; exit 1 ;;
esac

if [ "$ext_lower" = "wav" ]; then
  tmp_mp3="$(mktemp --suffix=.mp3)"
  trap 'rm -f "$tmp_mp3"' EXIT
  target="$tmp_mp3"
else
  target="$OUTPUT"
fi

args=(--voice "$VOICE" --write-media "$target")
[ -n "$RATE" ]  && args+=(--rate "$RATE")
[ -n "$PITCH" ] && args+=(--pitch "$PITCH")
if [ -n "$INPUT_FILE" ]; then
  args+=(--file "$INPUT_FILE")
else
  args+=(--text "$TEXT")
fi

edge-tts "${args[@]}"

if [ "$ext_lower" = "wav" ]; then
  ffmpeg -y -loglevel error -i "$target" "$OUTPUT"
fi

echo "Wrote $OUTPUT" >&2
