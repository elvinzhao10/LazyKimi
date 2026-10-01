#!/usr/bin/env bash
# session-start.sh — Kimi SessionStart hook: bootstrap .lazykimi state, run the
# package load-check, and summarize boulder / active-loop / active-run state.
# Ported from the LazyZCode v1.3.4 hook semantics (family parity).
#
# Kimi output contract: print EITHER strict JSON ({"additionalContext": "..."})
# OR nothing on stdout; diagnostics go to stderr. This hook is advisory and
# ALWAYS exits 0 — a degraded package must never break session startup.
set -uo pipefail

# --- Read event JSON from stdin defensively (cap input at 1 MiB) ---
INPUT=$(head -c 1048576 || true)
CWD=$(printf '%s' "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('cwd','.'))" 2>/dev/null || true)
[ -n "$CWD" ] || CWD="$PWD"
PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

NOTES_FILE=$(mktemp "${TMPDIR:-/tmp}/lazykimi-session-start.XXXXXX")
trap 'rm -f "$NOTES_FILE"' EXIT
note() { printf '%s\n' "$1" >>"$NOTES_FILE"; }

note "(LazyKimi v1.3.4): Session starting — checking project state..."

# --- Bootstrap the .lazykimi/ directory tree so skills/agents that read
# plans/, context/, drafts/, rules/, ulw-loop/, or runs/ don't crash on a
# fresh workspace. create-run.sh creates runs/<run_id>/ on demand; this
# ensures the parents exist.
if mkdir -p "$CWD/.lazykimi"/{plans,context,drafts,rules,runs,ulw-loop} 2>/dev/null; then
    note "(LazyKimi): .lazykimi state directories present (plans, context, drafts, rules, runs, ulw-loop)."
else
    note "(LazyKimi): WARNING could not create $CWD/.lazykimi state directories."
fi

# --- Package readiness (load-check; the standalone script lands with the
# verify-runner port — until then the CLI load-check is the readiness source) ---
if [ ! -d "$PLUGIN_ROOT" ]; then
    note "(LazyKimi): WARNING plugin root unavailable — package readiness unknown (SESSIONSTART_READINESS=failed reason=plugin-root-unavailable)."
elif [ -f "$PLUGIN_ROOT/scripts/lazykimi-load-check.sh" ]; then
    if load_check=$(bash "$PLUGIN_ROOT/scripts/lazykimi-load-check.sh" 2>&1); then
        if grep -q '^PACKAGE_READINESS=full$' <<<"$load_check"; then
            note "(LazyKimi): Package readiness: full."
            note "SESSIONSTART_READINESS=full"
        elif grep -q '^PACKAGE_READINESS=degraded$' <<<"$load_check"; then
            note "(LazyKimi): Package readiness: degraded — some verification gates may be unavailable."
            note "SESSIONSTART_READINESS=degraded"
        else
            note "(LazyKimi): Package readiness: unknown (missing readiness result)."
            note "SESSIONSTART_READINESS=degraded reason=missing-package-readiness-result"
        fi
    else
        note "(LazyKimi): Package readiness check failed — continuing in degraded mode."
        note "SESSIONSTART_READINESS=degraded reason=package-readiness-failed"
    fi
elif command -v node >/dev/null 2>&1 && [ -f "$PLUGIN_ROOT/dist/index.js" ]; then
    if node "$PLUGIN_ROOT/dist/index.js" load-check >/dev/null 2>&1; then
        note "(LazyKimi): Package readiness: full (CLI load-check)."
        note "SESSIONSTART_READINESS=full"
    else
        note "(LazyKimi): Package readiness: degraded — CLI load-check reported missing inventory."
        note "SESSIONSTART_READINESS=degraded reason=package-readiness-failed"
    fi
else
    note "(LazyKimi): Package readiness unknown — no load-check available (SESSIONSTART_READINESS=degraded reason=load-check-unavailable)."
fi

