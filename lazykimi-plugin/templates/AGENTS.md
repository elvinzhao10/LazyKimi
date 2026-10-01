# AGENTS.md — LazyKimi local onboarding

This is the reusable `v1.3.4` consumer template, not a claim that a host loaded
the plugin. Explicit user instructions and nearer project instructions take
precedence.

## When the user types `onboard`

Require **Node.js 20 or later**, **Git**, and **Python 3.10+** (MCP servers).
Bootstrap `onboard` only from the verified origin
`https://github.com/elvinzhao10/LazyKimi.git` once it exists; until then run
lifecycle commands from a local release root and report that honestly. The
durable launcher tree is
`LazyKimi/{active.json,launcher.js,releases/,receipts/,rollback/,staging/,locks/}`
under `~/Library/Application Support/LazySeries/LazyKimi/` on macOS.

If lifecycle state collides with an existing path, preserve the caller
workspace. Only an explicitly verified lifecycle-owned sibling bootstrap lock
or product `staging/`/`locks/` artifact is recoverable; never remove or replace
caller workspace files.

1. Ask which installed host they use: **Kimi Code CLI** or **Kimi Work**.
   Follow only that host route.
2. Resolve the absolute plugin root (`lazykimi-plugin/` in the checkout);
   never guess it from PATH.
3. Run safe package checks only: from the repository root, use
   `bash lazykimi-plugin/scripts/lazykimi-load-check.sh` and
   `node lazykimi-plugin/dist/index.js doctor` (build first with
   `npm install && npm run build` inside `lazykimi-plugin/`). Preserve project
   settings and do not change credentials, providers, or host settings.
4. Report **package readiness** separately. Files and declarations do not prove
   plugin discovery, commands, agents, hooks, SessionStart, or MCP connection.
5. Ask for explicit approval before marketplace add, plugin install, hook
   installation, skills import, connector setup, account, credential, or
   provider changes.
6. After approval, give exactly one host action and wait. Discovery,
   install, reload/new session, and verification are separate actions.
7. Inspect the host after each response. If inspection is unavailable, accept
   a user-pasted verbatim status or screenshot as observed evidence.
8. Verify one real skill/command appropriate to the selected route and all six
   MCP connections. Otherwise **HOST READINESS: PENDING**.

## Route selection (Kimi Code CLI)

Pick exactly one Kimi Code CLI route — never both; coexistence is unsupported
and may double-fire hook events:

- **`kimi-plugin-manifest` (default full route):** add the repository through
  `/plugins marketplace` using `lazykimi-plugin/marketplace.json` (v2), then
  install the `lazykimi` plugin as a separate approved action. Delivers
  skills, commands, agents, the 16 inline hooks, and the 6 inline
  `mcpServers`.
- **`project-init-route` (manual project route):** from the target project,
  run `lazykimi init` (copies `.kimi-code/` and `.lazykimi/`; rewrites the
  `__KIMI_PLUGIN_ROOT__` placeholder in `.kimi-code/mcp.json` to absolute
  paths — Kimi does not interpolate env vars in `mcp.json`), then run
  `bash lazykimi-plugin/scripts/install-hooks.sh` to append the eight
  critical `[[hooks]]` entries to `~/.kimi-code/config.toml`. The remaining
  eight advisory hook events activate only through the plugin manifest.
- **`kimi-work-skills-fallback` (Kimi Work, skills only):** run
  `bash lazykimi-plugin/scripts/install-kimi-work.sh` to copy the `lazy-*`
  skills into `~/.kimi-work/skills/`, restart Kimi Work, and add each
  `lazykimi-*` MCP server manually through the Kimi Work MCP configuration
  UI, one at a time. This route excludes commands, agents, and hooks.

## Kimi Work fallback boundary

Kimi Work supports full plugins; this package's full-plugin route remains
experimental pending live proof. The skills-only fallback installs no commands, agents, hooks,
no `sessionStart.skill`. A package file, manifest, or load-check never proves
those capabilities or that MCP loaded. Prepare manual connector values without
mutating the host from `.kimi-code/mcp.json` after `lazykimi init` rewrites
the `__KIMI_PLUGIN_ROOT__` placeholder to the absolute plugin path. After
approval add one connector, wait; handle any trust prompt separately, wait;
inspect it, then continue to the next server.

Do not run a full plugin route and the skills fallback together; coexistence
is unsupported. To switch, stop the session, remove only old LazyKimi entries
through the host UI, choose one route, start a fresh session, and verify it.
Each host mutation is separately approved.

## Honest readiness

Before asking for host approval, the read-only preflight prints
`HOST_PREPARATION=not-applied`, `HOST_MUTATION=none`, and
`HOST_READINESS=pending`; `--apply` refuses. A readiness receipt must bind
the active source/version and current build/session and show one loaded
skill, command, agent, hook, and all six connected MCP servers. Package
success never upgrades **HOST READINESS: PENDING** without observation.

Read the root `kimi.md` when present; a nearer child `kimi.md` refines that
guidance. Optional remote, browser, and architecture capabilities retain
their own approval lifecycle and are never enabled by onboarding.
