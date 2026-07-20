# Task 4: Add lazykimi completion-status CLI command

## Evidence

- `npm run build` passes.
- `bash scripts/lazykimi-smoke.sh` passes.
- `node dist/index.js completion-status --help` prints usage.
- `node dist/index.js completion-status` exits 0 and prints `Overall: READY`.
- `node dist/index.js completion-status --json` prints valid JSON.
- `node dist/index.js verify --must-pass` still exits 0 after refactor.

## Files changed

- `lazykimi-plugin/src/commands/completion-status.ts`
- `lazykimi-plugin/src/lib/completion.ts`
- `lazykimi-plugin/src/commands/verify.ts`
- `lazykimi-plugin/src/index.ts`
