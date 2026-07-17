#!/usr/bin/env bash
# LazyKimi — PostCompact hook
# Restores context markers after compaction by re-printing key state.
# Fail-open — never blocks.
set -euo pipefail
trap 'echo "[LazyKimi] post-compact internal error; failing open" >&2; exit 0' ERR

INPUT=""
[ ! -t 0 ] && INPUT=$(cat) || true
CWD="$PWD"
if [ -n "$INPUT" ] && command -v jq >/dev/null 2>&1; then
  CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // ""' 2>/dev/null || echo "")
  [ -z "$CWD" ] && CWD="$PWD"
fi

STATE_DIR="$CWD/.lazykimi/state"
EVIDENCE_DIR="$CWD/.lazykimi/evidence"
BOULDER="$STATE_DIR/boulder.json"
AGENTS_MD="$CWD/.kimi-code/AGENTS.md"

echo "[LazyKimi] Post-compact context restoration:"

# Re-anchor AGENTS.md
if [ -f "$AGENTS_MD" ]; then
  echo "[LazyKimi] Re-read .kimi-code/AGENTS.md to restore project memory."
else
  echo "[LazyKimi] NOTE: .kimi-code/AGENTS.md missing."
fi

# Re-print boulder state
if [ -f "$BOULDER" ] && command -v jq >/dev/null 2>&1; then
  active_plan=$(jq -r '.plan_path // .active_plan // "(none)"' "$BOULDER" 2>/dev/null || echo "(none)")
  in_progress=$(jq -r '[.tasks[]? | select(.status=="in_progress")] | length' "$BOULDER" 2>/dev/null || echo "0")
  next_task=$(jq -r '[.tasks[]? | select(.status=="in_progress" or .status=="pending")][0].description // "(none)"' "$BOULDER" 2>/dev/null || echo "(none)")
  echo "[LazyKimi] Active plan: $active_plan"
  echo "[LazyKimi] In-progress tasks: $in_progress"
  echo "[LazyKimi] Next task: $next_task"
fi

# Evidence summary
if [ -d "$EVIDENCE_DIR" ]; then
  ev_count=$(find "$EVIDENCE_DIR" -type f 2>/dev/null | wc -l | tr -d ' ')
  echo "[LazyKimi] Evidence files available: $ev_count"
fi

# Point to latest checkpoint
CP_DIR="$STATE_DIR/checkpoints"
if [ -d "$CP_DIR" ]; then
  latest=$(ls -1dt "$CP_DIR"/cp-* 2>/dev/null | head -n1 || true)
  [ -n "$latest" ] && echo "[LazyKimi] Latest pre-compact snapshot: $latest"
fi

exit 0
