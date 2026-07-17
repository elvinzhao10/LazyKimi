#!/usr/bin/env bash
# v001-mcp-config-regression.sh
# Verify .kimi-code/mcp.json is valid JSON with 6 servers, all required:false.
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

echo "v001 mcp-config regression: PASS"
