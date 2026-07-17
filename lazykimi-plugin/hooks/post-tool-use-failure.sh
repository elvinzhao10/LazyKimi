#!/usr/bin/env bash
# LazyKimi — PostToolUseFailure hook
# Advisory: logs tool failures to .lazykimi/evidence/test-runs.md. Never blocks.
set -euo pipefail
trap 'echo "[LazyKimi] post-tool-use-failure internal error; failing open" >&2; exit 0' ERR

[ -t 0 ] && exit 0
payload=$(cat)
truncated=${payload:0:200}
ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)

evidence_dir="$PWD/.lazykimi/evidence"
evidence_file="$evidence_dir/test-runs.md"

mkdir -p "$evidence_dir" 2>/dev/null || true
printf -- '- %s PostToolUseFailure: %s\n' "$ts" "$truncated" >> "$evidence_file" 2>/dev/null || true

echo "[${ts}] PostToolUseFailure: ${truncated}" >&2
exit 0
