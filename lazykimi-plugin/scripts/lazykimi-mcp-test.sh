#!/usr/bin/env bash
# lazykimi-mcp-test.sh — MCP integration test for the six declared servers.
#
# Ported from the LazyZCode v1.3.4 family script (lazyzcode-mcp-test.sh):
# exercises initialize + tools/list on every server, asserts the exact
# 32-tool family surface (9/7/4/5/5/2 per server), runs the run-state
# round-trip through the run-ledger tools against a temp project CWD, plus
# one safe representative tool call per server, the stream-protocol
# robustness check, malformed-params robustness, and the SSRF/path-boundary
# regressions. Exit 0 = all pass.
#
# Usage: bash lazykimi-mcp-test.sh
set -euo pipefail

PLUGIN="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[ -f "$PLUGIN/kimi.plugin.json" ] || {
    echo "MCP test: FAIL (missing $PLUGIN/kimi.plugin.json)" >&2
    exit 1
}

TMP="$(mktemp -d "${TMPDIR:-/tmp}/lazykimi-mcp-test.XXXXXX")"
PROJECT="$TMP/project"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT
mkdir -p "$PROJECT"
printf 'LazyKimi MCP test fixture README.\n' >"$PROJECT/README.md"
export CWD="$PROJECT"

PASS=0
FAIL=0
PASS_LIST=()
FAIL_LIST=()

check() {
    # check <label> <expected_substring> <actual_json>
    local label="$1" needle="$2" hay="$3"
    # Semantic checks run on decoded tools/call data, after validating its MCP envelope.
    if [[ "$label" != */initialize && "$label" != */tools-list ]]; then
        if ! hay="$(python3 - "$hay" "$label" <<'PYMCP'
import json
import sys
reply = json.loads(sys.argv[1])
assert reply["jsonrpc"] == "2.0", reply
if sys.argv[2].endswith('/no-project-file'):
    assert "result" not in reply and isinstance(reply.get("error"), dict), reply
    assert reply["error"]["code"] == -32603, reply
    print(json.dumps(reply["error"]))
    raise SystemExit(0)
assert "result" in reply and "error" not in reply, reply
result = reply["result"]
assert isinstance(result, dict) and isinstance(result.get("content"), list), reply
assert len(result["content"]) == 1, reply
block = result["content"][0]
assert block.get("type") == "text" and isinstance(block.get("text"), str), reply
assert result.get("isError", False) is False, reply
if sys.argv[2].endswith('-content-blocks'):
    print(json.dumps(reply))
else:
    try:
        print(json.dumps(json.loads(block["text"])))
    except json.JSONDecodeError:
        print(block["text"])
PYMCP
)"; then
            FAIL=$((FAIL+1)); FAIL_LIST+=("$label/envelope")
            echo "  FAIL: $label (invalid MCP tool result envelope)" >&2
            return
        fi
    fi
    if echo "$hay" | grep -Eqi "$needle"; then
        PASS=$((PASS+1)); PASS_LIST+=("$label")
    else
        FAIL=$((FAIL+1)); FAIL_LIST+=("$label")
        echo "  FAIL: $label (expected '$needle')" >&2
    fi
}

rpc() {
    # rpc <server> <json> -> stdout
    local server="$1" json="$2"
    printf '%s' "$json" | LAZYKIMI_MCP_MODE="${LAZYKIMI_MCP_MODE:-orchestrated}" bash "$PLUGIN/mcp/$server/server.sh" 2>/dev/null || echo '{}'
}

tool_names() {
    # tool_names <expected-count> <expected-csv> <tools-list-json>
    if python3 - "$1" "$2" "$3" <<'PYEOF'
import json, sys
expected_count, expected_csv, hay = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    response = json.loads(hay)
    names = [t["name"] for t in response["result"]["tools"]]
except Exception as error:
    raise SystemExit(f"tools/list response unparsable: {error}: {hay[:200]}")
expected = expected_csv.split(",")
if names != expected or len(names) != int(expected_count):
    raise SystemExit(f"tool surface mismatch: got {names}, expected {expected}")
PYEOF
    then
        PASS=$((PASS+1)); PASS_LIST+=("tools-surface")
    else
        FAIL=$((FAIL+1)); FAIL_LIST+=("tools-surface")
        echo "  FAIL: tools-surface" >&2
    fi
}

