# LazyKimi verification evidence

This document records public, present-tense evidence for the LazyKimi package
(v1.3.3, family parity with LazyZCode v1.3.3). It is not evidence that a
specific Kimi Code CLI or Kimi Work session has loaded a plugin. Verification
is on macOS only.

## Evidence scope vocabulary

Every claim below carries one of three scopes:

- **package** — proven by the copied package and its local checks
  (load-check, doctor, verify, regressions) on this checkout.
- **probe** — proven by a bounded local protocol probe against a packaged
  endpoint or script (e.g. JSON-RPC stream fixtures), still without a host;
  since the T21 pass, this also covers bounded probes of the real host
  binary, host config, and past host session transcripts on this machine
  (see "T21 host verification pass"), which still observe no live session.
- **current-session** — observed in a live host session and recorded as an
  observation receipt. No claim in this document currently holds this scope.

Any host behavior not yet observed is **documented-untested**: the package
describes the mechanism, and the host observation pass owns converting it
into evidence. **HOST READINESS: PENDING** until a complete observation
receipt exists (one loaded skill, command, agent, hook, and all six MCP
connections, bound to the active source/version/build/session).

## Project purpose and attribution

LazyKimi is the Kimi-native port of the evidence-led agent workflow harness
originally shipped as LazyBuddy (CodeBuddy host) and LazyTrae (Trae host). It
is primarily inspired by lazycodex/OmO (the canonical TypeScript reference).
Upstream attribution is recorded in [lazykimi-plugin/NOTICE](lazykimi-plugin/NOTICE).
The package is an independent implementation and does not require LazyBuddy,
LazyTrae, or lazycodex at runtime.

## Implemented package behavior

LazyKimi packages 19 `lazy-` skills, 20 `lazy-*` command documents, 13 family
role-agent definitions, 16 hook event declarations (critical 8 on the TOML
route), and six local MCP declarations exposing 32 tools: `run-ledger` (9),
`verification` (7), `status-dashboard` (4), `context-graph` (5), `code-intel`
(5), and `docs` (2). The package checks validate manifests, component
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

## T21 host verification pass (2026-09-30)

A real Kimi Code CLI is installed on this machine: `/Users/Admin/.kimi-code/bin/kimi`
(also on `PATH`), `kimi --version` → `0.27.0` (v0.26.0+ requirement met).
Every item below records one of three outcomes — OBSERVED (with receipt),
DOCUMENTED-UNTESTED (with the exact blocking reason), or FAILED-MISMATCH
(observed behavior differs from the shipped claim; the adaptation is recorded,
never silently invented). Live-session items are blocked by host auth: the
stored OAuth credential is expired (`expires_at: 0`, refresh fails) and
`kimi -p "..."` exits with
`error: failed to run prompt: auth.login_required: OAuth provider "managed:kimi-code" requires login before it can be used.`
Device-code re-login requires an interactive user browser action and was not
performed. Scope for all OBSERVED items below is `probe` (bounded probes of
the real host binary, host config, and past host session transcripts on this
machine); no `current-session` claim is made, so **HOST READINESS: PENDING**
stands.

