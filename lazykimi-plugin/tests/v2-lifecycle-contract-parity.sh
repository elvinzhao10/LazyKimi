#!/usr/bin/env bash
# v2-lifecycle-contract-parity.sh — lifecycle-v2 writer/reader/contract parity
# between LazyKimi and LazyZCode. Ported from lazyzcode v1.3.3
# tests/v2-lifecycle-contract-parity.sh (which compared LazyTrae vs LazyZCode)
# and adapted to the lazykimi facts:
#   - lazy-harness-active.v2.schema.json is enum-extended (LazyKimi added to
#     the product enum, family growth pattern) — identical outside that enum;
#   - lazy-harness-lifecycle.v2.schema.json is a per-host adaptation (product
#     enum, per-product origin conditionals, .kimi-code/mcp.json declaration
#     path) — checked structurally, not byte-wise;
#   - contracts/fixtures/lifecycle-v2 is a per-host fixture set (excluded from
#     the family-shared byte-identical trees), so both sides prove their own
#     fixtures by running their own lifecycle-v2 contract tests;
#   - lifecycle domain code: state.js, launcher.js, core.js byte-identical;
#     ownership.js differs only by the documented per-product table.
# This is package evidence only. It does not inspect or claim host readiness.
set -euo pipefail

fail() {
    echo "FAIL: $1" >&2
    exit 1
}

LAZYZCODE_ROOT=""
LAZYKIMI_ROOT=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        --lazyzcode-root)
            [ "$#" -ge 2 ] || fail "--lazyzcode-root requires a value"
            LAZYZCODE_ROOT="$2"
            shift 2
            ;;
        --lazykimi-root)
            [ "$#" -ge 2 ] || fail "--lazykimi-root requires a value"
            LAZYKIMI_ROOT="$2"
            shift 2
            ;;
        *)
            fail "unknown argument: $1"
            ;;
    esac
done

