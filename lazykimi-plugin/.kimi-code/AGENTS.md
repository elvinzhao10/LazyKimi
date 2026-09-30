# AGENTS.md — LazyKimi Project Configuration

## OVERVIEW

LazyKimi is the Kimi-native member of the LazySeries evidence-gated agent workflow family (at parity with LazyZCode v1.3.3). It runs the thirteen family role agents on Kimi Code CLI's three built-in sub-agent channels (`coder`, `explore`, `plan`) plus the top-level main session, preserving the Explore -> Plan -> Implement -> Verify -> Review loop, the DoneClaim -> independent verification -> completion contract, and the five-agent ALL-MUST-PASS review panel. The harness is driven by the `lazykimi` CLI and the Kimi-native `/swarm`, `/goal`, and `/plan` modes; state lives under `.lazykimi/`, configuration under `.kimi-code/`.

## AGENT ROLE CATALOG

| # | Role | Kimi channel | Tool surface | Model | Primary responsibility |
| --- | --- | --- | --- | --- | --- |
| 1 | `orchestrator` | Main session | `.lazykimi/` state writes only | `kimi-k3` | Workflow lifecycle: plan -> dispatch -> verify -> review -> loop; never implements |
| 2 | `planner` | `plan` | Read-only except plan artifacts | `kimi-k3` | Author ONE decision-complete family work plan per request |
| 3 | `implementer` | `coder` | Read/Edit/Write/Bash (surgical) | `kimi-k3` | Execute one bounded task: smallest correct change + DoneClaim |
| 4 | `verifier` | Main session | Read/Bash + run-scoped report Write | `kimi-k3` | Independent DoneClaim verification; confirmed/false-positive/needs-fix verdicts |
| 5 | `reviewer` | Main session | Read-only | `kimi-k3` | Multi-angle review: executability mode + gap-analysis mode |
| 6 | `security-auditor` | Main session | Read-only | `kimi-k3` | Security lane: secrets, unsafe commands, injection, permission issues |
| 7 | `qa-executor` | `coder` | Read/Bash (+evidence writes) | `kimi-k3` | Run the application; execute test scenarios; capture real-surface evidence |
| 8 | `context-indexer` | `plan` | Read-only | `kimi-k3` | Build/refresh `.lazykimi/context/`: project map, commands, structure index |
| 9 | `context-miner` | `explore` | Read-only | `kimi-k3` | Context-mining review lane: git history, docs, cross-references |
| 10 | `explorer` | `explore` | Read-only | `kimi-k3` | Codebase search; absolute paths; structured results |
| 11 | `librarian` | `explore` | Read-only; memory/docs updates | `kimi-k3` | External docs research; SHA-pinned citations; project memory |
| 12 | `gate-reviewer` | Main session | Read-only | `kimi-k3` | Final approval gate: re-audit evidence, reports, QA artifacts |
| 13 | `migration-planner` | `coder` | Read/Write/Bash (adapter docs) | `kimi-k3` | Plan LazyKimi adaptations to another host; planning only |

### Sub-Agent Channel Allocation

- **`coder` sub-agent**: implementer (bounded task execution), qa-executor (real-surface QA), migration-planner (migration plan authoring — needs coder-channel code inspection).
- **`explore` sub-agent**: explorer (codebase search), librarian (external research + memory), context-miner (context-mining review lane). All read-only for product code.
- **`plan` sub-agent**: planner (plan author), context-indexer (context index build/refresh). Read-only over the repository; plan artifacts land under `.lazykimi/`.
- **Main session**: orchestrator (root coordinator), verifier, reviewer, security-auditor, gate-reviewer (judgment roles run as main-session peers to preserve separation between orchestration and judgment).
- **Review panel (ALL-MUST-PASS)**: verifier (Goal Verifier), qa-executor (QA Executor), reviewer (Code Reviewer), security-auditor (Security Auditor), context-miner (Context Miner).

## WORKFLOW PHASES

LazyKimi follows the canonical evidence-gated loop. Each phase has a primary owner; the orchestrator steers transitions.

