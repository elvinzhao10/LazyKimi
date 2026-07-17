#!/usr/bin/env bash
# LazyKimi — hooks installer (config.toml route)
#
# Appends LazyKimi [[hooks]] entries to ~/.kimi-code/config.toml with ABSOLUTE
# paths to the project's hook scripts. Use this when you cloned the repo and
# ran `lazykimi init` but did NOT install as a plugin via /plugins install
# (plugin manifest hooks auto-activate from kimi.plugin.json).
#
# Idempotent: skips entries whose command string is already present in
# config.toml. A backup config.toml.bak is written before the first modification.
set -euo pipefail

PROJECT_ROOT="${PWD:-}"
CONFIG_DIR="${HOME}/.kimi-code"
CONFIG_FILE="$CONFIG_DIR/config.toml"

usage() {
  cat <<'EOF'
Usage: bash install-hooks.sh [--project-root <path>] [--help]

Appends LazyKimi [[hooks]] entries to ~/.kimi-code/config.toml with ABSOLUTE
paths to <project>/.kimi-code/hooks/<name>.sh so hooks resolve regardless of
CWD when Kimi Code CLI invokes them.

Options:
  --project-root <path>   Project where LazyKimi hooks were installed via
                          `lazykimi init` (default: $PWD). The script looks
                          for hook scripts under <path>/.kimi-code/hooks/
                          (installed location) and falls back to <path>/hooks/
                          (plugin source layout).
  --help, -h              Show this help message and exit 0.

Idempotent: skips entries whose command string is already present in
config.toml. A backup config.toml.bak is written before the first new entry
is appended. Restart Kimi Code CLI after running this script.

Events wired (mirrors kimi.plugin.json manifest hooks array):
  SessionStart, UserPromptSubmit, PreToolUse (Bash), PostToolUse, Stop,
  SubagentStop, PreCompact, PostCompact.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --project-root)
      shift
      if [ $# -eq 0 ]; then
        echo "install-hooks.sh: --project-root requires a value" >&2
        exit 1
      fi
      PROJECT_ROOT="$1"
      shift
      ;;
    --project-root=*) PROJECT_ROOT="${1#--project-root=}"; shift ;;
    *) echo "install-hooks.sh: unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [ -z "$PROJECT_ROOT" ]; then
  echo "install-hooks.sh: --project-root is required (or run from the project root)" >&2
  exit 1
fi

# Resolve to absolute path
if [ ! -d "$PROJECT_ROOT" ]; then
  echo "install-hooks.sh: project root not found: $PROJECT_ROOT" >&2
  exit 1
fi
PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"

# Hook scripts live in <project>/.kimi-code/hooks/ after `lazykimi init`.
# Fall back to <project>/hooks/ (plugin source layout) so the script also
# works against a cloned plugin root for testing.
HOOKS_DIR=""
if [ -d "$PROJECT_ROOT/.kimi-code/hooks" ]; then
  HOOKS_DIR="$PROJECT_ROOT/.kimi-code/hooks"
elif [ -d "$PROJECT_ROOT/hooks" ]; then
  HOOKS_DIR="$PROJECT_ROOT/hooks"
else
  echo "install-hooks.sh: hooks directory not found." >&2
  echo "  Looked for: $PROJECT_ROOT/.kimi-code/hooks/" >&2
  echo "  Looked for: $PROJECT_ROOT/hooks/" >&2
  echo "  Run \`lazykimi init --target <project>\` first to copy hook scripts." >&2
  exit 1
fi

# Define the 8 hooks: event|matcher|script|timeout
# (mirrors kimi.plugin.json manifest hooks array)
HOOKS=(
  "SessionStart||session-start.sh|10"
  "UserPromptSubmit||user-prompt-submit.sh|5"
  "PreToolUse|Bash|pre-tool-use.sh|5"
  "PostToolUse||post-tool-use.sh|5"
  "Stop||stop-gate.sh|10"
  "SubagentStop||subagent-stop.sh|5"
  "PreCompact||pre-compact.sh|5"
  "PostCompact||post-compact.sh|5"
)

# Verify all 8 hook scripts exist
MISSING=0
for entry in "${HOOKS[@]}"; do
  IFS='|' read -r _ _ script _ <<< "$entry"
  if [ ! -f "$HOOKS_DIR/$script" ]; then
    echo "install-hooks.sh: missing hook script: $HOOKS_DIR/$script" >&2
    MISSING=$((MISSING + 1))
  fi
done
if [ "$MISSING" -gt 0 ]; then
  echo "install-hooks.sh: $MISSING hook script(s) missing in $HOOKS_DIR." >&2
  echo "  Run \`lazykimi init --target <project>\` first to copy hook scripts." >&2
  exit 1
fi

# Ensure ~/.kimi-code/ exists and config.toml is present
mkdir -p "$CONFIG_DIR"
if [ ! -f "$CONFIG_FILE" ]; then
  touch "$CONFIG_FILE"
  echo "install-hooks.sh: created $CONFIG_FILE"
fi

# Idempotent append: skip entries whose command string is already present
ADDED=0
SKIPPED=0
BACKED_UP=0

for entry in "${HOOKS[@]}"; do
  IFS='|' read -r event matcher script timeout <<< "$entry"
  abs_script="$HOOKS_DIR/$script"
  cmd="bash $abs_script"

  if grep -qF "command = \"$cmd\"" "$CONFIG_FILE" 2>/dev/null; then
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  # Backup config.toml before the first modification
  if [ "$BACKED_UP" -eq 0 ]; then
    cp "$CONFIG_FILE" "$CONFIG_FILE.bak"
    BACKED_UP=1
  fi

  # Ensure file ends with a newline before appending
  if [ -s "$CONFIG_FILE" ]; then
    last_char="$(tail -c1 "$CONFIG_FILE" 2>/dev/null || true)"
    if [ "$last_char" != $'\n' ]; then
      printf '\n' >> "$CONFIG_FILE"
    fi
  fi

  {
    printf '[[hooks]]\n'
    printf 'event = "%s"\n' "$event"
    if [ -n "$matcher" ]; then
      printf 'matcher = "%s"\n' "$matcher"
    fi
    printf 'command = "%s"\n' "$cmd"
    printf 'timeout = %s\n' "$timeout"
    printf '\n'
  } >> "$CONFIG_FILE"

  ADDED=$((ADDED + 1))
done

echo "Added $ADDED new [[hooks]] entries to $CONFIG_FILE ($SKIPPED already present, skipped)."
if [ "$BACKED_UP" -eq 1 ]; then
  echo "Backup written to $CONFIG_FILE.bak"
fi
if [ "$ADDED" -gt 0 ]; then
  echo "Restart Kimi Code CLI to activate hooks."
fi
exit 0
