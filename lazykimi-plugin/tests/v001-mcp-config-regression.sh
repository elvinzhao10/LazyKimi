#!/usr/bin/env bash
# v001-mcp-config-regression.sh
# Verify .kimi-code/mcp.json is valid JSON with 6 servers, all required:false,
# and that the six declared servers expose the exact v1.3.4 family tool
# surface: 9/7/4/5/5/2 tools = 32 total (v1.3.4 port expectation).
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/lazykimi-mcp-config.XXXXXX")"

cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

EXPECTED=6
MCP="$PLUGIN_ROOT/.kimi-code/mcp.json"
[ -f "$MCP" ] || fail "mcp.json missing"

python3 - "$MCP" "$EXPECTED" <<'PYEOF'
import json, sys
path, expected = sys.argv[1], int(sys.argv[2])
with open(path, encoding="utf-8") as f:
    data = json.load(f)
if not isinstance(data, dict):
    print("FAIL: mcp.json not a JSON object", file=sys.stderr); sys.exit(1)
servers = data.get("mcpServers")
if not isinstance(servers, dict) or not servers:
    print("FAIL: mcpServers missing or empty", file=sys.stderr); sys.exit(1)
if len(servers) != expected:
    print(f"FAIL: expected {expected} servers, found {len(servers)}", file=sys.stderr)
    sys.exit(1)
for name, cfg in servers.items():
    if not isinstance(cfg, dict):
        print(f"FAIL: {name} config not an object", file=sys.stderr); sys.exit(1)
    # type:stdio is implied by Kimi Code CLI mcp.json format (command+args);
    # only the plugin manifest (kimi.plugin.json) carries an explicit type field.
    if cfg.get("required") is not False:
        print(f"FAIL: {name} required is not false", file=sys.stderr); sys.exit(1)
    if not cfg.get("command") or not isinstance(cfg.get("args"), list):
        print(f"FAIL: {name} missing command/args", file=sys.stderr); sys.exit(1)
PYEOF

# Live tool-surface check: every server.sh answers tools/list with the exact
# family tool set (32 tools across 6 servers). Kimi provides no env
# interpolation; the launcher derives the plugin root from its own path and
# the project CWD comes from the CWD env (as init injects it).
python3 - "$PLUGIN_ROOT" "$TMP" <<'PYEOF'
import json, os, subprocess, sys

plugin, project = sys.argv[1:]
expected = {
    "run-ledger": "create_run,list_runs,latest_run,read_state,summarize_run,append_event,update_task,create_checkpoint,recover_run",
    "verification": "discover_checks,run_check,record_gate_result,record_criterion_result,list_gate_results,create_repair_task,summarize_verification",
    "status-dashboard": "show_run_status,show_task_graph,show_verification_matrix,show_pending_approvals",
    "context-graph": "blast_radius,file_deps,symbol_search,symbol_refs,repo_overview",
    "code-intel": "diagnostics,typecheck,find_references,goto_definition,symbols",
    "docs": "get_library_docs,list_supported_registries",
}
environment = {**os.environ, "CWD": project}
environment.setdefault("LAZYKIMI_MCP_MODE", "orchestrated")
total = 0
for server, csv in expected.items():
    request = json.dumps({"jsonrpc": "2.0", "id": 1, "method": "tools/list"}) + "\n"
    completed = subprocess.run(
        ["bash", os.path.join(plugin, "mcp", server, "server.sh")],
        input=request, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        cwd=project, env=environment, timeout=20, check=False,
    )
    if completed.returncode != 0:
        raise SystemExit(f"{server}: exited {completed.returncode}: {completed.stderr.strip()}")
    try:
        response = json.loads(completed.stdout.splitlines()[0])
        names = [tool["name"] for tool in response["result"]["tools"]]
    except Exception as error:
        raise SystemExit(f"{server}: unparsable tools/list: {error}: {completed.stdout[:200]}")
    want = csv.split(",")
    if names != want:
        raise SystemExit(f"{server}: tool surface mismatch: got {names}, expected {want}")
    total += len(names)
if total != 32:
    raise SystemExit(f"expected 32 tools across 6 servers, counted {total}")
print(f"tool surface: 6 servers, {total} tools, exact family sets")
PYEOF

echo "v001 mcp-config regression: PASS"