1. **Explore (init-deep)** — `lazykimi init-deep` or `/swarm` with parallel explorer + librarian + context-indexer instances. Owner: orchestrator dispatching `explore` sub-agents. Output: hierarchical repo understanding, prior state reconstruction (context-indexer), external citations (librarian).
2. **Plan (ulw-plan)** — `lazykimi ulw-plan` or `/plan on` then `plan` sub-agent. Owner: planner. The reviewer's gap-analysis mode runs as pre-plan risk analysis; its executability mode runs as plan-acceptance review. Output: ONE plan file at `.lazykimi/plans/<slug>.md`.
3. **Implement (start-work)** — `lazykimi start-work` or `/goal <objective>` for autonomous execution. Owner: implementer (per-task) via the `coder` sub-agent. Boulder state advances one task at a time. Output: changed files, commits, per-task evidence.
4. **Verify (verifier)** — `lazykimi verify` or verifier invocation. Owner: verifier. Independent DoneClaim verification plus the review panel. Output: confirmed / false-positive / needs-fix / needs-human-review verdicts with evidence.
5. **Review (reviewer)** — `lazykimi review-work`. Owner: reviewer (post-implementation review and plan-vs-implementation compliance) with security-auditor and context-miner lanes. Output: consolidated review report.
6. **Librarian** — Memory update. Owner: Librarian. Updates AGENTS.md managed sections, parity ledger, command index. Output: `.lazykimi/evidence/` research findings and memory-update report.
7. **Handoff** — `/lazy-handoff`. Owner: orchestrator. Produces a parseable handoff summary that lets the next session resume without re-discovery (context-indexer reconstructs it on resume).

## EVIDENCE GATE REQUIREMENTS

Every completion must pass the five-gate review panel (ALL-MUST-PASS). Gates are mandatory; the orchestrator cannot waive them. The gate-reviewer consolidates the panel and issues the final verdict.

| Gate | Name | Owner | Evidence Required |
| --- | --- | --- | --- |
| 1 | **plan-reread** | orchestrator (at resume) / planner (at creation) / reviewer (at execution entry) / context-indexer (at reconstruction) | Plan file re-read end-to-end; every task has References + Acceptance Criteria + QA Scenarios + Commit instruction; all referenced paths exist |
| 2 | **automated-verification** | implementer (per-task executor) | LSP diagnostics clean on all changed files; related tests passing; full build green |
| 3 | **manual-qa** | qa-executor (or implementer) | Real-surface artifact: CLI output, HTTP response, browser screenshot, or data output — concrete, not asserted |
| 4 | **adversarial-qa** | verifier | Edge cases and regression scenarios executed with captured evidence |
| 5 | **cleanup** | implementer (lazy-remove-ai-slops skill) | No AI-slop remains; regression tests pass identically before and after; lint and type-check clean |

A failed gate blocks completion. The panel returns ITERATE (max 3 fixable issues) or REJECT (blocking). The orchestrator may not declare completion until all five gates are PASS.

## KIMI-NATIVE MODE USAGE

LazyKimi maps its workflow onto Kimi Code CLI's native modes:

- **`/swarm <task>`** — Parallel execution. Use for the Explore phase (multiple explorer / librarian / context-indexer instances in parallel), for parallel task implementation when tasks are independent, or for parallel review (review panel lanes). Swarm members write heartbeat markers (`WORKING:` / `BLOCKED:`) and deliverable reports to `.lazykimi/team/members/<id>/`.
- **`/goal <objective>`** — Persistent autonomous objective. Use for the Implement phase when the work is a single large objective rather than a checklist. The goal runs the full Explore -> Plan -> Implement -> Verify -> QA loop under the orchestrator's oversight. The context-indexer reconstructs state on goal resumption.
- **`/plan on` / `/plan off`** — Plan mode toggle. Use to constrain the session to read-only + plan-file writes while the planner works. Turn off before entering the Implement phase.

The orchestrator decides when to invoke each mode based on the workflow phase and task shape. Review-panel roles may be invoked as peers inside a `/swarm` or as the closing checkpoint of a `/goal`.

## STATE LOCATIONS

All LazyKimi runtime state lives under `.lazykimi/`. Configuration lives under `.kimi-code/`. Do not mix the two.

| Artifact | Path | Owner | Format |
| --- | --- | --- | --- |
| Boulder state (current task index, status) | `.lazykimi/state/boulder.json` | orchestrator | JSON (see `boulder.schema.json`) |
| Active loop state | `.lazykimi/state/active-loop.json` | orchestrator | JSON (see `active-loop.schema.json`) |
| Sessions ledger | `.lazykimi/state/sessions.json` | orchestrator | JSON (see `sessions.schema.json`) |
| Plan files | `.lazykimi/plans/<slug>.md` | planner (author) / reviewer (reviewer) | Markdown |
| Migration plans | `.lazykimi/plans/migration-<target>.md` | Migration Planner | Markdown |
| Evidence files | `.lazykimi/evidence/<gate>.md` | Per-gate owner | Markdown |
| Handoff summary | `.lazykimi/evidence/handoff.md` | orchestrator | Markdown |
| Schemas | `.lazykimi/schemas/*.schema.json` | LazyKimi CLI | JSON Schema |
| Project config | `.kimi-code/` (this directory) | LazyKimi CLI | Markdown + JSON |
| Agent definitions | `.kimi-code/agents/lazykimi-*.md` (or `agents/`) | LazyKimi CLI | Markdown |

