# Task 8 Evidence — Expanded Regression Test Coverage

## Files Created

- `lazykimi-plugin/tests/v003-ssrf-boundary-regression.sh`
- `lazykimi-plugin/tests/v003-mcp-path-traversal-regression.sh`
- `lazykimi-plugin/tests/v003-hook-uninstall-corrupt-regression.sh`
- `lazykimi-plugin/tests/v003-evidence-gate-content-regression.sh`
- Updated `lazykimi-plugin/scripts/lazykimi-verify.sh` to include all v003 tests.

## Verification

Individual test runs:
```bash
PASS: v003 ssrf boundary regression
PASS: v003 mcp path traversal regression
PASS: v003 hook uninstall corrupt regression
PASS: v003 evidence gate content regression
```

Master verify runner:
```bash
bash scripts/lazykimi-verify.sh
```
Result: `all_pass: true`, `failed_count: 0`, all 11 v003 checks PASS.

## Result

PASS
