#!/usr/bin/env bash
# LazyKimi — Interrupt hook
# Advisory: logs user interrupts to stderr. Never blocks.
set -euo pipefail
trap 'echo "[LazyKimi] interrupt internal error; failing open" >&2; exit 0' ERR

[ -t 0 ] && exit 0
payload=$(cat)
truncated=${payload:0:200}
ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)

echo "[${ts}] Interrupt: ${truncated}" >&2
exit 0
