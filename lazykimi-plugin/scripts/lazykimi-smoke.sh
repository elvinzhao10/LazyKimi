#!/usr/bin/env bash
# lazykimi-smoke.sh — End-to-end smoke test
#
# Creates a temp project dir, runs `lazykimi init`, verifies the expected
# files/dirs are created, runs `lazykimi doctor` (must PASS) and `lazykimi
# load-check` (must report 17/17, 11/11, 8/8, 6/6), then cleans up.
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/lazykimi-smoke.XXXXXX")"

cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

CLI="$PLUGIN_ROOT/dist/index.js"
if [ ! -f "$CLI" ]; then
  (cd "$PLUGIN_ROOT" && npm run build >"$TMP/build.log" 2>&1) \
    || { cat "$TMP/build.log" >&2; fail "build failed"; }
fi
[ -f "$CLI" ] || fail "dist/index.js missing after build"

echo "=== LazyKimi Smoke Test ==="

# 1. init into a temp project (HOME isolated so ~/.kimi-code/config.toml is untouched).
HOME="$TMP" node "$CLI" init --target "$TMP" >"$TMP/init.out" 2>&1 \
  || { cat "$TMP/init.out" >&2; fail "init failed"; }

[ -d "$TMP/.kimi-code/skills" ] || fail ".kimi-code/skills/ not created"
[ -f "$TMP/.kimi-code/AGENTS.md" ] || fail ".kimi-code/AGENTS.md not created"
[ -f "$TMP/.kimi-code/mcp.json" ] || fail ".kimi-code/mcp.json not created"
[ -d "$TMP/.lazykimi" ] || fail ".lazykimi/ not created"
echo "  [PASS] init creates .kimi-code/ and .lazykimi/"

# 2. doctor must PASS (exit 0) in the fresh project.
( cd "$TMP" && HOME="$TMP" node "$CLI" doctor ) >"$TMP/doctor.out" 2>&1 \
  || { cat "$TMP/doctor.out" >&2; fail "doctor did not pass"; }
grep -q 'PASS' "$TMP/doctor.out" || fail "doctor reported no PASS check"
echo "  [PASS] doctor passes in fresh project"

# 3. load-check reports the expected package readiness counts.
node "$CLI" load-check >"$TMP/load.out" 2>&1 \
  || { cat "$TMP/load.out" >&2; fail "load-check failed"; }
grep -q '17/17 skills' "$TMP/load.out" || fail "load-check: 17/17 skills missing"
grep -q '11/11 agents' "$TMP/load.out" || fail "load-check: 11/11 agents missing"
grep -q '8/8 hooks' "$TMP/load.out" || fail "load-check: 8/8 hooks missing"
grep -q '6/6 MCP' "$TMP/load.out" || fail "load-check: 6/6 MCP missing"
echo "  [PASS] load-check reports 17/17, 11/11, 8/8, 6/6"

echo ""
echo "Smoke test: ALL PASS"
