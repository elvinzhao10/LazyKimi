# Task 9: Add lazykimi tooling CLI command

## Evidence

- `node dist/index.js tooling --help` lists `detect`, `status`, and `policy`.
- `node dist/index.js tooling detect` exits 0 and prints detected tools (e.g., `rg`, `sg`).
- `node dist/index.js tooling status` exits 0.
- `node dist/index.js tooling policy` exits 0 and prints contract version and permissions.
- `bash tests/v003-tooling-command-regression.sh` passes.
- `npm run build` exits 0.

## Files changed

- `lazykimi-plugin/src/commands/tooling.ts`
- `lazykimi-plugin/src/index.ts`
- `lazykimi-plugin/tests/v003-tooling-command-regression.sh`
