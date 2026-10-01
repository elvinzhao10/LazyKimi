# Kimi products and LazyKimi acceptance

Researched against official documentation on 2026-10-01. Kimi Code is the
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

## LazyKimi v1.3.4 support statement

Package fixtures, extracted archives and isolated lifecycle checks pass.
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
