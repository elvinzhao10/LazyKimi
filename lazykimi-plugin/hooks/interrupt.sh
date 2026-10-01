#!/usr/bin/env bash
# interrupt.sh — Kimi Interrupt hook (advisory, interrupt ledger).
# v1.3.4 mapped semantics: records an interrupted event on the active run so
# abrupt stops remain visible in the run ledger.
#
# Kimi output contract: print NOTHING on stdout; diagnostics to stderr.
# Advisory only — ALWAYS exits 0.
set -uo pipefail

INPUT=$(head -c 1048576 || true)
CWD=$(printf '%s' "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('cwd',''))" 2>/dev/null || echo "")
[ -n "$CWD" ] || CWD="$PWD"
PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

RID=$(CWD="$CWD" bash "$PLUGIN_ROOT/scripts/state/latest-run.sh" 2>/dev/null || true)
[ -n "$RID" ] || exit 0

printf '{"source":"Interrupt"}' \
  | CWD="$CWD" bash "$PLUGIN_ROOT/scripts/state/append-event.sh" "$RID" interrupted >/dev/null 2>&1 || true

exit 0
