#!/usr/bin/env bash
# post-compact.sh — Kimi PostCompact hook (advisory, context-recovery).
# v1.3.4 mapped semantics: writes a context-recovery checkpoint for the
# active run (state snapshot under .lazykimi/runs/<id>/checkpoints/), records
# a post_compact ledger event, and re-anchors context with an
# additionalContext reminder pointing at durable state instead of stale
# in-context pointers.
#
# Kimi output contract: print EITHER strict JSON ({"additionalContext": ...})
# OR nothing on stdout; diagnostics to stderr. Advisory only — ALWAYS exits 0.
set -uo pipefail

INPUT=$(head -c 1048576 || true)
CWD=$(printf '%s' "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('cwd',''))" 2>/dev/null || echo "")
[ -n "$CWD" ] || CWD="$PWD"
PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

REMINDER="[LazyKimi] Post-compact context restoration: re-read .kimi-code/AGENTS.md for project memory and recover the active run from .lazykimi/runs/ (state.json, events.jsonl) plus the plan under .lazykimi/plans/ instead of trusting stale in-context pointers."

RID=$(CWD="$CWD" bash "$PLUGIN_ROOT/scripts/state/latest-run.sh" 2>/dev/null || true)
if [ -n "$RID" ]; then
    # Context-recovery checkpoint: timestamped state snapshot + ledger event.
    CWD="$CWD" bash "$PLUGIN_ROOT/scripts/state/checkpoint.sh" "$RID" >/dev/null 2>&1 || true
    printf '{"trigger":"PostCompact","source":"post-compact.sh"}' \
      | CWD="$CWD" bash "$PLUGIN_ROOT/scripts/state/append-event.sh" "$RID" post_compact >/dev/null 2>&1 || true
    REMINDER="$REMINDER A context-recovery checkpoint was written to .lazykimi/runs/$RID/checkpoints/."
fi

printf '%s' "$REMINDER" | python3 -c 'import json,sys; print(json.dumps({"additionalContext": sys.stdin.read()}))'
exit 0
