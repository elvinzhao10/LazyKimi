# LazyKimi Plugin

> Self-contained evidence-led agent workflow harness for Kimi Code CLI and Kimi Work.

This package belongs to the LazyKimi project, the Kimi-native port of the
LazyBuddy and LazyTrae harness designs. It is primarily inspired by
lazycodex/OmO (the canonical TypeScript reference), with [NOTICE](NOTICE)
recording upstream attribution. It is an independent implementation and does
not require LazyBuddy, LazyTrae, or lazycodex at runtime.

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

**Verification scope:** macOS only. Repository-level public guides cover the
workflow and host-specific onboarding/offboarding; package readiness remains
package evidence, not proof of live host loading or MCP connection.

## What this plugin provides

LazyKimi provides a workflow harness for Kimi Code CLI (primary) and Kimi
Work (secondary). Host plugin/marketplace behavior must be verified in a live
session; the local fallback imports skills manually:

- **Hierarchical project memory** (`lazy-init-deep`) — generates `AGENTS.md`
  with directory scoring and a `.lazykimi/context/` knowledge base.
- **Prometheus planning** (`lazy-ulw-plan`) — decision-complete work plans;
  never writes product code. Maps to Kimi's `plan` sub-agent and `/plan on`.
- **Orchestrated execution** (`lazy-start-work`) — delegates to sub-agents
  via the `coder` channel; Sisyphus never implements directly.
- **Verified completion loop** (`lazy-ulw-loop`) — evidence-backed done claims
  with adversarial verification; maps to `/goal <objective>`.
- **Independent review** (`lazy-reviewer`) — Oracle and Momus review lanes:
  goal, QA, code, security, context; all must pass.
- **Kimi-native swarm** (`/swarm <task>`) — up to 300 parallel agents for the
  Explore phase and parallel independent task execution.
- **Persistent autonomous goals** (`/goal <objective>`) — durable objective
  that runs the full Explore -> Plan -> Implement -> Verify -> QA loop.

## Component Map

| Directory | Purpose | Status |
|-----------|---------|--------|
| `.kimi-code/skills/` | 17 portable workflow skills | Kimi Code CLI plugin content; verified Kimi Work local import source |
| `.kimi-code/AGENTS.md` | Project agent catalog (11 roles mapped to 3 Kimi sub-agents) | Loaded by Kimi Code CLI session |
| `.kimi-code/mcp.json` | 6 local MCP server declarations | Kimi Code CLI declarations; manual connector configuration is the verified Kimi Work fallback |
| `agents/` | 11 agent role definitions (Greek-myth identities) | Used by Sisyphus for role dispatch |
| `hooks/` | 8 hook event declarations + shell scripts | Installed into `~/.kimi-code/config.toml` via `scripts/install-hooks.sh` |
| `hooks/hooks-config.toml` | Hook registration fragment for `~/.kimi-code/config.toml` | Appended to user config; never overwrites |
| `mcp/` | 6 local MCP servers (Python stdio) with 19 tools | Host starts each over stdio; declarations are recipes, not running services |
| `src/` | TypeScript CLI (`lazykimi` command) | Builds to `dist/`; provides init, doctor, load-check, verify, mcp, uninstall |
| `scripts/` | install-hooks.sh and verification utilities | Used by package readiness and workflow checks |

## Install

For **Kimi Code CLI**, the package is loaded through the host's project
configuration. Ensure Kimi Code CLI v0.26.0 or later is installed at
`~/.kimi-code/bin/kimi`, then open the cloned repository and let Kimi Code
CLI auto-discover `.kimi-code/`. For **Kimi Work**, use its documented Skills
UI to import skills; the copied repository is not a verified Kimi Work
installer and a loaded session must be verified before relying on plugin
capabilities.

### Development validation

```bash
# From lazykimi-plugin/: build the CLI and validate the package.
cd lazykimi-plugin
npm install
npm run build
node dist/index.js load-check
node dist/index.js doctor
```

### Hook installation

```bash
# Append LazyKimi hooks to ~/.kimi-code/config.toml (idempotent).
bash lazykimi-plugin/scripts/install-hooks.sh
```

