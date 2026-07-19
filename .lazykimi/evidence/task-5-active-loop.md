# Task 5 Evidence — Align active-loop path and shape

## Plan Reread
- Checkbox: Align `active-loop` storage path and shape across schema, MCP servers, and hooks.
- Acceptance criteria: `state/active-loop.json` canonical; run-ledger and status-dashboard use schema shape.

## Automated Verification
- `npm run build`: PASS
- `python3 -m py_compile mcp/run-ledger/server.py mcp/status-dashboard/server.py`: PASS
- `create_run` writes schema-valid `state/active-loop.json`: PASS
- `status-dashboard.get_status` reads new shape: PASS

## Manual QA
`active-loop.json` contents after `create_run`:
```json
{
  "loop_id": "r1",
  "objective": "test objective",
  "mode": "goal",
  "started_at": "2026-07-19T07:52:17Z",
  "turn_count": 0,
  "status": "active"
}
```

Status dashboard JSON output:
```json
{
  "active_loop": {
    "present": true,
    "loop_id": "r1",
    "objective": "test objective",
    "mode": "goal",
    "status": "active",
    "turn_count": 0,
    "started_at": "2026-07-19T07:52:17Z"
  }
}
```

## Adversarial QA
- Invalid `run_id` → error, no active-loop written.
- Missing `active-loop.json` → status dashboard reports gracefully.
- Extra fields in `active-loop.json` → status dashboard tolerates.

## Cleanup
- Removed `/tmp/lazykimi-loop-test`.

## Note
`status-dashboard` boulder summary still reads old boulder fields (`tasks`, `goal`). This is outside the current task scope; status-dashboard active-loop is now correct.
