#!/usr/bin/env bash
# turn-started.sh — Kimi TurnStarted hook (advisory, turn ledger).
# Native host event documented in the Kimi Code CLI hooks reference (added in
# CLI 0.32.0, re-verified 2026-10-18; observation-only, never blocks). Records a
# turn_started event with structural metadata only — turn_id and origin_kind;
# the prompt text is deliberately NOT ledgered (redaction boundary).
#
# Kimi output contract: print NOTHING on stdout; diagnostics to stderr.
# Advisory only — ALWAYS exits 0.
set -uo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/bounded-input.bash"
hook_read_input || exit 0
CWD=$(cat "$HOOK_INPUT_FILE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('cwd',''))" 2>/dev/null || echo "")
[ -n "$CWD" ] || CWD="$PWD"
PLUGIN_ROOT="$(cd "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

TURN_ID=$(cat "$HOOK_INPUT_FILE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('turn_id',''))" 2>/dev/null || true)
ORIGIN_KIND=$(cat "$HOOK_INPUT_FILE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('origin_kind',''))" 2>/dev/null || true)

RID=$(CWD="$CWD" bash "$PLUGIN_ROOT/scripts/state/latest-run.sh" 2>/dev/null || true)
[ -n "$RID" ] || exit 0

PAYLOAD=$(printf '{"source":"TurnStarted","turn_id":"%s","origin_kind":"%s"}' "${TURN_ID//\"/}" "${ORIGIN_KIND//\"/}")
CWD="$CWD" bash "$PLUGIN_ROOT/scripts/state/append-event.sh" "$RID" turn_started "$PAYLOAD" >/dev/null 2>&1 || true

exit 0
