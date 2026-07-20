#!/usr/bin/env bash
# LazyKimi — PostToolUse hook
# Checks for file drift (writes to state/evidence paths), recommends tools,
# and prints relevant .kimi-code/rules/ advisories.
# Advisory only — always exits 0.
set -euo pipefail
trap 'echo "[LazyKimi] post-tool-use internal error; failing open" >&2; exit 0' ERR

INPUT=""
[ ! -t 0 ] && INPUT=$(cat) || true
[ -z "$INPUT" ] && exit 0

# Extract tool_name, single file path, and changed_files list (prefer jq, fall back to python3)
tool_name=""
file_path=""
changed_files=""
if command -v jq >/dev/null 2>&1; then
  tool_name=$(printf '%s' "$INPUT" | jq -r '.tool_name // .toolName // ""' 2>/dev/null || true)
  file_path=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_input.filePath // .tool_input.path // .tool_input.target // ""' 2>/dev/null || true)
  changed_files=$(printf '%s' "$INPUT" | jq -r '(.changed_files // [])[]' 2>/dev/null || true)
elif command -v python3 >/dev/null 2>&1; then
  tool_name=$(printf '%s' "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_name','') or d.get('toolName',''))" 2>/dev/null || true)
  file_path=$(printf '%s' "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); ti=d.get('tool_input',d.get('toolInput',{})); print((ti.get('file_path','') or ti.get('filePath','') or ti.get('path','') or ti.get('target','')) if isinstance(ti,dict) else '')" 2>/dev/null || true)
  changed_files=$(printf '%s' "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print('\\n'.join(d.get('changed_files',[])))" 2>/dev/null || true)
fi

# Collect file paths to inspect
files_to_inspect=""
[ -n "$changed_files" ] && files_to_inspect="$changed_files" || { [ -n "$file_path" ] && files_to_inspect="$file_path"; }

[ -z "$tool_name" ] && [ -z "$files_to_inspect" ] && exit 0

# Only inspect write/edit tools when relying on the legacy single file path
case "$tool_name" in
  Write|Edit|MultiEdit|apply_patch|delete_files|DeleteFile|"") ;;
  *) [ -z "$changed_files" ] && exit 0 ;;
esac

# File drift: flag writes that look like unauthorized state mutation
if [ -n "$files_to_inspect" ]; then
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    case "$f" in
      *.lazykimi/state/*|*/.lazykimi/state/*) echo "[LazyKimi] State file touched: $f — ensure this is an authorized state mutation." ;;
      *.lazykimi/evidence/*|*/.lazykimi/evidence/*) echo "[LazyKimi] Evidence file written: $f — keep evidence receipts current." ;;
      */AGENTS.md|*/.kimi-code/AGENTS.md) echo "[LazyKimi] AGENTS.md modified — re-read it to keep context current." ;;
      *) echo "[LazyKimi] File changed: $f" ;;
    esac
  done <<< "$files_to_inspect"
fi

# Dynamic rule matching: map a file extension to a rule file name.
rule_file_for_extension() {
  case "$1" in
    ts|tsx) echo "typescript.md" ;;
    py) echo "python.md" ;;
    js|jsx) echo "javascript.md" ;;
    sh|bash) echo "bash.md" ;;
    md|markdown) echo "markdown.md" ;;
    json) echo "json.md" ;;
    yaml|yml) echo "yaml.md" ;;
    css) echo "css.md" ;;
    html) echo "html.md" ;;
  esac
}

RULES_DIR="./.kimi-code/rules"
if [ -d "$RULES_DIR" ]; then
  matched_rules=""
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    ext="${f##*.}"
    [ "$ext" = "$f" ] && continue
    rule_name=$(rule_file_for_extension "$ext")
    [ -z "$rule_name" ] && continue
    [ -f "$RULES_DIR/$rule_name" ] && matched_rules="${matched_rules:+$matched_rules$'\n'}$rule_name"
  done <<< "$files_to_inspect"

  if [ -n "$matched_rules" ]; then
    printf '%s' "$matched_rules" | sort -u | while IFS= read -r r; do
      [ -z "$r" ] && continue
      echo "RULE: $r"
    done
  fi
fi

# Recommend tools based on the edit
echo "[LazyKimi] Tip: lazy-debugging for failures, lazy-reviewer before claiming done, lazy-verifier to run gates."

exit 0
