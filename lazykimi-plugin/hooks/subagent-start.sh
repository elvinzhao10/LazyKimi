#!/usr/bin/env bash
# LazyKimi — SubagentStart hook
# Advisory: logs subagent start to stderr. Never blocks.
set -euo pipefail
trap 'echo "[LazyKimi] subagent-start internal error; failing open" >&2; exit 0' ERR

[ -t 0 ] && exit 0
payload=$(cat)
truncated=${payload:0:200}
ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)

echo "[${ts}] SubagentStart: ${truncated}" >&2
exit 0
