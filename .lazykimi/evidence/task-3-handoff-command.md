# Task 3: Add lazykimi handoff CLI command

## Evidence

- `npm run build` passes.
- `bash scripts/lazykimi-smoke.sh` passes.
- `node dist/index.js handoff --stdout` prints Markdown with Active Work, Active Loop, Recent Evidence, Next Steps.
- `node dist/index.js handoff` writes `.lazykimi/evidence/handoff.md`.
- Fresh init target shows `(none)` for active work.

## Files changed

- `lazykimi-plugin/src/commands/handoff.ts`
- `lazykimi-plugin/src/index.ts`
