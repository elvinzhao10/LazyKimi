# Task 2 Evidence — Fix session-end hook JSON corruption

## Plan Reread
- Checkbox: Fix `hooks/session-end.sh` so it no longer corrupts `.lazykimi/state/sessions.json`.
- Acceptance criteria: valid JSON after multiple SessionEnd events; `init` seeds `sessions.json`; schema matches object-with-array shape.

## Automated Verification
- `npm run build`: PASS
- `bash -n hooks/session-end.sh`: PASS
- `bash scripts/lazykimi-verify.sh`: PASS (`all_pass: true`)

## Manual QA
Terminal output from target directory:
```
[2026-07-19T07:35:31Z] SessionEnd: {"hook_event_name":"SessionEnd"}
[2026-07-19T07:35:31Z] SessionEnd: {"hook_event_name":"SessionEnd"}
4
{
  "sessions": [
    { "timestamp": "...", "event": "SessionEnd", "payload": "..." },
    ...
  ]
}
```
`sessions.json` parses as valid JSON.

## Adversarial QA
- Missing `sessions.json` → creates valid file.
- Malformed `sessions.json` → resets and appends, exits 0.
- Empty stdin → exits 0, creates entry with empty payload.
- No `.lazykimi/state/` directory → exits 0 without creating anything.

## Cleanup
- Removed `/tmp/lazykimi-sessions-test` and adversarial temp dirs.
