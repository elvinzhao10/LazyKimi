#!/usr/bin/env bash
# pre-compact.sh — Kimi PreCompact hook (advisory, context-recovery).
# v1.3.5 mapped semantics: records a pre_compact ledger event on the active
# run so context-recovery checkpoints (written by post-compact.sh into
# .lazykimi/runs/<id>/checkpoints/) can be tied to the compaction boundary.
#
# Kimi output contract: print NOTHING on stdout; diagnostics to stderr.
# Advisory only — ALWAYS exits 0 (never blocks compaction).
set -uo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/bounded-input.bash"
hook_read_input || exit 0
CWD=$(cat "$HOOK_INPUT_FILE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('cwd',''))" 2>/dev/null || echo "")
[ -n "$CWD" ] || CWD="$PWD"
PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

RID=$(CWD="$CWD" bash "$PLUGIN_ROOT/scripts/state/latest-run.sh" 2>/dev/null || true)
[ -n "$RID" ] || exit 0

printf '{"trigger":"PreCompact","source":"pre-compact.sh"}' \
  | CWD="$CWD" bash "$PLUGIN_ROOT/scripts/state/append-event.sh" "$RID" pre_compact >/dev/null 2>&1 || true

exit 0
