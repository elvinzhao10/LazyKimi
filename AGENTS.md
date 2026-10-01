# AGENTS.md — LazyKimi setup and removal guide

LazyKimi targets the **Kimi Code CLI** host (primary) and **Kimi Work**
(secondary; full-plugin route experimental, skills fallback available). Automated package checks run locally;
no current-session host activation is established. Package files, host
settings, credentials, marketplace state, and live sessions remain separate
authorities.

## Current documentation release: v1.3.4

The package version is v1.3.4, aligned at family contract
parity with LazyZCode v1.3.4. Fresh Kimi host readiness requires direct observation. This
guide names current human-facing boundaries only and does not promote
package evidence to host proof. The route IDs are `kimi-plugin-manifest`
(the default full-plugin route), `project-init-route` (the manual project
route), and `kimi-work-skills-fallback` (recovery/secondary, skills import
only). Evidence scopes are `package`, `probe`, and `current-session`; public
labels are `documented-tested`, `documented-untested`, `observed-build-
specific`, and `unavailable`.

Automatic workflow selection uses existing risk and complexity signals to
choose the smallest sufficient workflow. Until the host is observed, that
result is selection-only: it does not claim native workflow loading or
dispatch, and **HOST READINESS: PENDING** remains authoritative.

## Durable onboarding (start here)

For new installations use **Node.js 20 or later** plus **Git** and
**Python 3.10+** for the MCP servers. The v1.3.4 family port adds the
durable lifecycle (`lazykimi lifecycle onboard|update|status|offboard|
recover-bootstrap-lock`) under `~/Library/Application Support/LazySeries/
LazyKimi/` on macOS, mirroring the LazyZCode pattern. The public source is
`https://github.com/elvinzhao10/LazyKimi.git`. For project-level use,
`lazykimi init` (from `lazykimi-plugin/`)
copies `.kimi-code/` and `.lazykimi/` into the project and rewrites the
`__KIMI_PLUGIN_ROOT__` placeholder in `.kimi-code/mcp.json` to absolute
paths (Kimi does not interpolate env vars in `mcp.json`). Never treat
package state as proof that a host loaded it.

## Current-message routing contract

Before taking onboarding action, scan the whole current user message,
including every line. Route only explicit direct actions for this turn.
Text presented as a quote, history, example, transcript, or instruction
under discussion is not a new action. If the host or operation is still
ambiguous (Kimi Code CLI vs Kimi Work), ask one focused question and take
no action.

## `onboard` protocol

When the user types `onboard`:

1. Ask which installed host they use: **Kimi Code CLI** or **Kimi Work**.
   Follow only that host route.
2. Run the safe package checks first: `lazykimi load-check` and
   `lazykimi doctor`. These validate package manifests, skills,
   declarations, and local contracts without installing a host plugin,
   changing host settings, or contacting providers.
3. When upgrading from an earlier release, inventory receipt-owned versus
   modified/unknown assets first. Preserve user changes and host settings
   until the new session is observed. Never infer host readiness from a
   PATH entry, file existence, or a load-check.
4. **Kimi Code CLI** has two routes — pick exactly one:
   - **Plugin manifest route (`kimi-plugin-manifest`, default full
     route):** add the repository through `/plugins marketplace` using
     `lazykimi-plugin/marketplace.json` (v2). Declares skills, commands, agents and 16 inline hooks. Manifest MCP
     launchers fail closed without explicit project binding; use the project
     init route for project-bound MCP until manifest request context is supported.
   - **Project init route (`project-init-route`, manual project route):**
     run `lazykimi init`, then `bash lazykimi-plugin/scripts/install-hooks.sh`
     to append the eight critical `[[hooks]]` entries to
     `~/.kimi-code/config.toml`; the project `.kimi-code/mcp.json` declares
     the six servers.
   Do not run both routes together; coexistence is unsupported and may
   double-fire hook events.
5. **Kimi Work** supports full plugins per its official overview; LazyKimi
   full-plugin loading remains experimental until live proof. For the
   recovery route (`kimi-work-skills-fallback`), run
   `bash lazykimi-plugin/scripts/install-kimi-work.sh` to copy the `lazy-*`
   skills into `~/.kimi-work/skills/`, restart Kimi Work, and add each
   `lazykimi-*` MCP server manually through Kimi Work's MCP configuration
   UI (no `mcp.json` autoload; excludes commands/agents/hooks). See
   `lazykimi-plugin/docs/11-kimi-work-setup.md`.
