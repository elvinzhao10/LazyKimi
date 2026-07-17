#!/usr/bin/env bash
# LazyKimi — SessionStart hook
# Loads .kimi-code/AGENTS.md, detects .lazykimi/ state, prints readiness.
# Fail-open: never blocks a session. Always exits 0 on internal error.
set -euo pipefail
trap 'echo "[LazyKimi] session-start internal error; failing open" >&2; exit 0' ERR

INPUT=""
[ ! -t 0 ] && INPUT=$(cat) || true
CWD="$PWD"
if [ -n "$INPUT" ] && command -v jq >/dev/null 2>&1; then
  CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // ""' 2>/dev/null || echo "")
  [ -z "$CWD" ] && CWD="$PWD"
fi

AGENTS_MD="$CWD/.kimi-code/AGENTS.md"
STATE_DIR="$CWD/.lazykimi/state"
EVIDENCE_DIR="$CWD/.lazykimi/evidence"
BOULDER="$STATE_DIR/boulder.json"

echo "[LazyKimi] Session starting — checking project state..."

# 1. AGENTS.md presence
if [ -f "$AGENTS_MD" ]; then
  echo "[LazyKimi] AGENTS.md loaded: $AGENTS_MD"
else
  echo "[LazyKimi] NOTE: .kimi-code/AGENTS.md missing. Run lazy-init-deep to bootstrap project memory."
fi

# 2. .lazykimi/ state directory
if [ -d "$CWD/.lazykimi" ]; then
  echo "[LazyKimi] State dir present: .lazykimi/"
else
  echo "[LazyKimi] NOTE: .lazykimi/ missing — initializing minimal state dirs."
  mkdir -p "$STATE_DIR" "$EVIDENCE_DIR" 2>/dev/null || true
fi

# 3. Boulder active task summary (jq required for structured read)
if [ -f "$BOULDER" ] && command -v jq >/dev/null 2>&1; then
  active_plan=$(jq -r '.plan_path // .active_plan // "(none)"' "$BOULDER" 2>/dev/null || echo "(none)")
  in_progress=$(jq -r '[.tasks[]? | select(.status=="in_progress")] | length' "$BOULDER" 2>/dev/null || echo "0")
  next_task=$(jq -r '[.tasks[]? | select(.status=="in_progress" or .status=="pending")][0].description // "(none)"' "$BOULDER" 2>/dev/null || echo "(none)")
  echo "[LazyKimi] Active plan: $active_plan"
  echo "[LazyKimi] In-progress tasks: $in_progress"
  echo "[LazyKimi] Next task: $next_task"
fi

# 4. Evidence directory inventory
if [ -d "$EVIDENCE_DIR" ]; then
  count=$(find "$EVIDENCE_DIR" -type f 2>/dev/null | wc -l | tr -d ' ')
  echo "[LazyKimi] Evidence files: $count"
fi

echo "[LazyKimi] Readiness: ready"
exit 0
