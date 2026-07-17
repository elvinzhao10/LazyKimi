#!/usr/bin/env bash
# LazyKimi — Stop hook
# Verifies completion evidence before allowing stop. Fail-open by default.
# Set LAZYKIMI_STRICT=1 to enforce blocking (exit 2) when gates are unmet.
set -euo pipefail
trap 'echo "[LazyKimi] stop-gate internal error; failing open" >&2; exit 0' ERR

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
STRICT="${LAZYKIMI_STRICT:-0}"

warn_count=0
warn() {
  echo "[LazyKimi] STOP GATE WARNING: $1" >&2
  warn_count=$((warn_count + 1))
}

# 1. In-progress tasks in boulder.json
if [ -f "$BOULDER" ] && command -v jq >/dev/null 2>&1; then
  in_progress=$(jq -r '[.tasks[]? | select(.status=="in_progress")] | length' "$BOULDER" 2>/dev/null || echo "0")
  if [ "${in_progress:-0}" -gt 0 ]; then
    warn "boulder.json has $in_progress task(s) with status in_progress"
  fi
fi

# 2. Evidence files
if [ -d "$EVIDENCE_DIR" ]; then
  ev_count=$(find "$EVIDENCE_DIR" -type f 2>/dev/null | wc -l | tr -d ' ')
  if [ "${ev_count:-0}" -eq 0 ]; then
    warn "no evidence files present in .lazykimi/evidence/"
  fi
else
  warn "no .lazykimi/evidence/ directory found"
fi

# 3. Decision
if [ "$warn_count" -gt 0 ]; then
  echo "[LazyKimi] Stop gate: $warn_count warning(s). Run lazy-verifier or record evidence before completing." >&2
  if [ "$STRICT" = "1" ]; then
    echo "[LazyKimi] STRICT mode active — blocking stop." >&2
    exit 2
  fi
fi

exit 0
