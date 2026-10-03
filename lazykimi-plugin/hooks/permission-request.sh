#!/usr/bin/env bash
# permission-request.sh — Kimi PermissionRequest hook (critical event).
# Advisory audit consumer: records a normalized, redacted approval-request
# event into the workspace .lazykimi/ ledger. See permission-record.js for
# the ported v1.3.5 consumer semantics (contracts/kimi-hook-consumers.v1.json).
#
# Kimi output contract: print NOTHING on stdout; diagnostics to stderr.
# ALWAYS exits 0 — this hook never denies a permission request.
set -u
exec node "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/permission-record.js" PermissionRequest
