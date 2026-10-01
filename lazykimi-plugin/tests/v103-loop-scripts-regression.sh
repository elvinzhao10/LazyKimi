#!/usr/bin/env bash
# v103-loop-scripts-regression.sh — failure->classify->repair loop machinery.
#
# Covers the v1.3.4 loop scripts against a temp project: next-task dependency
# selection, classify-failure family classes, create-repair-task (retry +
# ask-user), the finalize-run gates (including the plan.md checkbox
# cross-check), and the state round-trip they ride on.
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/lazykimi-loop.XXXXXX")"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

STATE="$PLUGIN_ROOT/scripts/state"
LOOP="$PLUGIN_ROOT/scripts/loop"

fail() { echo "FAIL: $1" >&2; exit 1; }

seed_run() {
  CWD="$TMP" bash "$STATE/create-run.sh" looptest "loop regression" >/dev/null || fail "create-run"
  RUN_DIR="$TMP/.lazykimi/runs/looptest"
  python3 - "$RUN_DIR" <<'PYEOF'
import json, sys
run_dir = sys.argv[1]
state = {
    "schema_version": "2", "run_id": "looptest", "objective": "loop regression",
    "status": "executing", "plan_reference": "",
    "tasks": [
        {"id": "T1", "title": "first", "status": "queued", "depends_on": []},
        {"id": "T2", "title": "second", "status": "queued", "depends_on": ["T1"]},
    ],
    "verification_gates": [], "review_status": "not_started",
    "iteration": {"count": 0, "max": 500, "mode": "normal"},
}
json.dump(state, open(f"{run_dir}/state.json", "w"), indent=2)
PYEOF
  cat >"$RUN_DIR/plan.md" <<'PLAN'
# Loop regression plan

TL;DR: exercised by tests/v103-loop-scripts-regression.sh.

## TODOs

- [x] T1: first
- [ ] T2: second

## Final Verification Wave

- [ ] F1 gate
PLAN
}

echo "=== v103 loop-scripts regression ==="

# 1. next-task respects dependencies: T1 is selectable, T2 is not yet.
seed_run
NEXT=$(CWD="$TMP" bash "$LOOP/next-task.sh" looptest) || fail "next-task should select T1"
echo "$NEXT" | grep -q '"id": *"T1"' || fail "next-task selected wrong task: $NEXT"
CWD="$TMP" bash "$STATE/update-task.sh" looptest T1 done || fail "update-task T1"
NEXT=$(CWD="$TMP" bash "$LOOP/next-task.sh" looptest) || fail "next-task should select T2 after T1 done"
echo "$NEXT" | grep -q '"id": *"T2"' || fail "next-task did not unlock T2: $NEXT"
echo "  [PASS] next-task respects dependencies"

# 2. Blocked run: T2 queued but dependency failed -> blocked reason.
seed_run
CWD="$TMP" bash "$STATE/update-task.sh" looptest T1 failed >/dev/null 2>&1 || true
OUT=$(CWD="$TMP" bash "$LOOP/next-task.sh" looptest 2>&1) && fail "next-task should fail on blocked run"
echo "$OUT" | grep -q '"blocked"' || fail "expected blocked reason, got: $OUT"
echo "  [PASS] next-task reports blocked"

# 3. classify-failure emits the family classes.
seed_run
for pair in "permission denied:ask-user" "connection refused:retry" "no such file:fallback" "weird crash:human-needed"; do
  MSG="${pair%%:*}"; WANT="${pair##*:}"
  GOT=$(CWD="$TMP" bash "$LOOP/classify-failure.sh" looptest T1 "$MSG") || fail "classify-failure rc for $MSG"
  [ "$GOT" = "$WANT" ] || fail "classify-failure('$MSG') = $GOT, expected $WANT"
done
echo "  [PASS] classify-failure family classes"

# 4. create-repair-task: retry spawns a queued R* task; ask-user blocks the run.
seed_run
NEWID=$(CWD="$TMP" bash "$LOOP/create-repair-task.sh" looptest T1 retry) || fail "create-repair-task retry"
case "$NEWID" in R*) ;; *) fail "retry repair id should start with R: $NEWID";; esac
python3 - "$TMP" <<'PYEOF'
import json, sys
state = json.load(open(f"{sys.argv[1]}/.lazykimi/runs/looptest/state.json"))
repair = next((t for t in state["tasks"] if t.get("repair_of") == "T1"), None)
assert repair and repair["status"] == "queued", repair
PYEOF
CWD="$TMP" bash "$LOOP/create-repair-task.sh" looptest T2 ask-user >/dev/null || fail "create-repair-task ask-user"
python3 - "$TMP" <<'PYEOF'
import json, sys
state = json.load(open(f"{sys.argv[1]}/.lazykimi/runs/looptest/state.json"))
assert state["status"] == "blocked", state["status"]
assert "awaiting human decision" in state["blocker"]["reason"], state["blocker"]
PYEOF
echo "  [PASS] create-repair-task retry + ask-user"

