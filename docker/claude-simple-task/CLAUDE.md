---
name: browser-use CLI (no LLM needed)
description: How to use browser-use CLI as a Playwright wrapper without any LLM API key in this sandbox
type: reference
originSessionId: 5d35fbfe-bdee-4a1c-a363-dd497e099b9f
---
# browser-use is installed in this environment

- Install location: `/opt/browser-use-venv/` (Python venv)
- Main binary: `/opt/browser-use-venv/bin/browser-use` (also `browseruse`, `browser-task`, `browser-use-tui`)
- Version: browser-use 0.12.6, playwright 1.58.0
- Chromium: pre-installed at `/opt/ms-playwright/`
- **No LLM API key is configured.** The agent mode (autonomous LLM-driven) will NOT work out of the box. The `extract` subcommand also requires an LLM.

# CLI manual mode — no API key required

Treat `browser-use <subcommand>` as a Playwright wrapper. The browser runs as a **persistent daemon** — state (current URL, tabs) carries across commands. Close with `browser-use close` when done.

## Core subcommands (LLM-free)
- `open <URL>` — navigate
- `state` — dump viewport, scroll, and an indexed element tree (each interactive element gets an `[N]` index). Use these indices for click/type/etc.
- `click <index>` or `click <x> <y>`
- `type <text>` / `input <index> <text>`
- `scroll` / `back` / `wait` / `keys` / `hover` / `dblclick` / `rightclick` / `select` / `upload`
- `screenshot` — saves PNG
- `eval '<js>'` — run JavaScript in page
- `python '<code>'` — run Python with page object
- `get title | html | text | value | attributes | bbox` — read data (no LLM)
- `cookies` / `sessions` / `switch` / `close-tab` / `close`
- `--json` global flag for machine-readable output
- `--headed` to show window (default is headless in this sandbox; GUI not available anyway)

## LLM-required (do NOT use without API key)
- `extract <query>` — uses LLM
- Agent mode (`browser-task`, `browser-use` without subcommand in agent style)

## Typical flow
```
/opt/browser-use-venv/bin/browser-use open "https://example.com"
/opt/browser-use-venv/bin/browser-use state        # find element index
/opt/browser-use-venv/bin/browser-use click 12
/opt/browser-use-venv/bin/browser-use get html
/opt/browser-use-venv/bin/browser-use close
```

## Gotchas
- `state` output can be long — pipe to `head` / `tail` when scanning.
- Japanese/CJK pages render fine; text appears inline in `state` output.
- The daemon keeps the session alive between separate Bash invocations — you don't need to re-open the URL each time.
- Bash timeout: give `open` / `state` ~60s on heavy pages.

# Text-to-speech (edge-tts)

`edge-tts` is installed for converting text into a human-sounding voice file. It uses Microsoft Edge's online Read Aloud service — **no API key required**, but **needs network access**.

- Install location: `/opt/edge-tts-venv/` (Python venv), binary at `/opt/edge-tts-venv/bin/edge-tts`
- Wrapper script: `/usr/local/bin/tts.sh` (recommended entry point)
- Native output is **MP3**. For **WAV**, `tts.sh` transcodes via `ffmpeg` automatically based on the output filename extension.

## Usage (`tts.sh`)
```
tts.sh [-v VOICE] [-r RATE] [-p PITCH] TEXT OUTPUT
tts.sh [-v VOICE] [-r RATE] [-p PITCH] -f INPUT_FILE OUTPUT
```
- Output format is decided by `OUTPUT`'s extension: `.mp3` or `.wav` only.
- Default voice: `ja-JP-NanamiNeural` (Japanese female). Other JA voices: `ja-JP-KeitaNeural` (male), `ja-JP-AoiNeural`, `ja-JP-DaichiNeural`, etc. List all voices with `edge-tts --list-voices`.
- `-r` example: `+10%` / `-20%` (rate). `-p` example: `+5Hz` / `-10Hz` (pitch).

## Examples
```
tts.sh "こんにちは、テストです" hello.mp3
tts.sh -f manuscript.txt narration.wav
tts.sh -v ja-JP-KeitaNeural -r "+10%" -f script.txt fast_male.mp3
```

## Notes
- Requires outbound HTTPS to Microsoft endpoints. Offline use is not supported (use a local TTS engine like `piper` if needed).
- `edge-tts` itself can also be invoked directly: `edge-tts --voice <v> --text "<t>" --write-media out.mp3` — `tts.sh` is just a thin wrapper that adds defaults and WAV transcoding.

# Discord notifications

Use `/usr/local/bin/notify-discord.sh <message>` to post to Discord.

- The environment variables `DISCORD_WEBHOOK_URL` (the webhook URL) and `DISCORD_MENTION` (a mention string in the form `<@USER_ID>`) are already set.
- To include a mention, embed `$DISCORD_MENTION` in the message body:
  ```
  /usr/local/bin/notify-discord.sh "$DISCORD_MENTION Processing complete"
  ```
- Messages longer than 2000 characters are automatically truncated by the script.
- On success the script exits 0 (HTTP 204); on failure it prints the response to stderr and exits 1.

