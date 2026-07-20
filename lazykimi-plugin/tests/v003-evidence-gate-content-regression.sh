#!/usr/bin/env bash
# LazyKimi v0.3 evidence gate content regression test.
# Verifies placeholder evidence files fail and concrete evidence files pass.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DIST_INDEX="${PLUGIN_ROOT}/dist/index.js"

fail() { echo "FAIL: $1" >&2; exit 1; }

if [ ! -f "${DIST_INDEX}" ]; then
  echo "INFO: dist/index.js missing; running npm run build..." >&2
  cd "${PLUGIN_ROOT}"
  npm run build >&2 || fail "npm run build failed"
fi

TMP="$(mktemp -d "${TMPDIR:-/tmp}/lazykimi-evidence.XXXXXX")"
cleanup() { rm -rf "${TMP}"; }
trap cleanup EXIT

TARGET="${TMP}/project"
EVIDENCE_DIR="${TARGET}/.lazykimi/evidence"
mkdir -p "${EVIDENCE_DIR}"

NODE_SCRIPT="${TMP}/check-gates.js"
cat > "${NODE_SCRIPT}" <<'JSEOF'
const path = require('path');
const { checkEvidenceGates } = require(path.join(process.argv[2], 'dist', 'lib', 'completion.js'));
const target = process.argv[3];
const spec = process.argv[4]; // "ALL:PASS", "ALL:FAIL", or "manual-qa:FAIL"
const [gate, expected] = spec.split(':');
const results = checkEvidenceGates(target);
if (gate === 'ALL') {
  const allMatch = results.every(r => r.status === expected);
  if (!allMatch) {
    console.error(`Expected all ${expected}, got:`, JSON.stringify(results, null, 2));
    process.exit(1);
  }
  console.log(`All gates ${expected}: OK`);
} else {
  const found = results.find(r => r.gate === gate);
  if (!found) {
    console.error(`Gate ${gate} not found in results`);
    process.exit(1);
  }
  if (found.status !== expected) {
    console.error(`Expected ${gate}=${expected}, got:`, JSON.stringify(found, null, 2));
    process.exit(1);
  }
  console.log(`${gate} gate ${expected}: OK`);
}
JSEOF

# Placeholder content should FAIL all gates.
for file in plan-reread.md test-runs.md manual-qa.md oracle-review.md reviewer.md; do
  echo "(none yet)" > "${EVIDENCE_DIR}/${file}"
done

node "${NODE_SCRIPT}" "${PLUGIN_ROOT}" "${TARGET}" ALL:FAIL || fail "placeholder content did not fail"

# Concrete content should PASS all gates.
cat > "${EVIDENCE_DIR}/plan-reread.md" <<'EOF'
# Plan Reread
- Re-read plan end-to-end.
- Verified acceptance criteria and QA scenarios.
EOF
cat > "${EVIDENCE_DIR}/test-runs.md" <<'EOF'
# Automated Verification
- npm run build: success.
- All regression tests passed.
EOF
cat > "${EVIDENCE_DIR}/manual-qa.md" <<'EOF'
# Manual QA
Ran the CLI and observed expected output.
EOF
cat > "${EVIDENCE_DIR}/oracle-review.md" <<'EOF'
# Adversarial QA
- Edge case: empty input handled.
- Regression: prior behavior preserved.
EOF
cat > "${EVIDENCE_DIR}/reviewer.md" <<'EOF'
# Cleanup
No AI slop remains; lint and type-check are clean.
EOF

node "${NODE_SCRIPT}" "${PLUGIN_ROOT}" "${TARGET}" ALL:PASS || fail "concrete content did not pass"

# Missing file should return FAIL for that gate.
rm "${EVIDENCE_DIR}/manual-qa.md"
node "${NODE_SCRIPT}" "${PLUGIN_ROOT}" "${TARGET}" manual-qa:FAIL || fail "missing file did not fail"

echo "PASS: v003 evidence gate content regression"
