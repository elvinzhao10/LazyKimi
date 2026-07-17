#!/usr/bin/env bash
# LazyKimi — StopFailure hook
# Advisory: logs Stop hook failures to stderr. Never blocks.
set -euo pipefail
trap 'echo "[LazyKimi] stop-failure internal error; failing open" >&2; exit 0' ERR

[ -t 0 ] && exit 0
payload=$(cat)
truncated=${payload:0:200}
ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)

echo "[${ts}] StopFailure: ${truncated}" >&2
exit 0
