# LazyKimi v1.4.0 - local dashboard core and honest capability labels

A dashboard release across the six LazySeries siblings. Each package vendors
the family's portable dashboard core behind its own host adapter; LazyKimi
adds the Kimi-native adapter surface and keeps every host claim labeled,
bounded and pending.

## Project platform (2026-10-07)

- The persistent project record is vendored as the family's second pinned
  tree: `lazykimi-plugin/shared/project/` + `project.vendor.json` re-pin to
  family tree `1feb5646…` (source revision `537f393`). Kimi's adapter keeps
  its own authority — journal/CAS, the Kimi namespace, and per-surface
  boundaries — over the shared runtime's init/read/command/observe routes,
  registered original-source editing, reconciliation, and telemetry.
- The project context summary states the git-observation boundary explicitly:
  the vendored collectors are byte-pinned but wired to no Kimi-exposed route,
  and commit links stay run-side (`repo_head`/`content_revision`).
- The T24-R1 capability-honesty assertion (no capability key ever claims
  observed host adoption) stays in force unchanged; host embedding, chat
  handoff, and host wake remain unobserved, native host readiness stays
  pending, and each surface (Kimi Code CLI, VS Code/ACP, Code Desktop, Work)
  still requires its own current-client acceptance.

## Eval-driven fixes

- The status-dashboard MCP server grows from 4 to 6 tools:
  `dashboard_service` (start, inspect, stop, or return the local browser
  dashboard entry) and the read-only `copy_task_context` (copy a validated
  native Kimi producer context without executing or consuming it). The
  declared tool total moves from 32 to 34 across the six servers, extended
  to 35 by the typed `project` platform tool below.
- The portable dashboard core is vendored hash-pinned under
  `lazykimi-plugin/shared/dashboard/` with a tracked vendor manifest, and the
  Kimi-native adapter ships beside it (`shared/dashboard-host/`). The
  product-naming guard exempts vendored bytes only while they still match the
  pinned hashes, so any local edit resurfaces review instead of riding the
  exemption.
- Queue planning (create, amend, reorder queued plans) is available through
  the browser UI; queue edits never start work. Activation remains a
  separate explicit bridge action.
- Documentation mirrors now state the exact surface (6 servers / 35 tools)
  and correct the stale 4-tool and 32-tool strings, including the capability
  comparison row; a committed machine-local path in the history docs was
  replaced with a workspace placeholder.
- The extracted-package self-check boundary is documented: `doctor` is
  project-scoped and exits 1 in a bare extraction until `lazykimi init` has
  bound a project; use `load-check` for bare-extraction verification.
- The persistent project platform is vendored hash-pinned under
  `lazykimi-plugin/shared/project/` (with `project.vendor.json`, the same
  hash-pinned exemption as the dashboard core) and ported through the Kimi
  native adapter: a persistent project record under `.lazykimi/project/`,
  the neutral `.lazyseries/project.json` registry, registered original-source
  editing with crash-recovery journaling, honest native run observations from
  Kimi's own journal/CAS evidence, and a typed `project` tool on the
  status-dashboard server. Pre-init surfaces stay inert with typed hints, and
  every capability stays package-scoped per
  [the surface record](docs/reference/kimi-product-surfaces.md) — no host
  adoption is claimed for any Kimi surface.

## Measured efficiency

No latency, token, cost or native-host performance improvement is claimed.
The dashboard service binds locally (loopback-only access, port-0 default
binding, credential files at mode 0600, challenge-gated stop). Transactional
edits, queue planning and context copy are package behaviors verified by
local tests; they are not native host observations.

## Host capability matrix

Kimi Code CLI, Kimi Code for VS Code, CLI through ACP editors, Kimi Code
Desktop and Kimi Work remain distinct acceptance targets. The 1.4.0 package
capability labels are: browser, transactional edits, project queue, context
copy and observations `available`; embedding, chat handoff and wake
`unobserved`; native host readiness `pending`. Project-bound MCP binding
rules are unchanged: manifest MCP launchers still fail closed without
explicit project binding, and the project init route remains the route for
project-bound MCP.

See [the dated platform audit](docs/reference/platform-status-2026-10-02.md).
**HOST READINESS: PENDING** until the selected client demonstrates
discovery, skill/command execution, relevant hooks and MCP connections.
Official feature documentation and package tests are separate evidence.

## Dependencies and runtime requirements

Node.js 24 is recommended. Core lifecycle compatibility remains Node.js 20;
optional TypeScript language-server 6.x requires Node.js 22.22.2 or later.
Python 3.10+ is required for the MCP servers. LazyTrae's standalone CLI
retains its separate Node.js 18 compatibility tier, and LazyTrae carries the
fast-uri 4.2.1 dependency with the patched 3.1.8 Ajv edge; neither changes
this package's runtime floors.

## Migration and upgrade

Use the receipt-aware lifecycle update with an explicit project binding.
Preserve populated run state, modified assets, unknown files and host
settings. The previous v1.3.5 release archive remains valid; select the
newly versioned archive explicitly when upgrading. A bare extraction passes
`load-check` immediately; `doctor` reports project-scoped checks as failing
until `lazykimi init` has run for the selected project.

Read [AGENTS.md](AGENTS.md), [README.md](README.md) and the selected host guide.

## Known risks

Authenticated current-client acceptance remains pending. A copied
configuration, manifest validation, or isolated lifecycle fixture cannot
establish host loading. Dashboard embedding into a Kimi host surface, chat
handoff and wake remain unobserved; no host support is claimed for them.
Optional providers must satisfy their own runtime floor.

## Rollback

Retain the previous release and receipts. Follow the scoped lifecycle removal
or rollback plan, preserving user-modified and foreign assets. Stopping the
dashboard service is a local action (`dashboard_service` stop or the adapter
CLI stop entry) and never touches host-managed registrations; never remove
credentials, sessions or entire shared configuration directories.
