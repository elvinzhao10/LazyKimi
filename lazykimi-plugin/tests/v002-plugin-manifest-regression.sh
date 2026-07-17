#!/usr/bin/env bash
set -euo pipefail

# Regression v002: Verify kimi.plugin.json at plugin root has correct Kimi spec schema.

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="${PLUGIN_ROOT}/kimi.plugin.json"

fail() { echo "FAIL: $1" >&2; exit 1; }

# 1. Manifest exists at plugin root
[[ -f "${MANIFEST}" ]] || fail "kimi.plugin.json not found at plugin root"

# 2. Valid JSON
node -e "JSON.parse(require('fs').readFileSync('${MANIFEST}','utf8'))" || fail "manifest is not valid JSON"

# 3. Required fields
node -e "
const m = require('${MANIFEST}');
const required = ['name', 'version', 'description', 'author', 'interface', 'skills', 'mcpServers', 'hooks', 'commands'];
for (const f of required) {
  if (!(f in m)) { console.error('missing field: ' + f); process.exit(1); }
}
if (!m.interface.displayName) { console.error('missing interface.displayName'); process.exit(1); }
" || fail "manifest missing required fields"

# 4. Name matches regex ^[a-z0-9][a-z0-9_-]{0,63}$
node -e "
const m = require('${MANIFEST}');
if (!/^[a-z0-9][a-z0-9_-]{0,63}\$/.test(m.name)) { console.error('bad name: ' + m.name); process.exit(1); }
" || fail "manifest name does not match regex"

# 5. No publisher field (should be author)
node -e "
const m = require('${MANIFEST}');
if ('publisher' in m) { console.error('publisher field present, should be author'); process.exit(1); }
" || fail "manifest has publisher field (should be author)"

# 6. No \${KIMI_PLUGIN_ROOT} interpolation in manifest
if grep -q '\${KIMI_PLUGIN_ROOT}' "${MANIFEST}"; then
  fail "manifest contains \${KIMI_PLUGIN_ROOT} interpolation"
fi

# 7. hooks is an array with >= 8 entries
node -e "
const m = require('${MANIFEST}');
if (!Array.isArray(m.hooks) || m.hooks.length < 8) { console.error('hooks array too small: ' + m.hooks.length); process.exit(1); }
" || fail "manifest hooks array has fewer than 8 entries"

# 8. Old manifest location absent
[[ ! -f "${PLUGIN_ROOT}/.kimi-code/plugin.json" ]] || fail "old .kimi-code/plugin.json still exists"

echo "PASS: v002-plugin-manifest-regression"
exit 0
