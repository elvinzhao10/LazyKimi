# Task 7 Evidence — Post-Compact Recovery Hook

## Verification

- `bash -n lazykimi-plugin/hooks/pre-compact.sh`: PASS
- `bash -n lazykimi-plugin/hooks/session-start.sh`: PASS
- `bash tests/v003-compact-recovery-regression.sh`: PASS

## Manual QA

Command:
```bash
rm -rf /tmp/lk-qa-task7 && mkdir -p /tmp/lk-qa-task7 && cd /tmp/lk-qa-task7
node /Users/Admin/Desktop/lazykimi/lazykimi-plugin/dist/index.js init
printf '%s' '{"hook_event_name":"PreCompact"}' | bash /Users/Admin/Desktop/lazykimi/lazykimi-plugin/hooks/pre-compact.sh
cat .lazykimi/state/sessions.json
printf '%s' '{"hook_event_name":"SessionStart"}' | bash /Users/Admin/Desktop/lazykimi/lazykimi-plugin/hooks/session-start.sh
cat .lazykimi/state/sessions.json
```

Observed:
- After PreCompact, `sessions.json` contains `"post_compact_recovery_needed": true`.
- SessionStart prints recovery hint including rule file list and active plan.
- After SessionStart, `sessions.json` contains `"post_compact_recovery_needed": false`.

## Adversarial QA

- Missing `sessions.json`: session-start hook exits 0, no error.
- Empty input to hooks: exits 0.

## Result

PASS
