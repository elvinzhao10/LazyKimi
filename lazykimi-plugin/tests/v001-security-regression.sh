#!/usr/bin/env bash
# v001-security-regression.sh
# Verify no secrets in hooks, destructive ops are blocked, and fail-open is present.
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/lazykimi-security.XXXXXX")"

cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

expect_rejected() {
  local label="$1"; shift
  if "$@" >"$TMP/out" 2>&1; then
    fail "$label was accepted (should have been blocked)"
  fi
}

HOOKS_DIR="$PLUGIN_ROOT/hooks"
PRE="$HOOKS_DIR/pre-tool-use.sh"
[ -f "$PRE" ] || fail "pre-tool-use.sh missing"

# 1. No hardcoded secret patterns in any hook.
for f in "$HOOKS_DIR"/*.sh; do
  if grep -qE 'sk-[A-Za-z0-9]{20,}|gh[pousr]_[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|Bearer[[:space:]]+[A-Za-z0-9._/+=]{20,}' "$f"; then
    fail "secret pattern found in $(basename "$f")"
  fi
done

# 2. pre-tool-use.sh must fail-open on internal errors (ERR trap -> exit 0).
#    The trap line may order ERR and exit 0 either way; accept both.
grep -qE 'trap.*(ERR.*exit 0|exit 0.*ERR)' "$PRE" \
  || fail "pre-tool-use.sh missing fail-open ERR trap"

# 3. Destructive commands are blocked at runtime (exit 2).
rpc() {
  local cmd="$1"
  printf '%s' "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$cmd\"}}" | bash "$PRE"
}

expect_rejected "rm -rf /"            rpc "rm -rf /"
expect_rejected "rm -rf ~"            rpc "rm -rf ~"
expect_rejected "rm -rf \$HOME"       rpc 'rm -rf $HOME'
expect_rejected "git push --force main" rpc "git push --force origin main"
expect_rejected "git reset --hard"    rpc "git reset --hard HEAD~1"
expect_rejected "curl http://"        rpc "curl http://127.0.0.1:9/"
expect_rejected "chmod 777"           rpc "chmod 777 file"
expect_rejected "embedded secret"     rpc "export TOKEN=sk-aaaaaaaaaaaaaaaaaaaa"

# 4. Safe command is allowed (no output, exit 0).
out=$(printf '%s' '{"tool_name":"Bash","tool_input":{"command":"ls -la"}}' | bash "$PRE" 2>&1) \
  || fail "safe command was blocked"
[ -z "$out" ] || fail "safe command produced unexpected output: $out"

echo "v001 security regression: PASS"