The installer appends the eight `[[hooks]]` entries from
`hooks/hooks-config.toml` to `~/.kimi-code/config.toml`. It does not
overwrite existing entries, does not modify provider/model/permission
configuration, and does not touch any other host file.

### MCP configuration

`.kimi-code/mcp.json` declares six local MCP servers. Kimi Code CLI
auto-discovers this file when the project is opened. To inspect or modify
MCP registration interactively, use `/mcp` (list servers) and
`/mcp-config` (configure servers) inside a Kimi Code CLI session. The
`${KIMI_PLUGIN_ROOT}` variable in each declaration resolves to the
`lazykimi-plugin/` directory.

## Uninstall

Use `lazykimi uninstall --yes` to remove package-owned assets. Then perform
the manual host step: remove the eight `[[hooks]]` entries from
`~/.kimi-code/config.toml` and remove MCP servers via `/mcp-config` in a
Kimi Code CLI session. For Kimi Work, remove imported skills through its
Skills UI. Never guess, scan for, or delete host-managed installation paths,
`~/.kimi-code/` global state, or MCP configuration belonging to another
host. The copied repository is independent of host removal and may be
deleted only after the host confirms the skills and connectors are gone.
The root `offboard` protocol records this package result separately from
the user-observed host result.

## Verify

```bash
# Run from lazykimi-plugin/ after npm run build.
node dist/index.js load-check
node dist/index.js doctor
node dist/index.js verify --must-pass
```

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
| `/swarm <task>` | Explore, parallel Implement, parallel Review | Up to 300 parallel agents; members write heartbeat markers and deliverables to `.lazykimi/team/members/<id>/` |
| `/goal <objective>` | Implement (single large objective) | Persistent autonomous objective; runs full loop under Sisyphus; Atlas reconstructs state on resumption |
| `/plan on` / `/plan off` | Plan | Constrains session to read-only + plan-file writes while Prometheus and Metis work; turn off before Implement |
| `/yolo` | (optional) | Skip approval prompts; use only when the user explicitly accepts the risk |
| `/auto` | (optional) | Automatic tool execution; follows host permission policy |

Sisyphus decides when to invoke each mode based on the workflow phase and
task shape. Momus and Oracle may be invoked as peers inside a `/swarm` or
as the closing checkpoint of a `/goal`.

## Skill list (17)

| Skill | Role | Phase |
| --- | --- | --- |
| `lazy-init-deep` | Hierarchical repo understanding | Explore |
| `lazy-ulw-plan` | Decision-complete planning | Plan |
| `lazy-start-work` | Plan execution orchestration | Implement |
| `lazy-ulw-loop` | Durable goal execution | Implement |
| `lazy-verifier` | Bounded verification | Verify |
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
| `lazy-lcx-report-bug` | Structured bug reporting | Verify |

## Agent list (11)

| Agent | Greek-myth identity | Kimi sub-agent | Responsibility |
| --- | --- | --- | --- |
| `sisyphus` | Sisyphus (orchestrator) | Main | Workflow lifecycle |
| `prometheus` | Prometheus (planner) | `plan` | Author ONE plan per request |
| `hephaestus` | Hephaestus (implementer) | `coder` | Deep autonomous implementation |
| `oracle` | Oracle (verifier) | Main | Post-implementation review; gate enforcement |
| `momus` | Momus (reviewer) | `plan` | Plan executability review |
| `explorer` | Explorer | `explore` | Codebase search |
| `librarian` | Librarian | `explore` | External docs and memory |
| `metis` | Metis (gap analyst) | `explore` | Pre-planning risk analysis |
| `cleaner` | Cleaner | `coder` | AI-slop removal |
| `atlas` | Atlas (context recovery) | `explore` | Session state reconstruction |
| `migration-planner` | Migration Planner | `coder` | Foreign-host adaptation |

The eleven roles map to Kimi Code CLI's three built-in sub-agent channels
(`coder`, `explore`, `plan`) plus the top-level main agent, preserving the
planner/implementer/verifier separation the five evidence gates depend on.

## Hook list (8)

