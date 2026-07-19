# Test Runs Evidence

## Automated Verification

- `cd lazykimi-plugin && npm run build` exits 0.
- `bash scripts/lazykimi-verify.sh` reports `all_pass: true`.
- `bash scripts/lazykimi-smoke.sh` reports `Smoke test: ALL PASS`.
- `bash tests/v003-tooling-command-regression.sh` passes.
- `bash tests/v003-hook-uninstall-regression.sh` passes.
- Python MCP servers compile: `python3 -m py_compile mcp/run-ledger/server.py` OK.

## Regression Results

- 15/15 regression scripts pass when evidence gates are populated.
