#!/usr/bin/env bash
# v001-hook-syntax-regression.sh
# Verify 16 hooks present and each passes `bash -n` (syntax check).
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/lazykimi-hook-syntax.XXXXXX")"

cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

EXPECTED=16
HOOKS_DIR="$PLUGIN_ROOT/hooks"
[ -d "$HOOKS_DIR" ] || fail "hooks dir missing"

shopt -s nullglob
hooks=("$HOOKS_DIR"/*.sh)
shopt -u nullglob

count=${#hooks[@]}
[ "$count" -ge 1 ] || fail "no .sh hooks found"
[ "$count" -eq "$EXPECTED" ] || fail "expected $EXPECTED hooks, found $count"

for f in "${hooks[@]}"; do
  # Each hook must use the env bash shebang.
  head -1 "$f" | grep -q '^#!/usr/bin/env bash' \
    || fail "$(basename "$f") missing #!/usr/bin/env bash shebang"
  # Syntax check.
  bash -n "$f" || fail "syntax error in $(basename "$f")"
  # Each hook must fail-safe with set -euo pipefail OR a trap.
  grep -qE 'set -[a-z]*u|trap ' "$f" \
    || fail "$(basename "$f") missing set -u or trap (unsafe hook)"
done

echo "v001 hook-syntax regression: PASS"
