#!/usr/bin/env bash
# v003-compact-recovery-regression.sh
# v1.3.4 port: PreCompact/PostCompact carry context-recovery semantics —
# pre-compact.sh records a pre_compact ledger event on the active run;
# post-compact.sh writes a context-recovery checkpoint under
# .lazykimi/runs/<id>/checkpoints/, records a post_compact event, and
# re-anchors context via additionalContext. Without an active run both hooks
# stay silent no-ops (pre-compact) / reminder-only (post-compact). Fail-open.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

fail() { echo "FAIL: $1" >&2; exit 1; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/lazykimi-compact-test.XXXXXX")"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

# 1. Seed a temp project with an active run (v1.3.4 state model).
mkdir -p "$TMP"
CWD="$TMP" bash "$PLUGIN_ROOT/scripts/state/create-run.sh" compact-test "compact recovery regression" >/dev/null \
  || fail "create-run failed"

EVENTS="$TMP/.lazykimi/runs/compact-test/events.jsonl"

# 2. PreCompact with no cwd in payload falls back to PWD; run hooks from $TMP.
cd "$TMP"
printf '{"hook_event_name":"PreCompact"}\n' | CWD="$TMP" bash "$PLUGIN_ROOT/hooks/pre-compact.sh" \
  || fail "pre-compact.sh exited non-zero"

grep -q '"event": *"pre_compact"' "$EVENTS" || fail "pre_compact ledger event missing"

# 3. PostCompact writes a checkpoint + ledger event + additionalContext reminder.
OUT=$(printf '{"hook_event_name":"PostCompact","cwd":"%s"}\n' "$TMP" | CWD="$TMP" bash "$PLUGIN_ROOT/hooks/post-compact.sh")
grep -q 'additionalContext' <<<"$OUT" || fail "post-compact must emit additionalContext: $OUT"
grep -Eq 'AGENTS|restoration' <<<"$OUT" || fail "post-compact must re-anchor project memory: $OUT"
grep -q '"event": *"post_compact"' "$EVENTS" || fail "post_compact ledger event missing"
CKPTS=$(find "$TMP/.lazykimi/runs/compact-test/checkpoints" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
[ "$CKPTS" -ge 1 ] || fail "context-recovery checkpoint missing"

# 4. SessionStart stays advisory (strict JSON or nothing, always exit 0).
OUT=$(printf '{"hook_event_name":"SessionStart","cwd":"%s"}\n' "$TMP" | CWD="$TMP" bash "$PLUGIN_ROOT/hooks/session-start.sh")
grep -Eq '^[{].*additionalContext' <<<"$OUT" || fail "session-start must emit strict JSON additionalContext: $OUT"

# 5. Fail-open: hooks survive empty payloads and unknown projects.
printf '' | CWD="$TMP/nonexistent" bash "$PLUGIN_ROOT/hooks/pre-compact.sh" || fail "pre-compact must fail open"
printf '' | CWD="$TMP/nonexistent" bash "$PLUGIN_ROOT/hooks/post-compact.sh" >/dev/null 2>&1 || fail "post-compact must fail open"
printf 'not-json{{{' | CWD="$TMP" bash "$PLUGIN_ROOT/hooks/pre-compact.sh" >/dev/null 2>&1 || fail "pre-compact must fail open on malformed input"

echo "PASS: v003 compact recovery regression (v1.3.4 semantics)"
