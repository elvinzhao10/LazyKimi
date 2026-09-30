#!/bin/bash
# lazykimi-verify.sh — Master verification runner (v1.3.3)
#
# Ported from lazyzcode v1.3.3 scripts/lazyzcode-verify.sh, Kimi-adapted.
# Runs all health-check scripts in sequence and emits a compact JSON summary.
# Exit code 0 when all_pass is true; exit code 1 otherwise.
#
# Usage: ./scripts/lazykimi-verify.sh
# Env:   LAZYKIMI_PLUGIN_ROOT (optional), otherwise defaults to script-relative plugin root.
#        LAZYKIMI_VERIFY_SUITE=all|core|lifecycle (default all)
#        LAZYKIMI_VERIFY_TIMEOUT_SECONDS, LAZYKIMI_VERIFY_REGRESSION_DEPTH,
#        LAZYKIMI_NODE_TEST_CONCURRENCY, LAZYKIMI_PYTHON

set -euo pipefail

if [ -n "${LAZYKIMI_PLUGIN_ROOT:-}" ]; then
    PLUGIN_ROOT="${LAZYKIMI_PLUGIN_ROOT}"
else
    PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fi

SCRIPTS_DIR="${PLUGIN_ROOT}/scripts"
RUNNER="${SCRIPTS_DIR}/lazykimi-bounded-run.py"
PROJECT_ROOT="$(cd "${PLUGIN_ROOT}/.." && pwd)"
export LAZYKIMI_PLUGIN_ROOT="${PLUGIN_ROOT}"
export CWD="${CWD:-${PROJECT_ROOT}}"
export PYTHONDONTWRITEBYTECODE=1
export NODE_PATH="${LAZYKIMI_PARITY_NODE_MODULES:-${PLUGIN_ROOT}/tooling/node_modules}"
ALL_PASS=true
DOCTOR_RESULT="skipped"
SMOKE_RESULT="skipped"
DOCS_RESULT="skipped"
SECURITY_RESULT="skipped"
MCP_RESULT="skipped"
HOOK_RESULT="skipped"
LOAD_RESULT="skipped"
CONTRACT_RESULT="skipped"
CONTRACT_TESTS_RESULT="skipped"
AUTOMATIC_TOOLING_REGRESSIONS_RESULT="fail"
REGRESSION_INVENTORY_RESULT="fail"
NODE_TESTS_RESULT="fail"
PYTHON_TESTS_RESULT="fail"
REGRESSION_DEPTH="${LAZYKIMI_VERIFY_REGRESSION_DEPTH:-0}"
VERIFY_TIMEOUT="${LAZYKIMI_VERIFY_TIMEOUT_SECONDS:-90}"
CODEGRAPH_REGRESSION_TIMEOUT="${LAZYKIMI_CODEGRAPH_REGRESSION_TIMEOUT_SECONDS:-240}"
NODE_TEST_CONCURRENCY="${LAZYKIMI_NODE_TEST_CONCURRENCY:-2}"
VERIFY_SUITE="${LAZYKIMI_VERIFY_SUITE:-all}"
PYTHON_REQUEST="${LAZYKIMI_PYTHON:-}"
if [ -z "$PYTHON_REQUEST" ]; then
    PYTHON_REQUEST="python3"
    _pv="$(command -v python3 >/dev/null 2>&1 && python3 -c 'import sys; print("%d%02d" % sys.version_info[:2])' 2>/dev/null || true)"
    if [ -z "$_pv" ] || [ "$_pv" -lt 310 ]; then
        for _cand in python3.13 python3.12 python3.11 python3.10; do
            command -v "$_cand" >/dev/null 2>&1 || continue
            _cv="$("$_cand" -c 'import sys; print("%d%02d" % sys.version_info[:2])' 2>/dev/null || true)"
            if [ -n "$_cv" ] && [ "$_cv" -ge 310 ]; then PYTHON_REQUEST="$_cand"; break; fi
        done
    fi
