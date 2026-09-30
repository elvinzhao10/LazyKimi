#!/bin/bash
# v103-lifecycle-entrypoint-regression.sh — bounded node:test entrypoint over
# the durable lifecycle surface. Ported from lazyzcode v1.3.3
# tests/v103-lifecycle-entrypoint-regression.sh (same five-file selection).
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
node --test \
    "${PLUGIN_ROOT}/tests/lifecycle-source-inventory.test.js" \
    "${PLUGIN_ROOT}/tests/lifecycle-entrypoint.test.js" \
    "${PLUGIN_ROOT}/tests/lifecycle-entrypoint-bootstrap.test.js" \
    "${PLUGIN_ROOT}/tests/lifecycle-host-handoff.test.js" \
    "${PLUGIN_ROOT}/tests/lifecycle-platform-fixtures.test.js"
