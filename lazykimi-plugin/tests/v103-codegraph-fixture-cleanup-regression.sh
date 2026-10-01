#!/usr/bin/env bash
# v103-codegraph-fixture-cleanup-regression.sh — ported from lazyzcode v1.3.4 tests/v017-codegraph-fixture-cleanup-regression.sh; family
# versioning keeps the new port on the v103 prefix.
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/lazykimi-codegraph-fixture-cleanup.XXXXXX")"

cleanup() {
    [ "${LAZYKIMI_KEEP_TEST_FIXTURES:-}" = 1 ] && {
        printf 'KEEP fixture: %s\n' "$TMP" >&2
        return
    }
    rm -rf "$TMP"
}
trap cleanup EXIT

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

snapshot() {
    local prefix="$1" output="$2"
    find "${TMPDIR:-/tmp}" -maxdepth 1 -type d -name "${prefix}*" -print 2>/dev/null | sort > "$output"
}

check_fixture_cleanup() {
    local prefix="$1" test_path="$2" label="$3"
    local before="$TMP/$label.before" after="$TMP/$label.after" output="$TMP/$label.output"
    snapshot "$prefix" "$before"
    if ! bash "$test_path" >"$output" 2>&1; then
        cat "$output" >&2
        fail "$label regression failed"
    fi
    snapshot "$prefix" "$after"
    cmp -s "$before" "$after" || {
        diff -u "$before" "$after" >&2 || true
        fail "$label left a fixture outside its invocation-owned root"
    }
    printf 'PASS: %s cleans its owned fixture prefix\n' "$label"
}

check_fixture_cleanup 'lazykimi-codegraph.' "$PLUGIN_ROOT/tests/v103-codegraph-regression.sh" 'CodeGraph lifecycle'
check_fixture_cleanup 'lazykimi-codegraph-install-timeout.' "$PLUGIN_ROOT/tests/v103-codegraph-install-timeout-regression.sh" 'CodeGraph install timeout'
check_fixture_cleanup 'lazykimi-codegraph-pid-identity.' "$PLUGIN_ROOT/tests/v103-codegraph-uninstall-pid-identity-regression.sh" 'CodeGraph PID identity'

printf 'PASS: CodeGraph fixture cleanup inventory is unchanged\n'
