#!/usr/bin/env bash
# v103-execution-context-hardening-regression.sh
# Adversarial battery for the v1.3.4 hardened PreToolUse policy, ported from
# the LazyZCode v1.3.4 fixture set plus the execution-context-security
# contract's wrapper rules: oversized input, wrapper-hidden destructive
# command, secret path (structured + generic), role-scoped write violations,
# malformed-payload rejection, and fail-open internals.
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$PLUGIN_ROOT/hooks/pre-tool-use.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/lazykimi-hardening.XXXXXX")"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }
[ -f "$HOOK" ] || fail "pre-tool-use.sh missing"

mkdir -p "$TMP/project"

# run_hook <json> -> sets OUT/ERR/STATUS
run_hook() {
    STATUS=0
    OUT=$(printf '%s' "$1" | bash "$HOOK" 2>"$TMP/err") || STATUS=$?
    ERR=$(cat "$TMP/err" 2>/dev/null)
}

# expect_deny <label> <json>
expect_deny() {
    run_hook "$2"
    [ "$STATUS" -eq 2 ] || fail "$1: expected exit 2, got $STATUS (stderr: ${ERR:0:100})"
    [ -z "$OUT" ] || fail "$1: deny must keep stdout empty, got: ${OUT:0:80}"
    printf '%s' "$ERR" | grep -Eqi 'denial|denied' || fail "$1: stderr must carry the reason, got: ${ERR:0:100}"
    echo "  [PASS] $1"
}

# expect_allow <label> <json>
expect_allow() {
    run_hook "$2"
    [ "$STATUS" -eq 0 ] || fail "$1: expected exit 0, got $STATUS (stderr: ${ERR:0:100})"
    [ -z "$OUT" ] || fail "$1: allow must stay silent, got: ${OUT:0:80}"
    echo "  [PASS] $1"
}

echo "=== v103 execution-context hardening regression ==="

# 1. Oversized input (> 1 MiB) is rejected before any policy parsing.
OVERSIZED='{"cwd":"'"$TMP/project"'","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"ls","pad":"'"$(python3 -c 'print("x" * 1048600)')"'"},"tail":true}'
run_hook "$OVERSIZED"
[ "$STATUS" -eq 2 ] || fail "oversized: expected exit 2, got $STATUS"
printf '%s' "$ERR" | grep -Eqi '1 MiB' || fail "oversized: must cite the 1 MiB limit, got: ${ERR:0:100}"
echo "  [PASS] oversized input rejected at the 1 MiB cap"

# 2. Exactly-at-limit input still parses (boundary is > 1 MiB, not >=).
AT_LIMIT='{"cwd":"'"$TMP/project"'","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"ls -la"}}'
expect_allow "at-limit payload allowed" "$AT_LIMIT"

# 3. Wrapper-hidden destructive commands are denied (execution-context wrappers).
expect_deny "wrapper env rm -rf /" '{"cwd":"'"$TMP/project"'","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"env rm -rf /"}}'
expect_deny "wrapper /usr/bin/env rm -rf $HOME" '{"cwd":"'"$TMP/project"'","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"/usr/bin/env rm -rf $HOME"}}'
expect_deny "wrapper nice sh -c style rm -rf ~" '{"cwd":"'"$TMP/project"'","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"nice rm -r --recursive ~"}}'
expect_deny "wrapper nohup rm -rf .." '{"cwd":"'"$TMP/project"'","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"nohup rm -rf ../escape"}}'
expect_deny "wrapper xargs-style rm -rf /tmp/x" '{"cwd":"'"$TMP/project"'","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"xargs rm -rf /"}}'
# Unparseable shell literal cannot be proven safe.
expect_deny "unparseable literal" '{"cwd":"'"$TMP/project"'","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"rm -rf \"unterminated"}}'

# 4. Wrapper commands WITHOUT a destructive payload are allowed.
expect_allow "env without destructive payload" '{"cwd":"'"$TMP/project"'","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"env LC_ALL=C grep -r foo ."}}'

# 5. Secret-like paths denied (structured Write + generic Bash).
expect_deny "secret path .env.production (Write)" '{"cwd":"'"$TMP/project"'","hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":"config/.env.production"}}'
expect_deny "secret path .aws/credentials (Write)" '{"cwd":"'"$TMP/project"'","hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":".aws/credentials"}}'
expect_deny "secret path .ssh/id_ prefix via nested component" '{"cwd":"'"$TMP/project"'","hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"path":"backup/.ssh/id_ed25519"}}'
expect_deny "secret path .npmrc (Bash generic)" '{"cwd":"'"$TMP/project"'","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"cat .npmrc"}}'
# Benign similarly-named paths are allowed (component match, not substring).
expect_allow "non-secret .environment.ts" '{"cwd":"'"$TMP/project"'","hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":"src/app.environment.ts"}}'

# 6. Destructive git + publish denial.
expect_deny "git push --force" '{"cwd":"'"$TMP/project"'","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git push --force origin main"}}'
expect_deny "git reset --hard" '{"cwd":"'"$TMP/project"'","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git reset --hard HEAD~3"}}'
expect_deny "npm publish" '{"cwd":"'"$TMP/project"'","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"npm publish --access public"}}'

