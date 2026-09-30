#!/usr/bin/env bash
# v003-tooling-command-regression.sh
# Verify the `lazykimi tooling` command exposes the family capability surface
# (detect/status/policy/capability-status) and invokes the ported Python
# tooling layer successfully. User state is sandboxed so the test never
# depends on (or mutates) the real ~/.config/lazyseries config.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DIST_INDEX="${PLUGIN_ROOT}/dist/index.js"

if [ ! -f "${DIST_INDEX}" ]; then
  echo "ERROR: ${DIST_INDEX} not found. Run npm run build first." >&2
  exit 1
fi

fail() { echo "FAIL: $1" >&2; exit 1; }

SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/lazykimi-tooling-cmd.XXXXXX")"
cleanup() { rm -rf "$SANDBOX"; }
trap cleanup EXIT
export XDG_CONFIG_HOME="$SANDBOX/config"

HELP_OUT="$(mktemp)"
trap 'rm -f "${HELP_OUT}"; cleanup' EXIT

cd "${PLUGIN_ROOT}"
node "${DIST_INDEX}" tooling --help >"${HELP_OUT}" 2>&1

if ! grep -qE '\bdetect\b' "${HELP_OUT}"; then
  cat "${HELP_OUT}" >&2
  fail "tooling --help does not list detect"
fi
if ! grep -qE '\bstatus\b' "${HELP_OUT}" || ! grep -q 'capability-status' "${HELP_OUT}"; then
  cat "${HELP_OUT}" >&2
  fail "tooling --help does not list status/capability-status"
fi
if ! grep -qE '\bpolicy\b' "${HELP_OUT}"; then
  cat "${HELP_OUT}" >&2
  fail "tooling --help does not list policy"
fi

DETECT_OUT="$(mktemp)"
trap 'rm -f "${HELP_OUT}" "${DETECT_OUT}"; cleanup' EXIT

node "${DIST_INDEX}" tooling detect >"${DETECT_OUT}" 2>&1 \
  || { cat "${DETECT_OUT}" >&2; fail "tooling detect exited non-zero"; }

if ! grep -q 'PROVIDER: rg' "${DETECT_OUT}"; then
  cat "${DETECT_OUT}" >&2
  fail "tooling detect output does not report the rg provider"
fi

STATUS_OUT="$(mktemp)"
trap 'rm -f "${HELP_OUT}" "${DETECT_OUT}" "${STATUS_OUT}"; cleanup' EXIT

node "${DIST_INDEX}" tooling capability-status --json >"${STATUS_OUT}" 2>&1 \
  || { cat "${STATUS_OUT}" >&2; fail "tooling capability-status exited non-zero"; }

if ! grep -q '"records"' "${STATUS_OUT}"; then
  cat "${STATUS_OUT}" >&2
  fail "tooling capability-status output does not contain readiness records"
fi
if ! grep -q '"route": "selection-only"' "${STATUS_OUT}"; then
  cat "${STATUS_OUT}" >&2
  fail "tooling capability-status does not report the selection-only adaptive route"
fi
if ! grep -q '"hostReadiness": "pending"' "${STATUS_OUT}"; then
  cat "${STATUS_OUT}" >&2
  fail "tooling capability-status does not report pending host readiness"
fi

ALIAS_OUT="$(mktemp)"
trap 'rm -f "${HELP_OUT}" "${DETECT_OUT}" "${STATUS_OUT}" "${ALIAS_OUT}"; cleanup' EXIT

node "${DIST_INDEX}" tooling status >"${ALIAS_OUT}" 2>&1 \
  || { cat "${ALIAS_OUT}" >&2; fail "tooling status exited non-zero"; }

if ! grep -q 'CAPABILITY:' "${ALIAS_OUT}"; then
  cat "${ALIAS_OUT}" >&2
  fail "tooling status output does not contain capability records"
fi

POLICY_OUT="$(mktemp)"
trap 'rm -f "${HELP_OUT}" "${DETECT_OUT}" "${STATUS_OUT}" "${ALIAS_OUT}" "${POLICY_OUT}"; cleanup' EXIT

node "${DIST_INDEX}" tooling policy >"${POLICY_OUT}" 2>&1 \
  || { cat "${POLICY_OUT}" >&2; fail "tooling policy exited non-zero"; }

if ! grep -q '"contract_digest"' "${POLICY_OUT}"; then
  cat "${POLICY_OUT}" >&2
  fail "tooling policy output does not contain contract_digest"
fi

echo "PASS: v003 tooling command regression"