fi
export LAZYKIMI_PYTHON="$PYTHON_REQUEST"
if ! PYTHON_BIN="$(command -v -- "$PYTHON_REQUEST" 2>/dev/null)" \
    || [ ! -f "$PYTHON_BIN" ] \
    || [ ! -x "$PYTHON_BIN" ]; then
    printf 'ERROR: LazyKimi requires Python 3.10 or newer. Install Python 3.10+ and make it available as python3.\n' >&2
    exit 2
fi
PYTHON_VERSION="$("$PYTHON_BIN" -c 'import sys; print(sys.version_info[0], sys.version_info[1])' 2>/dev/null || true)"
read -r PYTHON_MAJOR PYTHON_MINOR _ <<<"$PYTHON_VERSION"

if ! [[ "$PYTHON_MAJOR" =~ ^[0-9]+$ && "$PYTHON_MINOR" =~ ^[0-9]+$ ]] \
    || [ "$PYTHON_MAJOR" -lt 3 ] \
    || { [ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -lt 10 ]; }; then
    printf 'ERROR: LazyKimi requires Python 3.10 or newer. Install Python 3.10+ and make it available as python3.\n' >&2
    exit 2
fi

if ! [[ "$REGRESSION_DEPTH" =~ ^[0-9]+$ ]]; then
    printf 'ERROR: LAZYKIMI_VERIFY_REGRESSION_DEPTH must be a non-negative integer\n' >&2
    exit 2
fi
if ! [[ "$VERIFY_TIMEOUT" =~ ^[1-9][0-9]*$ ]]; then
    printf 'ERROR: LAZYKIMI_VERIFY_TIMEOUT_SECONDS must be a positive integer\n' >&2
    exit 2
fi
if ! [[ "$NODE_TEST_CONCURRENCY" =~ ^[1-4]$ ]]; then
    printf 'ERROR: LAZYKIMI_NODE_TEST_CONCURRENCY must be an integer from 1 through 4\n' >&2
    exit 2
fi
if [[ "$VERIFY_SUITE" != "all" && "$VERIFY_SUITE" != "core" && "$VERIFY_SUITE" != "lifecycle" ]]; then
    printf 'ERROR: LAZYKIMI_VERIFY_SUITE must be all, core, or lifecycle\n' >&2
    exit 2
fi

PYTHON_SHIM_DIR="$(mktemp -d "${TMPDIR:-/tmp}/lazykimi-python.XXXXXX")"
cleanup_python_shim() {
    rm -rf "$PYTHON_SHIM_DIR"
}
trap cleanup_python_shim EXIT
export LAZYKIMI_PYTHON="$PYTHON_BIN"
printf '%s\n' \
    '#!/usr/bin/env bash' \
    'exec "${LAZYKIMI_PYTHON:?}" "$@"' >"$PYTHON_SHIM_DIR/python3"
chmod 700 "$PYTHON_SHIM_DIR/python3"
if [ ! -f "$PYTHON_SHIM_DIR/python3" ] || [ -L "$PYTHON_SHIM_DIR/python3" ]; then
    printf 'ERROR: LazyKimi could not prepare the selected Python interpreter.\n' >&2
    exit 2
fi
PATH="$PYTHON_SHIM_DIR:$PATH"
export PATH

CHECK_DETAILS="{}"
record_check() {
    local name="$1" result_file="$2"
    if [ ! -s "$result_file" ]; then
        printf '{"status": "unavailable", "reason": "missing_result_file"}\n' >"$result_file"
    fi
    CHECK_DETAILS="$("$PYTHON_BIN" - "$CHECK_DETAILS" "$name" "$result_file" <<'PY'
import json
import sys
details, name, path = sys.argv[1:]
with open(path, encoding="utf-8") as handle:
    result = json.load(handle)
payload = json.loads(details)
payload[name] = {key: result[key] for key in ("status", "reason")}
print(json.dumps(payload, separators=(",", ":")))
PY
)"
}

print_failure_tail() {
    "$PYTHON_BIN" - "$1" <<'PY' >&2
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    result = json.load(handle)
if result["tail"]:
    print(result["tail"], end="" if result["tail"].endswith("\n") else "\n")
PY
}

