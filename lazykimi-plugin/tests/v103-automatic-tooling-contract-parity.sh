#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'USAGE'
Usage: v103-automatic-tooling-contract-parity.sh --lazyzcode-root ABSOLUTE_ROOT --lazykimi-root ABSOLUTE_ROOT

Compare the family-shared byte-identical contract set between the LazyZCode
reference checkout and this LazyKimi checkout. Both roots are required; this
integration check never infers a sibling checkout. Only the shared set is
compared; per-host contracts (model-routing-policy kimi entry, model-routing.js
host adaptation, kimi-* contracts, lifecycle fixtures) are intentionally
excluded because LazyKimi legitimately differs there.
USAGE
}

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
        --help|-h)
            usage
            exit 0
            ;;
        *)
            usage >&2
            fail "unknown argument: $1"
            ;;
    esac
done

[ -n "$LAZYZCODE_ROOT" ] || { usage >&2; fail "--lazyzcode-root is required"; }
[ -n "$LAZYKIMI_ROOT" ] || { usage >&2; fail "--lazykimi-root is required"; }
[ -d "$LAZYZCODE_ROOT" ] || fail "missing LazyZCode root: $LAZYZCODE_ROOT"
[ -d "$LAZYKIMI_ROOT" ] || fail "missing LazyKimi root: $LAZYKIMI_ROOT"

LAZYZCODE_ROOT="$(cd "$LAZYZCODE_ROOT" && pwd -P)"
LAZYKIMI_ROOT="$(cd "$LAZYKIMI_ROOT" && pwd -P)"
LZ_CONTRACTS="$LAZYZCODE_ROOT/plugins/lazyzcode/contracts"
LK_CONTRACTS="$LAZYKIMI_ROOT/lazykimi-plugin/contracts"

[ -f "$LZ_CONTRACTS/automatic-tooling-contract.v1.json" ] \
    || fail "misconfigured LazyZCode root: missing plugins/lazyzcode/contracts/automatic-tooling-contract.v1.json"
[ -f "$LK_CONTRACTS/automatic-tooling-contract.v1.json" ] \
    || fail "misconfigured LazyKimi root: missing lazykimi-plugin/contracts/automatic-tooling-contract.v1.json"

# The family-shared byte-identical set (per lazyzcode/.build-conventions.md).
SHARED_FILES=(
    lazyseries-shared-semantics.v1.json
    lazyseries-shared-semantics.v1.json.sha256
    adaptive-harness-contract.v1.json
    adaptive-harness-contract.v1.json.sha256
    adaptive-harness-contract.v1.schema.json
    adaptive-harness-v103-digest.json
    automatic-tooling-contract.v1.json
    automatic-tooling-contract.v1.json.sha256
    lazyseries-capability-readiness.v1.json
    lazyseries-capability-readiness.v1.json.sha256
    lazyseries-capability-readiness.v2.json
    lazyseries-capability-readiness.v2.json.sha256
    outcome-evaluation.js
    OUTCOME-EVALUATION.md
    lazyseries-canonical-event.v1.schema.json
    lazyseries-completion-evidence.v1.schema.json
    lazyseries-cost-outcome.v1.schema.json
    lazyseries-execution-context.v1.schema.json
    lazyseries-generated-mirror.v1.schema.json
    lazyseries-host-event-vocabulary.v1.json
    lazyseries-host-evidence-defs.v1.schema.json
    lazyseries-host-evidence.v1.js
    lazyseries-host-observation.v1.schema.json
    lazyseries-onboarding-receipt.v1.schema.json
    lazy-harness-active.v2.schema.json
    lazy-harness-active.v2.schema.json.sha256
    asset-ownership-contract.v1.json
    paired-candidate-contract.v1.schema.json
    paired-candidate-contract.v1.schema.json.sha256
    validate-lazyseries-record.js
    validate-paired-candidate.js
    execution-context-security.js
    model-routing-validation.js
    host-evidence-contract.test.js
    tests/completion-cost-contract.test.js
    tests/execution-context-contract.test.js
    tests/model-routing.test.js
    tests/outcome-evaluation.test.js
    tests/paired-candidate-contract.test.js
    tests/v122-harness-semantic-parity.test.js
    fixtures/lazyseries-v130-scenarios.v1.json
    fixtures/lazyseries-v130-scenarios.v1.json.sha256
)

for f in "${SHARED_FILES[@]}"; do
    [ -f "$LZ_CONTRACTS/$f" ] || fail "LazyZCode is missing shared contract file: $f"
    [ -f "$LK_CONTRACTS/$f" ] || fail "LazyKimi is missing shared contract file: $f"
    cmp -s "$LZ_CONTRACTS/$f" "$LK_CONTRACTS/$f" \
        || fail "family-shared contract drifted from LazyZCode: $f"
done

# Shared fixture trees (everything except the per-host lifecycle-v1/v2 sets).
for fixture_dir in completion-evidence-v1 cost-outcome-v1 host-evidence-v1 \
                   outcome-evaluation-v1 readiness-v2 v017 v018 v103 v120; do
    [ -d "$LZ_CONTRACTS/fixtures/$fixture_dir" ] || fail "LazyZCode is missing fixture dir: $fixture_dir"
    [ -d "$LK_CONTRACTS/fixtures/$fixture_dir" ] || fail "LazyKimi is missing fixture dir: $fixture_dir"
    while IFS= read -r lz_file; do
        rel="${lz_file#"$LZ_CONTRACTS/fixtures/"}"
        [ -f "$LK_CONTRACTS/fixtures/$rel" ] || fail "LazyKimi is missing shared fixture: $rel"
        cmp -s "$lz_file" "$LK_CONTRACTS/fixtures/$rel" \
            || fail "family-shared fixture drifted from LazyZCode: $rel"
    done < <(find "$LZ_CONTRACTS/fixtures/$fixture_dir" -type f | sort)
done

# Sidecar honesty: pinned digests must match their own file content.
for pinned in lazyseries-shared-semantics.v1.json adaptive-harness-contract.v1.json \
              automatic-tooling-contract.v1.json lazyseries-capability-readiness.v1.json \
              lazyseries-capability-readiness.v2.json lazy-harness-active.v2.schema.json \
              paired-candidate-contract.v1.schema.json; do
    expected="$(shasum -a 256 "$LK_CONTRACTS/$pinned" | cut -d' ' -f1)"
    grep -q "$expected" "$LK_CONTRACTS/$pinned.sha256" \
        || fail "pinned digest sidecar does not match file content: $pinned"
done

echo "PASS: family-shared contract parity vs LazyZCode (${#SHARED_FILES[@]} files + 10 fixture trees)"