check_stream_protocol() {
    local server="$1"
    if python3 - "$PLUGIN" "$server" "$CWD" <<'PYEOF'
import json
import os
import subprocess
import sys

plugin, server, cwd = sys.argv[1:]
requests = "\n".join((
    "{bad json",
    "null",
    json.dumps({"jsonrpc": "2.0", "method": "notifications/initialized", "params": {}}),
    json.dumps({"jsonrpc": "2.0", "id": 41, "method": "initialize"}),
    json.dumps({"jsonrpc": "2.0", "id": 42, "method": "tools/list"}),
)) + "\n"
environment = os.environ.copy()
environment["CWD"] = cwd
environment.setdefault("LAZYKIMI_MCP_MODE", "orchestrated")
try:
    completed = subprocess.run(
        ["bash", os.path.join(plugin, "mcp", server, "server.sh")],
        input=requests,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        cwd=cwd,
        env=environment,
        timeout=10,
        check=False,
    )
except subprocess.TimeoutExpired as error:
    raise SystemExit(f"{server}: stream process timed out and was cleaned up") from error
if completed.returncode != 0:
    raise SystemExit(f"{server}: stream process exited {completed.returncode}; stderr={completed.stderr}")
try:
    responses = [json.loads(line) for line in completed.stdout.splitlines() if line]
except json.JSONDecodeError as error:
    raise SystemExit(f"{server}: stdout was not newline-delimited JSON: {error}") from error
if len(responses) != 4:
    raise SystemExit(f"{server}: expected four responses (notification is silent), got {len(responses)}: {responses}")
assert responses[0]["jsonrpc"] == "2.0"
assert responses[0]["id"] is None
assert responses[0]["error"]["code"] == -32700
assert responses[1]["jsonrpc"] == "2.0"
assert responses[1]["id"] is None
assert responses[1]["error"]["code"] == -32600
assert responses[2]["id"] == 41 and isinstance(responses[2]["result"]["serverInfo"]["name"], str)
assert responses[3]["id"] == 42 and isinstance(responses[3]["result"]["tools"], list)
PYEOF
    then
        PASS=$((PASS+1)); PASS_LIST+=("$server/stream-protocol")
    else
        FAIL=$((FAIL+1)); FAIL_LIST+=("$server/stream-protocol")
        echo "  FAIL: $server/stream-protocol" >&2
    fi
}

check_invalid_tool_params() {
    if CWD="$CWD" bash "$PLUGIN/tests/v103-mcp-params-regression.sh"; then
        PASS=$((PASS+1)); PASS_LIST+=("tools/call-invalid-params")
    else
        FAIL=$((FAIL+1)); FAIL_LIST+=("tools/call-invalid-params")
        echo "  FAIL: tools/call-invalid-params" >&2
    fi
}

tools_call() {
    python3 - "$1" <<'PYEOF'
import json
import sys

print(json.dumps({
    "jsonrpc": "2.0",
    "id": 3,
    "method": "tools/call",
    "params": {"name": "symbols", "arguments": {"path": sys.argv[1]}},
}))
PYEOF
}

echo "=== LazyKimi MCP integration test (6 declared servers, 32 tools) ==="
echo "Plugin root: $PLUGIN"
echo "Project CWD: $CWD"
echo ""

echo "--- run-ledger (9 tools) ---"
OUT=$(rpc run-ledger '{"jsonrpc":"2.0","id":1,"method":"initialize"}')
check "run-ledger/initialize" "run-ledger" "$OUT"
OUT=$(rpc run-ledger '{"jsonrpc":"2.0","id":2,"method":"tools/list"}')
tool_names 9 "create_run,list_runs,latest_run,read_state,summarize_run,append_event,update_task,create_checkpoint,recover_run" "$OUT"
OUT=$(rpc run-ledger '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"create_run","arguments":{"run_id":"mcptest","objective":"mcp integration test run"}}}')
check "run-ledger/create_run" "\"status\": *\"ok\"" "$OUT"
OUT=$(rpc run-ledger '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"append_event","arguments":{"run_id":"mcptest","event_type":"note","payload":{"k":"v"}}}}')
check "run-ledger/append_event" "event_appended" "$OUT"
OUT=$(rpc run-ledger '{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"create_checkpoint","arguments":{"run_id":"mcptest"}}}')
check "run-ledger/create_checkpoint" "\"status\": *\"ok\"" "$OUT"
OUT=$(rpc run-ledger '{"jsonrpc":"2.0","id":6,"method":"tools/call","params":{"name":"recover_run","arguments":{"run_id":"mcptest"}}}')
check "run-ledger/recover_run" "\"recovered\": *true" "$OUT"
OUT=$(rpc run-ledger '{"jsonrpc":"2.0","id":7,"method":"tools/call","params":{"name":"read_state","arguments":{"run_id":"mcptest"}}}')
check "run-ledger/read_state" "\"run_id\": *\"mcptest\"" "$OUT"
OUT=$(rpc run-ledger '{"jsonrpc":"2.0","id":8,"method":"tools/call","params":{"name":"summarize_run","arguments":{"run_id":"mcptest"}}}')
check "run-ledger/summarize_run" "Status:|Objective:" "$OUT"
OUT=$(rpc run-ledger '{"jsonrpc":"2.0","id":9,"method":"tools/call","params":{"name":"list_runs","arguments":{}}}')
check "run-ledger/list_runs" "\"runs\":" "$OUT"
OUT=$(rpc run-ledger '{"jsonrpc":"2.0","id":10,"method":"tools/call","params":{"name":"latest_run","arguments":{}}}')
check "run-ledger/latest_run" "mcptest" "$OUT"

