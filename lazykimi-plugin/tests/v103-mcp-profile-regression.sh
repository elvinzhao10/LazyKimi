#!/usr/bin/env bash
# v103-mcp-profile-regression.sh — MCP profile gate (v1.3.3 port).
# Modes direct/assisted/planned/orchestrated/long-horizon; unset mode defaults
# to orchestrated (all six servers active); deferred servers exit 0 quietly
# via deferred-server.py; invalid mode fails closed with stderr + exit 2;
# init --mcp-mode persists the mode and injects the LAZYKIMI_MCP_MODE env
# stanza into every project mcp.json server entry (idempotent re-rewrite).
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_INDEX="${PLUGIN_ROOT}/dist/index.js"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/lazykimi-mcp-profile.XXXXXX")"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

if [ ! -f "${DIST_INDEX}" ]; then
  (cd "${PLUGIN_ROOT}" && npm run build >/dev/null 2>&1) || fail "build failed"
fi

echo "=== v103 mcp-profile regression ==="

# 1. Profile-gate mode table: selected servers per mode.
expect_servers() {
  local mode="$1" want="$2"
  local got
  got=$(LAZYKIMI_MCP_MODE="$mode" bash -c '
    source "$1/mcp/profile-gate.sh"
    picked=""
    for s in run-ledger verification status-dashboard context-graph code-intel docs; do
      if lazykimi_require_mcp_profile "$s" 2>/dev/null; then picked="$picked $s"; fi
    done
    printf "%s" "${picked# }"
  ' _ "$PLUGIN_ROOT")
  [ "$got" = "$want" ] || fail "mode $mode selected '$got', expected '$want'"
  echo "  [PASS] mode $mode -> ${want}"
}
expect_servers direct "run-ledger verification status-dashboard"
expect_servers assisted "run-ledger verification status-dashboard context-graph code-intel"
expect_servers planned "run-ledger verification status-dashboard context-graph docs"
expect_servers orchestrated "run-ledger verification status-dashboard context-graph code-intel docs"
expect_servers long-horizon "run-ledger verification status-dashboard context-graph code-intel docs"

# 2. Unset mode defaults to orchestrated (all six active out of the box).
GOT=$(bash -c '
  source "$1/mcp/profile-gate.sh"
  lazykimi_require_mcp_profile docs 2>/dev/null && echo active
' _ "$PLUGIN_ROOT")
[ "$GOT" = "active" ] || fail "unset mode must default to orchestrated (docs active)"
echo "  [PASS] unset mode defaults to orchestrated"

# 3. Deferred servers exit 0 quietly via deferred-server.py.
mkdir -p "$TMP/project"
OUT=$(LAZYKIMI_MCP_MODE=direct CWD="$TMP/project" bash "$PLUGIN_ROOT/mcp/context-graph/server.sh" </dev/null 2>"$TMP/defer.err"); RC=$?
[ "$RC" -eq 0 ] || fail "deferred server must exit 0, got $RC (stderr: $(cat "$TMP/defer.err"))"
[ -z "$OUT" ] || fail "deferred server must stay silent on stdin EOF, got: $OUT"
printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' \
  | LAZYKIMI_MCP_MODE=direct CWD="$TMP/project" bash "$PLUGIN_ROOT/mcp/context-graph/server.sh" 2>/dev/null \
  | grep -q '"tools":\[\]' || fail "deferred server must answer tools/list with an empty list"
echo "  [PASS] direct mode defers context-graph quietly (empty tool list)"

# 4. Invalid mode fails closed: stderr marker + exit 2.
RC=0
OUT=$(LAZYKIMI_MCP_MODE=bogus CWD="$TMP/project" bash "$PLUGIN_ROOT/mcp/run-ledger/server.sh" </dev/null 2>"$TMP/invalid.err") || RC=$?
[ "$RC" -eq 2 ] || fail "invalid mode must exit 2, got $RC"
grep -q 'MCP_PROFILE_INVALID' "$TMP/invalid.err" || fail "invalid mode must print MCP_PROFILE_INVALID to stderr"
[ -z "$OUT" ] || fail "invalid mode must not answer on stdout"
echo "  [PASS] invalid mode fails closed (exit 2 + stderr)"

# 5. init --mcp-mode persists the mode and injects the env stanza (6 entries).
HOME="$TMP" node "$DIST_INDEX" init --target "$TMP/project" --mcp-mode direct >/dev/null 2>&1 \
  || fail "init --mcp-mode direct failed"
MODE_COUNT=$(python3 -c "
import json
d = json.load(open('$TMP/project/.kimi-code/mcp.json'))
count = sum(1 for s in d['mcpServers'].values() if s.get('env', {}).get('LAZYKIMI_MCP_MODE') == 'direct')
print(len(d['mcpServers']), count)
")
[ "$MODE_COUNT" = "6 6" ] || fail "expected 6 servers each carrying LAZYKIMI_MCP_MODE=direct, got: $MODE_COUNT"
python3 -c "
import json
d = json.load(open('$TMP/project/.lazykimi/config.json'))
assert d.get('mcpMode') == 'direct', d
" || fail ".lazykimi/config.json must record mcpMode=direct"
echo "  [PASS] init --mcp-mode direct: env stanza in 6/6 entries + config.json record"

# 6. Re-init with a new mode rewrites exactly (no duplicate keys, all updated).
HOME="$TMP" node "$DIST_INDEX" init --target "$TMP/project" --mcp-mode orchestrated >/dev/null 2>&1 \
  || fail "init --mcp-mode orchestrated failed"
python3 - "$TMP/project/.kimi-code/mcp.json" <<'PYEOF'
import json, sys
raw = open(sys.argv[1]).read()
d = json.loads(raw)  # JSON object keys are per-object; duplicates would collapse silently,
                     # so also assert the raw text carries no repeated env blocks per server.
assert raw.count('"LAZYKIMI_MCP_MODE": "orchestrated"') == 6, raw.count('"LAZYKIMI_MCP_MODE": "orchestrated"')
assert '"__KIMI_MCP_MODE__"' not in raw and '"__KIMI_PLUGIN_ROOT__"' not in raw and '"__KIMI_PROJECT_ROOT__"' not in raw
for server in d["mcpServers"].values():
    assert server["env"]["LAZYKIMI_MCP_MODE"] == "orchestrated", server
    assert server["env"]["CWD"].startswith("/"), server
PYEOF
echo "  [PASS] re-init with orchestrated rewrites all 6 stanzas (no placeholders, no duplicates)"

# 7. The direct-mode project env stanza actually defers the python servers.
HOME="$TMP" node "$DIST_INDEX" init --target "$TMP/project" --mcp-mode direct >/dev/null 2>&1 \
  || fail "re-init --mcp-mode direct failed"
python3 - "$TMP/project" "$PLUGIN_ROOT" <<'PYEOF'
import json, os, subprocess, sys
project, plugin = sys.argv[1:]
mcp = json.load(open(f"{project}/.kimi-code/mcp.json"))
env = mcp["mcpServers"]["lazykimi-context-graph"]["env"]
request = json.dumps({"jsonrpc": "2.0", "id": 1, "method": "tools/list"}) + "\n"
completed = subprocess.run(
    ["bash", f"{plugin}/mcp/context-graph/server.sh"],
    input=request, text=True, capture_output=True, env={**os.environ, **env}, timeout=10, check=False,
)
assert completed.returncode == 0, (completed.returncode, completed.stderr)
assert '"tools":[]' in completed.stdout.replace(" ", ""), completed.stdout
print("  [PASS] project env stanza (direct) defers context-graph through server.sh")
PYEOF

# 8. Declaration validation: profile.py --validate-commands passes on the template.
bash -c '. "$1/scripts/lazykimi-python-resolver.sh" && "$LAZYKIMI_PYTHON_RESOLVED" "$1/scripts/lazykimi-mcp-profile.py" --validate-commands' _ "$PLUGIN_ROOT" \
  || fail "--validate-commands must pass on the shipped template"
echo "  [PASS] mcp-profile.py --validate-commands"

# 9. The shipped template is untouched (placeholders intact, no env leakage).
grep -q '__KIMI_MCP_MODE__' "$PLUGIN_ROOT/.kimi-code/mcp.json" || fail "shipped template must keep __KIMI_MCP_MODE__ placeholders"
echo "  [PASS] shipped template keeps placeholders"

echo ""
echo "v103 mcp-profile regression: PASS"
