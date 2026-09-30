#!/usr/bin/env bash
# lazykimi-package-verify.sh — ported from lazyzcode v1.3.3
# scripts/lazyzcode-package-verify.sh: full verify against a pristine,
# dependency-isolated tooling install (never the working tree's node_modules).
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TOOLING_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/lazykimi-package-verify.XXXXXX")"

cleanup() {
    rm -rf -- "$TOOLING_ROOT"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

cp "$PLUGIN_ROOT/tooling/package.json" "$PLUGIN_ROOT/tooling/package-lock.json" "$TOOLING_ROOT/"
(cd "$TOOLING_ROOT" && npm ci --ignore-scripts --no-audit --no-fund) >&2
LAZYKIMI_PARITY_NODE_MODULES="$TOOLING_ROOT/node_modules" \
    bash "$PLUGIN_ROOT/scripts/lazykimi-verify.sh"
