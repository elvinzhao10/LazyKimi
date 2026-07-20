#!/usr/bin/env bash
# v003-tooling-capability-regression.sh
# Verify the optional-MCP capability lifecycle (enable/disable/list) in the
# `lazykimi tooling` command.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DIST_INDEX="${PLUGIN_ROOT}/dist/index.js"

if [ ! -f "${DIST_INDEX}" ]; then
  echo "ERROR: ${DIST_INDEX} not found. Run npm run build first." >&2
  exit 1
fi

fail() { echo "FAIL: $1" >&2; exit 1; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/lazykimi-cap-test.XXXXXX")"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

HOME="$TMP" node "${DIST_INDEX}" init --target "$TMP" >"$TMP/init.out" 2>&1 \
  || { cat "$TMP/init.out" >&2; fail "init failed"; }

[ -f "$TMP/.kimi-code/mcp.json" ] || fail ".kimi-code/mcp.json not created"

cd "$TMP"

# 1. enable an optional capability
ENABLE_OUT="$(mktemp)"
trap 'rm -f "$ENABLE_OUT"' EXIT

node "${DIST_INDEX}" tooling enable lsp >"$ENABLE_OUT" 2>&1 \
  || { cat "$ENABLE_OUT" >&2; fail "tooling enable lsp exited non-zero"; }

if ! grep -q 'lazykimi-lsp' "$TMP/.kimi-code/mcp.json"; then
  cat "$TMP/.kimi-code/mcp.json" >&2
  fail "mcp.json does not contain lazykimi-lsp after enable"
fi

# 2. list shows the capability as enabled
LIST_OUT="$(mktemp)"
trap 'rm -f "$ENABLE_OUT" "$LIST_OUT"' EXIT

node "${DIST_INDEX}" tooling list >"$LIST_OUT" 2>&1 \
  || { cat "$LIST_OUT" >&2; fail "tooling list exited non-zero"; }

if ! grep -qE '^lsp: enabled$' "$LIST_OUT"; then
  cat "$LIST_OUT" >&2
  fail "tooling list does not report lsp as enabled"
fi

# 3. disable removes the capability
DISABLE_OUT="$(mktemp)"
trap 'rm -f "$ENABLE_OUT" "$LIST_OUT" "$DISABLE_OUT"' EXIT

node "${DIST_INDEX}" tooling disable lsp >"$DISABLE_OUT" 2>&1 \
  || { cat "$DISABLE_OUT" >&2; fail "tooling disable lsp exited non-zero"; }

if grep -q 'lazykimi-lsp' "$TMP/.kimi-code/mcp.json"; then
  cat "$TMP/.kimi-code/mcp.json" >&2
  fail "mcp.json still contains lazykimi-lsp after disable"
fi

# 4. list shows the capability as disabled
LIST2_OUT="$(mktemp)"
trap 'rm -f "$ENABLE_OUT" "$LIST_OUT" "$DISABLE_OUT" "$LIST2_OUT"' EXIT

node "${DIST_INDEX}" tooling list >"$LIST2_OUT" 2>&1 \
  || { cat "$LIST2_OUT" >&2; fail "tooling list (second) exited non-zero"; }

if ! grep -qE '^lsp: disabled$' "$LIST2_OUT"; then
  cat "$LIST2_OUT" >&2
  fail "tooling list does not report lsp as disabled"
fi

# 5. enable with an invalid capability is rejected
INVALID_OUT="$(mktemp)"
trap 'rm -f "$ENABLE_OUT" "$LIST_OUT" "$DISABLE_OUT" "$LIST2_OUT" "$INVALID_OUT"' EXIT

node "${DIST_INDEX}" tooling enable not_a_capability >"$INVALID_OUT" 2>&1 \
  && { cat "$INVALID_OUT" >&2; fail "tooling enable invalid capability should fail"; }

echo "PASS: v003 tooling capability regression"
