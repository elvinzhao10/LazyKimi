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

# 5. Post-compact recovery hint (fail-open, no jq required).
if command -v python3 >/dev/null 2>&1; then
  python3 -c "
import json, os
sessions_path = '$STATE_DIR/sessions.json'
boulder_path = '$BOULDER'
rules_dir = '$CWD/.kimi-code/rules'
hint_lines = []
try:
    if os.path.isfile(sessions_path):
        with open(sessions_path, 'r') as f:
            data = json.load(f)
        if isinstance(data, dict) and data.get('post_compact_recovery_needed'):
            plan_path = '(none)'
            if os.path.isfile(boulder_path):
                with open(boulder_path, 'r') as bf:
                    boulder = json.load(bf)
                if isinstance(boulder, dict):
                    plan_path = boulder.get('plan_path') or boulder.get('active_plan') or '(none)'
            rule_files = []
            if os.path.isdir(rules_dir):
                for root, dirs, files in os.walk(rules_dir):
                    for name in sorted(files):
                        path = os.path.join(root, name)
                        rule_files.append(os.path.relpath(path, rules_dir))
            hint_lines.append('[LazyKimi] Compact recovery needed — context may have been compacted.')
            hint_lines.append('[LazyKimi] Active plan: ' + plan_path)
            hint_lines.append('[LazyKimi] Rule files: ' + ','.join(rule_files))
            data['post_compact_recovery_needed'] = False
            with open(sessions_path, 'w') as f:
                json.dump(data, f, indent=2)
except Exception:
    pass
for line in hint_lines:
    print(line)
" 2>/dev/null || true
fi

echo "[LazyKimi] Readiness: ready"
exit 0