# 5. finalize-run refuses while work remains (gates/review/checkboxes).
seed_run
OUT=$(CWD="$TMP" bash "$LOOP/finalize-run.sh" looptest 2>&1) && fail "finalize-run should refuse an unfinished run"
echo "$OUT" | grep -q 'review_status' || fail "finalize should cite review_status: $OUT"
echo "$OUT" | grep -q 'unchecked checkbox' || fail "finalize should cite unchecked plan checkboxes: $OUT"

# 6. finalize-run completes a clean run and emits the terminal report.
seed_run
RUN_DIR="$TMP/.lazykimi/runs/looptest"
python3 - "$RUN_DIR" <<'PYEOF'
import json, sys
run_dir = sys.argv[1]
p = f"{run_dir}/state.json"
d = json.load(open(p))
for t in d["tasks"]:
    t["status"] = "done"
d["verification_gates"] = [{"name": "F1", "status": "passed", "result": "ok"}]
d["review_status"] = "accepted"
json.dump(d, open(p, "w"), indent=2)
open(f"{run_dir}/plan.md", "w").write(
    "# Loop regression plan\n\n## TODOs\n\n- [x] T1: first\n- [x] T2: second\n\n## Final Verification Wave\n\n- [x] F1 gate\n"
)
PYEOF
CWD="$TMP" bash "$STATE/checkpoint.sh" looptest >/dev/null || fail "checkpoint"
OUT=$(CWD="$TMP" bash "$LOOP/finalize-run.sh" looptest) || fail "finalize-run should complete"
echo "$OUT" | grep -q 'RUN COMPLETE: looptest' || fail "finalize-run output: $OUT"
python3 - "$TMP" <<'PYEOF'
import json, sys
state = json.load(open(f"{sys.argv[1]}/.lazykimi/runs/looptest/state.json"))
assert state["status"] == "complete", state["status"]
PYEOF
grep -q '"event": *"run_completed"' "$RUN_DIR/events.jsonl" || fail "run_completed event missing"
echo "  [PASS] finalize-run gates + terminal report"

# 7. The lazykimi-verification MCP server wires the same loop scripts
#    (run_check -> classify-failure, create_repair_task -> create-repair-task).
seed_run
CWD="$TMP" bash "$STATE/update-task.sh" looptest T1 running >/dev/null 2>&1 || true
OUT=$(printf '%s' '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"run_check","arguments":{"run_id":"looptest","task_id":"T1","error_message":"connection refused during fetch"}}}' \
  | CWD="$TMP" LAZYKIMI_MCP_MODE=orchestrated bash "$PLUGIN_ROOT/mcp/verification/server.sh" 2>/dev/null || true)
python3 - "$OUT" <<'PYMCP' || fail "verification run_check wiring: $OUT"
import json
import sys
reply = json.loads(sys.argv[1])
assert reply["jsonrpc"] == "2.0" and reply["id"] == 1, reply
assert "error" not in reply, reply
result = reply["result"]
assert result.get("isError", False) is False, reply
assert isinstance(result.get("content"), list) and len(result["content"]) == 1, reply
block = result["content"][0]
assert block.get("type") == "text", reply
assert json.loads(block["text"])["classification"] == "retry", reply
PYMCP
OUT=$(printf '%s' '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"create_repair_task","arguments":{"run_id":"looptest","failed_task_id":"T1","classification":"retry"}}}' \
  | CWD="$TMP" LAZYKIMI_MCP_MODE=orchestrated bash "$PLUGIN_ROOT/mcp/verification/server.sh" 2>/dev/null || true)
python3 - "$OUT" <<'PYMCP' || fail "verification create_repair_task wiring: $OUT"
import json
import sys
reply = json.loads(sys.argv[1])
assert reply["jsonrpc"] == "2.0" and reply["id"] == 2, reply
assert "error" not in reply, reply
result = reply["result"]
assert result.get("isError", False) is False, reply
assert isinstance(result.get("content"), list) and len(result["content"]) == 1, reply
block = result["content"][0]
assert block.get("type") == "text", reply
assert json.loads(block["text"])["repair_task_id"].startswith("R"), reply
PYMCP
python3 - "$TMP" <<'PYEOF'
import json, sys
events = [json.loads(l) for l in open(f"{sys.argv[1]}/.lazykimi/runs/looptest/events.jsonl") if l.strip()]
assert any(e.get("event") == "task_failed" and e.get("classification") == "retry" for e in events), events
assert any(e.get("event") == "repair_task_created" for e in events), events
PYEOF
echo "  [PASS] verification MCP server wires classify/repair loop"

echo ""
echo "v103 loop-scripts regression: PASS"
