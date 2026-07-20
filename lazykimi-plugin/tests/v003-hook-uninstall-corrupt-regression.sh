#!/usr/bin/env bash
# LazyKimi v0.3 hook uninstall corrupt regression test.
# Verifies removeHooksFromConfig() handles malformed [[hooks]] blocks without
# corrupting the config and preserves foreign blocks.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DIST_INDEX="${PLUGIN_ROOT}/dist/index.js"
INSTALL_HOOKS="${PLUGIN_ROOT}/scripts/install-hooks.sh"

fail() { echo "FAIL: $1" >&2; exit 1; }

if [ ! -f "${DIST_INDEX}" ]; then
  echo "INFO: dist/index.js missing; running npm run build..." >&2
  cd "${PLUGIN_ROOT}"
  npm run build >&2 || fail "npm run build failed"
fi

TMP_HOME="$(mktemp -d)"
cleanup() { rm -rf "${TMP_HOME}"; }
trap cleanup EXIT

PROJECT_ROOT="${TMP_HOME}/proj"
CONFIG_FILE="${TMP_HOME}/.kimi-code/config.toml"

init_project() {
  # Avoid removing the directory while it is the shell's cwd.
  cd /
  rm -rf "${PROJECT_ROOT}" "${TMP_HOME}/.kimi-code"
  mkdir -p "${PROJECT_ROOT}"
  HOME="${TMP_HOME}" node "${DIST_INDEX}" init --target "${PROJECT_ROOT}" >/dev/null 2>&1 || fail "init failed"
  HOME="${TMP_HOME}" bash "${INSTALL_HOOKS}" --project-root "${PROJECT_ROOT}" >/dev/null 2>&1 || fail "install-hooks failed"
}

run_uninstall() {
  HOME="${TMP_HOME}" node "${DIST_INDEX}" uninstall --yes --soft "$@"
}

# Scenario 1: malformed LazyKimi block (missing closing quote on a non-command
# field) followed by a valid foreign [[hooks]] block. The LazyKimi block should
# still be detected/removed and the foreign block preserved.
init_project
HOOK_CMD="bash ${PROJECT_ROOT}/.kimi-code/hooks/session-start.sh"
cat >> "${CONFIG_FILE}" <<EOF
[[hooks]]
event = "SessionStart"
command = "${HOOK_CMD}"
timeout = 5
malformed = "no closing quote

[[hooks]]
event = "PreToolUse"
matcher = "Bash"
command = "/usr/local/bin/foreign-hook.sh"
timeout = 3

EOF

cd "${PROJECT_ROOT}"
run_uninstall >/dev/null 2>&1 || fail "scenario 1 uninstall crashed"

FOREIGN_COUNT="$(grep -c 'foreign-hook' "${CONFIG_FILE}" || true)"
LAZYKIMI_COUNT="$(grep -c "${PROJECT_ROOT}/.kimi-code/hooks" "${CONFIG_FILE}" || true)"
HOOKS_COUNT="$(grep -c '\[\[hooks\]\]' "${CONFIG_FILE}" || true)"

if [ "${FOREIGN_COUNT}" -ne 1 ]; then
  fail "scenario 1: foreign hook not preserved (count=${FOREIGN_COUNT})"
fi
if [ "${LAZYKIMI_COUNT}" -ne 0 ]; then
  fail "scenario 1: LazyKimi hook not removed (count=${LAZYKIMI_COUNT})"
fi
if [ "${HOOKS_COUNT}" -ne 1 ]; then
  fail "scenario 1: expected 1 remaining hook block, got ${HOOKS_COUNT}"
fi

# Scenario 2: LazyKimi block where command has no closing quote. The uninstall
# must not crash and must not corrupt the config (foreign block preserved).
init_project
cat >> "${CONFIG_FILE}" <<'EOF'
[[hooks]]
event = "SessionStart"
command = "bash /usr/local/bin/not-a-hook.sh

[[hooks]]
event = "PreToolUse"
matcher = "Bash"
command = "/usr/local/bin/foreign-hook.sh"
timeout = 3

EOF

cd "${PROJECT_ROOT}"
run_uninstall >/dev/null 2>&1 || fail "scenario 2 uninstall crashed"

FOREIGN_COUNT="$(grep -c 'foreign-hook' "${CONFIG_FILE}" || true)"
if [ "${FOREIGN_COUNT}" -ne 1 ]; then
  fail "scenario 2: foreign hook not preserved (count=${FOREIGN_COUNT})"
fi

# Scenario 3: multiple LazyKimi blocks and one foreign block; only LazyKimi
# blocks are removed.
init_project
cat >> "${CONFIG_FILE}" <<'EOF'
[[hooks]]
event = "PreToolUse"
matcher = "Bash"
command = "/usr/local/bin/foreign-hook.sh"
timeout = 3

EOF

BEFORE_LAZY="$(grep -c "${PROJECT_ROOT}/.kimi-code/hooks" "${CONFIG_FILE}" || true)"
BEFORE_FOREIGN="$(grep -c 'foreign-hook' "${CONFIG_FILE}" || true)"
if [ "${BEFORE_LAZY}" -lt 2 ]; then
  fail "scenario 3: expected multiple LazyKimi hooks, got ${BEFORE_LAZY}"
fi

cd "${PROJECT_ROOT}"
run_uninstall >/dev/null 2>&1 || fail "scenario 3 uninstall crashed"

AFTER_LAZY="$(grep -c "${PROJECT_ROOT}/.kimi-code/hooks" "${CONFIG_FILE}" || true)"
AFTER_FOREIGN="$(grep -c 'foreign-hook' "${CONFIG_FILE}" || true)"
if [ "${AFTER_LAZY}" -ne 0 ]; then
  fail "scenario 3: LazyKimi hooks not all removed (count=${AFTER_LAZY})"
fi
if [ "${AFTER_FOREIGN}" -ne 1 ]; then
  fail "scenario 3: foreign hook not preserved (count=${AFTER_FOREIGN})"
fi

# Scenario 4: config with only a LazyKimi block whose command has no closing
# quote. Uninstall must not crash and config may be left unchanged.
init_project
# Remove the installed hooks so only the malformed block remains.
rm -f "${CONFIG_FILE}"
cat > "${CONFIG_FILE}" <<'EOF'
[[hooks]]
event = "SessionStart"
command = "bash /path/to/.kimi-code/hooks/session-start.sh

EOF

cd "${PROJECT_ROOT}"
run_uninstall >/dev/null 2>&1 || fail "scenario 4 uninstall crashed"

if ! grep -q '\[\[hooks\]\]' "${CONFIG_FILE}"; then
  fail "scenario 4: malformed block unexpectedly removed"
fi

echo "PASS: v003 hook uninstall corrupt regression"
