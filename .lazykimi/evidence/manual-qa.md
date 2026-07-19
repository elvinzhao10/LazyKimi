# Manual QA Evidence

## Scenarios Executed

- **Boulder seed**: `init --target /tmp/...` emits `schema_version: 2`, `active_work_id: null`, `works: {}`.
- **Session-end hook**: Two simulated SessionEnd events append valid JSON records; `sessions.length === 2`.
- **Hook uninstall**: Isolated HOME install then uninstall leaves 0 LazyKimi `[[hooks]]` entries while preserving foreign hooks.
- **Doctor from plugin root**: Reports 7 PASS, 0 FAIL.
- **Init copy assets**: Target contains `.kimi-code/commands/`, `.kimi-code/contracts/`, `.kimi-code/tooling/`, `.kimi-code/kimi.plugin.json`.
- **Tooling command**: `node dist/index.js tooling detect` prints detected tools and exits 0.
- **Run-ledger tools**: `tools/list` contains `get_active_plan` and `generate_handoff`; fresh project returns `null` and Markdown handoff.
