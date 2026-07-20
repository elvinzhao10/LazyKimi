#!/usr/bin/env bash
# v003-sync-regression.sh
# Verify `lazykimi sync` restores missing managed templates, preserves
# user-owned files, skips runtime state, and supports --dry-run.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DIST_INDEX="${PLUGIN_ROOT}/dist/index.js"

if [ ! -f "${DIST_INDEX}" ]; then
  echo "ERROR: ${DIST_INDEX} not found. Run npm run build first." >&2
  exit 1
fi

fail() { echo "FAIL: $1" >&2; exit 1; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/lazykimi-sync.XXXXXX")"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

# 1. --help lists usage.
HELP_OUT="$(mktemp)"
trap 'rm -f "${HELP_OUT}"' EXIT

node "${DIST_INDEX}" sync --help >"${HELP_OUT}" 2>&1
if ! grep -qE '\bdry-run\b' "${HELP_OUT}"; then
  cat "${HELP_OUT}" >&2
  fail "sync --help does not mention --dry-run"
fi
if ! grep -qE '\btarget\b' "${HELP_OUT}"; then
  cat "${HELP_OUT}" >&2
  fail "sync --help does not mention --target"
fi
echo "  [PASS] sync --help prints usage"

# 2. init a fresh target, then remove commands/ to simulate a partial install.
HOME="$TMP" node "${DIST_INDEX}" init --target "$TMP" >"$TMP/init.out" 2>&1 \
  || { cat "$TMP/init.out" >&2; fail "init failed"; }
[ -d "$TMP/.kimi-code/commands" ] || fail "commands/ missing after init"
rm -rf "$TMP/.kimi-code/commands"
[ ! -d "$TMP/.kimi-code/commands" ] || fail "commands/ still present after removal"

# 3. dry-run preview reports it would restore commands/ but does not write.
DRY_OUT="$(mktemp)"
trap 'rm -f "${HELP_OUT}" "${DRY_OUT}"' EXIT

( cd "$TMP" && HOME="$TMP" node "${DIST_INDEX}" sync --dry-run >"${DRY_OUT}" 2>&1 ) \
  || { cat "${DRY_OUT}" >&2; fail "sync --dry-run exited non-zero"; }
if ! grep -qE 'copy \.kimi-code/commands/' "${DRY_OUT}"; then
  cat "${DRY_OUT}" >&2
  fail "dry-run did not preview commands/ restoration"
fi
[ ! -d "$TMP/.kimi-code/commands" ] || fail "dry-run wrote commands/ despite --dry-run"
echo "  [PASS] sync --dry-run previews without writing"

# 4. actual sync restores commands/.
SYNC_OUT="$(mktemp)"
trap 'rm -f "${HELP_OUT}" "${DRY_OUT}" "${SYNC_OUT}"' EXIT

( cd "$TMP" && HOME="$TMP" node "${DIST_INDEX}" sync >"${SYNC_OUT}" 2>&1 ) \
  || { cat "${SYNC_OUT}" >&2; fail "sync exited non-zero"; }
[ -d "$TMP/.kimi-code/commands" ] || fail "commands/ not restored after sync"
[ -f "$TMP/.kimi-code/commands/lazy-init-deep.md" ] || fail "lazy-init-deep.md not restored"
echo "  [PASS] sync restores missing commands/"

# 5. sync does not touch runtime state.
[ -f "$TMP/.lazykimi/state/boulder.json" ] || fail "boulder.json missing before sync"
BOULDER_BEFORE="$(cat "$TMP/.lazykimi/state/boulder.json")"
( cd "$TMP" && HOME="$TMP" node "${DIST_INDEX}" sync >"$TMP/sync2.out" 2>&1 ) \
  || { cat "$TMP/sync2.out" >&2; fail "second sync failed"; }
BOULDER_AFTER="$(cat "$TMP/.lazykimi/state/boulder.json")"
[ "$BOULDER_BEFORE" = "$BOULDER_AFTER" ] || fail "sync modified runtime state boulder.json"
echo "  [PASS] sync leaves .lazykimi/state/ untouched"

# 6. sync preserves a user-owned file (no managed blocks) that has been modified.
USER_FILE="$TMP/.kimi-code/skills/lazy-init-deep/SKILL.md"
cp "$USER_FILE" "$TMP/skill-backup.md"
echo -e "\n<!-- USER-ADDED-CONTENT -->\nUser note." >> "$USER_FILE"
( cd "$TMP" && HOME="$TMP" node "${DIST_INDEX}" sync >"$TMP/sync3.out" 2>&1 ) \
  || { cat "$TMP/sync3.out" >&2; fail "sync with user-owned file failed"; }
if ! grep -q "User note." "$USER_FILE"; then
  fail "sync overwrote user-owned file"
fi
echo "  [PASS] sync preserves user-owned files without managed blocks"

# 7. sync preserves a file with managed blocks when the source template has none.
AGENTS_FILE="$TMP/.kimi-code/AGENTS.md"
cp "$AGENTS_FILE" "$TMP/agents-backup.md"
cat > "$AGENTS_FILE" <<'EOF'
# User header

<!-- lazykimi:managed:start -->
User-managed block.
<!-- lazykimi:managed:end -->

User footer.
EOF
( cd "$TMP" && HOME="$TMP" node "${DIST_INDEX}" sync >"$TMP/sync4.out" 2>&1 ) \
  || { cat "$TMP/sync4.out" >&2; fail "sync with managed-block file failed"; }
if ! grep -q "User header" "$AGENTS_FILE"; then
  fail "sync overwrote user-owned content around managed blocks"
fi
if ! grep -q "User footer" "$AGENTS_FILE"; then
  fail "sync overwrote user-owned content around managed blocks"
fi
echo "  [PASS] sync skips files with managed blocks when source template has none"

echo "PASS: v003 sync regression"
