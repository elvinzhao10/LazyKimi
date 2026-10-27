# Changelog

## Platform audit (2026-10-27)

Document CLI 2.3.0 qualified plugin skill and command names, route-specific host acceptance, the hook cwd documentation conflict, and current dashboard features. Local MCP integration verifies six servers and 35 tools; no live current-client acceptance or new efficiency claim. See the [platform audit](docs/reference/platform-status-2026-10-27.md).

Root release history for LazyKimi. Detailed plugin-level history (including the v0.x record) remains in [lazykimi-plugin/CHANGELOG.md](lazykimi-plugin/CHANGELOG.md).

## [1.4.0] - 2026-10-19 — completion pass (isolation, hook adoption, repin)

Complete the 1.4.0 surfaces on the Kimi side: the family-wide per-repo store isolation and foreign-runtime refusal matrix (d2f9651); the reconciled served-project truth stating the live git view explicitly (`/api/project/git`, 200 behind the session, vendored local collector; run-side links stay `repo_head`/`content_revision`) (b767b59); the Kimi rescan adoption of the TurnStarted, UserPromptQueued and TaskStarted native hook events as advisory manifest-only ledger consumers (16 → 19 inline hook events; SessionHeartbeat deliberately not adopted) with the per-surface rescan table (8b3a782); and the family repin at source revision `bb696092` — dashboard tree `e55a9c00…`, project tree `16561f3…` — carrying the family's completed project-dashboard UI (dark-first tokens v2, de-tabbed sidebar shell with in-place navigation, six redesigned views, navigation guards, held performance budgets) into this package byte-identically (be663b4). At the 2026-10-27 audit, the manifests pinned dashboard revision `7124d4ee` (tree `9aa188df…`) and project revision `9b8aa938` (tree `16561f3…`). The current release pins are recorded in [lazykimi-plugin/shared/dashboard.vendor.json](lazykimi-plugin/shared/dashboard.vendor.json) and [lazykimi-plugin/shared/project.vendor.json](lazykimi-plugin/shared/project.vendor.json). Dashboard embedding, chat handoff and wake stay unobserved; each surface still requires its own current-client acceptance; the known wall-clock telemetry flake is pre-existing. See RELEASE_NOTES.md "Completion pass (2026-10-19)".

## [1.4.0] - 2026-10-07 — project platform

Adopt the family's persistent project platform through the Kimi-native adapter: the vendored `lazykimi-plugin/shared/project/` family re-pins to tree `1feb5646…` (source revision `537f393`; its README no longer links files the family selection excludes and its CLI entry guard resolves symlinked invocation paths instead of silently no-oping), while Kimi's journal/CAS, namespace, and per-surface boundaries remain the owning surfaces. The project context summary gains the explicit git-observation boundary: the vendored collectors are byte-pinned but wired to no Kimi-exposed route, and commit links stay run-side (`repo_head`/`content_revision`). The T24-R1 no-observed-host-adoption capability assertion stays in force unchanged. Host embedding, chat handoff, and wake remain unobserved; host readiness stays pending; each surface (CLI, VS Code/ACP, Code Desktop, Work) still requires its own current-client acceptance. See RELEASE_NOTES.md.

## [1.4.0] - 2026-10-05

Vendor the family's portable dashboard core hash-pinned behind a Kimi-native adapter, grow the status-dashboard MCP server from 4 to 6 tools (34 declared tools across 6 servers), and publish honest capability labels: browser, transactional edits, project queue, context copy and observations available; embedding, chat handoff and wake unobserved; native host readiness pending. Queue edits never start work; project-bound MCP binding rules are unchanged. Correct the stale tool-count mirrors, neutralize a committed machine-local path in the history docs, and document the project-scoped doctor init gate (`load-check` validates bare extractions). See RELEASE_NOTES.md for verification scope and pending native host acceptance.

## [1.3.5] - 2026-10-02

Execute real runtime-floor and provider checks, bound hook input while preserving host refusal contracts, and update platform guidance. Optional TypeScript LSP requires Node 22.22.2; the core lifecycle retains its separate Node 20 floor. See RELEASE_NOTES.md archives and lazykimi-plugin/CHANGELOG.md for details and pending native host acceptance.

## [1.3.4] - 2026-09-30

Transactional run and hook updates preserve concurrent changes. MCP tools use native content envelopes and isolate malformed requests. Lifecycle and native-host support boundaries are documented; host acceptance remains pending.
