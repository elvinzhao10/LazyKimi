---
description: "Resume the latest active LazyKimi run using the run-ledger MCP tools."
argument-hint: "[run_id]"
---

Use the `lazykimi-run-ledger` MCP server for this request (declared inline in `kimi.plugin.json` on the manifest route, or in `.kimi-code/mcp.json` on the project route).

$ARGUMENTS

# /lazy-resume

## Usage

/lazy-resume [run_id]

## What it does

Resumes latest active run using run-ledger MCP (`latest_run`, `read_state`, `summarize_run`). Loads task graph, checkpoints, and re-entry context.

## Success criteria

Active run loaded with full task context and last checkpoint position.

Do not claim completion without verification.
