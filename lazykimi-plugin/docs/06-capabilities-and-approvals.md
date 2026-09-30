# Capabilities and approvals

LazyKimi is local-first. The package ships six local MCP servers and a
TypeScript CLI; it does not bundle remote providers, browser automation, or
architecture indexing. Optional capabilities follow an explicit approval
boundary inherited from the LazyBuddy tooling contract.

## Capability ladder

| Need | Preferred provider | Fallback or boundary |
| --- | --- | --- |
| Local text search | `rg` / ripgrep | Resolves through `tooling/node_modules` (locked `@vscode/ripgrep`); host search otherwise. |
| Structural search | `sg` / ast-grep | Resolves through `tooling/node_modules` (locked `@ast-grep/cli`); `lazy-ast-grep` skill. |
| Codebase semantic search | Kimi Code CLI `search_tools` | Host-native; no package-side index. |
| JS/TS or Python navigation | LSP | `tooling/lsp/` bridges; host LSP if available. |
| Architecture exploration | CodeGraph | `tooling/` codegraph lifecycle (explicit, caller-survival semantics); heuristic `context-graph` otherwise. |
| Current library documentation | Context7 | Not bundled; explicit remote selection. |
| Browser automation | Playwright | Not bundled; explicit approval required. |
| Filesystem reads | Filesystem capability | Read-only and project-scoped. |

LazyKimi ships the family adaptive tooling layer (`tooling/`, locked node
dependencies in `tooling/package.json` + lockfile; node_modules are never
committed). The adaptive layer is **selection-only until host observed**: it
reports capability status and selection explanations, and does not mutate host
configuration. `lazykimi tooling capability-status` is the read-only report.

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
| `lazykimi-run-ledger` | 9 | Read/write durable workflow records | Path-boundary checked |
| `lazykimi-verification` | 7 | Verification store, checks, and gates | Path-boundary checked |
| `lazykimi-status-dashboard` | 4 | Display package and run status | Read-only |
| `lazykimi-context-graph` | 5 | Local grep-based relationships | Heuristic, not CodeGraph |
| `lazykimi-code-intel` | 5 | Local code-oriented helpers | Path-boundary checked |
| `lazykimi-docs` | 2 | Fixed-registry documentation lookup | SSRF boundaries; npm/PyPI only |

The `docs` MCP server accepts validated npm or PyPI package names and
requests only the fixed HTTPS npm or PyPI registry endpoint. Redirects and
metadata URLs (homepage, repository, documentation link) are not followed.
This is an SSRF boundary, not a general web fetch.

## Hook policy

The sixteen hook scripts under `hooks/` apply narrow local policy to host
events with the v1.3.3 hardened semantics (1 MiB input cap with
oversized-input rejection, malformed-payload rejection, identity
normalization + wrapper resolution, role-scoped writes, secret-like path
denial, destructive-operation denial, deny = exit 2, fail-open on internal
errors):

| Event | Policy |
| --- | --- |
| `SessionStart` | Bootstrap `.lazykimi/` state; report `SESSIONSTART_READINESS`; strict-JSON `additionalContext`. |
| `UserPromptSubmit` | Adaptive intake: surface run state and pressure signals. |
| `PreToolUse` (Bash) | The v1.3.3 hardening gate (see [reference/hook-policy.md](reference/hook-policy.md)). |
| `PostToolUse` | Append redacted tool-use event to the run ledger. |
| `Stop` | Unchecked-plan-task detection; advisory completion reminder. |
| `SubagentStop` | Executor-evidence gate reminder (authoritative gate stays in review skills). |
| `PreCompact` | Context-recovery checkpoint before compaction. |
| `PostCompact` | Context-recovery checkpoint after compaction. |
| `PostToolUseFailure` | Append failure event to the run ledger. |
| `SessionEnd` | Ledger-close event. |
| `SubagentStart` | Dispatch ledger event. |
| `StopFailure` | Stop-failure ledger event. |
| `Interrupt` | Interrupt ledger event. |
| `PermissionRequest` | Record approval request in the ledger. |
| `PermissionResult` | Record approval decision in the ledger. |
| `Notification` | No-op logger. |

Hooks are host-governed. The package can declare them and ship scripts, but
only a Kimi Code CLI session that loads `~/.kimi-code/config.toml` actually
fires them. Package readiness does not prove hook execution.

## What is not bundled

- **CodeGraph as a default**: the codegraph provider lifecycle exists in
  `tooling/` behind explicit selection with caller-survival semantics; it is
  never auto-enabled. `context-graph` (MCP) is a grep-based heuristic
  fallback, not semantic architecture analysis.
- **Context7 / grep_app**: not bundled. These are optional remote exports
  that require explicit selection and manual MCP registration.
- **Playwright**: not bundled. Browser automation requires explicit host
  approval.
- **Filesystem MCP**: not bundled. Filesystem reads use the host's native
  filesystem capability, scoped to the project.

Read [safe removal](08-safe-removal.md) before uninstalling any tooling.
