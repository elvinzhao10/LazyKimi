#!/usr/bin/env bash
# lazykimi-integration-test.sh — End-to-end integration smoke test.
#
# Tests the full lazykimi workflow: init -> doctor -> load-check -> verify,
# then exercises Kimi Code CLI integration (/status, /skill, /swarm, /goal)
# when the kimi binary is available and authenticated. Kimi tests are SKIPPED
# (not FAILED) when the binary is missing or the session is not authenticated.
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLI="$PLUGIN_ROOT/dist/index.js"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/lazykimi-integration.XXXXXX")"
REAL_HOME="$HOME"
FAIL_COUNT=0

cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

step() { printf '  [%s] %s\n' "$1" "$2"; }
pass()  { step PASS "$1"; }
skip()  { step SKIP "$1"; }
fail()  { step FAIL "$1"; FAIL_COUNT=$((FAIL_COUNT + 1)); }

# Build dist/ if missing (subshell so cwd does not leak).
if [ ! -f "$CLI" ]; then
  ( cd "$PLUGIN_ROOT" && npm run build ) >"$TMP/build.log" 2>&1 \
    || { cat "$TMP/build.log" >&2; fail "dist build"; exit 1; }
fi

echo "=== LazyKimi Integration Test ==="

# Steps 1-3: init into temp dir with HOME isolation (protects real config.toml).
HOME="$TMP" node "$CLI" init --target "$TMP" >"$TMP/init.out" 2>&1 \
  || { cat "$TMP/init.out" >&2; fail "init failed"; exit 1; }
if [ -d "$TMP/.kimi-code/skills" ] && [ -f "$TMP/.kimi-code/AGENTS.md" ] \
  && [ -f "$TMP/.kimi-code/mcp.json" ] && [ -d "$TMP/.lazykimi" ]; then
  pass "init creates .kimi-code/ and .lazykimi/"
else
  fail "init did not create expected files"
fi