# 7. Malformed payloads are rejected (fail closed on unprovable input).
expect_deny "missing tool_name" '{"cwd":"'"$TMP/project"'","hook_event_name":"PreToolUse","tool_input":{"command":"ls"}}'
expect_deny "mutating tool without object input" '{"cwd":"'"$TMP/project"'","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":"ls -la"}'
run_hook 'not-json{{{'
[ "$STATUS" -eq 2 ] || fail "non-JSON input: expected exit 2, got $STATUS"
echo "  [PASS] non-JSON input rejected"

# 8. Role-scoped writes (identity normalization incl. dual key styles).
# Verifier may only write its verification report inside an active run.
mkdir -p "$TMP/project/.lazykimi/runs/active-run/evidence"
python3 - "$TMP/project" <<'PYEOF'
import json, sys
state = {
    "schema_version": "2", "run_id": "active-run", "status": "executing",
    "tasks": [], "verification_gates": [], "review_status": "not_started",
}
json.dump(state, open(f"{sys.argv[1]}/.lazykimi/runs/active-run/state.json", "w"), indent=2)
PYEOF
expect_deny "verifier write outside .lazykimi" '{"cwd":"'"$TMP/project"'","hook_event_name":"PreToolUse","agent_type":"lazykimi-verifier","tool_name":"Write","tool_input":{"file_path":"src/product.ts"}}'
expect_deny "verifier Bash denied" '{"cwd":"'"$TMP/project"'","hook_event_name":"PreToolUse","agent_type":"lazykimi-verifier","tool_name":"Bash","tool_input":{"command":"ls"}}'
expect_deny "orchestrator product write denied" '{"cwd":"'"$TMP/project"'","hook_event_name":"PreToolUse","agent_type_name":"lazykimi-orchestrator","tool_name":"Write","tool_input":{"file_path":"src/product.ts"}}'
expect_deny "orchestrator may not write verification reports" '{"cwd":"'"$TMP/project"'","hook_event_name":"PreToolUse","agent_type":"lazykimi-orchestrator","tool_name":"Write","tool_input":{"file_path":".lazykimi/runs/active-run/evidence/t9.verification.md"}}'
RESTRICTED_JSON='{"cwd":"'"$TMP/project"'","hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":"src/product.ts"}}'
STATUS=0
OUT=$(printf '%s' "$RESTRICTED_JSON" | LAZYKIMI_RESTRICTED_RUN=1 bash "$HOOK" 2>"$TMP/err") || STATUS=$?
ERR=$(cat "$TMP/err" 2>/dev/null)
[ "$STATUS" -eq 2 ] || fail "LAZYKIMI_RESTRICTED_RUN: expected exit 2, got $STATUS"
printf '%s' "$ERR" | grep -Eqi 'denial|denied' || fail "LAZYKIMI_RESTRICTED_RUN: stderr must carry the reason"
echo "  [PASS] LAZYKIMI_RESTRICTED_RUN denies anonymous mutating writes"
expect_allow "verifier writes its verification report" '{"cwd":"'"$TMP/project"'","run_id":"active-run","hook_event_name":"PreToolUse","agent_type":"lazykimi-verifier","tool_name":"Write","tool_input":{"file_path":".lazykimi/runs/active-run/evidence/t9.verification.md"}}'
expect_allow "implementer (unrestricted role) writes product code" '{"cwd":"'"$TMP/project"'","hook_event_name":"PreToolUse","agent_type":"lazykimi-implementer","tool_name":"Write","tool_input":{"file_path":"src/product.ts"}}'

# 9. Symlinked .lazykimi state root is denied (boundary integrity).
mkdir -p "$TMP/real-state"
ln -s "$TMP/real-state" "$TMP/project2-lazykimi" 2>/dev/null || true
mkdir -p "$TMP/project2"
ln -sfn "$TMP/real-state" "$TMP/project2/.lazykimi"
expect_deny "symlinked .lazykimi denied" '{"cwd":"'"$TMP/project2"'","hook_event_name":"PreToolUse","agent_type":"lazykimi-verifier","tool_name":"Write","tool_input":{"file_path":".lazykimi/runs/active-run/evidence/t9.verification.md"}}'

# 10. The family execution-context contract rejects wrapper-hidden shell commands.
PLUGIN_ROOT="$PLUGIN_ROOT" node <<'JSEOF'
const { commandErrors } = require(`${process.env.PLUGIN_ROOT}/contracts/execution-context-security`);
const assert = require('node:assert/strict');
for (const argv of [
  ['env', 'sh', '-c', 'touch product.ts'],
  ['nice', 'sh', '-c', 'touch product.ts'],
  ['nohup', 'sh', '-c', 'touch product.ts'],
  ['xargs', 'sh', '-c', 'touch product.ts'],
  ['/usr/bin/env', 'sh', '-c', 'touch product.ts'],
]) {
  assert.ok(commandErrors([{ argv }]).length > 0, argv.join(' '));
}
assert.deepEqual(commandErrors([{ argv: ['git', 'status', '--short'] }]), []);
console.log('  [PASS] execution-context-security contract wrapper checks');
JSEOF

# 11. Fail-open internals: a truncated-but-valid event without cwd still parses.
expect_allow "payload without cwd allowed (safe command)" '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"ls -la"}}'

echo ""
echo "v103 execution-context hardening regression: PASS"
