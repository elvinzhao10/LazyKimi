#!/usr/bin/env bash
# v003-tooling-command-regression.sh
# Verify the `lazykimi tooling` command exposes detect/status/policy and
# invokes the Python capability broker successfully.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DIST_INDEX="${PLUGIN_ROOT}/dist/index.js"

if [ ! -f "${DIST_INDEX}" ]; then
  echo "ERROR: ${DIST_INDEX} not found. Run npm run build first." >&2
  exit 1
fi

fail() { echo "FAIL: $1" >&2; exit 1; }

HELP_OUT="$(mktemp)"
trap 'rm -f "${HELP_OUT}"' EXIT

cd "${PLUGIN_ROOT}"
node "${DIST_INDEX}" tooling --help >"${HELP_OUT}" 2>&1

if ! grep -qE '\bdetect\b' "${HELP_OUT}"; then
  cat "${HELP_OUT}" >&2
  fail "tooling --help does not list detect"
fi
if ! grep -qE '\bstatus\b' "${HELP_OUT}"; then
  cat "${HELP_OUT}" >&2
  fail "tooling --help does not list status"
fi
if ! grep -qE '\bpolicy\b' "${HELP_OUT}"; then
  cat "${HELP_OUT}" >&2
  fail "tooling --help does not list policy"
fi

DETECT_OUT="$(mktemp)"
trap 'rm -f "${HELP_OUT}" "${DETECT_OUT}"' EXIT

node "${DIST_INDEX}" tooling detect >"${DETECT_OUT}" 2>&1 \
  || { cat "${DETECT_OUT}" >&2; fail "tooling detect exited non-zero"; }

if ! grep -q '"rg"' "${DETECT_OUT}"; then
  cat "${DETECT_OUT}" >&2
  fail "tooling detect output does not contain expected tool name 'rg'"
fi

STATUS_OUT="$(mktemp)"
trap 'rm -f "${HELP_OUT}" "${DETECT_OUT}" "${STATUS_OUT}"' EXIT

node "${DIST_INDEX}" tooling status >"${STATUS_OUT}" 2>&1 \
  || { cat "${STATUS_OUT}" >&2; fail "tooling status exited non-zero"; }

if ! grep -q '"capabilities"' "${STATUS_OUT}"; then
  cat "${STATUS_OUT}" >&2
  fail "tooling status output does not contain capabilities"
fi

POLICY_OUT="$(mktemp)"
trap 'rm -f "${HELP_OUT}" "${DETECT_OUT}" "${STATUS_OUT}" "${POLICY_OUT}"' EXIT

node "${DIST_INDEX}" tooling policy >"${POLICY_OUT}" 2>&1 \
  || { cat "${POLICY_OUT}" >&2; fail "tooling policy exited non-zero"; }

if ! grep -q '"contract_version"' "${POLICY_OUT}"; then
  cat "${POLICY_OUT}" >&2
  fail "tooling policy output does not contain contract_version"
fi

echo "PASS: v003 tooling command regression"
