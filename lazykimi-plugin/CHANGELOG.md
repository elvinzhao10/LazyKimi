# LazyKimi Plugin Changelog

> **Historical/non-operational record.** This dated change history is retained
> for context only. In a repository checkout, current guidance is in
> `README.md`, `AGENTS.md`, and `lazykimi-plugin/README.md`; a copied package
> should use its local `README.md`.

## v0.2.0 — Spec compliance + Kimi Work support (2026-07-18)

- Moved plugin manifest from `.kimi-code/plugin.json` to `kimi.plugin.json`
  at plugin root per Kimi Code CLI spec; inlined 16 hooks with `./hooks/...`
  commands; inlined 6 `mcpServers` with `./mcp/.../server.py` commands.
- Removed `${KIMI_PLUGIN_ROOT}` interpolation from `.kimi-code/mcp.json`
  (Kimi does not interpolate env vars in mcp.json); `lazykimi init` now
  rewrites the `__KIMI_PLUGIN_ROOT__` placeholder to an absolute path.
- Deleted `hooks/hooks-config.toml` (superseded by inline manifest hooks).
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
  status-dashboard, context-graph, code-intel, docs) exposing 19 tools over
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
