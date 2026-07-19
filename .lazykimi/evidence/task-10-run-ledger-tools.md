# Task 10: Add run-ledger workflow tools

## Evidence

- `tools/list` from `mcp/run-ledger/server.sh` includes `get_active_plan` and `generate_handoff`.
- `get_active_plan` on a fresh init target returns `null` without error.
- `generate_handoff` on a fresh init target returns a Markdown handoff string.
- `python3 -m py_compile lazykimi-plugin/mcp/run-ledger/server.py` passes.
- `npm run build` exits 0.
- `bash scripts/lazykimi-smoke.sh` passes.

## Files changed

- `lazykimi-plugin/mcp/run-ledger/server.py`
- `lazykimi-plugin/.kimi-code/AGENTS.md`
