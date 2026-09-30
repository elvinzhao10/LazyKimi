---
description: "Run LazyKimi verification checks using the verification MCP tools."
argument-hint: "[run_id] [--gate <gate_name>]"
---

Use the `lazykimi-verification` MCP server for this request (declared inline in `kimi.plugin.json` on the manifest route, or in `.kimi-code/mcp.json` on the project route).

$ARGUMENTS

# /lazy-verify

## Usage

/lazy-verify [run_id] [--gate <gate_name>]

## What it does

Uses verification MCP tools (`discover_checks`, `run_check`, `record_gate_result`) to execute verification gates for current run.

## Success criteria

All verification gates executed; gate results recorded with pass/fail/repair status.

Do not claim completion without verification.
