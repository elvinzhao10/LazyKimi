#!/usr/bin/env bash
# lazykimi-hook-pipeline-test.sh — Simulates Kimi's 16-event hook lifecycle by
# piping realistic payloads (from tests/fixtures/hook-events/) through each
# hook in sequence. Ported from the LazyZCode v1.3.4 hook-pipeline-test.sh and
# extended to the Kimi 16-event surface, including oversized-input and
# wrapper-resolution adversarial cases. Proves the entire hook chain works
# end-to-end without requiring a live Kimi session.
#
# Kimi output contract under test:
#   - SessionStart / UserPromptSubmit / Stop / SubagentStop / PostCompact print
#     strict JSON ({"additionalContext": "..."}) or NOTHING on stdout, exit 0.
#   - PreToolUse denies with exit code 2 and a stderr reason; otherwise prints
#     NOTHING and exits 0.
#   - PostToolUse / PostToolUseFailure / ledger hooks print NOTHING, exit 0.
#   - PermissionRequest / PermissionResult print NOTHING, exit 0, and append a
#     normalized record under .lazykimi/hook-events/.
#
# Usage: bash lazykimi-hook-pipeline-test.sh
set -uo pipefail

TMP="$(mktemp -d "${TMPDIR:-/tmp}/lazykimi-hook-pipeline.XXXXXX")"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

CWD="${CWD:-$TMP}"
mkdir -p "$CWD"
PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURES="$PLUGIN_ROOT/tests/fixtures/hook-events"
HOOKS_DIR="$PLUGIN_ROOT/hooks"
if [ ! -d "$HOOKS_DIR" ] || [ ! -d "$FIXTURES" ]; then
    echo "Hook pipeline test: FAIL (hooks dir or fixtures dir missing)" >&2
    exit 1
fi
# Finite budget shared with the release verifier. Each hook invocation runs
# under an alarm so a hung hook cannot stall the suite; the alarm wrapper
# preserves stdout/stderr/exit code.
HOOK_TIMEOUT="${LAZYKIMI_VERIFY_TIMEOUT_SECONDS:-90}"
run_hook() {
    perl -e 'alarm shift; exec @ARGV or exit 127' "$HOOK_TIMEOUT" "$@"
}
SESSION_ID="hook-pipeline-test-$$"
PASS=0
FAIL=0
RESULTS=""

payload() {
    # payload <Event>.json — substitute the ${PROJECT_DIR} placeholder.
    sed "s|\${PROJECT_DIR}|$CWD|g" "$FIXTURES/$1"
}

report() {
    # report <name> <pass|fail> <detail>
    if [ "$2" = "pass" ]; then
        RESULTS="${RESULTS}  [PASS] $1 — $3\n"
        PASS=$((PASS + 1))
    else
        RESULTS="${RESULTS}  [FAIL] $1 — $3\n"
        FAIL=$((FAIL + 1))
    fi
}

# expect_stdout <name> <hook> <fixture> <pattern|-> <expected_exit>
expect_stdout() {
    local name="$1" hook="$2" fixture_file="$3" pattern="$4" expected_exit="$5"
    local out err status
    out=$(payload "$fixture_file" | run_hook bash "$HOOKS_DIR/$hook" 2>"$TMP/err")
    status=$?
    err=$(cat "$TMP/err" 2>/dev/null)
    if [ "$status" -ne "$expected_exit" ]; then
        report "$name" fail "exited $status (expected $expected_exit): ${err:0:80}"
    elif [ "$pattern" = "-" ]; then
        if [ -z "$out" ]; then
            report "$name" pass "silent stdout as expected (exit $status)"
        else
            report "$name" fail "expected empty stdout, got: ${out:0:80}"
        fi
    elif printf '%s' "$out" | grep -Eq "$pattern"; then
        report "$name" pass "stdout matched /$pattern/ (exit $status)"
    else
        report "$name" fail "expected stdout /$pattern/, got: ${out:0:80}"
    fi
}

