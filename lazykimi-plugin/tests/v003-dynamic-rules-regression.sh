#!/usr/bin/env bash
# v003-dynamic-rules-regression.sh
# Verify the post-tool-use hook prints relevant .kimi-code/rules/ advisories
# after a tool writes files, and fails open when the rules directory is absent.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DIST_INDEX="${PLUGIN_ROOT}/dist/index.js"
HOOK="${PLUGIN_ROOT}/hooks/post-tool-use.sh"

if [ ! -f "${DIST_INDEX}" ]; then
  echo "ERROR: ${DIST_INDEX} not found. Run npm run build first." >&2
  exit 1
fi

fail() { echo "FAIL: $1" >&2; exit 1; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/lazykimi-rules-test.XXXXXX")"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

# 1. Hook passes bash -n syntax check.
bash -n "$HOOK" || fail "post-tool-use.sh has syntax errors"

# 2. Init a temp project so .kimi-code/ exists.
HOME="$TMP" node "${DIST_INDEX}" init --target "$TMP" >"$TMP/init.out" 2>&1 \
  || { cat "$TMP/init.out" >&2; fail "init failed"; }

# 3. With a typescript.md rule present, writing a .ts file prints RULE: typescript.md
mkdir -p "$TMP/.kimi-code/rules"
echo '# TypeScript rules' > "$TMP/.kimi-code/rules/typescript.md"

cd "$TMP"
OUT1="$(mktemp)"
printf '{"hook_event_name":"PostToolUse","changed_files":["src/foo.ts"]}\n' \
  | bash "$HOOK" >"$OUT1" 2>&1 \
  || fail "hook exited non-zero with rules present"

if ! grep -q 'RULE: typescript.md' "$OUT1"; then
  cat "$OUT1" >&2
  fail "expected RULE: typescript.md for .ts file"
fi

# 4. With no rules directory, the hook still exits 0 (fail open).
rm -rf "$TMP/.kimi-code/rules"
OUT2="$(mktemp)"
printf '{"hook_event_name":"PostToolUse","changed_files":["src/foo.ts"]}\n' \
  | bash "$HOOK" >"$OUT2" 2>&1 \
  || fail "hook should fail open when .kimi-code/rules/ is missing"

# It should not print a RULE line when rules are absent.
if grep -q '^RULE:' "$OUT2"; then
  cat "$OUT2" >&2
  fail "unexpected RULE output when rules directory is absent"
fi

echo "PASS: v003-dynamic-rules-regression"
