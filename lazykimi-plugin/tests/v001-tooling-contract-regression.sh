#!/usr/bin/env bash
# v001-tooling-contract-regression.sh
# Verify the automatic-tooling contract has a valid sha256 sidecar and schema.
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/lazykimi-contract.XXXXXX")"

cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

CONTRACT="$PLUGIN_ROOT/contracts/automatic-tooling-contract.v1.json"
SHA="$PLUGIN_ROOT/contracts/automatic-tooling-contract.v1.json.sha256"
[ -f "$CONTRACT" ] || fail "contract json missing"
[ -f "$SHA" ] || fail "contract sha256 sidecar missing"

# 1. sha256 of the contract must match the sidecar.
actual="$(shasum -a 256 "$CONTRACT" | awk '{print $1}')"
expected="$(awk '{print $1}' "$SHA")"
[ "$actual" = "$expected" ] \
  || fail "sha256 mismatch: expected $expected, got $actual"

# 2. Contract JSON structure and security defaults.
python3 - "$CONTRACT" <<'PYEOF'
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    data = json.load(f)
assert data.get("schema") == "lazykimi.automatic-tooling.contract", "schema field"
assert data.get("schema_version") == 1, "schema_version"
assert isinstance(data.get("providers"), dict) and data["providers"], "providers"
assert isinstance(data.get("capabilities"), list) and data["capabilities"], "capabilities"
assert isinstance(data.get("fallback_chains"), dict), "fallback_chains"
perms = data.get("permissions", {})
assert perms.get("network") == "default_deny", "network must be default_deny"
assert perms.get("shell_exec") == "default_deny", "shell_exec must be default_deny"
assert perms.get("filesystem_read") == "default_allow", "filesystem_read default_allow"
prov = data["providers"]
# Explicit-network providers must be marked, local providers must be network:none.
for name, cfg in prov.items():
    assert "network" in cfg, "provider %s missing network field" % name
PYEOF

echo "v001 tooling-contract regression: PASS"
