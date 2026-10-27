#!/usr/bin/env bash
# user-prompt-queued.sh — Kimi UserPromptQueued hook (advisory, queue ledger).
# Native host event documented in the Kimi Code CLI hooks reference (added in
# CLI 0.32.0, re-verified 2026-10-18; observation-only, never blocks). Records a
# prompt_queued event with structural metadata only — prompt_id and
# queue_length; the queued prompt text is deliberately NOT ledgered (redaction
# boundary).
#
# Kimi output contract: print NOTHING on stdout; diagnostics to stderr.
# Advisory only — ALWAYS exits 0.
set -uo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/bounded-input.bash"
hook_read_input || exit 0
CWD=$(cat "$HOOK_INPUT_FILE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('cwd',''))" 2>/dev/null || echo "")
[ -n "$CWD" ] || CWD="$PWD"
PLUGIN_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

PROMPT_ID=$(cat "$HOOK_INPUT_FILE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('prompt_id',''))" 2>/dev/null || true)
QUEUE_LENGTH=$(cat "$HOOK_INPUT_FILE" | python3 -c "import sys,json; d=json.load(sys.stdin); q=d.get('queue_length'); print('' if not isinstance(q,int) else q)" 2>/dev/null || true)

RID=$(CWD="$CWD" bash "$PLUGIN_ROOT/scripts/state/latest-run.sh" 2>/dev/null || true)
[ -n "$RID" ] || exit 0

PAYLOAD=$(printf '{"source":"UserPromptQueued","prompt_id":"%s","queue_length":"%s"}' "${PROMPT_ID//\"/}" "${QUEUE_LENGTH//\"/}")
CWD="$CWD" bash "$PLUGIN_ROOT/scripts/state/append-event.sh" "$RID" prompt_queued "$PAYLOAD" >/dev/null 2>&1 || true

exit 0
