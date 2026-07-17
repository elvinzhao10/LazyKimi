# LazyKimi verification evidence

This document records public, present-tense evidence for the LazyKimi package.
It is not evidence that a specific Kimi Code CLI or Kimi Work session has
loaded a plugin. Verification is on macOS only.

## Project purpose and attribution

LazyKimi is the Kimi-native port of the evidence-led agent workflow harness
originally shipped as LazyBuddy (CodeBuddy host) and LazyTrae (Trae host). It
is primarily inspired by lazycodex/OmO (the canonical TypeScript reference).
Upstream attribution is recorded in [lazykimi-plugin/NOTICE](lazykimi-plugin/NOTICE).
The package is an independent implementation and does not require LazyBuddy,
LazyTrae, or lazycodex at runtime.

## Implemented package behavior

LazyKimi packages 17 `lazy-` skills, 11 Greek-myth agent role definitions, 8
hook event declarations, and six local MCP declarations exposing 19 tools:
`run-ledger`, `verification`, `status-dashboard`, `context-graph`,
`code-intel`, and `docs`. The package checks validate manifests, component
inventory, JSON, executable MCP scripts, internal Markdown links, hook and
security behavior, and MCP protocol regressions.

`lazykimi load-check` reports `PACKAGE_READINESS=full` when the copied
package assets and local contracts are complete. `lazykimi doctor` and
`lazykimi verify --must-pass` provide package health and an aggregate
verification gate. These commands are evidence about the package, not a host
session.

The `docs` MCP boundary accepts validated npm or PyPI package names and
requests only the fixed HTTPS npm or PyPI registry endpoint. Redirects and
metadata URLs such as a package homepage, repository, or documentation link
are not followed. Structured `Write` and `Edit` secret protection examines
only the supported target-path fields; text that merely mentions a
secret-like filename is not a target. `Bash` retains its conservative literal
scan, so a command that merely contains such a path can still be denied.

InitDeep can use an explicitly supplied absolute `KIMI_PLUGIN_ROOT` from an
unrelated workspace. It does not search parents, siblings, marketplaces, or
the filesystem for another plugin. A parent marketplace file may be read only
to compare its entry version with the already selected root; this is metadata
validation, not root discovery or host proof.

Aggregate verification emits bounded per-check status and reason. A deadline
is a failure, an absent Kimi Code CLI validator is **UNCHECKED**, and a
validator timeout, launch failure, nonzero result, or semantic failure never
becomes a host-success claim.

For trusted package-owned verification commands, each bounded check starts in
its own process group. A deadline triggers best-effort termination of that
owned group, and the JSON/stderr result reports whether descendants were still
detectable at cleanup time. This is not a security sandbox and does not
guarantee all descendants are gone; genuinely untrusted commands require a VM
or container-backed runner. A no-fork sandbox is not enabled by default.

## Host support and required observation

| Surface | Package evidence | Required user observation |
|---|---|---|
| Kimi Code CLI | Copyable package, `.kimi-code/` declarations, local checks, and six MCP declarations. | Open the project, confirm a `/skill:lazy-<name>` or `/<name>` invocation and MCP status in a new session. |
| Kimi Work | Compatibility metadata and package skills are present. | Use the documented Skills UI and confirm a loaded Skills entry and Agent Swarm session before relying on plugin capabilities. |
| Kimi Work local fallback | `lazykimi-plugin/.kimi-code/skills/` is the verified no-package-manager import source. | Import skills through the Skills UI and add each compatible MCP connector manually. |

The copied repository is not a verified Kimi Work plugin installer. Package
readiness cannot prove SessionStart, hook execution, Skills activation, a live
session, or MCP connection.

## Public capability status contract

`lazykimi doctor`, `load-check`, and capability reports are read-only
canonical package evidence. They report assets, capability eligibility,
policy, and receipt state without provider execution, optional activation,
host registration, or a claim that a live host loaded the package.

## Receipt and safe removal

Receipt ownership is enforced for package tooling. Only an exact, unmodified
receipt-owned root can be removed. Modified, foreign, linked, caller-owned,
project, and host-managed paths are preserved. This boundary protects local
tooling and does not authorize removal of host plugin, marketplace, MCP, or
credential state.

## Package readiness versus host verification

Package readiness validates copied contents, declarations, inventories, and
local contracts. It does not prove host discovery, SessionStart, hooks,
marketplace installation, a running session, or MCP connection. The host
observation in the support table is required before making an integration
claim.

## JSON-RPC resilience

The six packaged local MCP endpoints have JSON-RPC stream regression coverage,
including malformed input and subsequent-request behavior. This is protocol
evidence for the package, not proof that a host process launched or connected
an endpoint.

## Kimi-native mode integration

LazyKimi is the first harness in the LazySeries to map its workflow onto
native host modes rather than emulating them through agents alone:

- `/swarm <task>` (up to 300 agents) — used for parallel Explore, parallel
  independent task implementation, and parallel review (Oracle + Momus).
- `/goal <objective>` — persistent autonomous objective used for the
  Implement phase when the work is a single large objective.
