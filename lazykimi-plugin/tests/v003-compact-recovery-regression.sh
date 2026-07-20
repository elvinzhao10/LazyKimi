#!/usr/bin/env bash
# v003-compact-recovery-regression.sh
# Verify post-compact recovery flag is set by pre-compact.sh and cleared by
# session-start.sh, with a recovery hint printed. Fail-open if sessions.json is
# missing. No jq dependency.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DIST_INDEX="${PLUGIN_ROOT}/dist/index.js"
PRE_COMPACT="${PLUGIN_ROOT}/hooks/pre-compact.sh"
SESSION_START="${PLUGIN_ROOT}/hooks/session-start.sh"

if [ ! -f "${DIST_INDEX}" ]; then
  echo "ERROR: ${DIST_INDEX} not found. Run npm run build first." >&2
  exit 1
fi

fail() { echo "FAIL: $1" >&2; exit 1; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/lazykimi-compact-test.XXXXXX")"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

# 1. init into a temp project (HOME isolated so ~/.kimi-code/config.toml is untouched).
HOME="$TMP" node "${DIST_INDEX}" init --target "$TMP" >"$TMP/init.out" 2>&1 \
  || { cat "$TMP/init.out" >&2; fail "init failed"; }

[ -d "$TMP/.kimi-code/rules" ] || fail ".kimi-code/rules/ not created"
[ -f "$TMP/.lazykimi/state/sessions.json" ] || fail "sessions.json not created"

cd "$TMP"

# 2. simulate PreCompact hook
printf '{"hook_event_name":"PreCompact"}\n' | bash "$PRE_COMPACT" >"$TMP/pre-compact.out" 2>&1 \
  || { cat "$TMP/pre-compact.out" >&2; fail "pre-compact.sh exited non-zero"; }

RECOVERY_FLAG_AFTER_PRE=$(python3 -c "import json; d=json.load(open('.lazykimi/state/sessions.json')); print(d.get('post_compact_recovery_needed', 'MISSING'))")
[ "$RECOVERY_FLAG_AFTER_PRE" = "True" ] || fail "expected post_compact_recovery_needed=True after pre-compact, got $RECOVERY_FLAG_AFTER_PRE"

RULES_HASH_AFTER_PRE=$(python3 -c "import json; d=json.load(open('.lazykimi/state/sessions.json')); print(d.get('rules_hash_pre_compact', 'MISSING'))")
[ -n "$RULES_HASH_AFTER_PRE" ] || fail "expected non-empty rules_hash_pre_compact after pre-compact"
[ "$RULES_HASH_AFTER_PRE" != "MISSING" ] || fail "rules_hash_pre_compact missing after pre-compact"

# 3. simulate SessionStart hook
printf '{"hook_event_name":"SessionStart"}\n' | bash "$SESSION_START" >"$TMP/session-start.out" 2>&1 \
  || { cat "$TMP/session-start.out" >&2; fail "session-start.sh exited non-zero"; }

if ! grep -q 'Compact recovery needed' "$TMP/session-start.out"; then
  cat "$TMP/session-start.out" >&2
  fail "session-start.sh did not print compact recovery hint"
fi

if ! grep -q 'Active plan:' "$TMP/session-start.out"; then
  cat "$TMP/session-start.out" >&2
  fail "session-start.sh did not print active plan path"
fi

if ! grep -q 'Rule files:' "$TMP/session-start.out"; then
  cat "$TMP/session-start.out" >&2
  fail "session-start.sh did not print rule file list"
fi

RECOVERY_FLAG_AFTER_START=$(python3 -c "import json; d=json.load(open('.lazykimi/state/sessions.json')); print(d.get('post_compact_recovery_needed', 'MISSING'))")
[ "$RECOVERY_FLAG_AFTER_START" = "False" ] || fail "expected post_compact_recovery_needed=False after session-start, got $RECOVERY_FLAG_AFTER_START"

# 4. fail-open when sessions.json is missing
rm -f "$TMP/.lazykimi/state/sessions.json"
printf '{"hook_event_name":"SessionStart"}\n' | bash "$SESSION_START" >"$TMP/session-start-missing.out" 2>&1 \
  || { cat "$TMP/session-start-missing.out" >&2; fail "session-start.sh should fail open when sessions.json is missing"; }

# 5. fail-open when sessions.json is malformed
printf 'not-json{{{' > "$TMP/.lazykimi/state/sessions.json"
printf '{"hook_event_name":"SessionStart"}\n' | bash "$SESSION_START" >"$TMP/session-start-bad.out" 2>&1 \
  || { cat "$TMP/session-start-bad.out" >&2; fail "session-start.sh should fail open when sessions.json is malformed"; }

# 6. fail-open when sessions.json is valid but has no recovery flag
echo '{"sessions":[]}' > "$TMP/.lazykimi/state/sessions.json"
printf '{"hook_event_name":"SessionStart"}\n' | bash "$SESSION_START" >"$TMP/session-start-noflag.out" 2>&1 \
  || { cat "$TMP/session-start-noflag.out" >&2; fail "session-start.sh should fail open when recovery flag is absent"; }

if grep -q 'Compact recovery needed' "$TMP/session-start-noflag.out"; then
  fail "session-start.sh printed recovery hint when flag was absent"
fi

echo "PASS: v003 compact recovery regression"