# expect_deny <name> <payload-json> — PreToolUse deny: exit 2, empty stdout, stderr reason.
expect_deny() {
    local name="$1" payload_json="$2" out err status
    out=$(printf '%s' "$payload_json" | run_hook bash "$HOOKS_DIR/pre-tool-use.sh" 2>"$TMP/err")
    status=$?
    err=$(cat "$TMP/err" 2>/dev/null)
    if [ "$status" -ne 2 ]; then
        report "$name" fail "deny must exit 2, got $status"
    elif [ -n "$out" ]; then
        report "$name" fail "deny must keep stdout empty, got: ${out:0:80}"
    elif ! printf '%s' "$err" | grep -Eqi 'denial|denied'; then
        report "$name" fail "deny must explain the reason on stderr, got: ${err:0:80}"
    else
        report "$name" pass "denied with exit 2 and stderr reason"
    fi
}

echo "=== LazyKimi Hook Pipeline Activation Test (Kimi 16-event surface) ==="
echo "Simulating the Kimi hook lifecycle with realistic payloads (project: $CWD)..."
echo ""

# --- Critical 8 (gating semantics; wired on BOTH registration routes) ---

# 1. SessionStart — bootstraps state and reports readiness via additionalContext.
expect_stdout "SessionStart" "session-start.sh" "SessionStart.json" \
    'additionalContext.*(SESSIONSTART_READINESS|LazyKimi)' 0
[ -d "$CWD/.lazykimi/plans" ] && [ -d "$CWD/.lazykimi/runs" ] && [ -d "$CWD/.lazykimi/ulw-loop" ] \
    && report "SessionStart (state bootstrap)" pass ".lazykimi tree bootstrapped" \
    || report "SessionStart (state bootstrap)" fail "state tree missing after SessionStart"

# 2. UserPromptSubmit — plain prompt without action verbs or keywords: silent
#    (the adaptive runtime's ACTION_PATTERN gate keeps non-action prompts quiet).
expect_stdout "UserPromptSubmit (plain)" "user-prompt-submit.sh" "UserPromptSubmit.json" "-" 0

# 2b. UserPromptSubmit — action verb produces the adaptive intake directive
#     (selection-only until the kimi host is observed, per v1.3.4).
ACTION_PAYLOAD='{"session_id":"'"$SESSION_ID"'","cwd":"'"$CWD"'","hook_event_name":"UserPromptSubmit","prompt":"please review the current change set"}'
out=$(printf '%s' "$ACTION_PAYLOAD" | run_hook bash "$HOOKS_DIR/user-prompt-submit.sh" 2>/dev/null); status=$?
if [ "$status" -eq 0 ] && printf '%s' "$out" | grep -Eq 'additionalContext.*Adaptive intake directive' \
    && printf '%s' "$out" | grep -Eq 'selection-only'; then
    report "UserPromptSubmit (adaptive directive)" pass "action prompt produced a selection-only directive (exit 0)"
else
    report "UserPromptSubmit (adaptive directive)" fail "expected a selection-only adaptive directive, got: ${out:0:120}"
fi

# 3. UserPromptSubmit — command keyword routes to the explicit entry command.
KW_PAYLOAD='{"session_id":"'"$SESSION_ID"'","cwd":"'"$CWD"'","hook_event_name":"UserPromptSubmit","prompt":"run ultrawork on the auth flow"}'
out=$(printf '%s' "$KW_PAYLOAD" | run_hook bash "$HOOKS_DIR/user-prompt-submit.sh" 2>/dev/null); status=$?
if [ "$status" -eq 0 ] && printf '%s' "$out" | grep -Eq 'additionalContext.*(/lazy-ultrawork|ultrawork)'; then
    report "UserPromptSubmit (keyword)" pass "routed keyword to /lazy-ultrawork (exit 0)"
else
    report "UserPromptSubmit (keyword)" fail "expected keyword routing, got: ${out:0:80}"
fi

# 4. UserPromptSubmit — context-pressure marker triggers the recovery directive.
CP_PAYLOAD='{"session_id":"'"$SESSION_ID"'","cwd":"'"$CWD"'","hook_event_name":"UserPromptSubmit","prompt":"context compacted; continue the plan"}'
out=$(printf '%s' "$CP_PAYLOAD" | run_hook bash "$HOOKS_DIR/user-prompt-submit.sh" 2>/dev/null); status=$?
if [ "$status" -eq 0 ] && printf '%s' "$out" | grep -Eqi 'additionalContext.*(context pressure|recover)'; then
    report "UserPromptSubmit (context pressure)" pass "injected recovery directive (exit 0)"
