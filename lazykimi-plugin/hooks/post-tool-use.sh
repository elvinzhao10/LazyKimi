#!/usr/bin/env bash
# LazyKimi — PostToolUse hook
# Checks for file drift (writes to state/evidence paths) and recommends tools.
# Advisory only — always exits 0.
set -euo pipefail
trap 'echo "[LazyKimi] post-tool-use internal error; failing open" >&2; exit 0' ERR

INPUT=""
[ ! -t 0 ] && INPUT=$(cat) || true
[ -z "$INPUT" ] && exit 0

# Extract tool_name and changed file path (prefer jq, fall back to python3)
tool_name=""
file_path=""
if command -v jq >/dev/null 2>&1; then
  tool_name=$(printf '%s' "$INPUT" | jq -r '.tool_name // .toolName // ""' 2>/dev/null || true)
  file_path=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_input.filePath // .tool_input.path // .tool_input.target // ""' 2>/dev/null || true)
elif command -v python3 >/dev/null 2>&1; then
  tool_name=$(printf '%s' "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_name','') or d.get('toolName',''))" 2>/dev/null || true)
  file_path=$(printf '%s' "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); ti=d.get('tool_input',d.get('toolInput',{})); print((ti.get('file_path','') or ti.get('filePath','') or ti.get('path','') or ti.get('target','')) if isinstance(ti,dict) else '')" 2>/dev/null || true)
fi

[ -z "$tool_name" ] && exit 0

# Only inspect write/edit tools
case "$tool_name" in
  Write|Edit|MultiEdit|apply_patch|delete_files|DeleteFile) ;;
  *) exit 0 ;;
esac

# File drift: flag writes that look like unauthorized state mutation
if [ -n "$file_path" ]; then
  case "$file_path" in
    *.lazykimi/state/*|*/.lazykimi/state/*)
      echo "[LazyKimi] State file touched: $file_path — ensure this is an authorized state mutation."
      ;;
    *.lazykimi/evidence/*|*/.lazykimi/evidence/*)
      echo "[LazyKimi] Evidence file written: $file_path — keep evidence receipts current."
      ;;
    */AGENTS.md|*/.kimi-code/AGENTS.md)
      echo "[LazyKimi] AGENTS.md modified — re-read it to keep context current."
      ;;
    *)
      echo "[LazyKimi] File changed: $file_path"
      ;;
  esac
fi

# Recommend tools based on the edit
echo "[LazyKimi] Tip: lazy-debugging for failures, lazy-reviewer before claiming done, lazy-verifier to run gates."

exit 0
