#!/usr/bin/env bash
set -euo pipefail

# Regression v002: Verify .kimi-code/mcp.json has no \${KIMI_PLUGIN_ROOT} and has 6 servers.

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MCP_JSON="${PLUGIN_ROOT}/.kimi-code/mcp.json"

fail() { echo "FAIL: $1" >&2; exit 1; }

# 1. mcp.json exists
[[ -f "${MCP_JSON}" ]] || fail ".kimi-code/mcp.json not found"

# 2. Valid JSON
node -e "JSON.parse(require('fs').readFileSync('${MCP_JSON}','utf8'))" || fail "mcp.json is not valid JSON"

# 3. No \${KIMI_PLUGIN_ROOT} interpolation
if grep -q '\${KIMI_PLUGIN_ROOT}' "${MCP_JSON}"; then
  fail "mcp.json contains \${KIMI_PLUGIN_ROOT} interpolation (not supported by Kimi)"
fi

# 4. Uses __KIMI_PLUGIN_ROOT__ placeholder (rewritten by lazykimi init)
if ! grep -q '__KIMI_PLUGIN_ROOT__' "${MCP_JSON}"; then
  fail "mcp.json should contain __KIMI_PLUGIN_ROOT__ placeholder (rewritten by lazykimi init)"
fi

# 5. 6 servers present
node -e "
const m = require('${MCP_JSON}');
const servers = Object.keys(m.mcpServers || {});
if (servers.length !== 6) { console.error('expected 6 servers, got ' + servers.length); process.exit(1); }
const expected = ['lazykimi-run-ledger', 'lazykimi-verification', 'lazykimi-status-dashboard', 'lazykimi-context-graph', 'lazykimi-code-intel', 'lazykimi-docs'];
for (const s of expected) {
  if (!servers.includes(s)) { console.error('missing server: ' + s); process.exit(1); }
}
" || fail "mcp.json does not have 6 expected servers"

# 6. Each server has command and args
node -e "
const m = require('${MCP_JSON}');
for (const [name, server] of Object.entries(m.mcpServers)) {
  if (!server.command) { console.error(name + ': missing command'); process.exit(1); }
  if (!Array.isArray(server.args)) { console.error(name + ': missing args array'); process.exit(1); }
}
" || fail "some server missing command or args"

echo "PASS: v002-mcp-paths-regression"
exit 0