else
    report "UserPromptSubmit (context pressure)" fail "expected recovery directive, got: ${out:0:80}"
fi

# 5. PreToolUse — safe command: silent allow.
expect_stdout "PreToolUse (allow)" "pre-tool-use.sh" "PreToolUse.json" "-" 0

# 6. PreToolUse — dual key style (toolName/toolInput) still parses: silent allow.
DUAL_PAYLOAD='{"session_id":"'"$SESSION_ID"'","cwd":"'"$CWD"'","hook_event_name":"PreToolUse","toolName":"Bash","toolInput":{"command":"ls -la"}}'
out=$(printf '%s' "$DUAL_PAYLOAD" | run_hook bash "$HOOKS_DIR/pre-tool-use.sh" 2>/dev/null); status=$?
if [ "$status" -eq 0 ] && [ -z "$out" ]; then
    report "PreToolUse (dual keys)" pass "toolName/toolInput accepted (exit 0)"
else
    report "PreToolUse (dual keys)" fail "dual-key payload rejected: exit $status, got: ${out:0:80}"
fi

# 7. PreToolUse — destructive delete: deny via exit 2 + stderr.
expect_deny "PreToolUse (deny rm -rf /)" '{"session_id":"'"$SESSION_ID"'","cwd":"'"$CWD"'","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"rm -rf /"}}'

# 8. PreToolUse — wrapper-hidden destructive delete (env/nohup prefixes).
expect_deny "PreToolUse (wrapper env rm -rf /)" '{"session_id":"'"$SESSION_ID"'","cwd":"'"$CWD"'","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"env rm -rf /"}}'
expect_deny "PreToolUse (wrapper nohup rm -rf ~/proj)" '{"session_id":"'"$SESSION_ID"'","cwd":"'"$CWD"'","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"nohup rm -rf ~/proj"}}'

# 9. PreToolUse — oversized input (> 1 MiB): reject with exit 2.
OVERSIZED_PAYLOAD='{"session_id":"'"$SESSION_ID"'","cwd":"'"$CWD"'","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"ls","pad":"'"$(python3 -c 'print("x" * 1048600)')"'"},"tail":true}'
out=$(printf '%s' "$OVERSIZED_PAYLOAD" | run_hook bash "$HOOKS_DIR/pre-tool-use.sh" 2>"$TMP/err"); status=$?
err=$(cat "$TMP/err" 2>/dev/null)
if [ "$status" -eq 2 ] && [ -z "$out" ] && printf '%s' "$err" | grep -Eqi '1 MiB'; then
    report "PreToolUse (oversized input)" pass "rejected >1 MiB input with exit 2"
else
    report "PreToolUse (oversized input)" fail "exit $status, stderr: ${err:0:80}"
fi

# 10. PreToolUse — malformed payload (no tool_name): reject with exit 2.
expect_deny "PreToolUse (malformed payload)" '{"session_id":"'"$SESSION_ID"'","cwd":"'"$CWD"'","hook_event_name":"PreToolUse","tool_input":{"command":"ls"}}'

# 11. PostToolUse — silent ledger update (no active run here).
expect_stdout "PostToolUse" "post-tool-use.sh" "PostToolUse.json" "-" 0

# 12. PostToolUseFailure — silent failure classification.
expect_stdout "PostToolUseFailure" "post-tool-use-failure.sh" "PostToolUseFailure.json" "-" 0

# 13. PermissionRequest — advisory audit consumer: silent, exit 0, record persisted.
RECORDS_BEFORE=$(find "$CWD/.lazykimi/hook-events" -name '*.json' 2>/dev/null | wc -l | tr -d ' ')
out=$(payload "PermissionRequest.json" | run_hook bash "$HOOKS_DIR/permission-request.sh" 2>"$TMP/err"); status=$?
err=$(cat "$TMP/err" 2>/dev/null)
if [ "$status" -ne 0 ]; then
    report "PermissionRequest" fail "exited $status (expected 0): ${err:0:80}"
elif [ -n "$out" ]; then
    report "PermissionRequest" fail "expected empty stdout, got: ${out:0:80}"
else
    report "PermissionRequest" pass "silent stdout as expected (exit 0)"
