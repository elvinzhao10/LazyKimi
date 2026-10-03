#!/usr/bin/env bash
# subagent-start.sh — Kimi SubagentStart hook (advisory).
# Dispatch ledger event: appends a subagent_started event to the active run's
# events.jsonl via the scripts/state append machinery (transactional).
#
# Kimi output contract: print NOTHING on stdout; diagnostics to stderr.
# Advisory only — ALWAYS exits 0.
set -uo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/bounded-input.bash"
hook_read_input || exit 0
CWD=$(cat "$HOOK_INPUT_FILE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('cwd',''))" 2>/dev/null || echo "")
[ -n "$CWD" ] || CWD="$PWD"
PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

AGENT=$(cat "$HOOK_INPUT_FILE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('agent_type') or d.get('agent_type_name') or d.get('agent_name') or '')" 2>/dev/null || true)

RID=$(CWD="$CWD" bash "$PLUGIN_ROOT/scripts/state/latest-run.sh" 2>/dev/null || true)
[ -n "$RID" ] || exit 0

printf '{"agent":"%s","source":"SubagentStart"}' "${AGENT//\"/}" \
  | CWD="$CWD" bash "$PLUGIN_ROOT/scripts/state/append-event.sh" "$RID" subagent_started >/dev/null 2>&1 || true

exit 0