| # | Checklist item | Outcome | Evidence summary |
|---|---|---|---|
| 1 | CLI v0.26.0+, `/status`, `/mcp` six servers | OBSERVED (version/help) + DOCUMENTED-UNTESTED (session) | `kimi --version` → `0.27.0`; help exposes `-p/--prompt`, `--output-format stream-json`, `-m/--model`, `--plan`. `/status` and `/mcp` need an auth'd session (receipt above); the six-server surface keeps package-scope proof via `lazykimi-mcp-test.sh`. |
| 2 | Plugin-manifest route (marketplace add, 16 hooks fire, inline mcpServers, sessionStart.skill) | DOCUMENTED-UNTESTED | `/plugins marketplace` is interactive+auth-gated. Package scope: `kimi.plugin.json` (16 inline hook events, inline `mcpServers`) validated by marketplace-route-check and load-check. |
| 3 | TOML route: install critical-8, hooks fire, uninstall removes exactly those blocks | OBSERVED (structure + host validator + exact removal) + DOCUMENTED-UNTESTED (firing) | Driven in an isolated temp project. `lazykimi init` left `~/.kimi-code/config.toml` byte-untouched (`cmp` clean). `install-hooks.sh --project-root <tmp>` appended exactly 8 `[[hooks]]` blocks (absolute paths; `PreToolUse` carries `matcher = "Bash"`); real host `kimi doctor config` → `OK config.toml — All checked config files are valid` with the blocks present. Full `lazykimi uninstall --yes` from the temp project removed exactly those 8 blocks (0 references left; the 8 pre-existing v0.x blocks untouched). Residue: one trailing blank line at EOF (the remover's newline normalization); the file was restored byte-identically from a pre-test snapshot (sha256 match) and re-validated. Corroborating probe: the live host config already carried 8 v0.x-era `[[hooks]]` blocks with the same event/matcher/command/timeout schema. Hook *firing* still requires a session → documented-untested. |
| 4 | Subagent channels coder/explore/plan; 13-agent mapping; `disallowed`/`effort` effects | DOCUMENTED-UNTESTED (mapping/effects) + corroborating probe | Real past sessions on this machine store per-agent transcripts (`agents/main` plus `agents/agent-0..N/`) and the host active-tools record includes an `Agent` tool, so the multi-agent machinery is real; the lazykimi 3-channel mapping and frontmatter effects were not observed live. |
| 5 | PreToolUse tool names for the Write/Edit matcher | OBSERVED | Real session transcript (`~/.kimi-code/sessions/wd_lazykimi_1870ec855ce5/.../agents/main/wire.jsonl`, 2026-07-19): `tools.set_active_tools` + `llm.tools_snapshot` list exactly `Write` and `Edit` (with `Read`, `Bash`, `Grep`, `Glob`, `Agent`, `Skill`, …). The shipped T9 matcher (Write/Edit plus defensive Bash aliases) is confirmed — no mismatch. Corroborating: permission records use camelCase `toolName`, matching the shipped dual-key normalization. |
| 6 | Kimi effort/model routing scale | FAILED-MISMATCH → ADAPTED | OBSERVED: live `~/.kimi-code/config.toml` `[models."kimi-code/k3"]` carries `support_efforts = ["low", "high", "max"]` and `default_effort = "high"`; `kimi provider list` → 1 provider, 3 model aliases; `default_model = "kimi-code/kimi-for-coding"`; `-m` flag selects aliases. MISMATCH: the shipped agents used a provisional 4-tier scale (`low|standard|high|xhigh`, flagged "pending host verification" in `validate-agent-frontmatter.js`) — `standard` (2 agents) and `xhigh` (4 agents) are outside the observed `kimi-k3` scale. Adaptation applied: `standard`→`high` (family middle intent; Kimi has no middle tier and defaults to `high`), `xhigh`→`max`; validator `EFFORTS`, the frontmatter policy test, and both `model-routing.md` copies (hardlinked) updated; all 13 agents now use `low` (3) / `high` (6) / `max` (4). Per-agent effort *application* in a live session remains documented-untested; the routing policy entry stays effort-free. |
| 7 | Kimi Work: install 19 skills, restart, one skill observed | OBSERVED (installer mechanics) + DOCUMENTED-UNTESTED (activation) | Real target detected: `~/.kimi-work/skills` (pre-existing 17 v0.x `lazy-*` dirs). `install-kimi-work.sh` copied all 19 v1.3.3 skills (0 skipped — v0.x content differed; net-new dirnames `lazy-report-bug`, `lazy-review-work`, `lazy-ultrawork`) and printed the 6 manual MCP server commands with absolute paths. Test copy fully restored from snapshot (`diff -rq` clean, 17 dirs). Kimi Work restart/Skills-UI activation and manual MCP connectors are GUI-only → documented-untested; `/Applications/Kimi.app` identity as the Kimi Work beta host is unverified. |
| 8 | Native modes interplay (`/swarm`, `/goal`, `/plan`) | OBSERVED (surface) + DOCUMENTED-UNTESTED (behavior) | `kimi --help` exposes `--plan` ("Start in plan mode"); the real active-tools record includes `EnterPlanMode`/`ExitPlanMode`, `AgentSwarm`, and `CreateGoal`/`GetGoal`/`SetGoalBudget`/`UpdateGoal` — the native mode surfaces exist. Live `/swarm`/`/goal`/`/plan` behavior and coexistence with `.lazykimi/` runs remain documented-untested; the package continues to claim no auto-wiring between native modes and `.lazykimi/` state. |

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
  independent task implementation, and parallel review lanes (reviewer,
  verifier, security-auditor as peers).
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
| Skills | 14 | 17 | 16+ | 19 |
| Commands | — | — | — | 20 |
| Agents | 13 | 11 | 5 (TOML) | 13 family roles (mapped to 3 Kimi sub-agents + main) |
| Hooks | 12 | eight | 24 | 16 |
| MCP servers | 6 | 15 tools | N/A | 6 (32 tools) |
| Host | CodeBuddy | Trae IDE/Work/CLI | Codex | Kimi Code CLI |
| Language | Bash/Python | Node.js | TypeScript | TS CLI + Bash hooks + Bash/Python MCP |
| Native swarm | No | No | No | Yes (/swarm 300 agents) |
| Native goal mode | No | No | No | Yes (/goal) |
| Native plan mode | No | No | No | Yes (/plan on/off) |
| License | MIT | MIT | MIT | MIT |

### Per-capability notes

- **Skills**: LazyKimi historically inherited the LazyTrae skill set (17);
  v1.3.3 grows it to the family 19-skill set (renaming `lazy-lcx-report-bug`
  to `lazy-report-bug`, adding `lazy-review-work` and `lazy-ultrawork`) and
  adapts each `SKILL.md` to Kimi Code CLI's YAML frontmatter (`name`,
  `description`, `type`, `whenToUse`, `arguments`) and invocation conventions
  (`/skill:<name>` or `/<name>` shorthand).
- **Agents**: v0.x inherited LazyTrae's 11 Greek-myth roles (historical
  attribution); v1.3.3 replaces them with the 13 family role agents mapped to
  Kimi Code CLI's three built-in sub-agent channels (`coder`, `explore`,
  `plan`) plus the main session. This is a structural difference from
  LazyBuddy (13 roles, no sub-agent channel constraint) and lazycodex
  (5 TOML agents).
- **Hook scripts**: LazyKimi ships 16 hook scripts covering the
  events Kimi Code CLI exposes through `[[hooks]]` in `~/.kimi-code/config.toml`,
  with the lazyzcode v1.3.3 hardened pre-tool semantics.
- **MCP**: LazyKimi inherits LazyBuddy's six-server model (run-ledger,
  verification, status-dashboard, context-graph, code-intel, docs), rebuilt
  in v1.3.3 to the family 32-tool surface behind the profile gate. LazyTrae
  consolidates into a single Node.js core server exposing 15 tools.
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
