# Package delivery

This page explains the deployment boundary in code terms. A plugin package
contains files a host may load; it does not contain the host's session state,
API keys, or connector process table.

## Copyable versus observed state

`lazykimi-plugin/` can be copied and checked in isolation. `lazykimi load-check`
inspects the selected package root, manifests, inventories, declarations,
executable scripts, and tooling contract. `lazykimi doctor` adds health
diagnostics. Neither command asks a host to install a plugin or open an MCP
connection.

The host is a second runtime. Kimi Code CLI chooses how `.kimi-code/` is
discovered, when hooks receive events, and when MCP launchers are spawned.
Kimi Work chooses how imported Skills are loaded and whether its Agent Swarm is
invoked. The package models that with declarations and tests; it deliberately
does not scan or mutate host-owned paths to infer success.

## Two evidence channels

```mermaid
flowchart LR
    Copy["copied package"] --> Check["load-check / doctor"] --> Ready["package readiness"]
    Host["selected host"] --> Session["new/reloaded session"] --> Live["observed integration"]
    Ready -. does not imply .-> Live
```

The first channel supports claims about package contents. The second supports
claims about host loading. Keeping the channels separate is what lets uninstall
be safe: package removal cannot guess where a host stored session or connector
data.

## Delivery surfaces

The public source is [LazyKimi on GitHub](https://github.com/elvinzhao10/LazyKimi).
Public source availability does not prove that a particular tag or release
asset is published. Durable onboarding verifies the selected official source
revision before promotion; preserve the existing installation if that source
is unavailable or fails integrity checks.

For the durable lifecycle, use Node 20+, Git and Python 3.10+. The corrected
`v1.3.4` tag points to bootstrap-repaired source `6b5984e`. Select that
version explicitly:

```bash
node lazykimi-plugin/scripts/lazykimi-lifecycle.js onboard \
  --source https://github.com/elvinzhao10/LazyKimi/tree/v1.3.4 \
  --install-root <absolute-install-root> --project <absolute-project> --json
```

The bare official URL selects the current release tag (`v1.3.4`); an explicit
official `/tree/<ref>` URL selects that branch or tag. The lifecycle validates
source and receipts before promotion, preserves prior releases on update,
and requires explicit SHA confirmation when an update changes revision without
changing version. It reports package readiness separately from host readiness.

Kimi Code CLI auto-discovers `.kimi-code/` when the project is opened. Kimi
Work supports full plugins; LazyKimi activation on that route remains
experimental until observed. Work may also use its documented Skills UI or a narrower local-skills import path.
The latter imports skills only; it is intentionally not represented as
automatic agent, hook, command, or MCP loading.

## Hook installation

Hooks are not auto-installed. Run the installer explicitly:

```bash
bash lazykimi-plugin/scripts/install-hooks.sh
```

The installer appends eight critical `[[hooks]]` entries to
the selected `KIMI_CODE_HOME/config.toml`, defaulting to
`~/.kimi-code/config.toml`. It is idempotent and does not overwrite existing
entries, provider/model/permission configuration, or any other host file. After
installation, restart the Kimi Code CLI session so the new hooks take effect.

## MCP configuration

`.kimi-code/mcp.json` declares six local MCP servers. Kimi Code CLI
auto-discovers this file when the project is opened. To inspect or modify MCP
registration interactively, use `/mcp` (list servers) and `/mcp-config`
(configure servers) inside a Kimi Code CLI session. The shipped template uses
the `__KIMI_PLUGIN_ROOT__` placeholder — Kimi does not interpolate environment
variables in `mcp.json` — and `lazykimi init` rewrites it to the absolute
`lazykimi-plugin/` directory and project paths with explicit `--project` and
`--mode` adapter arguments when the project route is initialized. Host plugin
cwd and environment do not supply project binding; unbound manifest launchers
fail closed. The full route and
connector specification is in
[reference/host-routes.md](reference/host-routes.md).

For the Kimi Work fallback, first confirm local stdio support, then add each `lazykimi-*` MCP connector manually through Kimi
Work's MCP configuration UI. The copied repository does not auto-register MCP
servers in Kimi Work.

## Verification commands

```bash
# From lazykimi-plugin/ after npm run build.
node dist/index.js load-check
node dist/index.js doctor
node dist/index.js verify --must-pass
```

Package readiness is not a host-readiness claim. Perform the applicable host
proof from the table in [lazykimi-evaluation.md](../lazykimi-evaluation.md)
before relying on integration behavior.
