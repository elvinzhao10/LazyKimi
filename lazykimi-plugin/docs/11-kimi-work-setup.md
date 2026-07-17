# Kimi Work Setup (Secondary Host)

> **Honest-claims discipline.** Package evidence proves copied files and declarations, not plugin loading, SessionStart, hooks, or an MCP connection. A Kimi Work session must confirm connection.

## Overview

Kimi Work is a desktop agent (Beta, announced 2026-06-03) with Agent Swarm and a built-in Skills system. LazyKimi supports Kimi Work as a **secondary host** via skill import only. The primary host is Kimi Code CLI.

## Limitations

Kimi Work has **no plugin manifest support**. This means:

- No `kimi.plugin.json` loading (the manifest is ignored).
- No hooks (the 16 hook scripts do not run).
- No `sessionStart.skill` (no automatic skill loading on session start).
- No `/plugins install` route.
- MCP servers must be configured manually through Kimi Work's MCP configuration UI.

Only the 17 `lazy-*` skills can be imported.

## Install steps

1. Clone this repository:
   ```bash
   git clone https://github.com/elvinzhao10/LazyKimi.git
   cd LazyKimi
   ```

2. Run the Kimi Work setup script:
   ```bash
   bash lazykimi-plugin/scripts/install-kimi-work.sh
   ```
   The script detects the Kimi Work skills directory (tries `~/.kimi-work/skills/`, `~/.kimiwork/skills/`, `~/Library/Application Support/Kimi Work/skills/`) and copies all `lazy-*` skill directories into it. It is idempotent: skills with identical `SKILL.md` content are skipped.

3. Restart Kimi Work (or reload the Skills UI).

4. Verify the `lazy-*` skills appear in Kimi Work's Skills UI.

## MCP setup (manual)

Kimi Work does not auto-load `.kimi-code/mcp.json`. Add each of the 6 LazyKimi MCP servers manually through Kimi Work's MCP configuration UI:

| Server name | Command |
| --- | --- |
| `lazykimi-run-ledger` | `bash <plugin-root>/mcp/run-ledger/server.sh` |
| `lazykimi-verification` | `bash <plugin-root>/mcp/verification/server.sh` |
| `lazykimi-status-dashboard` | `bash <plugin-root>/mcp/status-dashboard/server.sh` |
| `lazykimi-context-graph` | `bash <plugin-root>/mcp/context-graph/server.sh` |
| `lazykimi-code-intel` | `bash <plugin-root>/mcp/code-intel/server.sh` |
| `lazykimi-docs` | `bash <plugin-root>/mcp/docs/server.sh` |

Replace `<plugin-root>` with the absolute path to `lazykimi-plugin/` on your machine.

## Uninstall

1. Delete the `lazy-*` skill directories from the Kimi Work skills directory:
   ```bash
   rm -rf ~/.kimi-work/skills/lazy-*
   ```
   (Adjust the path if your Kimi Work skills directory is elsewhere.)

2. Remove each `lazykimi-*` MCP server through Kimi Work's MCP configuration UI.

3. Restart Kimi Work.

## References

- Kimi Work announcement: https://platform.kimi.com/docs/guide/kimi-work (2026-06-03 Beta)
- Primary host (Kimi Code CLI) setup: see README.md