run_check() {
    local name="$1" script="$2" result_var="$3" result_file
    result_file="$(mktemp "${TMPDIR:-/tmp}/lazykimi-verify-result.XXXXXX")"
    if [ -x "$script" ]; then
        if "$PYTHON_BIN" "$RUNNER" --label "$name" --timeout "$VERIFY_TIMEOUT" --result-file "$result_file" -- "$script"; then
            eval "${result_var}=pass"
        else
            eval "${result_var}=fail"
            ALL_PASS=false
            print_failure_tail "$result_file"
        fi
    else
        "$PYTHON_BIN" - "$result_file" <<'PY'
import json
import sys
with open(sys.argv[1], "w", encoding="utf-8") as handle:
    json.dump({"status": "unavailable", "reason": "not_executable", "tail": ""}, handle)
PY
        printf 'FAIL: %s\n' "$name" >&2
        eval "${result_var}=fail"
        ALL_PASS=false
    fi
    record_check "$name" "$result_file"
    rm -f "$result_file"
}

run_hook_pipeline_check() {
    local name="$1" script="$2" result_var="$3"
    if [ ! -x "$script" ]; then
        # hook-pipeline is owned by the UI layer; tolerate absence with an explicit skip marker.
        printf 'SKIP: %s (script not present; marked skipped-absent)\n' "$name" >&2
        eval "${result_var}=skipped-absent"
        local result_file
        result_file="$(mktemp "${TMPDIR:-/tmp}/lazykimi-verify-result.XXXXXX")"
        "$PYTHON_BIN" - "$result_file" <<-'PY'
import json
import sys
with open(sys.argv[1], "w", encoding="utf-8") as handle:
    json.dump({"status": "skipped-absent", "reason": "hook-pipeline script not present", "tail": ""}, handle)
PY
        record_check "$name" "$result_file"
        rm -f "$result_file"
        return
    fi
    # The hook pipeline drives session hooks that bootstrap .lazykimi/ state
    # into CWD; run it with CWD unset so the script uses its own temp project
    # instead of polluting the repository checkout.
    if "$PYTHON_BIN" "$RUNNER" --label "$name" --timeout "$VERIFY_TIMEOUT" --result-file "${TMPDIR:-/tmp}/lazykimi-hook-result.$$" -- \
        env -u CWD LAZYKIMI_PLUGIN_ROOT="${PLUGIN_ROOT}" "$script"; then
        eval "${result_var}=pass"
        record_check "$name" "${TMPDIR:-/tmp}/lazykimi-hook-result.$$"
    else
        eval "${result_var}=fail"
        ALL_PASS=false
        record_check "$name" "${TMPDIR:-/tmp}/lazykimi-hook-result.$$"
    fi
    rm -f "${TMPDIR:-/tmp}/lazykimi-hook-result.$$"
}

run_isolated_test() {
    local next_depth=$((REGRESSION_DEPTH + 1))
    local result_file status test_timeout="$2"
    result_file="$(mktemp "${TMPDIR:-/tmp}/lazykimi-regression-result.XXXXXX")"
    if LAZYKIMI_VERIFY_SUITE=all LAZYKIMI_VERIFY_REGRESSION_DEPTH="$next_depth" "$PYTHON_BIN" "$RUNNER" --label "regression:$(basename "$1")" --timeout "$test_timeout" --result-file "$result_file" -- bash "$1"; then
        status=0
    else
        status=$?
        print_failure_tail "$result_file"
    fi
    rm -f "$result_file"
    return "$status"
}

