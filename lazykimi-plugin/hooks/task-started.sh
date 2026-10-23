#!/usr/bin/env bash
# task-started.sh — Kimi TaskStarted hook (advisory, task ledger).
# Native host event documented in the Kimi Code CLI hooks reference (added in
# CLI 0.32.0, re-verified 2026-10-18; observation-only, never blocks; matcher
# is the task kind, omitted so all kinds record). Records a task_started event
# with structural metadata only — task_id and detached; the model-authored
# description is deliberately NOT ledgered (redaction boundary).
#
# Kimi output contract: print NOTHING on stdout; diagnostics to stderr.
# Advisory only — ALWAYS exits 0.
set -uo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/bounded-input.bash"
hook_read_input || exit 0
CWD=$(cat "$HOOK_INPUT_FILE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('cwd',''))" 2>/dev/null || echo "")
[ -n "$CWD" ] || CWD="$PWD"
PLUGIN_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

TASK_ID=$(cat "$HOOK_INPUT_FILE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('task_id',''))" 2>/dev/null || true)
DETACHED=$(cat "$HOOK_INPUT_FILE" | python3 -c "import sys,json; d=json.load(sys.stdin); b=d.get('detached'); print('' if not isinstance(b,bool) else str(b).lower())" 2>/dev/null || true)

RID=$(CWD="$CWD" bash "$PLUGIN_ROOT/scripts/state/latest-run.sh" 2>/dev/null || true)
[ -n "$RID" ] || exit 0

PAYLOAD=$(printf '{"source":"TaskStarted","task_id":"%s","detached":"%s"}' "${TASK_ID//\"/}" "${DETACHED//\"/}")
CWD="$CWD" bash "$PLUGIN_ROOT/scripts/state/append-event.sh" "$RID" task_started "$PAYLOAD" >/dev/null 2>&1 || true

exit 0
