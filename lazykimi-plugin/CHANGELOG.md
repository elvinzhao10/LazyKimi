# LazyKimi Plugin Changelog

> **Historical/non-operational record.** This dated change history is retained
> for context only. In a repository checkout, current guidance is in
> `README.md`, `AGENTS.md`, and `lazykimi-plugin/README.md`; a copied package
> should use its local `README.md`.

## v1.3.3 — Full family parity port with LazyZCode v1.3.3 (2026-09-29)

- **Family alignment jump 0.x → 1.3.3.** LazyKimi adopts the LazySeries
  family version so shared contracts can be pinned byte-identically against
  LazyZCode v1.3.3 (released 2026-09-29). The version number now denotes
  family contract parity, not elapsed local development time; the previous
  0.2.0/0.3.0 drift is reconciled below and in the v0.3.0 entry.
- **Agents:** replaced the 11 Greek-myth agents
  (`lazykimi-{sisyphus,metis,hephaestus,oracle,momus,prometheus,atlas,
  cleaner,explorer,librarian,migration-planner}`) with the 13 family role
  agents (`lazykimi-{orchestrator,planner,implementer,verifier,reviewer,
  security-auditor,qa-executor,context-indexer,context-miner,explorer,
  librarian,gate-reviewer,migration-planner}`) carrying lazyzcode v1.3.3
  semantics on Kimi's coder/explore/plan/main dispatch channels, plus the
  `validate-agent-frontmatter.js` gate.
- **Commands:** grew 9 → 20 to the family canonical set (added
  lazy-librarian, lazy-migration-planner, lazy-new-run, lazy-offboard,
  lazy-onboard, lazy-resume, lazy-reviewer, lazy-status, lazy-ultrawork,
  lazy-update, lazy-verifier, lazy-verify; retired the
  lazy-remove-ai-slops command — it remains available as a skill).
- **Skills:** grew 17 → 19 (renamed lazy-lcx-report-bug → lazy-report-bug;
  added lazy-review-work and lazy-ultrawork) and ported the v1.3.3 skill
  semantics (plan format with `## Final Verification Wave`, dispatch
  records, DoneClaim protocol, goal tiers, selection-only adaptive layer).
- **Contracts:** copied the family-shared byte-identical contract base from
  lazyzcode v1.3.3 (shared semantics, adaptive harness, automatic tooling,
  capability readiness v1/v2, evaluator pair, canonical schemas, fixtures)
  with `cp`; added the Kimi per-host contracts (marketplace route contract
  with the three Kimi routes, hook consumers for the 16 events, lifecycle
  schemas, marketplace receipt schema) and the
  `lazykimi-regenerate-marketplace-contract.js` inventory script.
- **Package support:** ported `rules/`, `templates/`, `schemas/`, and
  `assets/` (+ truthful asset source manifest) to the family shape.
- Later waves (hooks hardening, 6-server/32-tool MCP surface, `.lazykimi/`
  run-state + loop scripts, tooling layer, lifecycle machinery, verify
  suites, docs, CI, host verification) land on this branch and are
  documented in their own sections as they ship.

## v0.3.0 (unreleased)

> Reconciled from git history 2026-07-20; manifests were never bumped —
> shipped manifests remained 0.2.0. The three commits below were verified
> through the v0.3.0 capability hardening plan; the version string "0.3.0"
> never shipped in `kimi.plugin.json`/`package.json`.

- `64a0501` (feat): capability hardening — `.kimi-code/rules/lazykimi.md`
  project rules; `sync`, `handoff`, `completion-status` CLI commands;
  optional-MCP enable/disable lifecycle; dynamic rule matching in
  post-tool-use; post-compact recovery in pre-compact/session-start; v003
  regression expansion (SSRF, path traversal, hooks, evidence gates);
  `.lazykimi/logs/` seeding; doctor required-vs-optional MCP validation;
  verify evidence-gate skip for fresh targets; sync preserving
  user-managed blocks.
- `5ab1987` (docs): added the v0.3.0 capability hardening plan.
- `69450fd` (docs): added v0.3.0 verification evidence and review report.

## v0.2.0 — Spec compliance + Kimi Work support (2026-07-18)

- Moved plugin manifest from `.kimi-code/plugin.json` to `kimi.plugin.json`
  at plugin root per Kimi Code CLI spec; inlined 16 hooks with `./hooks/...`
  commands; inlined 6 `mcpServers` with `./mcp/.../server.py` commands.
