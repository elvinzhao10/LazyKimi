# Task 6: Strengthen verify evidence gates

## Evidence

- `npm run build` passes.
- Fresh init target fails `verify --must-pass` with all 5 gates showing `contains only placeholder content`.
- After appending non-placeholder sections to the 5 evidence files, `verify --must-pass` passes (`Overall: READY`).
- `bash scripts/lazykimi-smoke.sh` passes.

## Files changed

- `lazykimi-plugin/src/commands/verify.ts`
- `lazykimi-plugin/src/commands/init.ts`
- `lazykimi-plugin/scripts/lazykimi-integration-test.sh`
