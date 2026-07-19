#!/usr/bin/env bash
# LazyKimi v0.3 hook uninstall regression test.
# Verifies that `lazykimi uninstall` removes the [[hooks]] entries appended by
# install-hooks.sh while preserving foreign [[hooks]] blocks.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DIST_INDEX="${PLUGIN_ROOT}/dist/index.js"
INSTALL_HOOKS="${PLUGIN_ROOT}/scripts/install-hooks.sh"

if [ ! -f "${DIST_INDEX}" ]; then
  echo "ERROR: ${DIST_INDEX} not found. Run npm run build first." >&2
  exit 1
fi

TMP_HOME="$(mktemp -d)"
PROJECT_ROOT="${TMP_HOME}/proj"
CONFIG_DIR="${TMP_HOME}/.kimi-code"
CONFIG_FILE="${CONFIG_DIR}/config.toml"

cleanup() {
  rm -rf "${TMP_HOME}"
}
trap cleanup EXIT

reset_home() {
  rm -rf "${TMP_HOME}"
  mkdir -p "${TMP_HOME}"
}

run_uninstall() {
  HOME="${TMP_HOME}" node "${DIST_INDEX}" uninstall --yes "$@"
}

# ---------------------------------------------------------------------------
# Main scenario: foreign hooks must be preserved.
# ---------------------------------------------------------------------------
HOME="${TMP_HOME}" node "${DIST_INDEX}" init --target "${PROJECT_ROOT}"
HOME="${TMP_HOME}" bash "${INSTALL_HOOKS}" --project-root "${PROJECT_ROOT}"

# Add a foreign [[hooks]] block that must survive uninstall.
cat >> "${CONFIG_FILE}" <<'EOF'
[[hooks]]
event = "PreToolUse"
matcher = "Bash"
command = "/usr/local/bin/foreign-hook.sh"
timeout = 3

EOF

HOOKS_BEFORE="$(grep -c '\[\[hooks\]\]' "${CONFIG_FILE}" || true)"
FOREIGN_BEFORE="$(grep -c 'foreign-hook' "${CONFIG_FILE}" || true)"
LAZYKIMI_HOOKS_BEFORE=$((HOOKS_BEFORE - FOREIGN_BEFORE))

cd "${PROJECT_ROOT}"
run_uninstall

HOOKS_AFTER="$(grep -c '\[\[hooks\]\]' "${CONFIG_FILE}" || true)"
FOREIGN_AFTER="$(grep -c 'foreign-hook' "${CONFIG_FILE}" || true)"
LAZYKIMI_HOOKS_AFTER=$((HOOKS_AFTER - FOREIGN_AFTER))

echo "Removed hooks from ${CONFIG_FILE}"
echo "hooks count before uninstall: ${LAZYKIMI_HOOKS_BEFORE}"
echo "hooks count after uninstall: ${LAZYKIMI_HOOKS_AFTER}"
echo "foreign hooks preserved: ${FOREIGN_AFTER}"

if [ "${HOOKS_BEFORE}" -ne 9 ]; then
  echo "FAIL: expected 9 hooks before uninstall (8 LazyKimi + 1 foreign), got ${HOOKS_BEFORE}" >&2
  exit 1
fi
if [ "${HOOKS_AFTER}" -ne 1 ]; then
  echo "FAIL: expected 1 foreign hook after uninstall, got ${HOOKS_AFTER}" >&2
  exit 1
fi
if [ "${LAZYKIMI_HOOKS_AFTER}" -ne 0 ]; then
  echo "FAIL: expected 0 LazyKimi hooks after uninstall, got ${LAZYKIMI_HOOKS_AFTER}" >&2
  exit 1
fi
if [ "${FOREIGN_AFTER}" -ne 1 ]; then
  echo "FAIL: expected foreign hook preserved, got ${FOREIGN_AFTER}" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Adversarial: uninstall --soft when no LazyKimi hooks are installed.
# ---------------------------------------------------------------------------
cd /
reset_home
mkdir -p "${PROJECT_ROOT}" "${CONFIG_DIR}"
cat > "${CONFIG_FILE}" <<'EOF'
[[hooks]]
event = "SessionStart"
command = "/usr/local/bin/other-hook.sh"
timeout = 5

EOF

cd "${PROJECT_ROOT}"
if run_uninstall --soft 2>&1 | grep -q 'Removed hooks from'; then
  echo "FAIL: --soft with no LazyKimi hooks should not report removal" >&2
  exit 1
fi
OTHER_AFTER="$(grep -c 'other-hook' "${CONFIG_FILE}" || true)"
if [ "${OTHER_AFTER}" -ne 1 ]; then
  echo "FAIL: foreign hook removed during --soft with no LazyKimi hooks" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Adversarial: idempotent install-hooks, then uninstall removes exactly 8.
# ---------------------------------------------------------------------------
cd /
reset_home
HOME="${TMP_HOME}" node "${DIST_INDEX}" init --target "${PROJECT_ROOT}"
HOME="${TMP_HOME}" bash "${INSTALL_HOOKS}" --project-root "${PROJECT_ROOT}"
HOME="${TMP_HOME}" bash "${INSTALL_HOOKS}" --project-root "${PROJECT_ROOT}"
HOOKS_BEFORE="$(grep -c '\[\[hooks\]\]' "${CONFIG_FILE}" || true)"
if [ "${HOOKS_BEFORE}" -ne 8 ]; then
  echo "FAIL: idempotent install should yield exactly 8 hooks, got ${HOOKS_BEFORE}" >&2
  exit 1
fi
cd "${PROJECT_ROOT}"
run_uninstall
HOOKS_AFTER="$(grep -c '\[\[hooks\]\]' "${CONFIG_FILE}" || true)"
if [ "${HOOKS_AFTER}" -ne 0 ]; then
  echo "FAIL: idempotent install then uninstall should leave 0 hooks, got ${HOOKS_AFTER}" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Adversarial: corrupt config.toml (missing closing quote) should not crash.
# ---------------------------------------------------------------------------
cd /
reset_home
mkdir -p "${PROJECT_ROOT}" "${CONFIG_DIR}"
cat > "${CONFIG_FILE}" <<'EOF'
[[hooks]]
event = "SessionStart"
command = "/usr/local/bin/broken-hook.sh
EOF

cd "${PROJECT_ROOT}"
if ! run_uninstall --soft; then
  echo "FAIL: uninstall should not crash on corrupt config.toml" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Adversarial: hooks installed from plugin source layout (<project>/hooks/).
# ---------------------------------------------------------------------------
cd /
reset_home
mkdir -p "${PROJECT_ROOT}/hooks"
cp -R "${PLUGIN_ROOT}/hooks/"* "${PROJECT_ROOT}/hooks/"
HOME="${TMP_HOME}" bash "${INSTALL_HOOKS}" --project-root "${PROJECT_ROOT}"
HOOKS_BEFORE="$(grep -c '\[\[hooks\]\]' "${CONFIG_FILE}" || true)"
cd "${PROJECT_ROOT}"
run_uninstall
HOOKS_AFTER="$(grep -c '\[\[hooks\]\]' "${CONFIG_FILE}" || true)"
if [ "${HOOKS_AFTER}" -ne 0 ]; then
  echo "FAIL: source-layout hooks should be removed, got ${HOOKS_AFTER}" >&2
  exit 1
fi

echo "PASS: v003 hook uninstall regression"