- Removed `${KIMI_PLUGIN_ROOT}` interpolation from `.kimi-code/mcp.json`
  (Kimi does not interpolate env vars in mcp.json); `lazykimi init` now
  rewrites the `__KIMI_PLUGIN_ROOT__` placeholder to an absolute path.
- Deleted `hooks/hooks-config.toml` (superseded by inline manifest hooks).
- Added `get_active_plan` and `generate_handoff` tools to `run-ledger` (10
  tools; 21 total across all MCP servers).
- Added 8 advisory hook scripts for full 16-event Kimi coverage
  (PostToolUseFailure, SessionEnd, SubagentStart, StopFailure, Interrupt,
  PermissionRequest, PermissionResult, Notification).
- Created 4 JSON Schema files at `.lazykimi/schemas/` (boulder, evidence,
  sessions, active-loop) using Draft 2020-12.
- Added v2 `marketplace.json` at plugin root for `/plugins marketplace`.
- Fixed `commands` manifest field to point to `./commands/` (the actual
  location of the 9 `.md` slash command files).
- Aligned npm `package.json` `name` to `lazykimi` and `version` to `0.2.0`
  to match the manifest and the `bin` mapping.
- Added Kimi Work setup script (`scripts/install-kimi-work.sh`) and
  `docs/11-kimi-work-setup.md` documenting Kimi Work as a secondary host
  (skills import only — no plugin manifest, hooks, or sessionStart).
- Fixed `code-intel/server.py` file handle leak (`with open(...)`).
- Added 3 v002 regression tests (manifest, mcp paths, inline hooks);
  updated v001 tests for 16-hook expectation; refreshed integration test.

## v0.1.0 — Initial Kimi-native port (2026-07-17)

- Ported the evidence-led agent workflow harness from LazyBuddy (CodeBuddy
  host) and LazyTrae (Trae host) to Kimi Code CLI as the primary host, with
  Kimi Work as the secondary host.
- Packaged 17 `lazy-` skills under `.kimi-code/skills/`, adapted from the
  LazyTrae skill set with Kimi-native `whenToUse` triggers and
  `/skill:<name>` / `/<name>` invocation conventions.
- Defined 11 Greek-myth agent roles under `agents/` and mapped them to
  Kimi Code CLI's three built-in sub-agent channels (`coder`, `explore`,
  `plan`) plus the top-level main agent, preserving the
  planner/implementer/verifier separation the five evidence gates depend on.
- Implemented 8 hook scripts under `hooks/` covering SessionStart,
  UserPromptSubmit, PreToolUse (Bash), PostToolUse, Stop, SubagentStop,
  PreCompact, and PostCompact, with a TOML registration fragment for
  `~/.kimi-code/config.toml` and an idempotent `install-hooks.sh` installer.
- Implemented 6 local MCP servers under `mcp/` (run-ledger, verification,
  status-dashboard, context-graph, code-intel, docs) exposing 21 tools over
  stdio JSON-RPC, with SSRF and path-boundary protections inherited from
  LazyBuddy.
- Built the `lazykimi` TypeScript CLI under `src/` providing `init`,
  `doctor`, `load-check`, `verify`, `mcp`, and `uninstall` commands,
  compiling to `dist/index.js`.
- Documented the five evidence gates (plan-reread, automated-verification,
  manual-qa, adversarial-qa, cleanup) and the seven workflow phases
  (Explore, Plan, Implement, Verify, Review, Librarian, Handoff).
- Mapped the workflow onto Kimi-native modes: `/swarm <task>` for parallel
  Explore and independent task execution, `/goal <objective>` for durable
  autonomous objectives, and `/plan on|off` for the Plan phase.
- Established `.lazykimi/` as the runtime state root (boulder, sessions,
  plans, evidence, schemas) and `.kimi-code/` as the project configuration
  root, keeping the two strictly separated.
- Added the learner documentation tree under `lazykimi-plugin/docs/`
  (10 pages) and the public capability comparison at
  `lazykimi-evaluation.md`.
- Verification scope: macOS only. Package readiness is package evidence,
  not proof of live Kimi Code CLI or Kimi Work host loading.

---

_Versioning follows semantic versioning from v1.0.0 onward. Historical v0.x
entries remain as the pre-stable development record._
