# Task 4 Evidence — Fix doctor/verify for plugin-root layout

## Plan Reread
- Checkbox: Make `lazykimi doctor`/`verify` useful when run from `lazykimi-plugin/` source root.
- Acceptance criteria: doctor/verify from plugin root report 0 FAIL; installed-layout behavior preserved.

## Automated Verification
- `npm run build`: PASS
- `node dist/index.js doctor` from plugin root: PASS (7 PASS, 0 FAIL)
- `node dist/index.js verify --must-pass` from plugin root: PASS (Overall: READY)
- `bash tests/v003-doctor-plugin-root-regression.sh`: PASS
- `bash scripts/lazykimi-verify.sh`: PASS (`all_pass: true`)

## Manual QA
Terminal output from plugin-root doctor:
```
LazyKimi Doctor v0.2.0
Target: /Users/Admin/Desktop/lazykimi/lazykimi-plugin

  [PASS] .kimi-code/ present
  [PASS] skills count (17 expected)     found 17
  [PASS] agents count (11 expected)     found 11
  [PASS] hooks count (16 expected)      found 16
  [PASS] mcp.json valid (6 servers)     found 6 servers
  [PASS] .lazykimi/state/boulder.json
  [PASS] kimi binary on PATH            /Users/Admin/.kimi-code/bin/kimi

=== Results: 7 PASS, 0 WARN, 0 FAIL ===
```

## Adversarial QA
- Doctor from `/tmp` (no `.kimi-code/`) → FAIL as expected.
- Doctor from installed target → PASS.
- Verify from plugin root → PASS.

## Cleanup
- No persistent temp resources.