# --- Check for project memory (Kimi project memory is AGENTS.md) ---
if [ -f "$CWD/AGENTS.md" ] || [ -f "$CWD/.kimi-code/AGENTS.md" ]; then
    note "(LazyKimi): Project memory found (AGENTS.md)."
else
    note "(LazyKimi): Project memory (AGENTS.md) missing. Run /lazy-init-deep or ask to initialize project memory."
fi

# --- Check for project rules ---
if [ -d "$CWD/.kimi-code/rules" ] && [ "$(ls -A "$CWD/.kimi-code/rules"/*.md 2>/dev/null)" ]; then
    note "(LazyKimi): Project rules loaded."
fi

# --- Boulder summary (legacy v0.x durable work tracking under .lazykimi/state/) ---
BOULDER_FILE="$CWD/.lazykimi/state/boulder.json"
if [ -f "$BOULDER_FILE" ]; then
    BOULDER=$(python3 - "$BOULDER_FILE" <<'PY' 2>/dev/null || true
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    raise SystemExit(0)
work_id = d.get('active_work_id')
works = d.get('works', {})
if isinstance(work_id, str) and work_id and isinstance(works, dict):
    work = works.get(work_id)
    detail = ''
    if isinstance(work, dict):
        detail = f" (status: {work.get('status', 'unknown')})"
    print(f"(LazyKimi): Boulder active work: {work_id}{detail}")
PY
)
    [ -n "$BOULDER" ] && note "$BOULDER"
fi

# --- Active-loop summary (legacy v0.x loop bridge; ulw-loop/ supersedes it) ---
ACTIVE_LOOP_FILE="$CWD/.lazykimi/state/active-loop.json"
if [ -f "$ACTIVE_LOOP_FILE" ]; then
    ACTIVE_LOOP=$(python3 - "$ACTIVE_LOOP_FILE" <<'PY' 2>/dev/null || true
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    raise SystemExit(0)
if not isinstance(d, dict):
    raise SystemExit(0)
plan = d.get('plan_name') or d.get('plan') or d.get('goal') or 'unknown'
print(f"(LazyKimi): Active loop present: {plan}. Continue with /lazy-ulw-loop or /lazy-start-work.")
PY
)
    [ -n "$ACTIVE_LOOP" ] && note "$ACTIVE_LOOP"
fi

# --- Active run summary (v1.3.4 run state under .lazykimi/runs/) ---
RUNS_DIR="$CWD/.lazykimi/runs"
if [ -d "$RUNS_DIR" ]; then
    for run_dir in "$RUNS_DIR"/*/; do
        state_file="${run_dir}state.json"
        if [ -f "$state_file" ]; then
            STATUS=$(python3 - "$state_file" <<'PY' 2>/dev/null || echo ""
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    raise SystemExit(1)
print(d.get('status', ''))
PY
)
            if [ "$STATUS" = "active" ] || [ "$STATUS" = "paused" ] || [ "$STATUS" = "executing" ] || [ "$STATUS" = "verifying" ] || [ "$STATUS" = "reviewing" ]; then
                PLAN=$(python3 - "$state_file" <<'PY' 2>/dev/null || echo "unknown"
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    raise SystemExit(1)
print(d.get('plan_name', d.get('run_id', '')))
PY
)
                PROGRESS=$(python3 - "$state_file" <<'PY' 2>/dev/null || echo "?/?"
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    raise SystemExit(1)
p = d.get('progress', {})
print(f"{p.get('completed_checkboxes', p.get('completed', 0))}/{p.get('total_checkboxes', p.get('total', 0))}")
PY
)
                note "(LazyKimi): Active run found: $PLAN (status: $STATUS, progress: $PROGRESS)"
                note "(LazyKimi): Run /lazy-start-work or ask to continue the planned work."
                break
            fi
        fi
    done
fi

# --- Emit strict JSON only: {"additionalContext": "<summary text>"} ---
NOTES="$(cat "$NOTES_FILE")" python3 - <<'PY'
import json, os
notes = os.environ.get('NOTES', '')
if notes.strip():
    print(json.dumps({"additionalContext": notes}))
PY

exit 0
