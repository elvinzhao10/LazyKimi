# Task 9 Evidence — Seed Logs Dir and Clean Empty Directories

## Changes

- `lazykimi-plugin/src/commands/init.ts` now creates `.lazykimi/logs/` during init.
- `lazykimi-plugin/scripts/lazykimi-smoke.sh` asserts `.lazykimi/logs/` exists after init.
- Removed empty unused directories `lazykimi-plugin/schemas/` and `lazykimi-plugin/templates/`.

## Verification

- `npm run build` in `lazykimi-plugin/`: PASS
- `bash lazykimi-plugin/scripts/lazykimi-smoke.sh`: PASS (reports `init creates .kimi-code/ and .lazykimi/ (including active-loop.json and logs/)`)
- Target init creates logs dir:
  ```bash
  rm -rf /tmp/lazykimi-logs-test && node lazykimi-plugin/dist/index.js init --target /tmp/lazykimi-logs-test && test -d /tmp/lazykimi-logs-test/.lazykimi/logs
  ```
  Result: PASS
- Empty `lazykimi-plugin/schemas/` and `lazykimi-plugin/templates/` removed.

## Result

PASS
