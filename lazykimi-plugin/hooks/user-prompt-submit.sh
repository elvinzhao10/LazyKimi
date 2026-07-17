#!/usr/bin/env bash
# LazyKimi — UserPromptSubmit hook
# Detects ultrawork/ulw keywords (injects skill pointer) and context-pressure markers.
# Advisory only — always exits 0.
set -euo pipefail
trap 'echo "[LazyKimi] user-prompt-submit internal error; failing open" >&2; exit 0' ERR

INPUT=""
[ ! -t 0 ] && INPUT=$(cat) || true
[ -z "$INPUT" ] && exit 0

# Extract prompt (prefer jq, fall back to python3)
prompt=""
if command -v jq >/dev/null 2>&1; then
  prompt=$(printf '%s' "$INPUT" | jq -r '.prompt // .user_prompt // .message // ""' 2>/dev/null || true)
elif command -v python3 >/dev/null 2>&1; then
  prompt=$(printf '%s' "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('prompt','') or d.get('user_prompt','') or d.get('message',''))" 2>/dev/null || true)
fi
[ -z "$prompt" ] && exit 0

# ULTRAWORK trigger detection — inject skill pointer
if printf '%s' "$prompt" | grep -qiE '\b(ultrawork|ulw)\b'; then
  cat <<'ULW_DIRECTIVE'
[LazyKimi] ULTRAWORK MODE DETECTED
Skill pointer: invoke the `lazy-ulw-loop` / `lazy-ulw-plan` skill before continuing.
Execution loop: PIN -> RED -> GREEN -> SURFACE -> CLEAN
Stop rules: no completion claim without evidence. Say "exit ultrawork" to leave this mode.
ULW_DIRECTIVE
fi

# LazyKimi workflow keyword detection
keywords="ulw-loop|start-work|ulw-plan|handoff|init-deep|review-work|remove-ai-slops|verifier|reviewer"
if printf '%s' "$prompt" | grep -qiE "\b($keywords)\b"; then
  echo "[LazyKimi] Workflow keyword detected — ensure the matching lazy-* skill is loaded."
fi

# Context-pressure detection
CONTEXT_MARKERS="context compacted|context_length_exceeded|skill descriptions were shortened|context_too_large|ran out of room|exceeds the context window|long threads and multiple compactions"
if printf '%s' "$prompt" | grep -qiE "($CONTEXT_MARKERS)"; then
  echo "[LazyKimi] Context pressure detected. Consider /compact or re-injecting .lazykimi/ state."
fi

exit 0
