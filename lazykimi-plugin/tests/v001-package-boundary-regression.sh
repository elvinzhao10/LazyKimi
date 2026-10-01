#!/usr/bin/env bash
# v001-package-boundary-regression.sh
# Verify the lazykimi-plugin package is self-contained within lazykimi-plugin/
# with no escaped symlinks or parent-dir refs (root runtime copies removed in v1.3.4).
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$PLUGIN_ROOT/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/lazykimi-pkg-boundary.XXXXXX")"

cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

[ -d "$PLUGIN_ROOT" ] || fail "lazykimi-plugin/ missing"

# 1. Expected package layout (dirs that must exist inside the plugin root).
for d in .kimi-code agents commands hooks mcp src contracts tooling scripts; do
  [ -d "$PLUGIN_ROOT/$d" ] || fail "missing package dir: $d"
done

# 2. Root-level runtime copies are intentionally absent (v1.3.4 repo hygiene):
#    the shipped payload is lazykimi-plugin/.kimi-code/ + .lazykimi/schemas/.
[ ! -e "$REPO_ROOT/.lazykimi" ] || fail "root .lazykimi/ runtime copy must not exist"
[ ! -e "$REPO_ROOT/.kimi-code" ] || fail "root .kimi-code/ runtime copy must not exist"
[ ! -e "$REPO_ROOT/.trae" ] || fail "root .trae/ must not exist"
[ ! -e "$REPO_ROOT/.lazytrae" ] || fail "root .lazytrae/ must not exist"
[ -d "$PLUGIN_ROOT/.lazykimi/schemas" ] || fail "shipped .lazykimi/schemas/ missing"

# 3. No git-tracked symlink inside the plugin escapes the plugin root. The
#    scripts/hooks -> ../hooks bridge serves the byte-identical family harness
#    tests (v122 semantic parity addresses hook drivers at scripts/hooks); it
#    resolves INSIDE the plugin root, so containment is decided on the resolved
#    target, not on a lexical ../ prefix.
cd "$REPO_ROOT"
while IFS= read -r f; do
  if [ -L "$f" ]; then
    resolved="$(cd "$(dirname "$f")" && cd "$(readlink "$f")" 2>/dev/null && pwd -P)" || \
      resolved=""
    case "$resolved" in
      "$PLUGIN_ROOT"|"$PLUGIN_ROOT"/*) ;;
      *) fail "tracked symlink escapes plugin: $f -> $(readlink "$f")" ;;
    esac
  fi
done < <(git ls-files lazykimi-plugin/)

# 4. Plugin code must not reference read-only parent reference dirs
#    (sources/ and any sibling harness dirs) — immutable references, not deps.
if grep -rIlE '(\.\./sources/|\.\./\.trae/|\.\./\.lazytrae/)' \
    "$PLUGIN_ROOT/src" "$PLUGIN_ROOT/mcp" "$PLUGIN_ROOT/tooling" \
    "$PLUGIN_ROOT/hooks" "$PLUGIN_ROOT/scripts" \
    >"$TMP/hits" 2>/dev/null; then
  fail "plugin references parent reference dirs: $(tr '\n' ' ' <"$TMP/hits")"
fi

# 5. Sanity: tracked plugin files are reported under lazykimi-plugin/ prefix.
git ls-files lazykimi-plugin/ | grep -qv '^lazykimi-plugin/' \
  && fail "tracked file outside lazykimi-plugin/ prefix reported" || true

echo "v001 package-boundary regression: PASS"
