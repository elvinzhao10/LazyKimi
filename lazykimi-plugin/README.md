# LazyKimi Plugin

> Self-contained evidence-led agent workflow harness for Kimi Code CLI and Kimi Work.

This package belongs to the LazyKimi project, the Kimi-native family port of
the LazyBuddy and LazyTrae harness designs, at parity with LazyZCode v1.3.5.
Its design lineage and upstream attribution are recorded in
[NOTICE](NOTICE). It is an independent implementation and does not require
any upstream project at runtime.

> **Package checks cover macOS and Linux; current host acceptance is pending.** A selected Kimi client session remains the authority for plugin loading, hooks and MCP connections. Windows host behaviour is unverified.

> **Honest-claims discipline.** Package evidence proves copied files and declarations, not plugin loading, SessionStart, hooks, or an MCP connection. A Kimi Code CLI or Kimi Work session must confirm connection. **HOST READINESS: PENDING** until a complete observation receipt exists.

## Quick Start

`.kimi-code/` is the Kimi Code CLI host entry point: skills live under
`.kimi-code/skills/`, MCP declarations under `.kimi-code/mcp.json`, and the
project agent catalog under `.kimi-code/AGENTS.md`. Kimi Work uses its own
Skills UI and Agent Swarm; the copied repository is not a verified Kimi Work
installer, and a loaded session must be verified before relying on plugin
capabilities.

