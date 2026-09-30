# LazyKimi Project Rules

> Kimi Code CLI operating rules for the LazyKimi evidence-led workflow.
> See `AGENTS.md` for the full project constitution and onboarding/offboarding steps.

## Core Operating Rules

### Inspect Before Editing
- Read the current project's `AGENTS.md`, plan file, and relevant source/tests before editing.
- Treat `.kimi-code/skills/` and `.kimi-code/commands/` as the workflow source of truth.
- Treat external reference repos under `sources/` as read-only parity evidence, never as editable code.

### Plan Before Multi-File Changes
- For ambiguous or multi-file work, invoke `/lazy-ulw-plan` before changing product files.
- Store active plans in `.lazykimi/plans/`; keep loop state in `.lazykimi/state/`.
- Keep LazyKimi configuration, state, and evidence in `.lazykimi/`.

### Kimi Code CLI Slash Conventions
- `/skill:<name>` or `/<name>` — invoke a LazyKimi skill; `/skill:<name>.<sub>` for sub-skills.
- `/swarm <task>` — parallel fan-out for independent explore or review work; collect evidence per task.
- `/goal <objective>` — persistent autonomous goal for durable implementation loops.
- `/plan on` / `/plan off` — read-only planning mode; toggle off before implementing.

### Sub-Agent Channel Mapping
- `coder` — implementer (bounded task execution), qa-executor (real-surface QA), migration-planner (migration plans).
- `explore` — explorer (codebase search), librarian (research/memory), context-miner (context-mining review lane).
- `plan` — planner (plan author), context-indexer (context index).
- Main session — orchestrator (root coordinator) with verifier, reviewer, security-auditor, and gate-reviewer as judgment peers. Review panel (ALL-MUST-PASS): verifier, qa-executor, reviewer, security-auditor, context-miner.

### Five Mandatory Evidence Gates
Every completion must pass all five gates before any done claim:
1. **Plan reread** — plan file re-read end-to-end; every task has References, Acceptance Criteria, QA Scenarios, Commit instruction; referenced paths exist.
2. **Automated verification** — LSP diagnostics clean on changed files; related tests passing; full build green.
3. **Manual-QA** — real-surface artifact (CLI output, HTTP response, browser screenshot, data output), not asserted.
4. **Adversarial QA** — edge cases and regression scenarios executed with captured evidence.
5. **Cleanup** — no AI-slop remains; regression tests pass before and after; lint and type-check clean.

### Agent Traffic
- Agent-to-agent traffic is in English.
- No emojis in output, logs, or commit messages.

### Execute One Checklist Item at a Time
- During `start-work`, execute one plan checkbox at a time.
- Never batch multiple tasks in a single step.
- Reconcile every plan step: completed, blocked (reason), or removed (reason).

### Verification Evidence Required
- Completion is invalid without evidence.
- Evidence includes: commands run, outputs, exit status, changed files, manual checks, reviewer findings.
- Never claim parity without evidence.

### Review Panel Required
- Long-horizon completion requires the ALL-MUST-PASS review panel (verifier, qa-executor, reviewer, security-auditor, context-miner).
- Reviewer must be read-only by default.
- A child agent saying "done" does not close the work.

### Update Memory After Changes
- Update the project's local instructions or documentation only when the accepted change makes them stale.
- Preserve evidence in `.lazykimi/evidence/` and runtime state in `.lazykimi/state/`.

## Git Workflow

- Use conventional commits.
- Keep commits atomic.
- Stage only the files you changed (no `git add -A`, no `git add .`).
- No `git commit --no-verify`.
- No force pushes.

## Version Numbering

Use semantic versioning. Stable releases use `v1.x` and later tags.

## Key References

- Project instructions: `AGENTS.md`
- Kimi host integration: `.kimi-code/`
- LazyKimi configuration and evidence: `.lazykimi/`
- Plans and loop state: `.lazykimi/plans/` and `.lazykimi/state/`
