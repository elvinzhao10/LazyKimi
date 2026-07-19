# Task 8: Fix evaluation.md hook count

## Evidence

- `grep -c 'Hooks.*8' lazykimi-evaluation.md` returns 0.
- `grep -A1 'Hooks' lazykimi-evaluation.md | grep -c '16'` returns 1.
- `grep -c 'hooks-config\.toml' lazykimi-plugin/README.md lazykimi-plugin/docs/*.md` returns 0.
- `grep -c 'hooks/hooks-config\.toml' lazykimi-plugin/README.md lazykimi-plugin/docs/*.md` returns 0.
- `grep -c 'eight hook scripts across eight events' README.md AGENTS.md` returns 0.
- `grep -c 'exposing 19 tools' README.md AGENTS.md lazykimi-plugin/README.md lazykimi-evaluation.md lazykimi-plugin/mcp/AGENTS.md lazykimi-plugin/CHANGELOG.md` returns 0.
- `grep -c 'run-ledger.*8' lazykimi-plugin/README.md lazykimi-plugin/mcp/AGENTS.md` returns 0.
- `lazykimi-plugin/docs/00-learning-path.md`, `03-install-and-host-verification.md`, `07-package-map.md`, and `08-safe-removal.md` no longer reference `hooks/hooks-config.toml` and distinguish 16 shipped hook scripts from 8 critical installed hooks.

## Files changed

- `README.md`
- `AGENTS.md`
- `lazykimi-plugin/README.md`
- `lazykimi-plugin/mcp/AGENTS.md`
- `lazykimi-plugin/CHANGELOG.md`
- `.kimi-code/AGENTS.md`
- `.lazykimi/evidence/task-8-evaluation-hook-count.md`
