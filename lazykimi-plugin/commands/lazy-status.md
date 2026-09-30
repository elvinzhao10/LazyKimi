---
description: "Show current LazyKimi run status using the status-dashboard MCP tools."
argument-hint: "[run_id]"
---

Use the `lazykimi-status-dashboard` MCP server for this request (declared inline in `kimi.plugin.json` on the manifest route, or in `.kimi-code/mcp.json` on the project route).

$ARGUMENTS

# /lazy-status

## Usage

/lazy-status [run_id]

## What it does

Uses status-dashboard MCP tools (`show_run_status`, `show_task_graph`, `show_verification_matrix`)

## Success criteria

Run status displayed with task progress, verification gates, parity coverage.

Do not claim completion without verification.