case "$LAZYZCODE_ROOT" in /*) ;; *) fail "--lazyzcode-root must be absolute" ;; esac
case "$LAZYKIMI_ROOT" in /*) ;; *) fail "--lazykimi-root must be absolute" ;; esac
LAZYZCODE_ROOT="$(cd "$LAZYZCODE_ROOT" && pwd -P)"
LAZYKIMI_ROOT="$(cd "$LAZYKIMI_ROOT" && pwd -P)"
ZCODE_PLUGIN="$LAZYZCODE_ROOT/plugins/lazyzcode"
KIMI_PLUGIN="$LAZYKIMI_ROOT/lazykimi-plugin"
ZCODE_CONTRACTS="$ZCODE_PLUGIN/contracts"
KIMI_CONTRACTS="$KIMI_PLUGIN/contracts"

[ -d "$ZCODE_PLUGIN/tooling/node_modules/ajv" ] || fail "LazyZCode contract dependencies are not installed"
[ -d "$KIMI_PLUGIN/tooling/node_modules/ajv" ] || fail "LazyKimi contract dependencies are not installed"

NODE_PATH="$ZCODE_PLUGIN/tooling/node_modules" node --test \
    "$ZCODE_PLUGIN/tests/lifecycle-v2-contract.test.js" \
    "$ZCODE_PLUGIN/tests/lifecycle-v2.test.js"
NODE_PATH="$KIMI_PLUGIN/tooling/node_modules" node --test \
    "$KIMI_PLUGIN/tests/lifecycle-v2-contract.test.js" \
    "$KIMI_PLUGIN/tests/lifecycle-v2.test.js"

# Enum-extended family schema: byte-identical outside the product enum.
node - "$ZCODE_CONTRACTS/lazy-harness-active.v2.schema.json" "$KIMI_CONTRACTS/lazy-harness-active.v2.schema.json" <<'NODE' \
    || fail "lazy-harness-active.v2.schema.json drifted beyond the product enum"
const fs = require('node:fs');
const [zpath, kpath] = process.argv.slice(2);
const zc = JSON.parse(fs.readFileSync(zpath, 'utf8'));
const kc = JSON.parse(fs.readFileSync(kpath, 'utf8'));
const expected = [...zc.properties.product.enum, 'LazyKimi'];
if (JSON.stringify(kc.properties.product.enum) !== JSON.stringify(expected)) {
    console.error(`product enum mismatch: got ${JSON.stringify(kc.properties.product.enum)}, want ${JSON.stringify(expected)}`);
    process.exit(1);
}
delete zc.properties.product.enum;
delete kc.properties.product.enum;
if (JSON.stringify(zc) !== JSON.stringify(kc)) {
    console.error('active.v2 schema drifted from LazyZCode outside the product enum');
    process.exit(1);
}
NODE

# Per-host lifecycle v2 schema: formatting, product enum, per-product origin
# conditionals, and the declaration path const are the sanctioned adaptations.
node - "$ZCODE_CONTRACTS/lazy-harness-lifecycle.v2.schema.json" "$KIMI_CONTRACTS/lazy-harness-lifecycle.v2.schema.json" <<'NODE' \
    || fail "lazy-harness-lifecycle.v2.schema.json drifted beyond the sanctioned per-host adaptations"
const fs = require('node:fs');
const [zpath, kpath] = process.argv.slice(2);
const zc = JSON.parse(fs.readFileSync(zpath, 'utf8'));
const kc = JSON.parse(fs.readFileSync(kpath, 'utf8'));

const expectedEnum = [...zc.properties.product.enum, 'LazyKimi'];
if (JSON.stringify(kc.properties.product.enum) !== JSON.stringify(expectedEnum)) {
    console.error('lifecycle.v2 product enum did not grow by exactly LazyKimi');
    process.exit(1);
}
delete zc.properties.product.enum;
delete kc.properties.product.enum;

const originOf = (entry) => entry?.then?.properties?.origin?.const ?? null;
const zOrigins = (zc.allOf ?? []).map(originOf).filter(Boolean);
const kOrigins = (kc.allOf ?? []).map(originOf).filter(Boolean);
for (const origin of zOrigins) {
    if (!kOrigins.includes(origin)) {
        console.error(`sibling product origin conditional was dropped: ${origin}`);
        process.exit(1);
    }
}
if (!kOrigins.includes('https://github.com/elvinzhao10/LazyKimi.git')) {
    console.error('LazyKimi origin conditional is missing');
    process.exit(1);
}
delete zc.allOf;
delete kc.allOf;

const zDecl = zc.definitions.project_declaration.properties.path.const;
const kDecl = kc.definitions.project_declaration.properties.path.const;
if (kDecl !== '.kimi-code/mcp.json') {
    console.error(`declaration path const must be the Kimi route, got ${kDecl}`);
    process.exit(1);
}
if (zDecl !== '.trae/mcp.json' && zDecl !== '.zcode/mcp.json') {
    console.error(`unexpected LazyZCode declaration path const: ${zDecl}`);
    process.exit(1);
}
delete zc.definitions.project_declaration.properties.path.const;
delete kc.definitions.project_declaration.properties.path.const;

if (JSON.stringify(zc) !== JSON.stringify(kc)) {
    console.error('lifecycle.v2 schema drifted from LazyZCode beyond enum/origins/declaration-path');
    process.exit(1);
}
NODE

# Mirrored lifecycle v2 domain code: three files byte-identical, ownership.js
# differing only by the documented per-product origins table and route guards.
for artifact in state.js launcher.js core.js
do
    cmp -s "$ZCODE_PLUGIN/scripts/lifecycle/$artifact" "$KIMI_PLUGIN/scripts/lifecycle/$artifact" ||
        fail "mirrored lifecycle v2 domain code differs: $artifact"
done
grep -q "LazyKimi: 'https://github.com/elvinzhao10/LazyKimi.git'" "$KIMI_PLUGIN/scripts/lifecycle/ownership.js" \
    || fail "ownership.js lost the LazyKimi origin entry"
grep -q "\.kimi-code" "$KIMI_PLUGIN/scripts/lifecycle/ownership.js" \
    || fail "ownership.js lost the Kimi private-route guard"

echo "PASS: lifecycle v2 writers, readers, schemas, and shared domain bytes (per-host adaptations verified structurally)"