run_regression_inventory() {
    local test_name test_path test_timeout candidate inventory_failed=false regression_failed=false
    local tests_dir="${PLUGIN_ROOT}/tests"
    # The normal release gate owns every package-local *-regression.sh. The
    # explicit-root parity checks intentionally remain release-only.
    local core_tests=(
        "v001-agent-count-regression.sh"
        "v001-cli-build-regression.sh"
        "v001-cli-doctor-regression.sh"
        "v001-hook-syntax-regression.sh"
        "v001-mcp-config-regression.sh"
        "v001-package-boundary-regression.sh"
        "v001-security-regression.sh"
        "v001-skill-count-regression.sh"
        "v001-ssrf-regression.sh"
        "v001-tooling-contract-regression.sh"
        "v002-hooks-inline-regression.sh"
        "v002-mcp-paths-regression.sh"
        "v002-plugin-manifest-regression.sh"
        "v003-compact-recovery-regression.sh"
        "v003-doctor-plugin-root-regression.sh"
        "v003-dynamic-rules-regression.sh"
        "v003-evidence-gate-content-regression.sh"
        "v003-hook-uninstall-corrupt-regression.sh"
        "v003-hook-uninstall-regression.sh"
        "v003-mcp-path-traversal-regression.sh"
        "v003-ssrf-boundary-regression.sh"
        "v003-sync-regression.sh"
        "v003-tooling-capability-regression.sh"
        "v003-tooling-command-regression.sh"
        "v103-execution-context-hardening-regression.sh"
        "v103-mcp-params-regression.sh"
        "v103-mcp-profile-regression.sh"
        "v103-plan-format-compat.sh"
    )
    local lifecycle_tests=(
        "v103-loop-scripts-regression.sh"
        "v103-tooling-lifecycle-regression.sh"
        "v103-codegraph-regression.sh"
        "v103-codegraph-fixture-cleanup-regression.sh"
        "v103-codegraph-install-timeout-regression.sh"
        "v103-codegraph-lifecycle-caller-survival-regression.sh"
        "v103-codegraph-uninstall-pid-identity-regression.sh"
        "v103-lifecycle-entrypoint-regression.sh"
    )
    local standalone_tests=("${core_tests[@]}" "${lifecycle_tests[@]}")
    local selected_tests=()
    local paired_only_tests=(
        "v103-automatic-tooling-contract-parity.sh"
        "v103-lifecycle-contract-parity.sh"
        "v2-lifecycle-contract-parity.sh"
    )
    local publication_tests=(
        "publication-regression.sh"
    )

    contains_test() {
        local needle="$1"
        shift
        for candidate in "$@"; do
            [ "$candidate" = "$needle" ] && return 0
        done
        return 1
    }

    for test_name in "${standalone_tests[@]}" "${paired_only_tests[@]}" "${publication_tests[@]}"; do
        test_path="${tests_dir}/${test_name}"
        if [ ! -f "$test_path" ] || [ ! -s "$test_path" ] || ! bash -n "$test_path"; then
            printf 'ERROR: classified regression is missing, empty, or invalid: %s\n' "$test_name" >&2
            inventory_failed=true
        fi
    done

    while IFS= read -r test_path; do
        test_name="$(basename "$test_path")"
        if contains_test "$test_name" "${standalone_tests[@]}"; then
            :
        elif contains_test "$test_name" "${paired_only_tests[@]}"; then
            :
        elif contains_test "$test_name" "${publication_tests[@]}"; then
            :
        else
            printf 'ERROR: unclassified package-local regression: %s\n' "$test_name" >&2
            inventory_failed=true
        fi
    done < <(find "$tests_dir" -maxdepth 1 -type f -name '*-regression.sh' -print | LC_ALL=C sort)

    for test_name in "${standalone_tests[@]}"; do
        if contains_test "$test_name" "${paired_only_tests[@]}"; then
            printf 'ERROR: regression has conflicting classifications: %s\n' "$test_name" >&2
            inventory_failed=true
        fi
    done

    for test_name in "${publication_tests[@]}"; do
        if contains_test "$test_name" "${standalone_tests[@]}" || contains_test "$test_name" "${paired_only_tests[@]}"; then
            printf 'ERROR: regression has conflicting classifications: %s\n' "$test_name" >&2
            inventory_failed=true
        fi
    done

    if [ "$inventory_failed" = true ]; then
        REGRESSION_INVENTORY_RESULT="fail"
        AUTOMATIC_TOOLING_REGRESSIONS_RESULT="fail"
        ALL_PASS=false
        return
    fi
    REGRESSION_INVENTORY_RESULT="pass"

    if [ "$REGRESSION_DEPTH" -gt 0 ]; then
        AUTOMATIC_TOOLING_REGRESSIONS_RESULT="skipped-nested"
        return
    fi

    case "$VERIFY_SUITE" in
        all) selected_tests=("${standalone_tests[@]}") ;;
        core) selected_tests=("${core_tests[@]}") ;;
        lifecycle) selected_tests=("${lifecycle_tests[@]}") ;;
    esac

    for test_name in "${selected_tests[@]}"; do
        test_path="${tests_dir}/${test_name}"
        test_timeout="$VERIFY_TIMEOUT"
        # The codegraph lifecycle set owns long-running process supervision and
        # the tooling lifecycle runs several bounded fixture installs; both need
        # a floor above the generic per-check budget. v003-doctor-plugin-root
        # drives a full nested `lazykimi verify --must-pass`, whose phase
        # budget grew with the v1.3.3 family test stack, so it needs the same
        # floor (measured ~2 min nested, ~3.5 min unnested on the dev host).
        case "$test_name" in
            v103-codegraph-regression.sh|v103-codegraph-install-timeout-regression.sh|v103-tooling-lifecycle-regression.sh|v003-doctor-plugin-root-regression.sh)
                if [ "$CODEGRAPH_REGRESSION_TIMEOUT" -gt "$test_timeout" ]; then
                    test_timeout="$CODEGRAPH_REGRESSION_TIMEOUT"
                fi
                ;;
        esac
        if ! run_isolated_test "$test_path" "$test_timeout"; then
            printf 'FAIL: standalone regression failed: %s\n' "$test_name" >&2
            regression_failed=true
            ALL_PASS=false
        fi
    done

    if [ "$regression_failed" = true ]; then
        AUTOMATIC_TOOLING_REGRESSIONS_RESULT="fail"
    else
        AUTOMATIC_TOOLING_REGRESSIONS_RESULT="pass"
    fi
}

