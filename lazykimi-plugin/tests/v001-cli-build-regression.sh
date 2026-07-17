#!/usr/bin/env bash
# v001-cli-build-regression.sh
# Verify `npm run build` succeeds and the CLI entrypoint is usable.
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/lazykimi-cli-build.XXXXXX")"

cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

cd "$PLUGIN_ROOT"
[ -f package.json ] || fail "package.json missing"
[ -d node_modules ] || fail "node_modules missing (run npm ci first)"

# 1. Build (tsc only, no network required).
npm run build >"$TMP/build.log" 2>&1 \
  || { cat "$TMP/build.log" >&2; fail "npm run build failed"; }

# 2. Entrypoint produced.
[ -f dist/index.js ] || fail "dist/index.js not produced by build"
head -1 dist/index.js | grep -q '^#!' \
  || fail "dist/index.js missing shebang"

# 3. CLI --help prints usage and exits 0.
node dist/index.js --help >"$TMP/help.out" 2>&1 || fail "CLI --help exited non-zero"
grep -q 'Usage: lazykimi' "$TMP/help.out" || fail "CLI --help missing usage line"
grep -q 'init' "$TMP/help.out" || fail "CLI --help missing init command"
grep -q 'doctor' "$TMP/help.out" || fail "CLI --help missing doctor command"

# 4. Unknown command exits non-zero (graceful, not a crash).
if node dist/index.js no-such-command >"$TMP/bad.out" 2>&1; then
  fail "unknown command was accepted"
fi
grep -q 'Unknown command' "$TMP/bad.out" || fail "unknown command did not report error"

echo "v001 cli-build regression: PASS"
