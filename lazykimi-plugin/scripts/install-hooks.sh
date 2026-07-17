#!/usr/bin/env bash
# LazyKimi — hooks installer
# Appends LazyKimi hook entries to ~/.kimi-code/config.toml idempotently,
# and copies hook scripts into ~/.kimi-code/hooks/ so the relative command
# paths in hooks-config.toml resolve.
set -euo pipefail

CONFIG_DIR="${HOME}/.kimi-code"
CONFIG_FILE="$CONFIG_DIR/config.toml"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOKS_DIR="$SCRIPT_DIR/../hooks"
TEMPLATE="$HOOKS_DIR/hooks-config.toml"
MARKER="# LazyKimi hooks for Kimi Code CLI"

# 1. Ensure ~/.kimi-code/ and hooks/ exist
mkdir -p "$CONFIG_DIR" "$CONFIG_DIR/hooks"

# 2. Create config.toml if missing
if [ ! -f "$CONFIG_FILE" ]; then
  touch "$CONFIG_FILE"
  echo "[LazyKimi] Created $CONFIG_FILE"
fi

# 3. Idempotency: skip if LazyKimi hooks already present
if grep -qF "$MARKER" "$CONFIG_FILE" 2>/dev/null; then
  echo "[LazyKimi] Hooks already present in $CONFIG_FILE — nothing to do."
else
  if [ ! -f "$TEMPLATE" ]; then
    echo "[LazyKimi] ERROR: template not found: $TEMPLATE" >&2
    exit 1
  fi
  # Ensure trailing newline before appending
  if [ -s "$CONFIG_FILE" ]; then
    last_byte=$(tail -c1 "$CONFIG_FILE" 2>/dev/null || true)
    if [ "$last_byte" != "" ]; then
      printf '\n' >> "$CONFIG_FILE"
    fi
  fi
  cat "$TEMPLATE" >> "$CONFIG_FILE"
  echo "[LazyKimi] Hooks appended to $CONFIG_FILE"
fi

# 4. Copy hook scripts into ~/.kimi-code/hooks/
if [ -d "$HOOKS_DIR" ]; then
  for script in session-start.sh user-prompt-submit.sh pre-tool-use.sh post-tool-use.sh \
                stop-gate.sh subagent-stop.sh pre-compact.sh post-compact.sh; do
    if [ -f "$HOOKS_DIR/$script" ]; then
      cp "$HOOKS_DIR/$script" "$CONFIG_DIR/hooks/" 2>/dev/null || true
      chmod +x "$CONFIG_DIR/hooks/$script" 2>/dev/null || true
    fi
  done
  echo "[LazyKimi] Hook scripts copied to $CONFIG_DIR/hooks/"
fi

echo "[LazyKimi] Install complete. Review $CONFIG_FILE and restart Kimi Code CLI."
exit 0