fi
RECORDS_AFTER=$(find "$CWD/.lazykimi/hook-events" -name '*.json' 2>/dev/null | wc -l | tr -d ' ')
if [ "$RECORDS_AFTER" -gt "$RECORDS_BEFORE" ]; then
    report "PermissionRequest (ledger)" pass "normalized record appended to .lazykimi/hook-events/"
else
    report "PermissionRequest (ledger)" fail "expected a persisted hook-event record"
fi

# 14. PermissionResult — decision recorded into the same ledger.
out=$(payload "PermissionResult.json" | run_hook bash "$HOOKS_DIR/permission-result.sh" 2>"$TMP/err"); status=$?
err=$(cat "$TMP/err" 2>/dev/null)
if [ "$status" -eq 0 ] && [ -z "$out" ]; then
    report "PermissionResult" pass "silent stdout as expected (exit 0)"
else
    report "PermissionResult" fail "exit $status, out: ${out:0:60}, err: ${err:0:60}"
fi

# 15. Stop — no active run: silent allow.
expect_stdout "Stop (no active run)" "stop-gate.sh" "Stop.json" "-" 0

# 16. Stop — context pressure passes through gracefully.
CP_STOP='{"session_id":"'"$SESSION_ID"'","cwd":"'"$CWD"'","hook_event_name":"Stop","stop_hook_active":false,"prompt":"context compacted"}'
out=$(printf '%s' "$CP_STOP" | run_hook bash "$HOOKS_DIR/stop-gate.sh" 2>/dev/null); status=$?
if [ "$status" -eq 0 ] && [ -z "$out" ]; then
    report "Stop (context pressure)" pass "passed through gracefully (exit 0)"
else
    report "Stop (context pressure)" fail "expected silent pass-through, got: ${out:0:80}"
fi

# --- Advisory 8 (plugin-manifest route only) ---

# 17. SubagentStart — silent dispatch ledger event (no active run here).
expect_stdout "SubagentStart" "subagent-start.sh" "SubagentStart.json" "-" 0

# 18. SubagentStop — implementer without evidence: advisory reminder, exit 0.
out=$(payload "SubagentStop.json" | run_hook bash "$HOOKS_DIR/subagent-stop.sh" 2>/dev/null); status=$?
if [ "$status" -eq 0 ] && printf '%s' "$out" | grep -Eq 'additionalContext.*(EVIDENCE_RECORDED|evidence)'; then
    report "SubagentStop (evidence reminder)" pass "advisory evidence reminder injected (exit 0)"
else
    report "SubagentStop (evidence reminder)" fail "expected evidence reminder, got: ${out:0:80}"
fi

# 19. PreCompact — silent (no active run here).
expect_stdout "PreCompact" "pre-compact.sh" "PreCompact.json" "-" 0

# 20. PostCompact — re-anchor reminder via additionalContext.
out=$(payload "PostCompact.json" | run_hook bash "$HOOKS_DIR/post-compact.sh" 2>/dev/null); status=$?
if [ "$status" -eq 0 ] && printf '%s' "$out" | grep -Eq 'additionalContext.*(AGENTS|restoration)'; then
    report "PostCompact (re-anchor)" pass "context re-anchor reminder injected (exit 0)"
else
    report "PostCompact (re-anchor)" fail "expected re-anchor reminder, got: ${out:0:80}"
fi

# 21-24. SessionEnd / StopFailure / Interrupt / Notification — silent advisory consumers.
expect_stdout "SessionEnd" "session-end.sh" "SessionEnd.json" "-" 0
expect_stdout "StopFailure" "stop-failure.sh" "StopFailure.json" "-" 0
expect_stdout "Interrupt" "interrupt.sh" "Interrupt.json" "-" 0
expect_stdout "Notification" "notification.sh" "Notification.json" "-" 0

printf '%b' "$RESULTS"
echo ""
echo "=== Results ==="
echo "Passed: $PASS"
echo "Failed: $FAIL"
echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "Hook pipeline test: ALL PASS"
    echo ""
    echo "All 16 Kimi hook events produce correct output for realistic payloads."
    echo "Package-level hook behavior passed; live host registration remains unchecked."
    exit 0
else
    echo "Hook pipeline test: $FAIL FAILURES"
    exit 1
fi
