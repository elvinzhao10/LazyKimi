# Host routes reference

Status: v1.3.3. LazyKimi reaches its hosts through three routes. The
authoritative machine-readable definition is
`contracts/marketplace-route-contract.v1.json` (inventory: 19 skills, 20
commands, 13 agents, 16 hook events, 6 MCP servers, 32 MCP tools); this page
explains each route and the manual connector spec for Kimi Work.

## Route 1 — `kimi-plugin-manifest` (default full route)

- **Registration**: `/plugins marketplace add` via `lazykimi-plugin/marketplace.json`
  (v2 shape), then install the `lazykimi` plugin.
- **Delivers**: skills, commands, agents, 16 inline hook events
  (`./hooks/<script>.sh`), 6 inline `mcpServers`
  (`python3 ./mcp/<server>/server.py`), and `sessionStart.skill:
  lazy-init-deep`.
- **MCP profile**: always-orchestrated (all six servers active). The manifest
  route has no env plumbing, which equals the family default out of the box.
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
  placeholder to the absolute plugin-root path at init time and injects the
  `"env"` stanza (`LAZYKIMI_MCP_MODE`, `CWD`) into every server entry. Re-run
  `lazykimi init --mcp-mode <new>` to change modes; the rewrite is idempotent.
- **Mode persistence**: the selected mode is recorded in
  `.lazykimi/config.json` (`"mcpMode"`); `lazykimi doctor` and load-check
  report it.
- **Boundary**: the remaining 8 advisory hook events activate only through
  route 1; this route installs exactly the critical 8.

## Route 3 — `kimi-work-skills-fallback` (recovery/secondary)

- **Registration**: `scripts/install-kimi-work.sh` — skills import only via
  Kimi Work's Skills UI (19 `lazy-*` skills). Commands, agents, and hooks are
  NOT delivered on this route; Kimi Work has no plugin-manifest support.
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
| `lazykimi-run-ledger` | `bash <root>/mcp/run-ledger/server.sh` | Durable run records (9 tools) |
| `lazykimi-verification` | `bash <root>/mcp/verification/server.sh` | Verification store and gates (7 tools) |
| `lazykimi-status-dashboard` | `bash <root>/mcp/status-dashboard/server.sh` | Run status views (4 tools) |
| `lazykimi-context-graph` | `bash <root>/mcp/context-graph/server.sh` | Local relationship queries (5 tools) |
| `lazykimi-code-intel` | `bash <root>/mcp/code-intel/server.sh` | Diagnostics/navigation helpers (5 tools) |
| `lazykimi-docs` | `bash <root>/mcp/docs/server.sh` | Fixed-registry docs lookup (2 tools) |

Rules that travel with the spec:

- Use absolute paths resolved at configuration time. Never paste
  environment-variable interpolation into an `mcp.json` —
  Kimi does not expand it; that is why the package ships the
  `__KIMI_PLUGIN_ROOT__` placeholder and rewrites it in `lazykimi init`.
- The bash `server.sh` launchers derive the plugin root from their own
  location and require a working directory (or the `CWD` env the init-rewritten
  `mcp.json` provides); the profile gate reads `LAZYKIMI_MCP_MODE` and
  defaults to `orchestrated` when absent.
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
