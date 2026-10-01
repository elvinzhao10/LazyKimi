# LazyKimi v1.3.4 — safer runs, clearer host boundaries

A small maintenance release for the LazySeries family. It repairs runtime and
host-adapter boundaries while retaining the workflow foundation inherited from
family versions v1.3.0–v1.3.3. Those inherited features are not new in this patch
and do not imply prior public releases of the Kimi or DeepSeek ports.

## Eval-driven fixes

- Project-bound MCP adapters use explicit project paths; unbound global launches fail closed. Native agent headers replace invented settings.
- Receipt-aware setup merges owned MCP entries, respects KIMI_CODE_HOME, and preserves modified or unknown files.
- Public-source bootstrap stages regular publication files and validates the internal hook bridge. The archive includes the compiled CLI.
- Finalization requires all intended tasks done; persisted status is assessed
  separately from completion evidence.

## Cumulative workflow experience

Describe work in natural language or use explicit workflow entry points.
Keep editable Markdown plans, durable decisions, evidence-bound completion
and verification sized to the change. Planning-only requests remain separate
from execution authority. The README presents these inherited features together
with the 1.3.4 fixes; historical notes below retain the version-by-version record.

## Measured efficiency

No new latency, token-saving, cost or recall improvement is measured for this
patch. Ledger append/compaction, learned routing and shared-core migration are deferred.

## Host capability matrix

Kimi Code terminal package fixtures pass; fresh authenticated CLI/IDE acceptance remains pending. The unbound global manifest project-state MCP fails closed; use the documented explicitly bound project config. Kimi Work supports native plugins in the host, while this package route remains experimental.

Package and distribution checks do not prove a current native host session.
**HOST READINESS: PENDING** until loading, command/skill behavior and the expected
MCP connections are observed. The README links the selected host's setup guide.

## Migration and upgrade

Use the receipt-aware upgrade route with an explicit project binding. Preserve project evidence and unknown host configuration. No credentials or production host settings are changed by package verification.

Read [AGENTS.md](AGENTS.md) and [the install guide](docs/03-install-and-host-verification.md).
Until the repaired tag is approved, use the immutable repaired source linked in
the README rather than the original public v1.3.4 tag. Choose one route, check the installed package version, and restart the host.
Source checkouts and release archives have different build requirements; follow
the documented route. Do not reset populated runs merely to upgrade.

## Known risks

Native acceptance is separate from package readiness. Token/cost budgets are
metadata; pending approvals are persisted observations without a live approval
queue. Shell loop policy beyond the configured global cap needs orchestrator enforcement.

## Rollback

Keep the prior local 1.3.3 checkout and ownership receipts; a prior public release is not established. Remove only receipt-owned, unmodified assets and use a fresh host session to verify removal.

## Documentation and family presentation

Aligned sibling README structure, current setup navigation and a shared six-repo
family table. Personal environment files and caches are ignored while example
configuration and pinned fixture logs remain publishable. Earlier release notes
remain below as historical evidence.

## Prior release notes

# LazyKimi v1.3.3 — full family parity port

**Status:** v1.3.3 release. This release aligns LazyKimi with LazyZCode
v1.3.3 at family contract parity. Local package checks gate the release;
fresh Kimi host activation remains pending (see Host capability matrix).

## Eval-driven fixes

- Version drift repaired: the shipped manifests said 0.2.0 while git
  history contained a verified-but-unreleased 0.3.0 hardening round. The
  v0.3.0 work is now reconciled honestly in CHANGELOG (history preserved,
  never rewritten) instead of being silently folded into a new version.
- The 0.x planning leftovers (LazyTrae-managed blocks, untracked planning
  infra, stale runtime copies) are retired; the repository now contains
  only LazyKimi product plus an explicitly optional, git-ignored `sources/`
  reference area.

## Measured efficiency

No token, latency, or cost improvement has been measured for this release.
All claims in this release are package-level; no host-session measurements
exist yet.

## Host capability matrix

| Host | Package route | Current session |
| --- | --- | --- |
| Kimi Code CLI | Plugin manifest route (16 inline hooks, inline mcpServers) and project init route (`lazykimi init` + `install-hooks.sh`) | Pending live observation |
| Kimi Work | Skills import only (`install-kimi-work.sh`) | Pending live observation |

HOST READINESS: PENDING. Package checks prove files and declarations, not
plugin loading, hook firing, or MCP connections. A 2026-09-30 host
verification pass (T21) probed the real Kimi Code CLI v0.27.0 on the
development machine: the `[[hooks]]` TOML schema, the `Write`/`Edit`
PreToolUse tool names, and the `kimi-k3` effort scale (`low|high|max`) were
observed at the config/transcript layer and the agent effort values were
adapted to that scale; live-session activation remains pending (expired
OAuth credential; see `lazykimi-evaluation.md`, "T21 host verification
pass").

## Migration and upgrade

- **0.2.0 → 1.3.3:** this is a family-alignment jump, not twenty-one minor
  releases of local development. Review the CHANGELOG v1.3.3 entry for the
  component-by-component port summary. The 11 Greek-myth agents are gone;
  update any dispatch references to the 13 role agents. The
  `lazy-remove-ai-slops` slash command is retired (the skill remains). The
  run-ledger MCP surface changes to the family 9-tool set (see CHANGELOG
  for the dropped tools and their command equivalents).
- **0.3.0 drift:** an unreleased v0.3.0 hardening round existed only in git
  history (commits `64a0501`, `5ab1987`, `69450fd`); shipped manifests
  never left 0.2.0. If you ran that unrevised tree, treat its behavior as
  superseded by v1.3.3.
- Re-run `lazykimi init` after upgrading so project assets
  (`.kimi-code/`, `.lazykimi/`) and the rewritten `__KIMI_PLUGIN_ROOT__`
  MCP paths refresh from the new package.

## Known risks

- Kimi host behaviors the package relies on (env stanza in `mcp.json`,
  PreToolUse matcher tool names, plugin-manifest deny semantics, effort
  scale) are documented-untested until the host verification pass records
  observation receipts; every unobserved item stays HOST READINESS:
  PENDING.
- The project route's "critical 8" TOML hooks and the manifest route's 16
  inline hooks overlap; installing both routes simultaneously is not
  supported and may double-fire events.

## Rollback

Use the previous verified checkout (v0.2.0 tag state) and re-run
`lazykimi init` in each project that adopted v1.3.3 assets. Project-local
`.lazykimi/` run state is preserved by uninstall; remove the eight
`[[hooks]]` TOML entries referencing `.kimi-code/hooks/` from
`~/.kimi-code/config.toml` if the project route was installed.

## Prior release notes

See `lazykimi-plugin/CHANGELOG.md` for the full dated history, including
the reconciled v0.3.0 (unreleased) entry.
