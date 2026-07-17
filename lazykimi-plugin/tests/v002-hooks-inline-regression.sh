#!/usr/bin/env bash
set -euo pipefail

# Regression v002: Verify plugin hooks are inlined in kimi.plugin.json (no hooks-config.toml).

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="${PLUGIN_ROOT}/kimi.plugin.json"
HOOKS_TOML="${PLUGIN_ROOT}/hooks/hooks-config.toml"

fail() { echo "FAIL: $1" >&2; exit 1; }

# 1. hooks-config.toml does NOT exist
[[ ! -f "${HOOKS_TOML}" ]] || fail "hooks-config.toml still exists (should be deleted, hooks inlined in manifest)"

# 2. Manifest has inline hooks array
node -e "
const m = require('${MANIFEST}');
if (!Array.isArray(m.hooks) || m.hooks.length === 0) { console.error('no inline hooks array in manifest'); process.exit(1); }
" || fail "manifest has no inline hooks array"

# 3. Manifest has 16 hooks (8 original + 8 new advisory)
node -e "
const m = require('${MANIFEST}');
if (m.hooks.length !== 16) { console.error('expected 16 hooks, got ' + m.hooks.length); process.exit(1); }
" || fail "manifest should have 16 hooks (8 original + 8 advisory)"

# 4. Each hook has event, command, timeout
node -e "
const m = require('${MANIFEST}');
for (const h of m.hooks) {
  if (!h.event) { console.error('hook missing event: ' + JSON.stringify(h)); process.exit(1); }
  if (!h.command) { console.error('hook missing command: ' + JSON.stringify(h)); process.exit(1); }
  if (typeof h.timeout !== 'number') { console.error('hook missing timeout: ' + JSON.stringify(h)); process.exit(1); }
}
" || fail "some hook missing event/command/timeout"

# 5. Hook commands use ./hooks/ prefix
node -e "
const m = require('${MANIFEST}');
for (const h of m.hooks) {
  if (!h.command.includes('./hooks/')) { console.error('hook command does not use ./hooks/ prefix: ' + h.command); process.exit(1); }
}
" || fail "some hook command does not use ./hooks/ prefix"

# 6. 16 hook scripts exist
count=$(ls "${PLUGIN_ROOT}/hooks/"*.sh 2>/dev/null | wc -l)
[[ ${count} -eq 16 ]] || fail "expected 16 hook scripts, got ${count}"

# 7. All hook scripts pass bash -n
for f in "${PLUGIN_ROOT}/hooks/"*.sh; do
  bash -n "$f" || fail "syntax error in $f"
done

echo "PASS: v002-hooks-inline-regression"
exit 0
