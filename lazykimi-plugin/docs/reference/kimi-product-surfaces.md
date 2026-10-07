# Kimi products and LazyKimi acceptance

Researched against official documentation on 2026-10-02. Kimi Code is the
coding service/product family; a model subscription or API key alone does not
identify the client executing a workflow. [Official overview](https://www.kimi.com/code/docs/en/).

## Names and execution surfaces

| Surface | Identity and purpose | Integration boundary |
| --- | --- | --- |
| Kimi Code CLI | Terminal coding agent, started with `kimi`. | Record client version and executable; terminal sessions own their loading and approvals. |
| Kimi Code for VS Code | Official extension inside VS Code, with chat and diff review. | The extension uses a CLI executable, bundled or selected with `kimi.executablePath`; record both versions. |
| CLI through an ACP editor | Zed, JetBrains and similar integrations start `kimi acp`. | The editor drives a CLI child process through ACP; editor process environment and MCP forwarding need their own checks. |
| Kimi Code Desktop | Dedicated graphical coding app with project/session management, changes, terminal and browser. | A distinct app, with documented shared CLI configuration and additional app-owned UI state. |
| Kimi Work | General-purpose local agent in the Work mode of the Kimi desktop client. | Knowledge-work tasks, local files and deliverables, browser work, plugins and scheduling; distinct from the dedicated coding app. |

The official names are **Kimi Code for VS Code** and **Kimi Code CLI in IDEs**;
“Kimi Code IDE” does not specify which of those is in use.
[VS Code quick start](https://www.kimi.com/code/docs/en/kimi-code-for-vscode/getting-started.html),
[ACP IDE guide](https://www.kimi.com/code/docs/en/kimi-code-cli/guides/ides.html),
[Code Desktop quick start](https://www.kimi.com/code/docs/en/kimi-code-desktop/getting-started.html),
[Work overview](https://www.kimi.com/en/help/kimi-work/overview).

## Shared settings do not merge product identities

Code Desktop documents the CLI's skill format and locations, user/project
`mcp.json`, and hooks in `~/.kimi-code/config.toml`. Its shared local data
includes configuration, credentials, sessions and logs; app UI state has a
separate location. These are host capabilities, not proof that LazyKimi has
loaded correctly. Removing owned LazyKimi entries can affect multiple Code
clients using the same configuration. Preserve host credentials, sessions,
other plugins and unknown files. [Desktop settings](https://www.kimi.com/code/docs/en/kimi-code-desktop/settings-and-extensions.html).

Work also documents full plugins, including skills, MCP, agents, hooks,
commands and system instructions. The Kimi web plugin surface documents only
skills and MCP. Work's broader host support does not make LazyKimi's full Work
route tested; the skills-copy helper is only a fallback.
[Official plugin comparison](https://www.kimi.com/en/help/plugins-and-skills/overview).

Work is supported on Windows and Apple-silicon Macs; the general Kimi desktop
app on Intel Macs supports Chat only. Code Desktop separately offers macOS
Apple-silicon/Intel and Windows builds. Verify the selected app's platform,
rather than transferring the Work restriction to Code Desktop.
[General Kimi downloads](https://www.kimi.com/en/products/download),
[Code client downloads](https://www.kimi.com/code/docs/en/).

## Current CLI versus legacy kimi-cli

The official migration guide describes the current CLI as a Node.js rewrite
of Python/uv `kimi-cli`. Migration can bring configuration, MCP settings and
selected sessions across, but excludes OAuth credentials, MCP authorizations
and legacy plugins. Do not assume a prior plugin installation migrated.
[Migration details](https://www.kimi.com/code/docs/en/kimi-code-cli/guides/migration.html).

The upstream command is `kimi`; the package's `lazykimi` command is the
LazyKimi harness CLI. LazyKimi's Python MCP prerequisites do not imply the
current upstream Kimi Code CLI is Python-based.

## LazyKimi v1.4.0 support statement

Package fixtures, extracted archives and isolated lifecycle checks are separate
from native client acceptance; consult their run artifacts for results.
No fresh authenticated acceptance was established for the current Node CLI,
VS Code extension, ACP editors, Code Desktop or Work during this research.
Shared configuration makes CLI/IDE/Desktop reuse a reasonable **candidate for
validation**, not established full support. Keep Work's route experimental.

Before promoting any surface to supported, record its version and runtime,
then observe discovery, one real skill/command, relevant hooks, project-bound
MCP, delegation restrictions and receipt-safe removal in that same surface.
For IDEs record the editor and extension or ACP transport; for desktop apps
record the exact app name. Use [the install guide](../03-install-and-host-verification.md)
for package checks and [the Work guide](../11-kimi-work-setup.md) for fallback limits.

See [the current platform audit](platform-status-2026-10-02.md) for the current plugin commands, managed-copy retention and shared-core boundary.

## Project platform capability surface record (v1.4.0, T24)

The persistent project platform (vendored `shared/project` family, the Kimi
project record under `.lazykimi/project/`, the neutral `.lazyseries/project.json`
registry, source editing, plan/baseline records and honest run observations) is
proven at the **package** scope only: real CLI round trips through
`shared/project/cli.mjs` and `shared/dashboard-host/project.mjs`, and real
MCP stdio round trips through the status-dashboard `project` tool, all driven
from this repository's tests against disposable fixture projects. Package
proof does not establish native host adoption.

| Capability | Package evidence (this repo) | Kimi Code CLI | VS Code / ACP editor | Code Desktop | Kimi Work |
| --- | --- | --- | --- | --- | --- |
| Project init/read/command (`.lazykimi/project/`) | `shared/dashboard-host/test/project-adapter.test.mjs` (real bridge round trips) | not observed in a host session | not observed | not observed | not observed |
| Registered original-source editing | same test, `source.edit` preview/apply with fence/prose preservation | not observed | not observed | not observed | not observed |
| Native run link + honest execution observation | same test, `link_native_run` + `observe` over `.lazykimi` journal/CAS manifests | not observed | not observed | not observed | not observed |
| Typed project tools over MCP | same test, status-dashboard `project` tool stdio round trip | host adoption pending (project-bound MCP route exists; not observed in a client) | not observed | not observed | not delivered by the skills fallback (fallback ships skills only, no MCP) |
| Pre-init inertness (typed hint, no side effects) | same test (IO-1/IO-3 probes) | n/a — property of the package route | n/a | n/a | n/a |

Conversational host-session consumption, automatic wake and host embedding of
the project tools stay explicitly **unavailable/unobserved** on every surface
until the exact named host surface exercises them; `HOST READINESS: PENDING`
remains authoritative. Native delivery/consumption of recorded requests is
reported by the native runtime only and is never inferred from file writes.
