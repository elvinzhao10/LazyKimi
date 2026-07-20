# Task 5: Add optional-MCP capability lifecycle

## Evidence

- `npm run build` passes.
- `bash scripts/lazykimi-smoke.sh` passes.
- `bash tests/v003-tooling-command-regression.sh` passes.
- `bash tests/v003-tooling-capability-regression.sh` passes.
- `tooling enable lsp` adds `lazykimi-lsp` to `.kimi-code/mcp.json` (count 1).
- `tooling disable lsp` removes it (count 0).

## Files changed

- `lazykimi-plugin/src/commands/tooling.ts`
- `lazykimi-plugin/tests/v003-tooling-capability-regression.sh`
