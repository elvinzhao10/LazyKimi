#!/usr/bin/env bash
# LazyKimi — SessionEnd hook
# Advisory: appends session-end timestamp line to .lazykimi/state/sessions.json
# if it exists. Never blocks.
set -euo pipefail
trap 'echo "[LazyKimi] session-end internal error; failing open" >&2; exit 0' ERR

[ -t 0 ] && exit 0
payload=$(cat)
truncated=${payload:0:200}
ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)

sessions_file="$PWD/.lazykimi/state/sessions.json"
if [ -f "$sessions_file" ]; then
  printf '%s SessionEnd %s\n' "$ts" "$truncated" >> "$sessions_file" 2>/dev/null || true
fi

echo "[${ts}] SessionEnd: ${truncated}" >&2
exit 0