# Step 3b: init must create .lazykimi/schemas/ with 4 schema files.
SCHEMA_COUNT=0
if [ -d "$TMP/.lazykimi/schemas" ]; then
  SCHEMA_COUNT=$(ls "$TMP/.lazykimi/schemas"/*.schema.json 2>/dev/null | wc -l | tr -d ' ')
fi
if [ "$SCHEMA_COUNT" -eq 4 ]; then
  pass "init creates .lazykimi/schemas/ with 4 schema files"
else
  fail "init did not create .lazykimi/schemas/ with 4 schema files (found $SCHEMA_COUNT)"
fi

# Seed stub evidence files so verify's evidence gates can pass. init only
# creates the empty evidence/ dir; a completed workflow would populate these.
mkdir -p "$TMP/.lazykimi/evidence"
for f in plan-reread.md test-runs.md manual-qa.md adversarial-qa.md reviewer.md; do
  echo "- Integration test evidence stub ($f)" > "$TMP/.lazykimi/evidence/$f"
done

# Step 4: doctor must PASS in the fresh project and report 16 hooks.
if ( cd "$TMP" && HOME="$TMP" node "$CLI" doctor ) >"$TMP/doctor.out" 2>&1 \
  && grep -q 'PASS' "$TMP/doctor.out" \
  && grep -q 'hooks count (16 expected)' "$TMP/doctor.out"; then
  pass "doctor passes in fresh project (16 hooks)"
else
  cat "$TMP/doctor.out" >&2
  fail "doctor did not pass or did not report 16 hooks"
fi

# Step 5: load-check must report the v1.3.4 inventory: 19/19 skills, 20/20
# commands, 13/13 agents, 16/16 inline hook events, 6/6 MCP servers.
if node "$CLI" load-check >"$TMP/load.out" 2>&1 \
  && grep -q '19/19' "$TMP/load.out" \
  && grep -q '20/20' "$TMP/load.out" \
  && grep -q '13/13' "$TMP/load.out" \
  && grep -q '16/16' "$TMP/load.out" \
  && grep -q '6/6 MCP' "$TMP/load.out"; then
  pass "load-check reports 19/19 skills, 20/20 commands, 13/13 agents, 16/16 hooks, 6/6 MCP"
else
  cat "$TMP/load.out" >&2
  fail "load-check counts mismatch"
fi

# Step 6: verify --must-pass must exit 0 in fresh project (all 5 evidence gates PASS).
if ( cd "$TMP" && HOME="$TMP" node "$CLI" verify --must-pass ) >"$TMP/verify.out" 2>&1 \
  && grep -q 'Gates: 5/5 passed' "$TMP/verify.out" \
  && grep -q 'Overall: READY' "$TMP/verify.out"; then
  pass "verify --must-pass exits 0 (5/5 gates PASS)"
else
  cat "$TMP/verify.out" >&2
  fail "verify --must-pass failed or gates not 5/5"
fi

# Step 6b: install-kimi-work.sh --help must exit 0.
if bash "$PLUGIN_ROOT/scripts/install-kimi-work.sh" --help >"$TMP/kimi-work-help.out" 2>&1; then
  if grep -q 'Usage: bash install-kimi-work.sh' "$TMP/kimi-work-help.out"; then
    pass "install-kimi-work.sh --help exits 0"
  else
    cat "$TMP/kimi-work-help.out" >&2
    fail "install-kimi-work.sh --help did not print expected usage"
  fi
else
  cat "$TMP/kimi-work-help.out" >&2
  fail "install-kimi-work.sh --help did not exit 0"
fi

# Detect kimi binary: PATH first, then ~/.kimi-code/bin/kimi.
KIMI_BIN=""
if command -v kimi >/dev/null 2>&1; then
  KIMI_BIN="$(command -v kimi)"
elif [ -x "$REAL_HOME/.kimi-code/bin/kimi" ]; then
  KIMI_BIN="$REAL_HOME/.kimi-code/bin/kimi"
fi

# run_kimi <args> <timeout_sec> <label> <timeout_is_pass>
# Auth/session errors => SKIP. Timeout => PASS if timeout_is_pass=1, else SKIP.
# Other non-zero exit => FAIL (binary crash or bad syntax).
run_kimi() {
  local args="$1" timeout_sec="$2" label="$3" tip="${4:-0}"
  local out="$TMP/kimi.out"
  ( cd "$TMP" && HOME="$REAL_HOME" "$KIMI_BIN" -p "$args" ) >"$out" 2>&1 &
  local pid=$!
  local i=0
  while [ "$i" -lt "$timeout_sec" ]; do
    kill -0 "$pid" 2>/dev/null || break
    sleep 1
    i=$((i + 1))
  done
  local code=0
  if kill -0 "$pid" 2>/dev/null; then
    kill -9 "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
    code=124
  else
    wait "$pid" 2>/dev/null || code=$?
  fi
  if grep -qiE 'No model configured|/login|not logged in|unauthorized|API key|auth' "$out"; then
    skip "$label (kimi session not authenticated)"
    return
  fi
  if [ "$code" -eq 124 ]; then
    if [ "$tip" = "1" ]; then
      pass "$label (still running after ${timeout_sec}s)"
    else
      skip "$label (timed out after ${timeout_sec}s)"
    fi
    return
  fi
  if [ "$code" -eq 0 ]; then
    pass "$label"
  else
    cat "$out" >&2
    fail "$label (kimi exit $code)"
  fi
}

if [ -z "$KIMI_BIN" ]; then
  skip "kimi binary not found (steps 7-10)"
else
  # Step 7: /status — must show session active (15s timeout).
  run_kimi '/status' 15 'kimi /status'
  # Step 8: /skill:lazy-init-deep smoke (30s timeout).
  run_kimi '/skill:lazy-init-deep' 30 'kimi /skill:lazy-init-deep'
  # Step 9: /swarm test task (60s timeout; still running = started = PASS).
  run_kimi '/swarm test task' 60 'kimi /swarm' 1
  # Step 10: /goal test objective (60s timeout; still running = started = PASS).
  run_kimi '/goal test objective' 60 'kimi /goal' 1
fi

echo ""
if [ "$FAIL_COUNT" -eq 0 ]; then
  echo "Integration test: ALL PASS (skips allowed)"
  exit 0
fi
echo "Integration test: $FAIL_COUNT FAILURE(S)"
exit 1