echo "--- verification (7 tools) ---"
OUT=$(rpc verification '{"jsonrpc":"2.0","id":1,"method":"initialize"}')
check "verification/initialize" "verification" "$OUT"
OUT=$(rpc verification '{"jsonrpc":"2.0","id":2,"method":"tools/list"}')
tool_names 7 "discover_checks,run_check,record_gate_result,record_criterion_result,list_gate_results,create_repair_task,summarize_verification" "$OUT"
OUT=$(rpc verification '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"discover_checks","arguments":{}}}')
check "verification/discover_checks" "MCP integration" "$OUT"
OUT=$(rpc verification '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"summarize_verification","arguments":{"run_id":"mcptest"}}}')
check "verification/summarize_verification" "\"run_id\": *\"mcptest\"" "$OUT"

echo "--- status-dashboard (4 tools) ---"
OUT=$(rpc status-dashboard '{"jsonrpc":"2.0","id":1,"method":"initialize"}')
check "status-dashboard/initialize" "status-dashboard" "$OUT"
OUT=$(rpc status-dashboard '{"jsonrpc":"2.0","id":2,"method":"tools/list"}')
tool_names 4 "show_run_status,show_task_graph,show_verification_matrix,show_pending_approvals" "$OUT"
OUT=$(rpc status-dashboard '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"show_run_status","arguments":{"run_id":"mcptest"}}}')
check "status-dashboard/show_run_status" "completion_assessment" "$OUT"
OUT=$(rpc status-dashboard '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"show_task_graph","arguments":{"run_id":"mcptest"}}}')
check "status-dashboard/show_task_graph" "\"nodes\":" "$OUT"

echo "--- context-graph (5 tools) ---"
OUT=$(rpc context-graph '{"jsonrpc":"2.0","id":1,"method":"initialize"}')
check "context-graph/initialize" "context-graph" "$OUT"
OUT=$(rpc context-graph '{"jsonrpc":"2.0","id":2,"method":"tools/list"}')
tool_names 5 "blast_radius,file_deps,symbol_search,symbol_refs,repo_overview" "$OUT"
OUT=$(rpc context-graph '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"symbol_refs","arguments":{"symbol":"lazykimi","limit":3}}}')
check "context-graph/symbol_refs" "symbol_refs|hits" "$OUT"

echo "--- code-intel (5 tools) ---"
OUT=$(rpc code-intel '{"jsonrpc":"2.0","id":1,"method":"initialize"}')
check "code-intel/initialize" "code-intel" "$OUT"
OUT=$(rpc code-intel '{"jsonrpc":"2.0","id":2,"method":"tools/list"}')
tool_names 5 "diagnostics,typecheck,find_references,goto_definition,symbols" "$OUT"
CODE_INTEL_PATH="${LAZYKIMI_MCP_TEST_CODE_PATH:-README.md}"
OUT=$(rpc code-intel "$(tools_call "$CODE_INTEL_PATH")")
if [ -f "$CWD/$CODE_INTEL_PATH" ]; then
    check "code-intel/symbols" "symbols|README" "$OUT"
else
    check "code-intel/no-project-file" "file not found" "$OUT"
fi

echo "--- docs (2 tools) ---"
OUT=$(rpc docs '{"jsonrpc":"2.0","id":1,"method":"initialize"}')
check "docs/initialize" "docs" "$OUT"
OUT=$(rpc docs '{"jsonrpc":"2.0","id":2,"method":"tools/list"}')
tool_names 2 "get_library_docs,list_supported_registries" "$OUT"
OUT=$(rpc docs '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"list_supported_registries","arguments":{}}}')
check "docs/list_registries" "npm|pypi" "$OUT"

for server in run-ledger verification status-dashboard context-graph code-intel docs; do
    check_stream_protocol "$server"
done
check_invalid_tool_params

if bash "$PLUGIN/tests/v003-mcp-path-traversal-regression.sh" >/dev/null 2>&1; then
    PASS=$((PASS+1)); PASS_LIST+=("path-boundary-regression")
else
    FAIL=$((FAIL+1)); FAIL_LIST+=("path-boundary-regression")
    echo "  FAIL: path-boundary-regression" >&2
fi
if bash "$PLUGIN/tests/v003-ssrf-boundary-regression.sh" >/dev/null 2>&1; then
    PASS=$((PASS+1)); PASS_LIST+=("ssrf-boundary-regression")
else
    FAIL=$((FAIL+1)); FAIL_LIST+=("ssrf-boundary-regression")
    echo "  FAIL: ssrf-boundary-regression" >&2
fi

echo ""
echo "=== Results ==="
echo "Passed: $PASS"
echo "Failed: $FAIL"
if [ "$FAIL" -gt 0 ]; then
    echo "Failed items: ${FAIL_LIST[*]}"
    echo "MCP test: FAIL"
    exit 1
fi
echo "MCP test: ALL PASS"
