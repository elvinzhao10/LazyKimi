#!/usr/bin/env bash
# v103-lifecycle-contract-parity.sh — compatibility entry point for the
# current bounded explicit-root parity gate (family-shared contracts vs
# LazyZCode). Ported from lazyzcode v1.3.3 tests/v103-lifecycle-contract-parity.sh,
# which execs its v110 six-host gate; LazyKimi's bounded gate is the
# v103-automatic-tooling-contract-parity.sh tooling-contract gate.
# This is package evidence only. It does not inspect or claim host readiness.
set -euo pipefail

usage() {
    cat <<'USAGE'
Usage: v103-lifecycle-contract-parity.sh --lazyzcode-root ABSOLUTE_ROOT --lazykimi-root ABSOLUTE_ROOT

Compatibility entry point for the current bounded explicit-root parity gate.
This is package evidence only. It does not inspect or claim host readiness.
USAGE
}

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

LAZYZCODE_ROOT=""
LAZYKIMI_ROOT=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        --lazyzcode-root)
            [ "$#" -ge 2 ] || fail "--lazyzcode-root requires a value"
            LAZYZCODE_ROOT="$2"
            shift 2
            ;;
        --lazykimi-root)
            [ "$#" -ge 2 ] || fail "--lazykimi-root requires a value"
            LAZYKIMI_ROOT="$2"
            shift 2
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            usage >&2
            fail "unknown argument: $1"
            ;;
    esac
done

[ -n "$LAZYZCODE_ROOT" ] || { usage >&2; fail "--lazyzcode-root is required"; }
[ -n "$LAZYKIMI_ROOT" ] || { usage >&2; fail "--lazykimi-root is required"; }
exec bash "$(cd "$(dirname "$0")" && pwd -P)/v103-automatic-tooling-contract-parity.sh" \
    --lazyzcode-root "$LAZYZCODE_ROOT" --lazykimi-root "$LAZYKIMI_ROOT"