The boulder state file (`.lazykimi/state/boulder.json`) is the single source of truth for "where are we in the plan?" — The context-indexer reconstructs from it, the orchestrator advances it, the verifier reads it to check plan compliance.

## State Schemas

JSON Schema (Draft 2020-12) files at `.lazykimi/schemas/` validate the runtime state files written under `.lazykimi/state/` and `.lazykimi/evidence/`. The `lazykimi init` command copies these schemas into the target project.

| Schema | Path | Validates | Required fields |
| --- | --- | --- | --- |
| `boulder.schema.json` | `.lazykimi/schemas/boulder.schema.json` | `.lazykimi/state/boulder.json` | `schema_version`, `active_work_id`, `works` (work entries: `work_id`, `active_plan`, `plan_name`, `session_ids`, `status`, `tasks_completed`, `tasks_remaining`, `started_at`, `worktree_path`) |
| `evidence.schema.json` | `.lazykimi/schemas/evidence.schema.json` | `.lazykimi/evidence/*.json` gate records | `gate`, `status`, `timestamp` |
| `sessions.schema.json` | `.lazykimi/schemas/sessions.schema.json` | `.lazykimi/state/sessions.json` | `sessions` array of records containing `timestamp`, `event`, `payload` |
| `active-loop.schema.json` | `.lazykimi/schemas/active-loop.schema.json` | `.lazykimi/state/active-loop.json` | `loop_id`, `objective`, `mode`, `started_at`, `turn_count`, `status` |

## MCP TOOLS

| Server | Tools |
| --- | --- |
| `lazykimi-run-ledger` | `create_run`, `list_runs`, `latest_run`, `read_state`, `append_event`, `update_task`, `create_checkpoint`, `recover_run`, `get_active_plan`, `generate_handoff` |
| `lazykimi-verification` | `record_evidence`, `get_evidence`, `mark_complete`, `get_completion_status` |
| `lazykimi-status-dashboard` | `get_status` |
| `lazykimi-context-graph` | `search_context`, `get_references` |
| `lazykimi-code-intel` | `get_symbols`, `find_references`, `goto_definition` |
| `lazykimi-docs` | `lookup_docs` |

## Kimi Work Limitations

Kimi Work (desktop agent, Beta 2026-06-03) is supported as a secondary host via skill import only. Limitations:

- **No plugin manifest support**: `kimi.plugin.json` is ignored. No `/plugins install` route.
- **No hooks**: The 16 hook scripts do not run on Kimi Work.
- **No `sessionStart.skill`**: No automatic skill loading on session start.
- **Manual MCP configuration**: Kimi Work does not auto-load `.kimi-code/mcp.json`. Add each of the 6 `lazykimi-*` MCP servers manually through Kimi Work's MCP configuration UI.

Setup: run `bash scripts/install-kimi-work.sh` to copy the 17 `lazy-*` skills into `~/.kimi-work/skills/`. See `docs/11-kimi-work-setup.md` for full instructions.

## CONVENTIONS

- **No emojis.** All agent output is plain text. This keeps output parseable by downstream agents and by the `lazykimi` CLI.
- **No `git add -A` or `git add .`.** Stage only the files you explicitly changed. This prevents accidentally staging secrets (`.env`, credentials) or large binaries.
- **Conventional commits.** Atomic commits in Conventional Commits format (`feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`). No WIP commits. Each commit must reference the plan task it implements.
- **No force push.** Never use `git push --force` or `git push --force-with-lease` unless the user explicitly requests it. Never force push to `main` or `master` — warn the user if they request it.
- **Read before modifying.** Every Edit call must be preceded by a Read of the file. Never edit blind.
- **Smallest effective change.** Make the smallest change that satisfies the request. Do not gold-plate, do not refactor surrounding code, do not add features beyond scope.
- **Stage only changed files.** When committing, list specific files. Do not use `git add -A` or `git add .`.
- **Separate commits for docs vs. code.** Documentation/memory changes (Librarian) go in their own commit, not bundled with product code.
- **Trust internal code.** Do not add error handling for scenarios that cannot happen. Do not add comments, docstrings, or type annotations to code you did not change.
- **No proactive documentation files.** Do not create `*.md` or `README` files unless explicitly requested.
- **English for agent-to-agent traffic.** Member-to-leader and member-to-peer traffic in `/swarm` is in English. When the end user addresses an agent directly, reply in the user's language.

## ANTI-PATTERNS

- Do not add hooks that block completion; use CLI/MCP gates instead.
- Do not modify MCP declarations without package lifecycle verification.
- Do not collapse planner and implementer into one agent — the five evidence gates depend on the separation.
- Do not let the orchestrator approve its own work — the verifier is the independent authority.
- Do not skip the Explore phase — never speculate about code not read.
- Do not trust subagent self-reports without independent verification.
- Do not declare completion without all five evidence gates PASS.