| Event | Script | Enforcement |
| --- | --- | --- |
| `SessionStart` | `session-start.sh` | Reports package readiness on session open |
| `UserPromptSubmit` | `user-prompt-submit.sh` | Advises on workflow selection |
| `PreToolUse` (Bash) | `pre-tool-use.sh` | Denies secrets and destructive operands |
| `PostToolUse` | `post-tool-use.sh` | Records tool output to run ledger |
| `Stop` | `stop-gate.sh` | Blocks premature completion without evidence |
| `SubagentStop` | `subagent-stop.sh` | Verifies sub-agent evidence; max 3 retries |
| `PreCompact` | `pre-compact.sh` | Snapshots state before context compaction |
| `PostCompact` | `post-compact.sh` | Reconstructs state after compaction via Atlas |

Hooks are host-governed: the package can declare them and ship scripts, but
only a Kimi Code CLI session that loads `~/.kimi-code/config.toml` actually
fires them. Package readiness does not prove hook execution.

## MCP list (6 servers, 19 tools)

| Server | Tools | Purpose |
| --- | ---: | --- |
| `lazykimi-run-ledger` | 4 | Read/write durable workflow records |
| `lazykimi-verification` | 4 | Report bounded package checks |
| `lazykimi-status-dashboard` | 3 | Display package and run status |
| `lazykimi-context-graph` | 3 | Local grep-based relationships (heuristic, not CodeGraph) |
| `lazykimi-code-intel` | 3 | Local code-oriented helpers |
| `lazykimi-docs` | 2 | Fixed-registry documentation lookup with SSRF boundaries |

Each declaration is a recipe for a host: it becomes a service only when
Kimi Code CLI starts it over stdio. The six endpoints have JSON-RPC stream
regression coverage, including malformed-input recovery; that is endpoint
protocol evidence, not a host connection claim.

## Workflow phases and evidence gates

LazyKimi follows the canonical evidence-led loop:

1. **Explore** — `lazy-init-deep` or `/swarm` with parallel Explorer +
   Librarian + Atlas. Output: hierarchical repo understanding and prior
   state reconstruction.
2. **Plan** — `lazy-ulw-plan` or `/plan on` then the `plan` sub-agent.
   Output: ONE plan file at `.lazykimi/plans/<slug>.md`.
3. **Implement** — `lazy-start-work` or `/goal <objective>`. Output:
   changed files, commits, per-task evidence.
4. **Verify** — `lazy-verifier` or Oracle invocation. Output: APPROVE /
   ITERATE / REJECT verdict with per-gate PASS/FAIL evidence.
5. **Review** — `lazy-reviewer`. Output: consolidated review report.
6. **Librarian** — Memory update. Output: `.lazykimi/evidence/` findings.
7. **Handoff** — `lazykimi handoff`. Output: parseable handoff summary.

Every completion must pass all five evidence gates:

| Gate | Name | Owner | Evidence |
| --- | --- | --- | --- |
| 1 | plan-reread | Sisyphus / Prometheus / Momus / Atlas | Plan re-read end-to-end; every task has References + Acceptance + QA + Commit |
| 2 | automated-verification | Hephaestus | LSP diagnostics clean; tests passing; build green |
| 3 | manual-qa | Hephaestus | Real-surface artifact: CLI output, HTTP response, screenshot |
| 4 | adversarial-qa | Oracle | Edge cases and regression scenarios executed |
| 5 | cleanup | Cleaner | No AI-slop remains; regression tests pass identically |

A failed gate blocks completion. Oracle returns ITERATE (max 3 fixable
issues) or REJECT (blocking). Sisyphus may not declare completion until all
five gates are PASS.

## License

MIT — see the package [LICENSE](LICENSE) and [NOTICE](NOTICE).

---

_This is the installable Kimi Code CLI package for LazyKimi. The copied
repository is not a verified Kimi Work installer; Kimi Work uses its
documented Skills UI with a live-session check, or the verified local
skills import plus manual MCP fallback. The `~/.kimi-code/` global
configuration directory is host-managed development state and is
intentionally not part of the release package._
