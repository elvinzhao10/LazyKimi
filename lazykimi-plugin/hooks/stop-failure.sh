#!/usr/bin/env bash
# stop-failure.sh — Kimi StopFailure hook (advisory, stop-failure ledger).
# v1.3.5 mapped semantics: records a stop_failure event on the active run so
# Stop-gate failures remain visible in the run ledger.
#
# Kimi output contract: print NOTHING on stdout; diagnostics to stderr.
# Advisory only — ALWAYS exits 0.
set -uo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/bounded-input.bash"
hook_read_input || exit 0
CWD=$(cat "$HOOK_INPUT_FILE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('cwd',''))" 2>/dev/null || echo "")
[ -n "$CWD" ] || CWD="$PWD"
PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

RID=$(CWD="$CWD" bash "$PLUGIN_ROOT/scripts/state/latest-run.sh" 2>/dev/null || true)
[ -n "$RID" ] || exit 0

printf '{"source":"StopFailure"}' \
  | CWD="$CWD" bash "$PLUGIN_ROOT/scripts/state/append-event.sh" "$RID" stop_failure >/dev/null 2>&1 || true

exit 0