- `/plan on` / `/plan off` — plan mode toggle used to constrain the session
  to read-only + plan-file writes during the Plan phase.

These modes are host capabilities; the package declares how to use them but
cannot prove the host actually invoked them.

## macOS verification scope

LazyKimi is verified on macOS only. Normal CI does not require a sibling
repository. Release-only paired parity receives explicitly supplied sibling
roots as release evidence and never creates a runtime or installation
dependency.

## Attribution and limits

[lazykimi-plugin/NOTICE](lazykimi-plugin/NOTICE) and
[lazykimi-plugin/LICENSE](lazykimi-plugin/LICENSE) are the attribution and
license records. This evidence describes the package's tested boundaries and
does not claim host behavior beyond the required manual observations.

## Capability comparison with LazyBuddy, LazyTrae, and lazycodex

The comparison below is a capability comparison, not a compatibility or
drop-in replacement claim. All four projects share the same evidence-led
workflow heritage and the same MIT license.

| Capability | LazyBuddy | LazyTrae | lazycodex | LazyKimi |
|---|---|---|---|---|
| Skills | 14 | 17 | 16+ | 17 |
| Agents | 13 | 11 | 5 (TOML) | 11 (mapped to 3 Kimi sub-agents) |
| Hooks | 12 | 8 | 24 | 8 |
| MCP servers | 6 | 15 tools | N/A | 6 (19 tools) |
| Host | CodeBuddy | Trae IDE/Work/CLI | Codex | Kimi Code CLI |
| Language | Bash/Python | Node.js | TypeScript | TS CLI + Bash hooks + Python MCP |
| Native swarm | No | No | No | Yes (/swarm 300 agents) |
| Native goal mode | No | No | No | Yes (/goal) |
| Native plan mode | No | No | No | Yes (/plan on/off) |
| License | MIT | MIT | MIT | MIT |

### Per-capability notes

- **Skills**: LazyKimi inherits the LazyTrae skill count (17) and adapts each
  `SKILL.md` to Kimi Code CLI's YAML frontmatter (`name`, `description`,
  `type`, `whenToUse`, `arguments`) and invocation conventions
  (`/skill:<name>` or `/<name>` shorthand).
- **Agents**: LazyKimi inherits LazyTrae's 11 Greek-myth roles and maps them
  to Kimi Code CLI's three built-in sub-agent channels (`coder`, `explore`,
  `plan`) plus the main agent. This is a structural difference from LazyBuddy
  (13 roles, no sub-agent channel constraint) and lazycodex (5 TOML agents).
- **Hooks**: LazyKimi ships 8 hook scripts (matching LazyTrae) covering the
  events Kimi Code CLI exposes through `[[hooks]]` in `~/.kimi-code/config.toml`.
- **MCP**: LazyKimi inherits LazyBuddy's six-server Python model (run-ledger,
  verification, status-dashboard, context-graph, code-intel, docs) exposing
  19 tools. LazyTrae consolidates into a single Node.js core server exposing
  15 tools.
- **Native modes**: LazyKimi is the only harness in the series whose target
  host exposes native swarm, goal, and plan modes. The other harnesses
  emulate these through agents and loops.
- **Language**: LazyKimi is polyglot by necessity — TypeScript for the CLI
  (matching Kimi Code CLI's own TypeScript runtime), Bash for hooks (matching
  the `command` field in `[[hooks]]` entries), and Python for MCP servers
  (inheriting LazyBuddy's proven JSON-RPC implementations).

## Deliberate differences from upstream

| Reference capability family | LazyKimi realization | Deliberate difference or limitation |
| --- | --- | --- |
| Project memory | `lazy-init-deep`, managed agent instructions, and explicit plugin-root selection. | No automatic parent/sibling or marketplace discovery; host loading remains unverified until observed. |
| Planning and durable execution | Plan, start-work, loop, evidence, and verifier instruction surfaces mapped to `/plan`, `/goal`, and `/swarm`. | The host decides whether commands, hooks, agents, and native modes are actually available in a session. |
| Specialized roles and review | Packaged planning, implementation, QA, security, context, and verifier roles mapped to three Kimi sub-agent channels. | Role definitions are package assets; they are not evidence that a host spawned a role. |
| Hooks and lifecycle | Declared hook events plus structured pre/post-tool policy scripts installed into `~/.kimi-code/config.toml`. | Hooks are host-governed and are not an enforcement boundary until the host reports them loaded. |
| Diagnostics and removal | Load-check, doctor, aggregate verifier, receipts, and conservative removal. | Results establish package readiness, not marketplace activation, live session behavior, or MCP connection. |
| Installation model | A self-contained Kimi Code CLI package with manual host steps. | It intentionally does not reproduce lazycodex's installer, managed global configuration, provisioning, model routing, or automatic host mutation. |

The upstream projects are useful architectural references, but LazyKimi keeps
the same small ownership model as LazyBuddy and LazyTrae: package-owned assets
are verifiable and removable; host-owned settings and live integrations
require an explicit user observation.
