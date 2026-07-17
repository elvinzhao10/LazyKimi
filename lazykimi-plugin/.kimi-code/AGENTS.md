# AGENTS.md — LazyKimi Project Configuration

## OVERVIEW

LazyKimi is the Kimi-native port of the evidence-led agent workflow harness originally shipped as LazyTrae (Trae host) and LazyBuddy (CodeBuddy host). It adapts the eleven Greek-myth specialist agent roles to Kimi Code CLI's three built-in sub-agent channels (`coder`, `explore`, `plan`) plus the top-level main agent, preserving the Explore -> Plan -> Implement -> Verify -> Review loop and the five mandatory evidence gates. The harness is driven by the `lazykimi` CLI and the Kimi-native `/swarm`, `/goal`, and `/plan` modes; state lives under `.lazykimi/`, configuration under `.kimi-code/`.

## AGENT ROLE CATALOG

| # | Role | Greek-Myth Identity | Kimi Sub-Agent | Isolation | Recommended Model | Primary Responsibility |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `sisyphus` | Sisyphus (orchestrator) | Main agent | Read-only | `kimi-k3` | Workflow lifecycle: plan -> implement -> verify -> review -> loop |
| 2 | `prometheus` | Prometheus (planner) | `plan` | Read-only except plan file | `kimi-k3` | Author ONE executable work plan per request; never implements |
| 3 | `hephaestus` | Hephaestus (implementer) | `coder` | Write-enabled (surgical) | `kimi-k2.7-code` | Deep autonomous implementation; full Explore -> Plan -> Implement -> Verify -> QA loop |
| 4 | `oracle` | Oracle (verifier) | Main agent | Read-only | `kimi-k3` | Post-implementation review; gate enforcement; APPROVE / ITERATE / REJECT |
| 5 | `momus` | Momus (reviewer) | `plan` | Read-only | `kimi-k3` | Plan executability review; OKAY / ITERATE / REJECT |
| 6 | `explorer` | Explorer | `explore` | Read-only | `kimi-k2.7-code` | Codebase search; absolute paths; structured results |
| 7 | `librarian` | Librarian | `explore` | Read-only for code; memory/docs write | `kimi-k3` | External docs research; SHA-pinned citations; project memory updates |
| 8 | `metis` | Metis (gap analyst) | `explore` | Read-only | `kimi-k3` | Pre-planning risk analysis; contradictions, ambiguity, missing constraints |
| 9 | `cleaner` | Cleaner | `coder` | Edit-only (no Write) | `kimi-k2.7-code` | AI-slop removal across 10 categories; behavior-preserving |
| 10 | `atlas` | Atlas (context recovery) | `explore` | Read-only | `kimi-k3` | Reconstruct session state from `.lazykimi/` after handoff or compaction |
| 11 | `migration-planner` | Migration Planner | `coder` | Read-only except migration plan file | `kimi-k3` | Adapt LazyKimi workflows to a foreign host platform; planning only |

### Sub-Agent Channel Allocation

- **`coder` sub-agent**: hephaestus (deep implementation), cleaner (slop removal), migration-planner (migration plan authoring — needs coder-channel code inspection).
- **`explore` sub-agent**: explorer (codebase search), librarian (external research + memory), atlas (context recovery), metis (gap analysis). All four are read-only for product code.
- **`plan` sub-agent**: prometheus (plan author), momus (plan reviewer). Both read-only except the single plan file (Prometheus only).
- **Main agent**: sisyphus (orchestrator), oracle (verifier). Both run in the top-level Kimi Code CLI session to preserve separation between orchestration and judgment.

## WORKFLOW PHASES

LazyKimi follows the canonical evidence-led loop. Each phase has a primary owner; Sisyphus steers transitions.

1. **Explore (init-deep)** — `lazykimi init-deep` or `/swarm` with parallel Explorer + Librarian + Atlas. Owner: Sisyphus dispatching `explore` sub-agents. Output: hierarchical repo understanding, prior state reconstruction (Atlas), external citations (Librarian).
2. **Plan (ulw-plan)** — `lazykimi ulw-plan` or `/plan on` then `plan` sub-agent. Owner: Prometheus. Metis runs as pre-plan risk analyst; Momus runs as plan-acceptance reviewer. Output: ONE plan file at `.lazykimi/plans/<slug>.md`.
3. **Implement (start-work)** — `lazykimi start-work` or `/goal <objective>` for autonomous execution. Owner: Hephaestus (deep) or per-task executors via the `coder` sub-agent. Boulder state advances one task at a time. Output: changed files, commits, per-task evidence.
4. **Verify (verifier)** — `lazykimi verify` or Oracle invocation. Owner: Oracle. Runs the five evidence gates. Output: APPROVE / ITERATE / REJECT verdict with per-gate PASS/FAIL evidence.
5. **Review (reviewer)** — `lazykimi review-work`. Owner: Oracle (post-implementation review) and Momus (plan-vs-implementation compliance). Output: consolidated review report.
6. **Librarian** — Memory update. Owner: Librarian. Updates AGENTS.md managed sections, parity ledger, command index. Output: `.lazykimi/evidence/` research findings and memory-update report.
7. **Handoff** — `lazykimi handoff`. Owner: Sisyphus. Produces a parseable handoff summary that lets the next session resume without re-discovery (Atlas reconstructs it on resume).