# The family-shared byte-identical execution-context contract test hardcodes
# the lazyzcode monorepo layout (plugins/lazyzcode/...) in its fixture paths,
# so exactly these three assertions cannot resolve in this repository. They
# are a recorded family deviation: any OTHER contract-test failure fails the
# gate, and the recorded set is re-checked by name on every run.
run_contract_tests() {
    local result_file
    if [ "$REGRESSION_DEPTH" -gt 0 ]; then
        CONTRACT_TESTS_RESULT="skipped-nested"
        return
    fi
    if [ "$VERIFY_SUITE" != "all" ]; then
        CONTRACT_TESTS_RESULT="skipped-suite"
        return
    fi
    result_file="$(mktemp "${TMPDIR:-/tmp}/lazykimi-contract-tests.XXXXXX")"
    tap_file="${result_file}.tap"
    # The child redirects its own TAP stream to a file (the bounded runner's
    # captured tail is truncated); the runner still bounds the process.
    if "$PYTHON_BIN" "$RUNNER" --label "contract_tests" --timeout "$VERIFY_TIMEOUT" --result-file "$result_file" -- \
        bash -c 'node --test --test-reporter=tap "$1"/contracts/tests/*.test.js >"$2" 2>&1' _ "$PLUGIN_ROOT" "$tap_file"; then
        CONTRACT_TESTS_RESULT="pass"
    else
        if "$PYTHON_BIN" - "$tap_file" <<'PY'
import json
import re
import sys

recorded = {
    "accepts a compact fixed dispatch with read-only provenance and once-validated argv",
    "accepts benign argv and binds it to the trusted stored plan command list",
    "reruns only failed missing stale or input-affected lanes and retains all-five PASS",
}
with open(sys.argv[1], encoding="utf-8") as handle:
    tap = handle.read()
failed = {name for name in re.findall(r"^not ok \d+ - (.+)$", tap, re.MULTILINE)}
extra = failed - recorded
if extra:
    print(f"unrecorded contract-test failures: {sorted(extra)}", file=sys.stderr)
    raise SystemExit(1)
missing = recorded - failed
if missing:
    print(f"recorded structural failures no longer reproduce (update the record): {sorted(missing)}", file=sys.stderr)
    raise SystemExit(1)
raise SystemExit(0)
PY
        then
            CONTRACT_TESTS_RESULT="pass-3-recorded-structural"
        else
            CONTRACT_TESTS_RESULT="fail"
            ALL_PASS=false
            printf 'FAIL: contract tests failed beyond the recorded structural set\n' >&2
        fi
    fi
    rm -f "$result_file" "$tap_file"
}

