#!/usr/bin/env bash
# v001-skill-count-regression.sh
# Verify 17 skills present, each with valid YAML frontmatter (starts with ---).
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/lazykimi-skill-count.XXXXXX")"

cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

EXPECTED=17
SKILLS_DIR="$PLUGIN_ROOT/.kimi-code/skills"
[ -d "$SKILLS_DIR" ] || fail "skills dir missing"

shopt -s nullglob
skill_dirs=("$SKILLS_DIR"/*/)
shopt -u nullglob

count=0
for d in "${skill_dirs[@]}"; do
  name="$(basename "$d")"
  case "$name" in
    lazy-*) ;;
    *) continue ;;
  esac
  skill="$d/SKILL.md"
  [ -f "$skill" ] || fail "missing SKILL.md for $name"
  # Frontmatter delimiter: first line must be exactly ---
  head -1 "$skill" | grep -q '^---$' \
    || fail "$name SKILL.md missing frontmatter delimiter (---)"
  # Required frontmatter keys.
  fm="$(sed -n '/^---$/,/^---$/p' "$skill")"
  echo "$fm" | grep -q '^name:' || fail "$name SKILL.md missing 'name' field"
  echo "$fm" | grep -q '^description:' || fail "$name SKILL.md missing 'description' field"
  count=$((count + 1))
done

[ "$count" -eq "$EXPECTED" ] \
  || fail "expected $EXPECTED skills, found $count"

echo "v001 skill-count regression: PASS"
