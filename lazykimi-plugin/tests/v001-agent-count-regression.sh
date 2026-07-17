#!/usr/bin/env bash
# v001-agent-count-regression.sh
# Verify 11 agents present (lazykimi-*.md), each non-empty.
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/lazykimi-agent-count.XXXXXX")"

cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

EXPECTED=11
AGENTS_DIR="$PLUGIN_ROOT/agents"
[ -d "$AGENTS_DIR" ] || fail "agents dir missing"

shopt -s nullglob
agents=("$AGENTS_DIR"/lazykimi-*.md)
shopt -u nullglob

count=${#agents[@]}
[ "$count" -eq "$EXPECTED" ] \
  || fail "expected $EXPECTED agents, found $count"

for f in "${agents[@]}"; do
  [ -s "$f" ] || fail "empty agent file: $(basename "$f")"
  # Each agent file should start with a markdown heading or frontmatter.
  head -1 "$f" | grep -qE '^(#|---)' \
    || fail "$(basename "$f") does not start with heading or frontmatter"
done

echo "v001 agent-count regression: PASS"
