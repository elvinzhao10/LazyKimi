# Host routes reference

Status: v1.3.4. LazyKimi reaches its hosts through three routes. The
authoritative machine-readable definition is
`contracts/marketplace-route-contract.v1.json` (inventory: 19 skills, 20
commands, 13 agents, 16 hook events, 6 MCP servers, 32 MCP tools); this page
explains each route and the manual connector spec for Kimi Work.

## Route 1 — `kimi-plugin-manifest` (default full route)

- **Registration**: `/plugins marketplace add` via `lazykimi-plugin/marketplace.json`
  (v2 shape), then install the `lazykimi` plugin.
- **Delivers**: skills, commands, agents, 16 inline hook events
  (`./hooks/<script>.sh`), 6 inline `mcpServers`
  (`node ./scripts/kimi-project-mcp.js <server>`), and `sessionStart.skill:
  lazy-init-deep`.
- **MCP boundary**: manifest stdio supplies no user project binding. These
  launchers fail closed; use the explicit project-init route for project MCP.
  The manifest route is experimental for project-state MCP until supported
  request context and a live host proof exist.
- **Boundary**: whether the host actually loads the manifest, fires the inline
  hooks, and spawns the servers is a host observation, not a package fact.

## Route 2 — `project-init-route` (manual project route)

- **Registration**: `lazykimi init` (optionally `--mcp-mode <mode>`, default
  `orchestrated`) copies `.kimi-code/`, `.lazykimi/`, and `mcp.json` into the
  project, then `bash lazykimi-plugin/scripts/install-hooks.sh --project-root
  <path>` appends the **critical 8** `[[hooks]]` entries to
  `~/.kimi-code/config.toml` (see [hook-policy.md](hook-policy.md) for the
  split).
- **Placeholder rewrite**: the shipped `.kimi-code/mcp.json` template uses the
  `__KIMI_PLUGIN_ROOT__` placeholder because Kimi does NOT interpolate
  environment variables in `mcp.json`. `lazykimi init` rewrites the
  placeholders to absolute plugin and project paths and explicit
  `--project`/`--mode` adapter arguments. Re-run
  `lazykimi init --mcp-mode <new>` to change modes; the rewrite is idempotent.
- **Mode persistence**: the selected mode is recorded in
  `.lazykimi/config.json` (`"mcpMode"`); `lazykimi doctor` and load-check
  report it.
- **Boundary**: the remaining 8 advisory hook events activate only through
  route 1; this route installs exactly the critical 8.

## Route 3 — `kimi-work-skills-fallback` (recovery/secondary)

- **Registration**: `scripts/install-kimi-work.sh` — skills import only via
  Kimi Work's Skills UI (19 `lazy-*` skills). Commands, agents, and hooks are
  not delivered by this fallback. Kimi Work supports full plugins; LazyKimi
  full-plugin loading remains experimental until live proof.
- **MCP**: manual connector configuration (spec below).
- **Boundary**: package evidence proves the source skills are present and
  importable, not that Kimi Work loaded them. See
  [11 — Kimi Work setup](../11-kimi-work-setup.md).

## Manual MCP connector spec (Kimi Work and any MCP-configurable host)

Add the six servers one at a time through the host's MCP configuration UI,
observing each connection before adding the next. Each entry is a stdio
launcher; run from a checkout, `<root>` is the absolute path to the
`lazykimi-plugin/` directory:

| Server | Launcher | Purpose |
| --- | --- | --- |
| `lazykimi-run-ledger` | `node <root>/scripts/kimi-project-mcp.js run-ledger --project <project>` | Durable run records (9 tools) |
| `lazykimi-verification` | `node <root>/scripts/kimi-project-mcp.js verification --project <project>` | Verification store and gates (7 tools) |
| `lazykimi-status-dashboard` | `node <root>/scripts/kimi-project-mcp.js status-dashboard --project <project>` | Run status views (4 tools) |
| `lazykimi-context-graph` | `node <root>/scripts/kimi-project-mcp.js context-graph --project <project>` | Local relationship queries (5 tools) |
| `lazykimi-code-intel` | `node <root>/scripts/kimi-project-mcp.js code-intel --project <project>` | Diagnostics/navigation helpers (5 tools) |
| `lazykimi-docs` | `node <root>/scripts/kimi-project-mcp.js docs --project <project>` | Fixed-registry docs lookup (2 tools) |

Rules that travel with the spec:

- Use absolute paths resolved at configuration time. Never paste
  environment-variable interpolation into an `mcp.json` —
  Kimi does not expand it; that is why the package ships the
  `__KIMI_PLUGIN_ROOT__` placeholder and rewrites it in `lazykimi init`.
- The adapter requires an absolute project binding and validates it before
  launching a server. Manifest stdio launches have no project binding and fail
  closed. Host-provided plugin cwd and KIMI_PLUGIN_ROOT never select a project.
- A connected server is a host observation: one at a time, confirmed in the
  host UI, before the next is added.

## Honesty rules

- No route's installation proves host readiness. `HOST READINESS` stays
  `pending` until a complete observation receipt exists (one loaded skill,
  command, agent, hook, and all six MCP connections, bound to the active
  source/version/build/session).
- Route capabilities described here are `documented-untested` until that
  receipt lands; see the evaluation document for the current evidence scopes
  (`package`, `probe`, `current-session`).
