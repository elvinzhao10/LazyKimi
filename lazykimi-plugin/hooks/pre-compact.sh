#!/usr/bin/env bash
# LazyKimi — PreCompact hook
# Snapshots .lazykimi/ state before compaction. Fail-open — never blocks compaction.
set -euo pipefail
trap 'echo "[LazyKimi] pre-compact internal error; failing open" >&2; exit 0' ERR

INPUT=""
[ ! -t 0 ] && INPUT=$(cat) || true
CWD="$PWD"
if [ -n "$INPUT" ] && command -v jq >/dev/null 2>&1; then
  CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // ""' 2>/dev/null || echo "")
  [ -z "$CWD" ] && CWD="$PWD"
fi

STATE_DIR="$CWD/.lazykimi"
if [ ! -d "$STATE_DIR" ]; then
  exit 0
fi

TS=$(date -u +"%Y%m%dT%H%M%SZ")
ISO=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
CP_DIR="$STATE_DIR/state/checkpoints/cp-$TS"
mkdir -p "$CP_DIR" 2>/dev/null || true

# Snapshot key state files
for f in state/boulder.json state/active-loop.json state/sessions.json config.json; do
  src="$STATE_DIR/$f"
  if [ -f "$src" ]; then
    cp -p "$src" "$CP_DIR/" 2>/dev/null || true
  fi
done

# Write a manifest
if command -v python3 >/dev/null 2>&1; then
  python3 -c "
import json, os
manifest={'timestamp':'$TS','reason':'pre_compact','iso':'$ISO'}
os.makedirs('$CP_DIR', exist_ok=True)
with open('$CP_DIR/manifest.json','w') as f:
    json.dump(manifest, f, indent=2)
" 2>/dev/null || true
else
  printf '{"timestamp":"%s","reason":"pre_compact","iso":"%s"}\n' "$TS" "$ISO" > "$CP_DIR/manifest.json" 2>/dev/null || true
fi

echo "[LazyKimi] Pre-compact snapshot written to $CP_DIR"
exit 0
