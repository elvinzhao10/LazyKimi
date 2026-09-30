#!/usr/bin/env bash
# notification.sh — Kimi Notification hook (advisory, no-op logger).
# v1.3.3 mapped semantics: Kimi-only event with no family gating analogue —
# log a bounded, redaction-safe trace to stderr only. Never writes state.
#
# Kimi output contract: print NOTHING on stdout; diagnostics to stderr.
# Advisory only — ALWAYS exits 0.
set -uo pipefail

INPUT=$(head -c 1048576 || true)
ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
# Bounded trace; never echo the raw payload (it may carry prompt content).
printf '[%s] Notification received (payload %s bytes)\n' "$ts" "$(printf '%s' "$INPUT" | wc -c | tr -d ' ')" >&2

exit 0
