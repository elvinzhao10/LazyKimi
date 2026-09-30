#!/usr/bin/env bash
# session-end.sh — Kimi SessionEnd hook (advisory, ledger-close).
# v1.3.3 mapped semantics: appends a session_end event to the active run's
# events.jsonl via the scripts/state append machinery (transactional).
#
# Kimi output contract: print NOTHING on stdout; diagnostics to stderr.
# Advisory only — ALWAYS exits 0 (never blocks session end).
set -uo pipefail

INPUT=$(head -c 1048576 || true)
CWD=$(printf '%s' "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('cwd',''))" 2>/dev/null || echo "")
[ -n "$CWD" ] || CWD="$PWD"
PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Only act if the project state directory already exists; never create it.
[ -d "$CWD/.lazykimi" ] || exit 0

RID=$(CWD="$CWD" bash "$PLUGIN_ROOT/scripts/state/latest-run.sh" 2>/dev/null || true)
[ -n "$RID" ] || exit 0

printf '{"source":"SessionEnd"}' \
  | CWD="$CWD" bash "$PLUGIN_ROOT/scripts/state/append-event.sh" "$RID" session_end >/dev/null 2>&1 || true

exit 0
