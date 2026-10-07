# Changelog

Root release history for LazyKimi. Detailed plugin-level history (including the v0.x record) remains in [lazykimi-plugin/CHANGELOG.md](lazykimi-plugin/CHANGELOG.md).

## [1.4.0] - 2026-10-07 — project platform

Adopt the family's persistent project platform through the Kimi-native adapter: the vendored `lazykimi-plugin/shared/project/` family re-pins to tree `95c0e0fc…` (source revision `7bf5bd8`; its README no longer links files the family selection excludes and its CLI entry guard resolves symlinked invocation paths instead of silently no-oping), while Kimi's journal/CAS, namespace, and per-surface boundaries remain the owning surfaces. The project context summary gains the explicit git-observation boundary: the vendored collectors are byte-pinned but wired to no Kimi-exposed route, and commit links stay run-side (`repo_head`/`content_revision`). The T24-R1 no-observed-host-adoption capability assertion stays in force unchanged. Host embedding, chat handoff, and wake remain unobserved; host readiness stays pending; each surface (CLI, VS Code/ACP, Code Desktop, Work) still requires its own current-client acceptance. See RELEASE_NOTES.md.

## [1.4.0] - 2026-10-05

Vendor the family's portable dashboard core hash-pinned behind a Kimi-native adapter, grow the status-dashboard MCP server from 4 to 6 tools (34 declared tools across 6 servers), and publish honest capability labels: browser, transactional edits, project queue, context copy and observations available; embedding, chat handoff and wake unobserved; native host readiness pending. Queue edits never start work; project-bound MCP binding rules are unchanged. Correct the stale tool-count mirrors, neutralize a committed machine-local path in the history docs, and document the project-scoped doctor init gate (`load-check` validates bare extractions). See RELEASE_NOTES.md for verification scope and pending native host acceptance.

## [1.3.5] - 2026-10-02

Execute real runtime-floor and provider checks, bound hook input while preserving host refusal contracts, and update platform guidance. Optional TypeScript LSP requires Node 22.22.2; the core lifecycle retains its separate Node 20 floor. See RELEASE_NOTES.md archives and lazykimi-plugin/CHANGELOG.md for details and pending native host acceptance.

## [1.3.4] - 2026-09-30

Transactional run and hook updates preserve concurrent changes. MCP tools use native content envelopes and isolate malformed requests. Lifecycle and native-host support boundaries are documented; host acceptance remains pending.
