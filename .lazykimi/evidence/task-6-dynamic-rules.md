# Task 6 Evidence — Dynamic Rule Matching Hook

## Verification

- `npm run build` in lazykimi-plugin: PASS
- `bash scripts/lazykimi-smoke.sh`: PASS
- `bash tests/v003-dynamic-rules-regression.sh`: PASS

## Manual QA

Command:
```bash
rm -rf /tmp/lk-qa-task6 && mkdir -p /tmp/lk-qa-task6 && cd /tmp/lk-qa-task6
node /Users/Admin/Desktop/lazykimi/lazykimi-plugin/dist/index.js init
mkdir -p .kimi-code/rules && echo '# TypeScript rules' > .kimi-code/rules/typescript.md
printf '%s' '{"hook_event_name":"PostToolUse","changed_files":["src/foo.ts"]}' | bash /Users/Admin/Desktop/lazykimi/lazykimi-plugin/hooks/post-tool-use.sh
```

Observed output contains:
```
[LazyKimi] File changed: src/foo.ts
RULE: typescript.md
```

## Adversarial QA

- Missing `.kimi-code/rules/` directory: hook exits 0 with no rule advisory.
- Non-matching extension (e.g. `.txt`): no `RULE:` line emitted.
- Empty `changed_files`: hook exits 0.

## Result

PASS
