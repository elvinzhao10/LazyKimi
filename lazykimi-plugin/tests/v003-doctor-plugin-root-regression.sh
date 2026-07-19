#!/usr/bin/env bash
# v003-doctor-plugin-root-regression.sh
# Verify `lazykimi doctor` and `lazykimi verify --must-pass` work when run from
# the lazykimi-plugin source root, where agents/hooks live at top level and
# .lazykimi/ lives at the project root.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DIST_INDEX="${PLUGIN_ROOT}/dist/index.js"

if [ ! -f "${DIST_INDEX}" ]; then
  echo "ERROR: ${DIST_INDEX} not found. Run npm run build first." >&2
  exit 1
fi

fail() { echo "FAIL: $1" >&2; exit 1; }

# When `verify --must-pass` runs regression tests it will invoke this script
# again. Skip the nested verify call to avoid infinite recursion.
if [ -n "${LAZYKIMI_V003_RECURSION_GUARD:-}" ]; then
  echo "PASS: v003 doctor plugin-root regression (nested invocation skipped)"
  exit 0
fi

DOCTOR_OUT="$(mktemp)"
trap 'rm -f "${DOCTOR_OUT}"' EXIT

cd "${PLUGIN_ROOT}"
node "${DIST_INDEX}" doctor >"${DOCTOR_OUT}" 2>&1 || true

if ! grep -q 'LazyKimi Doctor' "${DOCTOR_OUT}"; then
  cat "${DOCTOR_OUT}" >&2
  fail "doctor did not print header"
fi

if grep -q '\[FAIL\]' "${DOCTOR_OUT}"; then
  cat "${DOCTOR_OUT}" >&2
  fail "doctor reported FAIL when run from plugin source root"
fi

if ! grep -qE '=== Results: [0-9]+ PASS, [0-9]+ WARN, 0 FAIL ===' "${DOCTOR_OUT}"; then
  cat "${DOCTOR_OUT}" >&2
  fail "doctor did not report 0 FAIL"
fi

LAZYKIMI_V003_RECURSION_GUARD=1 node "${DIST_INDEX}" verify --must-pass >"${DOCTOR_OUT}" 2>&1 \
  || { cat "${DOCTOR_OUT}" >&2; fail "verify --must-pass exited non-zero from plugin source root"; }

if ! grep -q 'Overall: READY' "${DOCTOR_OUT}"; then
  cat "${DOCTOR_OUT}" >&2
  fail "verify did not report READY"
fi

echo "PASS: v003 doctor plugin-root regression"
