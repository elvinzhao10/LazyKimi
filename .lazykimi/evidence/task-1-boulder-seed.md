# Task 1 Evidence — Fix boulder seed state to match schema

## Plan Reread
- Checkbox: Fix `src/commands/init.ts` seed `boulder.json` to match `.lazykimi/schemas/boulder.schema.json`.
- Acceptance criteria: init writes `schema_version: 2`, `active_work_id`, `works`; doctor validates required fields.

## Automated Verification
- `npm run build`: PASS
- `node dist/index.js init --target /tmp/lazykimi-boulder-test`: PASS
- `node dist/index.js doctor` in installed target: PASS (7 PASS, 0 FAIL)
- `bash scripts/lazykimi-verify.sh`: PASS (`all_pass: true`)
- `tests/v001-cli-doctor-regression.sh`: PASS

## Manual QA
Terminal output from `/tmp/lazykimi-boulder-test` doctor:
```
LazyKimi Doctor v0.2.0
Target: /private/tmp/lazykimi-boulder-test

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
- Invalid boulder `{schema_version:1}` → doctor FAIL: `active_work_id must be a string or null`
- Old shape `{active_goal_id:null}` → doctor FAIL: `schema_version must be a number`
- Valid shape with extra field → doctor PASS
- Init idempotency → seed remains schema-valid

## Cleanup
- Removed `/tmp/lazykimi-boulder-test`, `/tmp/lazykimi-adv1`, `/tmp/lazykimi-adv2`, `/tmp/lazykimi-adv3`, `/tmp/lazykimi-idem`.
