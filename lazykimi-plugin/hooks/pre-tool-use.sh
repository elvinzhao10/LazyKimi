#!/usr/bin/env bash
# LazyKimi — PreToolUse hook
# Blocks destructive ops and secret leakage. Uses exit 2 to block (stderr shown to user).
# Fail-open on internal errors (ERR trap -> exit 0). Deliberate blocks use exit 2.
#
# Blocks: rm -rf /, rm -rf ~, rm -rf $HOME, git push --force/-f to main|master,
#         git reset --hard, sk-xxx secrets, curl/wget http://, chmod 777,
#         dd if=/dev/zero of=/dev/.
set -euo pipefail
trap 'echo "[LazyKimi] pre-tool-use internal error; failing open" >&2; exit 0' ERR

INPUT=""
[ ! -t 0 ] && INPUT=$(cat) || true
[ -z "$INPUT" ] && exit 0

# Extract tool_name and command (prefer jq, fall back to python3)
tool_name=""
cmd=""
if command -v jq >/dev/null 2>&1; then
  tool_name=$(printf '%s' "$INPUT" | jq -r '.tool_name // .toolName // ""' 2>/dev/null || true)
  cmd=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // .tool_input.cmd // .toolInput.command // ""' 2>/dev/null || true)
elif command -v python3 >/dev/null 2>&1; then
  tool_name=$(printf '%s' "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_name','') or d.get('toolName',''))" 2>/dev/null || true)
  cmd=$(printf '%s' "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); ti=d.get('tool_input',d.get('toolInput',{})); print(ti.get('command','') or ti.get('cmd','') if isinstance(ti,dict) else '')" 2>/dev/null || true)
fi
[ -z "$cmd" ] && exit 0

block() { echo "[LazyKimi] BLOCKED: $1" >&2; exit 2; }

# rm -rf (recursive rm) targeting root, home, or $HOME
if printf '%s' "$cmd" | grep -qiE 'rm[[:space:]]+(-[a-z]*[rR][a-z]*|--recursive)' && \
   printf '%s' "$cmd" | grep -qiE '(^|[[:space:]])/( |$)|[[:space:]]~($|/)|[$]HOME($|/)|[$][{]HOME[}]($|/)'; then
  block "recursive delete of root, home, or \$HOME is not permitted"
fi

# git push --force / -f to main or master
if printf '%s' "$cmd" | grep -qiE 'git[[:space:]]+push[[:space:]]+[^|;&]*(--force|-f\b)'; then
  if printf '%s' "$cmd" | grep -qiE '(^|[[:space:]/])(main|master)([[:space:]]|$)'; then
    block "force push to main/master is not permitted"
  fi
fi

# git reset --hard
if printf '%s' "$cmd" | grep -qiE 'git[[:space:]]+reset[[:space:]]+--hard'; then
  block "git reset --hard is not permitted"
fi

# API keys / secrets embedded in command
if printf '%s' "$cmd" | grep -qE 'sk-[A-Za-z0-9]{20,}|gh[pousr]_[A-Za-z0-9]{20,}|Bearer[[:space:]]+[A-Za-z0-9._/+=]{20,}|AKIA[0-9A-Z]{16}'; then
  block "command appears to contain an API key or secret"
fi

# curl/wget to non-HTTPS (http://) URLs
if printf '%s' "$cmd" | grep -qE '(curl|wget)[[:space:]]+[^|;&]*http://'; then
  block "curl/wget to non-HTTPS (http://) URL is not permitted"
fi

# chmod 777
if printf '%s' "$cmd" | grep -qE 'chmod[[:space:]]+777\b'; then
  block "chmod 777 is not permitted"
fi

# dd from /dev/zero to a device
if printf '%s' "$cmd" | grep -qE 'dd[[:space:]]+[^|;&]*if=/dev/zero[^|;&]*of=/dev/'; then
  block "dd from /dev/zero to a device is not permitted"
fi

exit 0