6. Before any host-managed mutation (marketplace add, plugin install,
   connector change, account, credential, or remote provider), ask for
   explicit approval naming the exact action, then give exactly one
   concrete action and wait.
7. After the user responds, inspect the host and record only what is
   visibly observed (`/status`, `/mcp`). Verify one real skill or command
   and the six expected MCP servers in a fresh session. Report the
   observed host result separately from package readiness; without
   observation, **HOST READINESS: PENDING** remains the only honest
   result.

## Host artifact boundary

| Route | Safe package artifact | Host action and expected observation |
| --- | --- | --- |
| **Kimi plugin manifest (`kimi-plugin-manifest`)** | `lazykimi-plugin/marketplace.json` (v2) + `lazykimi-plugin/kimi.plugin.json`; 19 skills, 20 commands, 13 agents, 16 hook events, 6 MCP servers (32 tools). | `/plugins marketplace` add with the repository, install `lazykimi`, start a fresh session; verify skills/commands, hook firing, and the six `lazykimi-*` servers via `/mcp`. |
| **Project init (`project-init-route`)** | `lazykimi init` output: project `.kimi-code/` (skills, `AGENTS.md`, `mcp.json` with rewritten absolute paths) + `.lazykimi/` state; `scripts/install-hooks.sh` appends the eight critical `[[hooks]]` TOML entries. | Open the project in Kimi Code CLI; confirm via `/status` and `/mcp` that the six servers connect with the rewritten absolute paths. |
| **Kimi Work fallback (`kimi-work-skills-fallback`)** | `scripts/install-kimi-work.sh` copying the `lazy-*` skills only. | Restart Kimi Work, observe one imported skill, add each `lazykimi-*` MCP connector manually one at a time. |

## Safe package commands

```bash
# Run from the repository checkout; these are package checks only.
cd lazykimi-plugin && npm ci --ignore-scripts --no-audit --fund=false && npm run build
node dist/index.js load-check
node dist/index.js doctor
node dist/index.js verify --must-pass
```

Do not enable optional remote, browser, or architecture capabilities during
onboarding, and do not run `npm`/`npx` merely to inspect workflow files.

## `offboard` protocol

When the user types `offboard`:

1. Confirm which selected host is being removed: **Kimi Code CLI** or
   **Kimi Work**. Inspect the project receipt and requested uninstall
   scope first.
2. Inspect the selected project's receipt, then run `lazykimi uninstall`
   with its confirmation prompt, or `lazykimi uninstall --yes` when the
   selected scope is already approved. Do not combine with `tooling enable`, guess
   a tooling/host/global path, or scan host directories.
3. Preserve modified, unknown, user-owned, linked, caller-owned, and
   host-managed assets. Report retained assets instead of deleting around
   them. Never delete `~/.kimi-code/` global state, credentials, or MCP
   configuration belonging to another host.
4. Give the remaining manual host step:
   - **Kimi Code CLI (project route):** remove the eight critical
     `[[hooks]]` entries from the selected Kimi config only after checking
     their exact project paths and ownership; preserve modified entries and
     hooks belonging to another project. Project uninstall removes only
     receipt-owned, unchanged MCP entries and preserves other configuration.
   - **Kimi Code CLI (manifest route):** uninstall the `lazykimi` plugin
     through `/plugins`.
   - **Kimi Work fallback:** use the receipt-aware removal described in
     `docs/11-kimi-work-setup.md`; preserve unknown or modified skills. Remove
     only connectors added for the selected route through the host UI.
5. Report **package removal** separately from the **user-observed host
   result** in a new host session; never claim host removal without that
   observation.

## References

- Everyday workflows: [lazykimi-plugin/README.md](lazykimi-plugin/README.md)
- Public verification evidence: [lazykimi-evaluation.md](lazykimi-evaluation.md)
- Kimi Code CLI setup: https://platform.kimi.com/docs/guide/kimi-code-support.md
- Kimi K3 tool calling: https://platform.kimi.com/docs/guide/kimi-k3-tool-calling-best-practice.md