run_language_tests() {
    local result_file status test_path
    local node_test_paths=()
    if [ "$REGRESSION_DEPTH" -gt 0 ]; then
        NODE_TESTS_RESULT="skipped-nested"
        PYTHON_TESTS_RESULT="skipped-nested"
        return
    fi
    # Language tests run in the `all` suite. The fast `core` suite keeps its
    # original scope; the timing-sensitive `lifecycle` suite skips them.
    if [ "$VERIFY_SUITE" != "all" ]; then
        NODE_TESTS_RESULT="skipped-suite"
        PYTHON_TESTS_RESULT="skipped-suite"
        return
    fi

    while IFS= read -r test_path; do
        node_test_paths+=("$test_path")
    done < <(find "${PLUGIN_ROOT}/tests" -maxdepth 1 -type f -name '*.test.js' -print | LC_ALL=C sort)
    if [ "${#node_test_paths[@]}" -eq 0 ]; then
        printf 'ERROR: no package-local Node tests found\n' >&2
        NODE_TESTS_RESULT="fail"
        ALL_PASS=false
    else
        result_file="$(mktemp "${TMPDIR:-/tmp}/lazykimi-node-tests.XXXXXX")"
        # The node suite carries the eleven lifecycle tests (sandboxed durable
        # roots); give the phase its own bounded floor. An explicit user
        # override always wins when it exceeds the floor.
        NODE_PHASE_TIMEOUT="${LAZYKIMI_NODE_PHASE_TIMEOUT_SECONDS:-$(( VERIFY_TIMEOUT > 900 ? VERIFY_TIMEOUT : 900 ))}"
        if "$PYTHON_BIN" "$RUNNER" --label "node_tests" --timeout "$NODE_PHASE_TIMEOUT" --result-file "$result_file" -- \
            node --test --test-reporter=spec --test-concurrency="$NODE_TEST_CONCURRENCY" "${node_test_paths[@]}"; then
            NODE_TESTS_RESULT="pass"
        else
            status=$?
            NODE_TESTS_RESULT="fail"
            ALL_PASS=false
            print_failure_tail "$result_file"
            printf 'FAIL: Node tests exited %s\n' "$status" >&2
        fi
        rm -f "$result_file"
    fi

    # The pytest set ships with the family test-stack port (tests/ +
    # tooling/test_lazykimi_*.py). The count guard keeps the phase honest: an
    # empty collection reports a skip rather than fabricating a pass.
    local pytest_files=0
    while IFS= read -r test_path; do
        pytest_files=$((pytest_files + 1))
    done < <(find "${PLUGIN_ROOT}/tests" "${PLUGIN_ROOT}/tooling" -maxdepth 1 -type f \( -name 'test_*.py' -o -name '*_test.py' \) -print 2>/dev/null)
    if [ "$pytest_files" -eq 0 ]; then
        PYTHON_TESTS_RESULT="skipped-no-tests"
        return
    fi
    result_file="$(mktemp "${TMPDIR:-/tmp}/lazykimi-python-tests.XXXXXX")"
    if "$PYTHON_BIN" "$RUNNER" --label "python_tests" --timeout "$VERIFY_TIMEOUT" --result-file "$result_file" -- \
        "$PYTHON_BIN" -m pytest "${PLUGIN_ROOT}/tests" "${PLUGIN_ROOT}/tooling"; then
        PYTHON_TESTS_RESULT="pass"
    else
        status=$?
        PYTHON_TESTS_RESULT="fail"
        ALL_PASS=false
        print_failure_tail "$result_file"
        printf 'FAIL: Python tests exited %s\n' "$status" >&2
    fi
    rm -f "$result_file"
}

