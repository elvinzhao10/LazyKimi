# LazyKimi

![LazyKimi](lazykimi-banner.png)

[![Package 1.3.4](https://img.shields.io/badge/package-1.3.4-7ce8d1)](RELEASE_NOTES.md)
[![MIT License](https://img.shields.io/badge/license-MIT-silver)](LICENSE)
[![LazySeries family](https://img.shields.io/badge/LazySeries-6_siblings-7ce8d1)](#lazyseries-family)

**Describe the work. Keep the plan. Prove the result.**

LazyKimi brings structured, evidence-based workflows to **Kimi Code CLI**.
Kimi Work is a secondary, experimental full-plugin route with a skills fallback.
Kimi Code for VS Code, IDE integration through ACP, and **Kimi Code Desktop**
are separate acceptance targets. Kimi Code Desktop and Kimi Work are distinct
products; see the [surface guide](docs/reference/kimi-product-surfaces.md).

[Get started](#recommended-install-with-ai-help) · [Host routes](#choose-one-route) ·
[1.3.4 notes](RELEASE_NOTES.md) · [Family](#lazyseries-family) · [Docs](docs/)

> **Current package version: v1.3.4. HOST READINESS: PENDING.** Local checks and release
> archives prove package behavior; a fresh host session must prove loading,
> command/skill execution and MCP connections.

## What's in 1.3.4

- Project-bound MCP adapters use explicit project paths; unbound global launches fail closed. Native agent headers replace invented settings.
- Receipt-aware setup merges owned MCP entries, respects KIMI_CODE_HOME, and preserves modified or unknown files.
- Public-source bootstrap stages regular publication files and validates the internal hook bridge. The archive includes the compiled CLI.
- Finalization requires all intended tasks to be done; persisted status is
  assessed separately from completion evidence.

This is a maintenance release. It includes the workflow foundation introduced
in the family since v1.3.0 and subsequent reliability work. For Kimi and DeepSeek,
that describes inherited family behavior, not prior public releases of these
ports. The details below describe the cumulative v1.3.4 experience; the
[release notes](RELEASE_NOTES.md) distinguish this patch's fixes from inherited
features. No new speed, token-saving or cost claim is made.

| Family milestone | What you get in the current package |
| --- | --- |
| v1.3.0 foundation | Natural-language entry, editable plans, durable decisions and verification tiers. |
| v1.3.1 reliability | Clearer execution intent, safer isolation and evidence comparisons. |
| v1.3.2 handoff | Revision-bound verification-report contracts; generic completion APIs have separate limits. |
| v1.3.3 hardening | Host-specific hook, MCP and publication repairs. |
| v1.3.4 maintenance | The run-integrity and native-adapter fixes listed above. |

### Just ask, or use a command — both work

Two entry routes converge on the same execution authority and gates:

- **Natural language**: describe the work plainly — "Fix the typo in the
  welcome label" — and the smallest sufficient workflow is selected and run.
- **Explicit commands**: `/lazy-ulw-plan <idea>` builds a new plan, and
  `/lazy-start-work <plan>` executes a known plan. Same authority, same gates.

No slash command is required for a clear implementation request. Conversely,
asking to *explain*, quoting a command, or saying "plan only" never touches
your files: the persisted `execution_intent` stays `plan_only` until you
actually ask for execution, and a vague "ok" with several open questions never
grants execution by itself.

### Plans you can edit while work runs

Plans are Markdown you own. Edit them mid-run; the harness reconciles your
changes at execution boundaries instead of overwriting them:

- Cosmetic wording and ordering edits preserve existing evidence.
- Semantic edits (acceptance, dependencies, verification commands) invalidate
  only the affected task and its dependents — unrelated work is untouched.
- Your checkbox is an *assertion*, not a verdict: a checked box alone never
  counts as verified completion, and unchecking reopens the task.

### Decisions the harness remembers

Cross-plan decisions live in a durable ledger (`.lazykimi/decisions/ledger.jsonl`).
When plan two hits a question plan one already answered — with evidence — it
recalls the decision instead of re-asking you. Contradictions are surfaced as
supersessions, defects become scoped corrections that block only the affected
work, and nothing in memory can override your current instructions.

### Verification sized to the change

The workflow calls for verification sized to the change: a documentation
inspection (V0), a focused check (V1), an integration scenario (V2), or a
comprehensive security/release gate (V3, normally in CI). Valid evidence may be
reused while its inputs match; affected, missing or stale checks must rerun.
Native execution still needs acceptance in the selected host.

Milestones, decision gates, and full state/version semantics are shared
byte-identically with its sibling ports (see
`lazykimi-plugin/contracts/lazyseries-shared-semantics.v1.json`).

## Recommended: install with AI help

Open an AI coding assistant in your project and paste this:

> Help me install LazyKimi from https://github.com/elvinzhao10/LazyKimi for
> this project. Read AGENTS.md and the current install guide. Use the
> versioned v1.3.4 source and run safe
> package checks first, choose one explicitly project-bound route, and ask me
> before changing plugins, global hooks, MCP, credentials or trust settings.

The assistant can guide onboarding; approve each host-managed change.

## Manual setup

Use **Node.js LTS 24 (recommended) or 22**, **Git**, and **Python 3.10+**
for the MCP servers. The lifecycle also accepts Node.js 20 for compatibility.
Follow [AGENTS.md](AGENTS.md) and the
[installation guide](docs/03-install-and-host-verification.md).

The corrected `v1.3.4` tag includes the bootstrap repair and family
documentation at commit `6b5984e`. Clone the versioned source:

```bash
git clone --branch v1.3.4 https://github.com/elvinzhao10/LazyKimi.git
cd LazyKimi
```

Source checkouts need a CLI build; the release archive includes it:

```bash
cd lazykimi-plugin
npm ci --ignore-scripts --no-audit --fund=false
npm run build
node dist/index.js load-check
node dist/index.js doctor
```

Run `lifecycle onboard` for a durable installation. Use its stable launcher
for later status, update and receipt-safe offboard, with the selected project:

```text
node "<install-root>/LazyKimi/launcher.js" lifecycle status --project "<absolute-project-root>"
```

## What “ready” means

- **Package readiness** means copied files, declarations and local checks pass.
- **Host readiness** requires a fresh selected-host session, one real skill or
  command, hook observations where supported, and all six MCP connections.

Until observed, **HOST READINESS: PENDING**. Package fixtures and macOS source
checks do not prove IDE, desktop, Linux or Windows acceptance. Do not turn
native `/swarm`, `/goal` or `/plan` availability into a LazyKimi acceptance claim.

## Choose one route

### Identify the Kimi client first

| Name | What it means | LazyKimi acceptance |
| --- | --- | --- |
| Kimi Code CLI | Coding agent launched with `kimi` in a terminal. | Primary package target; current native host session still pending. |
| Kimi Code for VS Code | Official editor extension with a Kimi panel and code review UI. | Separate extension/CLI build acceptance pending. |
| Kimi Code in an ACP IDE | An editor such as Zed or JetBrains launches `kimi acp`. | CLI-backed integration; editor session acceptance pending. |
| Kimi Code Desktop | Standalone graphical coding client for local projects. | Shares documented CLI extension settings; package acceptance pending. |
| Kimi Work | Work mode of the general Kimi desktop app, for local knowledge work. | Experimental full-plugin route; skills-only fallback remains narrower. |

“Kimi Code IDE” is a broad description, not a sufficient installation target.
Record the editor/extension or ACP path and exact host build. The current
[CLI migration guide](https://www.kimi.com/code/docs/en/kimi-code-cli/guides/migration.html)
also distinguishes the Node.js client from legacy Python `kimi-cli`; old
client evidence does not establish new-client compatibility. Product facts and
sources are in the [surface guide](docs/reference/kimi-product-surfaces.md).

| Route | Package behavior | Remaining acceptance |
| --- | --- | --- |
| Kimi Code CLI project init | `lazykimi init` creates explicitly bound project MCP configuration; the hook helper installs eight critical hooks in the selected Kimi config. | Fresh session loading, command/skill use, hooks and MCP. |
| Kimi plugin manifest | Declares skills, commands, agents, sixteen hooks and six MCP launchers. Unbound project-state MCP fails closed. | Full plugin acceptance and supported request-context project binding. Use the project route for bound MCP. |
| Kimi Work | Experimental full plugin; fallback imports skills and uses manual MCP configuration. | Full plugin loading, agents, commands, hooks and project binding. Fallback excludes commands, agents and hooks. |

Choose one route per project; combining manifest and project routes may fire
hooks twice. Respect `KIMI_CODE_HOME` when selecting global configuration.

Kimi Work's host supports broader plugin components according to the
[official overview](https://www.kimi.com/en/help/plugins-and-skills/overview).
That does not establish this package's full support. Kimi web supports skills
and MCP; it is not a full local LazyKimi installation route. See the
[Work guide](docs/11-kimi-work-setup.md) for the fallback limits.

## Design mindset

Start with the result you want and how you will know it worked. Then use the
smallest amount of structure that fits the task. You can simply describe the
work in plain language; the modes are guidance, not commands you need to
memorize. The v1.3.0 dual-entry routing picks one of these for you.

| Mode | Use it when | Example request |
| --- | --- | --- |
| Direct | The change is small and clear. | “Fix this error and run the relevant test.” |
| Assisted | You need help understanding an unfamiliar area or failure. | “Help me find why this command fails, then verify the fix.” |
| Planned | The work has several parts or important choices. | “Make a plan for this feature before changing files.” |
| Orchestrated | The work affects a release, security, or a risky change. | “Review this release and prepare it for publication.” |
| Long-horizon | The goal needs to continue across sessions. | “Keep working on this migration with checkpoints.” |


## Keep host changes deliberate

LazyKimi does not automate credentials, OAuth values, private registries, or
trust settings. It asks for approval before any host-managed action and keeps
safe package checks separate from marketplace and connector changes.


## Package inventory

| Surface | Count | Role |
| --- | ---: | --- |
| Skills | 19 | Host-facing workflow policies for planning, execution, review, and verification. |
| Commands | 20 | Named host entry points for those workflow policies. |
| Agents | 13 | Family role definitions mapped to Kimi Code CLI's three sub-agent channels plus the main session. |
| MCP declarations | 6 | Local services for ledger, verification, status, context, code intelligence, and docs (32 tools). |
| Hooks | 16 | Hook event declarations; the critical 8 install into `~/.kimi-code/config.toml`, all 16 ride the plugin manifest. |

## LazySeries family

**One workflow philosophy. Six host integrations.** Choose the sibling for the
host you use; each keeps its own native adapters, installation route and
acceptance evidence. These packages run independently.

| Sibling | Target host |
| --- | --- |
| [LazyBuddy](https://github.com/elvinzhao10/LazyBuddy) | CodeBuddy CLI / IDE · WorkBuddy |
| [LazyTrae](https://github.com/elvinzhao10/LazyTrae) | TraeCode / TraeWork / TraeCode CLI |
| [LazyQoder](https://github.com/elvinzhao10/LazyQoder) | Qoder CLI / IDE / app |
| [LazyZCode](https://github.com/elvinzhao10/LazyZCode) | ZCode |
| [LazyKimi](https://github.com/elvinzhao10/LazyKimi) **← you are here** | Kimi Code CLI · Kimi Work (experimental) |
| [LazyDeepSeek](https://github.com/elvinzhao10/LazyDeepSeek) | DeepSeek Harness 0.2.0-rc.2 |

The family shares planning, evidence, decision-memory and completion contracts.
Matching contracts do not make host capabilities interchangeable. In particular,
Kimi Work remains experimental for LazyKimi, and DeepSeek's synthesized events
are not native hooks. Use each sibling's host guide before installation.

## Technical reference and evaluation

The [documentation index](docs/) explains the package, state model,
security boundaries and MCP lifecycle. The
[plugin README](lazykimi-plugin/README.md) contains detailed routes and CLI use.
The [evaluation](lazykimi-evaluation.md) separates package checks from host evidence.

Root community files and `docs/` are regular publication copies, not symlinks.
The installable payload is `lazykimi-plugin/`. Optional local reference clones
under `sources/` are git-ignored and are not distributed with this repository.

LazyKimi follows the LazyCodex workflow design and its sibling implementations.
[NOTICE](NOTICE) records attribution; no sibling or upstream project is a runtime dependency.

## Learn more

- [Install and verify a host](docs/03-install-and-host-verification.md)
- [Remove receipt-owned assets safely](docs/08-safe-removal.md)
- [Workflow playbooks](docs/04-workflow-playbooks.md)
- [Evidence and completion](docs/05-evidence-and-completion.md)
- [Host routes and recovery](docs/reference/host-routes.md)
- [Kimi Work setup](docs/11-kimi-work-setup.md)
- [Release notes](RELEASE_NOTES.md)
- [Documentation index](docs/)

## License

[MIT](LICENSE). See [NOTICE](NOTICE) for attribution and provenance.

## Contributing

Issues and pull requests are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md)
for development checks and sanitized reproduction guidance. Report
vulnerabilities privately according to [SECURITY.md](SECURITY.md).
