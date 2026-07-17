# Capabilities and approvals

LazyKimi is local-first. The package ships six local MCP servers and a
TypeScript CLI; it does not bundle remote providers, browser automation, or
architecture indexing. Optional capabilities follow an explicit approval
boundary inherited from the LazyBuddy tooling contract.

## Capability ladder

| Need | Preferred provider | Fallback or boundary |
| --- | --- | --- |
| Local text search | `rg` / ripgrep | Host-provided search; no bundled fallback. |
| Structural search | `sg` / ast-grep | `lazy-ast-grep` skill; host-provided. |
| Codebase semantic search | Kimi Code CLI `search_tools` | Host-native; no package-side index. |
| JS/TS or Python navigation | LSP | Not bundled; host LSP if available. |
| Architecture exploration | CodeGraph | Not bundled; explicit lifecycle only. |
| Current library documentation | Context7 | Not bundled; explicit remote selection. |
| Browser automation | Playwright | Not bundled; explicit approval required. |
| Filesystem reads | Filesystem capability | Read-only and project-scoped. |

Unlike LazyBuddy, LazyKimi does not ship a pinned ripgrep/ast-grep/LSP
toolpack. Kimi Code CLI provides its own `search_tools` and codebase search;
the package relies on the host for language-aware navigation rather than
provisioning a separate tooling root.

## Approval boundaries

The default permission is deny. Local reads are allowed only within the
workspace; filesystem access is read-only and project-scoped. Network,
browser automation, costs, credentials/authentication, and writes need
explicit host permission. Kimi Code CLI's `permission` configuration in
`~/.kimi-code/config.toml` and `.kimi-code/local.toml` governs these
decisions; the package does not override them.

The `pre-tool-use.sh` hook applies a conservative literal scan to `Bash`
commands: commands that contain secret-like paths or destructive operands
(`rm -rf /`, `git push --force`, `git reset --hard`) are denied regardless of
host permission. This is advisory policy, not an enforcement boundary — the
host may still execute the command if the hook is not loaded.

## MCP server inventory

The six local MCP servers in `.kimi-code/mcp.json` are the package's
capability surface. Each is a Python stdio process started by the host:

| Server | Tools | Purpose | Boundary |
| --- | ---: | --- | --- |
| `lazykimi-run-ledger` | 4 | Read/write durable workflow records | Path-boundary checked |
| `lazykimi-verification` | 4 | Report bounded package checks | Read-only |
| `lazykimi-status-dashboard` | 3 | Display package and run status | Read-only |
| `lazykimi-context-graph` | 3 | Local grep-based relationships | Heuristic, not CodeGraph |
| `lazykimi-code-intel` | 3 | Local code-oriented helpers | Path-boundary checked |
| `lazykimi-docs` | 2 | Fixed-registry documentation lookup | SSRF boundaries; npm/PyPI only |

The `docs` MCP server accepts validated npm or PyPI package names and
requests only the fixed HTTPS npm or PyPI registry endpoint. Redirects and
metadata URLs (homepage, repository, documentation link) are not followed.
This is an SSRF boundary, not a general web fetch.

## Hook policy

The eight hook scripts under `hooks/` apply narrow local policy to host
events:

| Event | Policy |
| --- | --- |
| `SessionStart` | Report package readiness; advise on workflow selection. |
| `UserPromptSubmit` | Advise on workflow selection; record prompt to run ledger. |
| `PreToolUse` (Bash) | Deny secrets and destructive operands; literal scan only. |
| `PostToolUse` | Record tool output to run ledger. |
| `Stop` | Block premature completion without evidence; require gate PASS. |
| `SubagentStop` | Verify sub-agent evidence; max 3 retries before failure. |
| `PreCompact` | Snapshot state to `.lazykimi/` before context compaction. |
| `PostCompact` | Reconstruct state via Atlas after compaction. |

Hooks are host-governed. The package can declare them and ship scripts, but
only a Kimi Code CLI session that loads `~/.kimi-code/config.toml` actually
fires them. Package readiness does not prove hook execution.

## What is not bundled

- **CodeGraph**: not bundled. `context-graph` is a grep-based heuristic
  fallback, not semantic architecture analysis.
- **Context7 / grep_app**: not bundled. These are optional remote exports
  that require explicit selection and manual MCP registration.
- **Playwright**: not bundled. Browser automation requires explicit host
  approval.
- **Filesystem MCP**: not bundled. Filesystem reads use the host's native
  filesystem capability, scoped to the project.

Read [safe removal](08-safe-removal.md) before uninstalling any tooling.