## EVIDENCE GATE REQUIREMENTS

Every completion must pass all five gates. Gates are mandatory; Sisyphus cannot waive them. Oracle consolidates the gate review and issues the final verdict.

| Gate | Name | Owner | Evidence Required |
| --- | --- | --- | --- |
| 1 | **plan-reread** | Sisyphus (at resume) / Prometheus (at creation) / Momus (at execution entry) / Atlas (at reconstruction) | Plan file re-read end-to-end; every task has References + Acceptance Criteria + QA Scenarios + Commit instruction; all referenced paths exist |
| 2 | **automated-verification** | Hephaestus (or per-task executor) | LSP diagnostics clean on all changed files; related tests passing; full build green |
| 3 | **manual-qa** | Hephaestus (or per-task executor) | Real-surface artifact: CLI output, HTTP response, browser screenshot, or data output — concrete, not asserted |
| 4 | **adversarial-qa** | Oracle | Edge cases and regression scenarios executed with captured evidence |
| 5 | **cleanup** | Cleaner | No AI-slop remains; regression tests pass identically before and after; lint and type-check clean |

A failed gate blocks completion. Oracle returns ITERATE (max 3 fixable issues) or REJECT (blocking). Sisyphus may not declare completion until all five gates are PASS.

## KIMI-NATIVE MODE USAGE

LazyKimi maps its workflow onto Kimi Code CLI's native modes:

- **`/swarm <task>`** — Parallel execution. Use for the Explore phase (multiple Explorer / Librarian / Atlas instances in parallel), for parallel task implementation when tasks are independent, or for parallel review (Oracle + Momus). Swarm members write heartbeat markers (`WORKING:` / `BLOCKED:`) and deliverable reports to `.lazykimi/team/members/<id>/`.
- **`/goal <objective>`** — Persistent autonomous objective. Use for the Implement phase when the work is a single large objective rather than a checklist. The goal runs the full Explore -> Plan -> Implement -> Verify -> QA loop under Sisyphus's oversight. Atlas reconstructs state on goal resumption.
- **`/plan on` / `/plan off`** — Plan mode toggle. Use to constrain the session to read-only + plan-file writes while Prometheus and Metis work. Turn off before entering the Implement phase.

Sisyphus decides when to invoke each mode based on the workflow phase and task shape. Momus and Oracle may be invoked as peers inside a `/swarm` or as the closing checkpoint of a `/goal`.

## STATE LOCATIONS

All LazyKimi runtime state lives under `.lazykimi/`. Configuration lives under `.kimi-code/`. Do not mix the two.

| Artifact | Path | Owner | Format |
| --- | --- | --- | --- |
| Boulder state (current task index, status) | `.lazykimi/state/boulder.json` | Sisyphus | JSON (see `boulder.schema.json`) |
| Active loop state | `.lazykimi/state/active-loop.json` | Sisyphus | JSON (see `active-loop.schema.json`) |
| Sessions ledger | `.lazykimi/state/sessions.json` | Sisyphus | JSON (see `sessions.schema.json`) |
| Plan files | `.lazykimi/plans/<slug>.md` | Prometheus (author) / Momus (reviewer) | Markdown |
| Migration plans | `.lazykimi/plans/migration-<target>.md` | Migration Planner | Markdown |
| Evidence files | `.lazykimi/evidence/<gate>.md` | Per-gate owner | Markdown |
| Handoff summary | `.lazykimi/evidence/handoff.md` | Sisyphus | Markdown |
| Schemas | `.lazykimi/schemas/*.schema.json` | LazyKimi CLI | JSON Schema |
| Project config | `.kimi-code/` (this directory) | LazyKimi CLI | Markdown + JSON |
| Agent definitions | `.kimi-code/agents/lazykimi-*.md` (or `agents/`) | LazyKimi CLI | Markdown |

The boulder state file (`.lazykimi/state/boulder.json`) is the single source of truth for "where are we in the plan?" — Atlas reconstructs from it, Sisyphus advances it, Oracle reads it to verify plan compliance.

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
- Do not let Sisyphus approve its own work — Oracle is the independent verifier.
- Do not skip the Explore phase — never speculate about code not read.
- Do not trust subagent self-reports without independent verification.
- Do not declare completion without all five evidence gates PASS.