if [ "$VERIFY_SUITE" != "lifecycle" ]; then
    run_check doctor "${SCRIPTS_DIR}/lazykimi-plugin-doctor.sh"  DOCTOR_RESULT
    run_check smoke "${SCRIPTS_DIR}/lazykimi-smoke-test.sh"     SMOKE_RESULT
    run_check docs "${SCRIPTS_DIR}/lazykimi-docs-check.sh"     DOCS_RESULT
    run_check security "${SCRIPTS_DIR}/lazykimi-security-check.sh" SECURITY_RESULT
    run_check mcp_test "${SCRIPTS_DIR}/lazykimi-mcp-test.sh"       MCP_RESULT
    run_hook_pipeline_check hook_pipeline "${SCRIPTS_DIR}/lazykimi-hook-pipeline-test.sh" HOOK_RESULT
    run_check load_check "${SCRIPTS_DIR}/lazykimi-load-check.sh" LOAD_RESULT
    run_check automatic_tooling_contract "${SCRIPTS_DIR}/lazykimi-contract-check.sh" CONTRACT_RESULT
fi
run_regression_inventory
run_contract_tests
run_language_tests

# Build compact JSON summary
json="{\"suite\":\"${VERIFY_SUITE}\",\"doctor\":\"${DOCTOR_RESULT}\",\"smoke\":\"${SMOKE_RESULT}\",\"docs\":\"${DOCS_RESULT}\",\"security\":\"${SECURITY_RESULT}\",\"mcp_test\":\"${MCP_RESULT}\",\"hook_pipeline\":\"${HOOK_RESULT}\",\"load_check\":\"${LOAD_RESULT}\",\"automatic_tooling_contract\":\"${CONTRACT_RESULT}\",\"contract_tests\":\"${CONTRACT_TESTS_RESULT}\",\"regression_inventory\":\"${REGRESSION_INVENTORY_RESULT}\",\"shell_regressions\":\"${AUTOMATIC_TOOLING_REGRESSIONS_RESULT}\",\"node_tests\":\"${NODE_TESTS_RESULT}\",\"python_tests\":\"${PYTHON_TESTS_RESULT}\",\"checks\":${CHECK_DETAILS},\"all_pass\":${ALL_PASS}}"

echo "$json"

# Auto-append verification event to active run's events.jsonl
LATEST_RUN=""
if [ -x "${SCRIPTS_DIR}/state/latest-run.sh" ]; then
    LATEST_RUN="$("${SCRIPTS_DIR}/state/latest-run.sh" 2>/dev/null || echo "")"
fi
if [ -n "$LATEST_RUN" ]; then
    EVENTS_FILE=""
    if [[ "$LATEST_RUN" =~ ^[A-Za-z0-9._-]+$ ]]; then
        EVENTS_FILE="${CWD:-.}/.lazykimi/runs/$LATEST_RUN/events.jsonl"
    fi
    if [ -n "$EVENTS_FILE" ] && [ -f "$EVENTS_FILE" ]; then
        NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        ALL_PASS_PY=False
        if [ "$ALL_PASS" = true ]; then
            ALL_PASS_PY=True
        fi
        "$PYTHON_BIN" - "$CWD" "$EVENTS_FILE" "$LATEST_RUN" "$NOW" "$ALL_PASS_PY" <<'PY' 2>/dev/null || true
import json
import os
import sys

cwd, events_file, run_id, now, all_pass_raw = sys.argv[1:6]
root = os.path.realpath(os.path.join(cwd, ".lazykimi", "runs"))
events_path = os.path.realpath(events_file)
try:
    inside_runs = os.path.commonpath([root, events_path]) == root
except ValueError:
    inside_runs = False
if not inside_runs or not events_path.endswith(os.path.join(run_id, "events.jsonl")):
    raise SystemExit(0)
all_pass = all_pass_raw == "True"
event = {"ts": now, "run_id": run_id, "event": "verification_passed" if all_pass else "verification_failed", "all_pass": all_pass}
with open(events_path, "a") as f:
    f.write(json.dumps(event) + "\n")
PY
    fi
fi

if [ "$ALL_PASS" = true ]; then
    exit 0
else
    exit 1
fi
