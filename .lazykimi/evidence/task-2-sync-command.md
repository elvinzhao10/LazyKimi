# Task 2: Add lazykimi sync CLI command

## Evidence

- `npm run build` passes.
- `bash scripts/lazykimi-smoke.sh` passes.
- `bash tests/v003-sync-regression.sh` passes (6 checks).
- QA scenario: deleting `.kimi-code/commands/` then running `sync` restores all 9 command files.

## Files changed

- `lazykimi-plugin/src/commands/sync.ts`
- `lazykimi-plugin/src/index.ts`
- `lazykimi-plugin/src/commands/init.ts`
- `lazykimi-plugin/tests/v003-sync-regression.sh`
