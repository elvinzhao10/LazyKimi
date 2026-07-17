#!/usr/bin/env bash
# lazykimi-verify.sh — Master verification runner
#
# Runs the smoke gate plus the 10 v001 regression scripts and emits a bounded
# JSON summary. Exit 0 only when ALL_PASS is true; exit 1 otherwise.
#
# Usage: bash scripts/lazykimi-verify.sh
# Works from lazykimi-plugin/ (it cds into the plugin root).
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TESTS_DIR="$PLUGIN_ROOT/tests"
SCRIPTS_DIR="$PLUGIN_ROOT/scripts"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/lazykimi-verify.XXXXXX")"

cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

cd "$PLUGIN_ROOT"

# Parallel arrays: check name -> regression script (bash 3.2 compatible).
CHECK_NAMES=(
  "package_boundary"
  "skill_count"
  "agent_count"
  "hook_syntax"
  "mcp_config"
  "tooling_contract"
  "security"
  "cli_build"
  "cli_doctor"
  "ssrf"
)
CHECK_SCRIPTS=(
  "v001-package-boundary-regression.sh"
  "v001-skill-count-regression.sh"
  "v001-agent-count-regression.sh"
  "v001-hook-syntax-regression.sh"
  "v001-mcp-config-regression.sh"
  "v001-tooling-contract-regression.sh"
  "v001-security-regression.sh"
  "v001-cli-build-regression.sh"
  "v001-cli-doctor-regression.sh"
  "v001-ssrf-regression.sh"
)

run_one() {
  local name="$1" script="$2" path="$TESTS_DIR/$script"
  if [ ! -f "$path" ]; then
    echo "SKIP $name (missing $script)" >&2
    printf 'SKIP'
    return
  fi
  if bash "$path" >"$TMP/$name.log" 2>&1; then
    echo "PASS $name" >&2
    printf 'PASS'
  else
    echo "FAIL $name" >&2
    tail -n 15 "$TMP/$name.log" >&2
    printf 'FAIL'
  fi
}

echo "=== LazyKimi Verify ===" >&2

# 1. Smoke gate (init + doctor + load-check in a temp project).
SMOKE_RESULT="SKIP"
if [ -f "$SCRIPTS_DIR/lazykimi-smoke.sh" ]; then
  if bash "$SCRIPTS_DIR/lazykimi-smoke.sh" >"$TMP/smoke.log" 2>&1; then
    SMOKE_RESULT="PASS"
    echo "PASS smoke" >&2
  else
    SMOKE_RESULT="FAIL"
    echo "FAIL smoke" >&2
    tail -n 15 "$TMP/smoke.log" >&2
  fi
fi

# 2. Run each regression script and collect PASS/FAIL/SKIP.
RESULTS=()
for i in "${!CHECK_NAMES[@]}"; do
  name="${CHECK_NAMES[$i]}"
  script="${CHECK_SCRIPTS[$i]}"
  result="$(run_one "$name" "$script")"
  RESULTS+=("$result")
done

# 3. Write name<TAB>result pairs for the JSON assembler.
RESULTS_FILE="$TMP/results.tsv"
: >"$RESULTS_FILE"
for i in "${!CHECK_NAMES[@]}"; do
  printf '%s\t%s\n' "${CHECK_NAMES[$i]}" "${RESULTS[$i]}" >>"$RESULTS_FILE"
done

# 4. Emit bounded JSON summary.
python3 - "$RESULTS_FILE" "$SMOKE_RESULT" <<'PYEOF'
import json, sys
from datetime import datetime, timezone
results_file, smoke = sys.argv[1], sys.argv[2]
checks = {}
with open(results_file, encoding="utf-8") as f:
    for line in f:
        line = line.rstrip("\n")
        if not line:
            continue
        name, result = line.split("\t", 1)
        checks[name] = result
failed = sum(1 for v in checks.values() if v != "PASS")
if smoke != "PASS":
    failed += 1
all_pass = failed == 0 and all(v == "PASS" for v in checks.values()) and smoke == "PASS"
out = {
    "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "checks": checks,
    "smoke": smoke,
    "all_pass": all_pass,
    "failed_count": failed,
}
print(json.dumps(out, indent=2))
PYEOF

[ "$SMOKE_RESULT" = "PASS" ] || exit 1
for r in "${RESULTS[@]}"; do
  [ "$r" = "PASS" ] || exit 1
done
exit 0