1. **Onboard** — clone [LazyKimi](https://github.com/elvinzhao10/LazyKimi),
   open it in the selected host, and type `onboard`.
2. **Verify the package** — from this `lazykimi-plugin/` directory, run
   `lazykimi load-check`, then `lazykimi doctor`. These checks report
   package readiness, not host loading or MCP connection.
3. **Verify the host** — in Kimi Code CLI, confirm a `/skill:lazy-<command>`
   or `/<command>` shorthand and any required MCP connection. In Kimi Work,
   verify a loaded Skills entry and Agent Swarm session.
4. **Use the workflow** — invoke skills via `/skill:lazy-<name>` or
   `/<name>`; native modes `/swarm <task>`, `/goal <objective>`, and
   `/plan on|off` map onto the Explore, Plan, and Implement phases.

**Verification scope:** package CI covers macOS and Linux; current native host
acceptance remains pending for each client. Repository-level public guides cover
host-specific onboarding/offboarding. Package readiness does not prove live host
loading or MCP connections.

## What this plugin provides

LazyKimi provides a workflow harness for Kimi Code CLI (primary) and Kimi
Work (secondary, full-plugin route experimental; skills fallback available). Host plugin/marketplace behavior must
be verified in a live session:

- **Hierarchical project memory** (`lazy-init-deep`) — generates `AGENTS.md`
  with directory scoring and a `.lazykimi/context/` knowledge base.
- **Decision-complete planning** (`lazy-ulw-plan`) — one plan per request;
  never writes product code. Maps to Kimi's `plan` sub-agent and `/plan on`.
- **Orchestrated execution** (`lazy-start-work`) — delegates to named agents
  through the host's native Agent/AgentSwarm tools; the orchestrator never implements directly.
- **Verified completion loop** (`lazy-ulw-loop`) — evidence-backed done claims
  with adversarial verification; maps to `/goal <objective>`.
- **Independent review** (`lazy-review-work` / `lazy-reviewer`) — the
  five-agent ALL-MUST-PASS review panel: goal, QA, code, security, context.
- **Durable lifecycle** (`lazy-onboard` / `lazy-update` / `lazy-status` /
  `lazy-offboard`) — versioned releases with receipts and rollback under
  `~/Library/Application Support/LazySeries/LazyKimi/`.
- **Kimi-native swarm** (`/swarm <task>`) — parallel agents for the Explore
  phase and parallel independent task execution.
- **Persistent autonomous goals** (`/goal <objective>`) — durable objective
  that runs the full Explore -> Plan -> Implement -> Verify -> QA loop.

## Component Map

| Directory | Purpose | Status |
|-----------|---------|--------|
| `.kimi-code/skills/` | 19 portable workflow skills | Kimi Code CLI plugin content; Kimi Work fallback import source |
| `.kimi-code/AGENTS.md` | Project workflow instructions for 13 roles | Host discovery requires session observation |
| `.kimi-code/mcp.json` | 6 local MCP server declarations with explicit project binding | Kimi Code CLI project route; manual Kimi Work connectors require live proof |
| `agents/` | 13 family role-agent definitions | Used by the orchestrator for role dispatch |
| `commands/` | 20 named slash-command workflows | Host entry points incl. lifecycle commands |
| `hooks/` | 16 hook event declarations + shell scripts | Critical 8 installed into `~/.kimi-code/config.toml` via `scripts/install-hooks.sh`; the remaining 8 advisory hooks activate only through the plugin manifest |
| `mcp/` | 6 local MCP servers (bash + Python stdio) with 32 tools | Host starts each over stdio; declarations are recipes, not running services |
| `src/` | TypeScript CLI (`lazykimi` command) | Builds to `dist/`; init, doctor, load-check, verify, mcp, tooling, lifecycle, sync, handoff, completion-status, uninstall |
| `contracts/` | Family-shared byte-identical contracts + per-host Kimi set | Parity-gated against lazyzcode v1.3.5 |
| `tooling/` | Adaptive tooling layer, locked node dependencies | Selection-only until host observed |
| `scripts/` | State scripts, loop orchestration, lifecycle, verification utilities | Used by package readiness and workflow checks |

## Install

LazyKimi ships **three routes** (see
[docs/reference/host-routes.md](docs/reference/host-routes.md) for the full
specification):

- **Plugin manifest route (recommended):** `/plugins marketplace add` via
  `lazykimi-plugin/marketplace.json` (v2), then install the `lazykimi`
  plugin. Kimi Code CLI reads `kimi.plugin.json`, activates skills and
  commands and declares 16 inline hooks and 6 MCP launchers. Unbound manifest
  MCP launchers fail closed: managed plugin cwd is not the user's project.
  Use the project route for project-bound MCP. Live activation remains experimental.
- **Project config route (for cloned repos):** `lazykimi init [--mcp-mode
  <mode>]` copies `.kimi-code/`, `.lazykimi/`, and `mcp.json` into the
  project root — rewriting the `__KIMI_PLUGIN_ROOT__` placeholder to absolute
  plugin/project paths and explicit `--project`/`--mode` adapter arguments — then run
  `bash lazykimi-plugin/scripts/install-hooks.sh --project-root <path>` to
  append the eight critical `[[hooks]]` entries to `~/.kimi-code/config.toml`.
- **Kimi Work skills fallback (secondary):**
  `scripts/install-kimi-work.sh` imports the 19 skills through Kimi Work's
  Skills UI; commands, agents, and hooks are not delivered on this route.
  See [docs/11-kimi-work-setup.md](docs/11-kimi-work-setup.md).

Use an installed **Kimi Code CLI** with the documented plugin or project
configuration capabilities. Run `lazykimi init --target <absolute-project>`
before opening that project; cloning the repository alone does not configure
its root. Host configuration uses `KIMI_CODE_HOME` when set, otherwise
`~/.kimi-code/`. See the [host routes](docs/reference/host-routes.md).

### Development validation

```bash
# From lazykimi-plugin/: build the CLI and validate the package.
cd lazykimi-plugin
npm ci --ignore-scripts --no-audit --fund=false
npm run build
node dist/index.js load-check
node dist/index.js doctor
LAZYKIMI_VERIFY_SUITE=all bash scripts/lazykimi-verify.sh
```

### Hook installation

```bash
# Append the critical 8 LazyKimi hooks to ~/.kimi-code/config.toml (idempotent).
bash lazykimi-plugin/scripts/install-hooks.sh
```

The installer appends eight critical `[[hooks]]` entries — `SessionStart`,
`UserPromptSubmit`, `PreToolUse` (matcher `Write|Edit|Bash`), `PostToolUse`,
`PostToolUseFailure`, `Stop`, `PermissionRequest`, `PermissionResult` — to
`~/.kimi-code/config.toml`. The remaining eight advisory hooks
(`SubagentStart`, `SubagentStop`, `PreCompact`, `PostCompact`, `SessionEnd`,
`StopFailure`, `Interrupt`, `Notification`) are declared in
`kimi.plugin.json` and activate only when the plugin manifest is loaded. The
installer does not overwrite existing entries, does not modify
provider/model/permission configuration, and does not touch any other host
file. Full policy reference:
[docs/reference/hook-policy.md](docs/reference/hook-policy.md).

### MCP configuration

`.kimi-code/mcp.json` declares six local MCP servers. Kimi Code CLI
auto-discovers this file when the project is opened. To inspect or modify MCP
registration interactively, use `/mcp` (list servers) and `/mcp-config`
(configure servers) inside a Kimi Code CLI session. The shipped template uses
the `__KIMI_PLUGIN_ROOT__` placeholder — Kimi does not interpolate
environment variables in `mcp.json` — and `lazykimi init` rewrites it to the
absolute plugin path and explicit `--project`/`--mode` adapter arguments. The default profile is `orchestrated` (all six servers);
`lazykimi init --mcp-mode direct|assisted|planned|orchestrated|long-horizon`
merges receipt-owned declarations idempotently. Existing config and runtime state are preserved.

## Uninstall

Choose the installed scope first. Run `lazykimi uninstall --yes` from the
selected project directory. It removes only unchanged receipt-owned project assets
and MCP keys. Missing, malformed or unsafe receipts preserve assets; runtime
state and modified or unknown content stay in place. Durable lifecycle
offboarding is a separate plan-first operation. Remove host-managed plugins,
imported skills and connectors through their selected host route. See
[safe removal](docs/08-safe-removal.md) for exact scope and hook ownership.

## Verify

```bash
# Run from lazykimi-plugin/ after npm run build.
node dist/index.js load-check
node dist/index.js doctor
node dist/index.js verify --must-pass
LAZYKIMI_VERIFY_SUITE=all bash scripts/lazykimi-verify.sh
```

`lazykimi verify --must-pass` checks **PACKAGE READINESS** — copied assets,
declarations, regression tests, and evidence files. It does **NOT** check
host readiness. A Kimi Code CLI or Kimi Work session is a separate
observation: the package can prove its own files are correct without proving
that any host actually loaded a skill, fired a hook, or connected an MCP
server.

Package readiness, doctor, and capability-status output are read-only
package evidence. They do not activate optional providers, install a global
host integration, or prove that a live host session connected an MCP
server. See the package-owned verification matrix in
[docs/09-test-and-release-verification.md](docs/09-test-and-release-verification.md)
for the local checks and manual host observations.

Verification timeouts are best-effort cleanup for trusted package-owned
commands. Each command receives its own process group; a deadline terminates
that group and reports any still-detectable descendants in JSON/stderr. This
is not a security sandbox or a guarantee that every descendant stopped. Use
a VM or container-backed runner for genuinely untrusted commands; no
no-fork sandbox is enabled by default.

## Kimi-native modes

LazyKimi maps its workflow phases onto Kimi Code CLI's native modes:

| Mode | Workflow phase | Use |
| --- | --- | --- |
| `/swarm <task>` | Explore, parallel Implement, parallel Review | Parallel agents; members write heartbeat markers and deliverables to `.lazykimi/team/members/<id>/` |
| `/goal <objective>` | Implement (single large objective) | Persistent autonomous objective; runs the full loop under the orchestrator; the context-indexer reconstructs state on resumption |
| `/plan on` / `/plan off` | Plan | Constrains session to read-only + plan-file writes while the planner and context-indexer work; turn off before Implement |
| `/yolo` | (optional) | Skip approval prompts; use only when the user explicitly accepts the risk |
| `/auto` | (optional) | Automatic tool execution; follows host permission policy |

The orchestrator decides when to invoke each mode based on the workflow
phase and task shape. The reviewer and verifier may be invoked as peers
inside a `/swarm` or as the closing checkpoint of a `/goal`.

## Skill list (19)

| Skill | Role | Phase |
| --- | --- | --- |
| `lazy-init-deep` | Hierarchical repo understanding | Explore |
| `lazy-ulw-plan` | Decision-complete planning | Plan |
| `lazy-start-work` | Plan execution orchestration | Implement |
| `lazy-ulw-loop` | Durable goal execution | Implement |
| `lazy-ultrawork` | Long-horizon work loop | Implement |
| `lazy-verifier` | Bounded verification | Verify |
| `lazy-review-work` | Material-risk completion review | Review |
| `lazy-reviewer` | Multi-lane review | Review |
| `lazy-librarian` | External research and memory | Librarian |
| `lazy-debugging` | Systematic debugging | Implement |
| `lazy-programming` | General programming discipline | Implement |
| `lazy-frontend` | Frontend best practices | Implement |
| `lazy-refactor` | Safe refactoring | Implement |
| `lazy-git-master` | Git workflow discipline | Implement |
| `lazy-ast-grep` | Structural code search | Implement |
| `lazy-remove-ai-slops` | AI-slop cleanup | Cleanup |
| `lazy-migration-planner` | Host-adapter planning | Plan |
| `lazy-coding-agent-sessions` | Session reconstruction | Explore |
| `lazy-report-bug` | Structured bug reporting | Verify |

## Agent list (13)

| Agent | Native profile | Responsibility |
| --- | --- | --- |
| `lazykimi-orchestrator` | `orchestrator` | Workflow lifecycle; implementation delegated |
| `lazykimi-planner` | `planner` | Return ONE plan per request for caller persistence |
| `lazykimi-implementer` | `implementer` | Deep autonomous implementation |
| `lazykimi-verifier` | `verifier` | Post-implementation review; gate enforcement |
| `lazykimi-reviewer` | `reviewer` | Code review lane; consolidates the review panel |
| `lazykimi-security-auditor` | `security-auditor` | Security review lane |
| `lazykimi-qa-executor` | `qa-executor` | QA execution lane |
| `lazykimi-gate-reviewer` | `gate-reviewer` | Final gate review |
| `lazykimi-explorer` | `explorer` | Codebase search |
| `lazykimi-librarian` | `librarian` | Read available documentation and return findings |
| `lazykimi-context-indexer` | `context-indexer` | Return project indexing findings |
| `lazykimi-context-miner` | `context-miner` | Context mining; review-panel context lane |
| `lazykimi-migration-planner` | `migration-planner` | Return foreign-host adaptation plan |

The thirteen custom profiles are discoverable by their native role names. Their
`tools`, `disallowedTools`, and `subagents` fields are enforced by Kimi both
when tools are exposed and before execution. Read-only profiles allow only
Read/Grep/Glob and deny mutation, shell, and delegation tools. The verifier
retains Bash and Write for test execution and evidence; its shell commands
still require the independent hook permission layer. Model, effort, turn
budgets, and worktree isolation are plan/session decisions, not agent header
enforcement. See [native adapter boundaries](docs/reference/native-adapter.md).

## Hook list (16)

| Event | Script | Enforcement |
| --- | --- | --- |
| `SessionStart` | `session-start.sh` | Bootstrap `.lazykimi/` state; report `SESSIONSTART_READINESS`; strict-JSON `additionalContext` |
| `UserPromptSubmit` | `user-prompt-submit.sh` | Adaptive intake: run state and pressure signals |
| `PreToolUse` (Write/Edit/Bash) | `pre-tool-use.sh` | v1.3.5 hardening: 1 MiB cap, wrapper resolution, role-scoped writes, secrets/destructive denial (deny = exit 2) |
| `PostToolUse` | `post-tool-use.sh` | Append redacted tool-use event to the run ledger |
| `PostToolUseFailure` | `post-tool-use-failure.sh` | Append failure event to the run ledger |
| `Stop` | `stop-gate.sh` | Unchecked-plan-task detection; advisory completion reminder |
| `PermissionRequest` | `permission-request.sh` | Record approval request in the ledger |
| `PermissionResult` | `permission-result.sh` | Record approval decision in the ledger |
| `SubagentStart` | `subagent-start.sh` | Advisory: dispatch ledger event |
| `SubagentStop` | `subagent-stop.sh` | Advisory: executor-evidence gate reminder |
| `PreCompact` | `pre-compact.sh` | Advisory: context-recovery checkpoint |
| `PostCompact` | `post-compact.sh` | Advisory: context-recovery checkpoint |
| `SessionEnd` | `session-end.sh` | Advisory: ledger-close event |
| `StopFailure` | `stop-failure.sh` | Advisory: stop-failure ledger event |
| `Interrupt` | `interrupt.sh` | Advisory: interrupt ledger event |
| `Notification` | `notification.sh` | Advisory: no-op logger |

Hooks are host-governed: the package can declare them and ship scripts, but
only a Kimi Code CLI session that loads `~/.kimi-code/config.toml` (or the
plugin manifest) actually fires them. Package readiness does not prove hook
execution. Full policy: [docs/reference/hook-policy.md](docs/reference/hook-policy.md).

## MCP list (6 servers, 32 tools)

| Server | Tools | Purpose |
| --- | ---: | --- |
| `lazykimi-run-ledger` | 9 | Durable workflow records (`create_run`, `list_runs`, `latest_run`, `read_state`, `summarize_run`, `append_event`, `update_task`, `create_checkpoint`, `recover_run`) |
| `lazykimi-verification` | 7 | Verification store and gates (`create_repair_task`, `discover_checks`, `list_gate_results`, `record_criterion_result`, `record_gate_result`, `run_check`, `summarize_verification`) |
| `lazykimi-status-dashboard` | 4 | Status views (`show_run_status`, `show_task_graph`, `show_verification_matrix`, `show_pending_approvals`) |
| `lazykimi-context-graph` | 5 | Local relationships (`blast_radius`, `file_deps`, `symbol_search`, `symbol_refs`, `repo_overview`) |
| `lazykimi-code-intel` | 5 | Code helpers (`diagnostics`, `typecheck`, `find_references`, `goto_definition`, `symbols`) |
| `lazykimi-docs` | 2 | Fixed-registry docs (`get_library_docs`, `list_supported_registries`) |
| **Total** | **32** | Six stdio servers behind the profile gate |

Each declaration is a recipe for a host: it becomes a service only when
Kimi Code CLI starts it over stdio. The six endpoints have JSON-RPC stream
regression coverage, including malformed-input recovery; that is endpoint
protocol evidence, not a host connection claim.

## Kimi Work (Secondary Host)

Kimi Work supports the full plugin definition, including skills, MCP, agents,
hooks, and commands ([official overview](https://www.kimi.com/en/help/plugins-and-skills/overview)).
LazyKimi's full-plugin route there remains experimental until a fresh live
session proves loading and project binding. The skills import script remains
a recovery route. See [Kimi Work setup](docs/11-kimi-work-setup.md).

## Workflow phases and evidence gates

LazyKimi follows the canonical evidence-led loop:

1. **Explore** — `lazy-init-deep` or `/swarm` with parallel explorer,
   librarian, and context-miner. Output: hierarchical repo understanding and
   prior state reconstruction.
2. **Plan** — `lazy-ulw-plan` or `/plan on` then the named planner.
   Output: ONE plan returned for caller persistence at `.lazykimi/plans/<slug>.md`.
3. **Implement** — `lazy-start-work` or `/goal <objective>`. Output:
   changed files, commits, per-task evidence.
4. **Verify** — `lazy-verifier`. Output: APPROVE / ITERATE / REJECT verdict
   with per-gate PASS/FAIL evidence.
5. **Review** — `lazy-review-work` / `lazy-reviewer`. Output: consolidated
   review report.
6. **Librarian** — Memory update. Output: `.lazykimi/runs/<id>/memory_updates/`
   findings.
7. **Handoff** — `/lazy-handoff`. Output: parseable handoff summary.

Every completion must pass all five evidence gates:

| Gate | Name | Owner | Evidence |
| --- | --- | --- | --- |
| 1 | plan-reread | orchestrator / planner / reviewer / context-indexer | Plan re-read end-to-end; every task has References + Acceptance + QA + Commit |
| 2 | automated-verification | implementer | LSP diagnostics clean; tests passing; build green |
| 3 | manual-qa | implementer or qa-executor | Real-surface artifact: CLI output, HTTP response, screenshot |
| 4 | adversarial-qa | verifier (+ security-auditor) | Edge cases and regression scenarios executed |
| 5 | cleanup | context-miner | No AI-slop remains; regression tests pass identically |

At review time the five-member review panel (verifier, qa-executor, reviewer,
security-auditor, context-miner) is ALL-MUST-PASS. A failed gate blocks
completion. The reviewer returns ITERATE (max 3 fixable issues) or REJECT
(blocking). The orchestrator may not declare completion until all five gates
are PASS.

## License

MIT — see the package [LICENSE](LICENSE) and [NOTICE](NOTICE).

---

_This is the installable Kimi Code CLI package for LazyKimi. The copied
repository is not a verified Kimi Work installer; its full-plugin route is
experimental pending live proof. The local skills import and manual MCP
fallback also require host observation. The default `~/.kimi-code/` global
configuration directory is host-managed development state and is
intentionally not part of the release package._
