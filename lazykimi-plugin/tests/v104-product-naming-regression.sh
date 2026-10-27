#!/usr/bin/env bash
# v104-product-naming-regression.sh
# Gate the repo-root product-naming guard (T20): the positive run must pass on
# the real tree, an injected sibling-product string in a skill must fail it,
# and breaking a family contract's bytes must resurface the hash exemption.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GUARD="${REPO_ROOT}/scripts/check-product-naming.js"

fail() { echo "FAIL: $1" >&2; exit 1; }

[ -f "$GUARD" ] || fail "missing guard script: ${GUARD}"

# 1) Positive: the real tree is clean.
if ! node "$GUARD" >"$TMPDIR/.v104-naming.out" 2>&1; then
    cat "$TMPDIR/.v104-naming.out" >&2
    fail "product-naming guard failed on the real tree"
fi
grep -q 'NAMING_OK' "$TMPDIR/.v104-naming.out" || fail "guard did not report NAMING_OK"

# 2) Negative: injecting a sibling-product string into a skill must fail.
T1="$(mktemp -d)"
trap 'rm -rf "$T1" "${T3:-}"' EXIT
mkdir -p "$T1/lazykimi-plugin/.kimi-code/skills/lazy-demo"
printf '%s\n' '---' 'name: lazy-demo' '---' 'Ported from lazyzcode.' \
    > "$T1/lazykimi-plugin/.kimi-code/skills/lazy-demo/SKILL.md"
printf '%s\n' '{"formerDisplayNames":[],"stableIdentityFiles":[],"currentHostPages":[]}' \
    > "$T1/.product-naming-allowlist.json"
if PRODUCT_NAMING_ROOT="$T1" node "$GUARD" >"$TMPDIR/.v104-neg1.out" 2>&1; then
    cat "$TMPDIR/.v104-neg1.out" >&2
    fail "guard accepted an injected lazyzcode string in a skill"
fi
grep -q 'lazy-demo/SKILL.md :: lazyzcode' "$TMPDIR/.v104-neg1.out" \
    || { cat "$TMPDIR/.v104-neg1.out" >&2; fail "negative run did not name the injected skill occurrence"; }

# 3) Negative: tampering with a sidecar-pinned family contract must break the
#    hash exemption (the family vocabulary it legitimately contains then
#    resurfaces for review instead of silently riding the exemption).
T2="$(mktemp -d)"
mkdir -p "$T2/lazykimi-plugin/contracts"
printf '%s\n' '{"formerDisplayNames":[],"stableIdentityFiles":[],"currentHostPages":[]}' \
    > "$T2/.product-naming-allowlist.json"
cp "${REPO_ROOT}/lazykimi-plugin/contracts/lazyseries-shared-semantics.v1.json" \
   "${REPO_ROOT}/lazykimi-plugin/contracts/lazyseries-shared-semantics.v1.json.sha256" \
   "$T2/lazykimi-plugin/contracts/"
printf '\n<!-- local edit -->\n' >> "$T2/lazykimi-plugin/contracts/lazyseries-shared-semantics.v1.json"
if PRODUCT_NAMING_ROOT="$T2" node "$GUARD" >"$TMPDIR/.v104-neg2.out" 2>&1; then
    cat "$TMPDIR/.v104-neg2.out" >&2
    fail "guard kept the hash exemption for a tampered family contract"
fi
grep -q 'lazyseries-shared-semantics.v1.json :: ' "$TMPDIR/.v104-neg2.out" \
    || { cat "$TMPDIR/.v104-neg2.out" >&2; fail "tampered-contract run did not name the resurfaced vocabulary"; }
rm -rf "$T2"

# 4) The schema exception is scoped to one token in one test file.
T3="$(mktemp -d)"
health_path='lazykimi-plugin/shared/dashboard-host/test/health-route.test.mjs'
mkdir -p "$T3/$(dirname "$health_path")"
cp "$REPO_ROOT/$health_path" "$T3/$health_path"
retired_token="lazy"'buddy'
printf '{"formerDisplayNames":[{"path":"%s","text":"%s","count":1,"classification":"stable-machine-id","reason":"Shared wire schema identifier."}],"stableIdentityFiles":[],"currentHostPages":[]}\n' \
    "$health_path" "$retired_token" > "$T3/.product-naming-allowlist.json"
PRODUCT_NAMING_ROOT="$T3" node "$GUARD" >"$TMPDIR/.v104-scoped.out" 2>&1 \
    || { cat "$TMPDIR/.v104-scoped.out" >&2; fail "guard rejected the scoped schema identifier"; }
printf '\n%s\n' "$retired_token" >> "$T3/$health_path"
if PRODUCT_NAMING_ROOT="$T3" node "$GUARD" >"$TMPDIR/.v104-count.out" 2>&1; then
    fail "guard accepted a second occurrence in the schema test"
fi
grep -q 'expected 1 allowlisted occurrence(s), found 2' "$TMPDIR/.v104-count.out" \
    || { cat "$TMPDIR/.v104-count.out" >&2; fail "guard did not enforce the scoped occurrence count"; }

echo "PASS: v104 product-naming guard (positive, injected-skill, tampered-contract, scoped-count)"
