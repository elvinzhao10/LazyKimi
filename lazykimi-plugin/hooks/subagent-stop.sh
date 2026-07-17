#!/usr/bin/env bash
# LazyKimi — SubagentStop hook
# Verifies sub-agent evidence before allowing stop. Fail-open with warnings.
set -euo pipefail
trap 'echo "[LazyKimi] subagent-stop internal error; failing open" >&2; exit 0' ERR

INPUT=""
[ ! -t 0 ] && INPUT=$(cat) || true
[ -z "$INPUT" ] && exit 0

# Extract fields (prefer jq, fall back to python3)
agent_type=""
last_msg=""
cwd=""
if command -v jq >/dev/null 2>&1; then
  agent_type=$(printf '%s' "$INPUT" | jq -r '.agent_type // .agent_type_name // ""' 2>/dev/null || true)
  last_msg=$(printf '%s' "$INPUT" | jq -r '.last_assistant_message // ""' 2>/dev/null || true)
  cwd=$(printf '%s' "$INPUT" | jq -r '.cwd // ""' 2>/dev/null || true)
elif command -v python3 >/dev/null 2>&1; then
  agent_type=$(printf '%s' "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('agent_type','') or d.get('agent_type_name',''))" 2>/dev/null || true)
  last_msg=$(printf '%s' "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('last_assistant_message',''))" 2>/dev/null || true)
  cwd=$(printf '%s' "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('cwd',''))" 2>/dev/null || true)
fi
[ -z "$cwd" ] && cwd="$PWD"

# Only verify implementer/coder sub-agents
case "$agent_type" in
  *implementer*|*coder*|*hephaestus*) ;;
  *) exit 0 ;;
esac

[ -z "$last_msg" ] && exit 0

# Look for EVIDENCE_RECORDED: <path> marker
ev_path=""
if command -v python3 >/dev/null 2>&1; then
  ev_path=$(printf '%s' "$last_msg" | python3 -c "import sys,re; m=re.search(r'EVIDENCE_RECORDED:\s*(\S+)', sys.stdin.read()); print(m.group(1) if m else '')" 2>/dev/null || true)
else
  ev_path=$(printf '%s' "$last_msg" | grep -oE 'EVIDENCE_RECORDED:[[:space:]]*[^[:space:]]+' | sed 's/.*:[[:space:]]*//' 2>/dev/null || true)
fi

if [ -z "$ev_path" ]; then
  echo "[LazyKimi] SubagentStop: no EVIDENCE_RECORDED marker found in implementer output." >&2
  exit 0
fi

# Verify evidence file exists and is non-empty
[ "${ev_path:0:1}" != "/" ] && ev_path="$cwd/$ev_path"
if [ ! -f "$ev_path" ]; then
  echo "[LazyKimi] SubagentStop: evidence file does not exist: $ev_path" >&2
  exit 0
fi
if [ ! -s "$ev_path" ]; then
  echo "[LazyKimi] SubagentStop: evidence file is empty: $ev_path" >&2
  exit 0
fi

echo "[LazyKimi] SubagentStop: evidence verified at $ev_path"
exit 0
