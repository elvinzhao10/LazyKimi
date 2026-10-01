#!/usr/bin/env bash
# subagent-stop.sh — Kimi SubagentStop hook (advisory executor-evidence gate).
# v1.3.4 mapped semantics: Kimi having this event is an ADDITIVE reminder —
# the authoritative executor-evidence gate stays in the review skills, so
# behavior matches LazyZCode v1.3.4 (the family gate is skill-side).
#
# Verifies the implementer/coder sub-agent reported an EVIDENCE_RECORDED
# marker pointing at a non-empty evidence file and appends an advisory
# evidence-reminder (additionalContext) when it did not; also records the
# stop in the active run's ledger.
#
# Kimi output contract: print EITHER strict JSON ({"additionalContext": ...})
# OR nothing on stdout; diagnostics to stderr. Advisory only — ALWAYS exits 0.
set -uo pipefail

INPUT=$(head -c 1048576 || true)
[ -z "$INPUT" ] && exit 0
CWD=$(printf '%s' "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('cwd',''))" 2>/dev/null || echo "")
[ -n "$CWD" ] || CWD="$PWD"
PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

AGENT_TYPE=$(printf '%s' "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('agent_type','') or d.get('agent_type_name','') or '')" 2>/dev/null || true)
LAST_MSG=$(printf '%s' "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('last_assistant_message',''))" 2>/dev/null || true)

# Ledger record (best-effort, transactional via the state scripts).
RID=$(CWD="$CWD" bash "$PLUGIN_ROOT/scripts/state/latest-run.sh" 2>/dev/null || true)
if [ -n "$RID" ]; then
    printf '{"agent":"%s","source":"SubagentStop"}' "${AGENT_TYPE//\"/}" \
      | CWD="$CWD" bash "$PLUGIN_ROOT/scripts/state/append-event.sh" "$RID" subagent_stopped >/dev/null 2>&1 || true
fi

# Only gate implementer/coder-class sub-agents.
case "$AGENT_TYPE" in
  *implementer*|*coder*|*qa-executor*) ;;
  *) exit 0 ;;
esac
[ -n "$LAST_MSG" ] || { echo '[LazyKimi] SubagentStop: implementer output empty — no evidence recorded.' >&2; exit 0; }

EV_PATH=$(printf '%s' "$LAST_MSG" | python3 -c "import sys,re; m=re.search(r'EVIDENCE_RECORDED:\s*(\S+)', sys.stdin.read()); print(m.group(1) if m else '')" 2>/dev/null || true)

REMINDER=""
if [ -z "$EV_PATH" ]; then
    REMINDER="[LazyKimi] SubagentStop: no EVIDENCE_RECORDED marker found in implementer output. The executor-evidence gate (review skills) requires recorded evidence before work is accepted — record evidence now or expect the review gate to reject the claim."
else
    [ "${EV_PATH:0:1}" != "/" ] && EV_PATH="$CWD/$EV_PATH"
    if [ ! -f "$EV_PATH" ] || [ ! -s "$EV_PATH" ]; then
        REMINDER="[LazyKimi] SubagentStop: evidence file missing or empty: $EV_PATH. The executor-evidence gate (review skills) requires non-empty recorded evidence — repair it now or expect the review gate to reject the claim."
    fi
fi

if [ -n "$REMINDER" ]; then
    printf '%s' "$REMINDER" | python3 -c 'import json,sys; print(json.dumps({"additionalContext": sys.stdin.read()}))'
fi

exit 0
