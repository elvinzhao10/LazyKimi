#!/usr/bin/env bash
# permission-result.sh — Kimi PermissionResult hook (critical event).
# Advisory audit consumer: records the permission decision (outcome) into the
# same normalized .lazykimi/ ledger written by permission-request.sh. See
# permission-record.js for the ported v1.3.3 consumer semantics
# (contracts/kimi-hook-consumers.v1.json).
#
# Kimi output contract: print NOTHING on stdout; diagnostics to stderr.
# ALWAYS exits 0.
set -u
exec node "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/permission-record.js" PermissionResult
