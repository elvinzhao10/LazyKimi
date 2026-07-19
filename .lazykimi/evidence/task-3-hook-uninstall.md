# Task 3 Evidence — Fix uninstall hook removal

## Plan Reread
- Checkbox: Fix `lazykimi uninstall` so it can remove hooks installed by `scripts/install-hooks.sh`.
- Acceptance criteria: config.toml LazyKimi hooks removed, foreign hooks preserved, dead code fixed.

## Automated Verification
- `npm run build`: PASS
- `bash tests/v003-hook-uninstall-regression.sh`: PASS
- `bash scripts/lazykimi-verify.sh`: PASS (`all_pass: true`)

## Manual QA
Terminal output from regression test:
```
Removed hooks from /var/folders/.../.kimi-code/config.toml
hooks count before uninstall: 8
hooks count after uninstall: 0
foreign hooks preserved: 1
```

## Adversarial QA
- `uninstall --soft` with no LazyKimi hooks → reports "No hooks removed: no LazyKimi hooks found".
- `install-hooks.sh` idempotent then uninstall → exactly 8 blocks removed.
- Foreign `[[hooks]]` entry → preserved.
- Corrupt config.toml → uninstall completes without crashing.
- Plugin source layout (`<project>/hooks/`) → also removed.

## Cleanup
- Regression test uses `mktemp` and cleans up its temp directory.
