# Task 7: Extend init to copy commands, contracts, tooling, and manifest

## Evidence

- `npm run build` passes.
- After `init`, target contains `.kimi-code/commands/`, `.kimi-code/contracts/`, `.kimi-code/tooling/`, and `.kimi-code/kimi.plugin.json`.
- `bash scripts/lazykimi-smoke.sh` passes.
- `bash tests/v001-package-boundary-regression.sh` passes.
- `npm test` via `lazykimi-verify.sh` reports `all_pass: true`.

## Files changed

- `lazykimi-plugin/src/lib/paths.ts`
- `lazykimi-plugin/src/commands/init.ts`
- `lazykimi-plugin/scripts/lazykimi-smoke.sh`
- `lazykimi-plugin/package.json`
