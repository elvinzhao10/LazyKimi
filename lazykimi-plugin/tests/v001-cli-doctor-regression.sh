#!/usr/bin/env bash
# v001-cli-doctor-regression.sh
# Verify `lazykimi doctor` runs (exit 0 or 1, not crash) in a fresh init target,
# and `lazykimi load-check` reports 17/17, 11/11, 8/8, 6/6.
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/lazykimi-cli-doctor.XXXXXX")"

cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

CLI="$PLUGIN_ROOT/dist/index.js"
if [ ! -f "$CLI" ]; then
  (cd "$PLUGIN_ROOT" && npm run build >"$TMP/build.log" 2>&1) \
    || { cat "$TMP/build.log" >&2; fail "build failed"; }
fi
[ -f "$CLI" ] || fail "dist/index.js missing after build"

# 1. init into a temp project (HOME isolated so ~/.kimi-code/config.toml is untouched).
HOME="$TMP" node "$CLI" init --target "$TMP" >"$TMP/init.out" 2>&1 \
  || { cat "$TMP/init.out" >&2; fail "init failed"; }
[ -d "$TMP/.kimi-code" ] || fail ".kimi-code not created"
[ -d "$TMP/.kimi-code/skills" ] || fail ".kimi-code/skills not created"
[ -f "$TMP/.kimi-code/AGENTS.md" ] || fail ".kimi-code/AGENTS.md not created"
[ -f "$TMP/.kimi-code/mcp.json" ] || fail ".kimi-code/mcp.json not created"
[ -d "$TMP/.lazykimi" ] || fail ".lazykimi not created"

# 2. doctor must run without crashing (exit 0 or 1 acceptable).
rc=0
( cd "$TMP" && HOME="$TMP" node "$CLI" doctor ) >"$TMP/doctor.out" 2>&1 || rc=$?
[ "$rc" -eq 0 ] || [ "$rc" -eq 1 ] \
  || { cat "$TMP/doctor.out" >&2; fail "doctor crashed with exit $rc"; }
grep -q 'LazyKimi Doctor' "$TMP/doctor.out" || fail "doctor did not print header"

# 3. load-check reports the expected package readiness counts.
node "$CLI" load-check >"$TMP/load.out" 2>&1 \
  || { cat "$TMP/load.out" >&2; fail "load-check failed"; }
grep -q '17/17 skills' "$TMP/load.out" || fail "load-check: 17/17 skills missing"
grep -q '11/11 agents' "$TMP/load.out" || fail "load-check: 11/11 agents missing"
grep -q '8/8 hooks' "$TMP/load.out" || fail "load-check: 8/8 hooks missing"
grep -q '6/6 MCP' "$TMP/load.out" || fail "load-check: 6/6 MCP missing"

echo "v001 cli-doctor regression: PASS"
