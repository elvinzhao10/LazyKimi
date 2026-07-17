# Test and release verification

LazyKimi uses layered evidence. A release check is useful only when its scope
is explicit: a syntax check does not prove a protocol, a protocol fixture
does not prove a host connection, and host observation does not rewrite
package ownership.

```mermaid
flowchart TB
    Build["npm run build (TypeScript)"] --> Package["copied package checks"]
    Package --> Aggregate["lazykimi verify"]
    Aggregate --> Release["release evidence"]
    Release -. separate observation .-> Host["live host session"]
```

## Build verification

The TypeScript CLI must build cleanly before any package check is meaningful:

```bash
cd lazykimi-plugin
npm install
npm run build
```

The build emits `dist/index.js`, which is the `lazykimi` CLI entry point. A
failed build invalidates all downstream checks — `load-check`, `doctor`, and
`verify` all depend on `dist/index.js` existing.

## Read the aggregate result

`lazykimi verify` calls doctor, load-check, MCP protocol, hook pipeline, and
classified regression checks. It uses bounded execution for package-owned
checks so the JSON result contains a status and reason instead of a bare exit
code. A timeout or failed check is a failure; an unavailable host-side
validator is reported as an unchecked condition rather than a fabricated host
success.

The verifier's timeout cleanup is **best-effort** process-group cleanup. It is
**not a security sandbox** and does not guarantee descendant cleanup. Tests
that need to execute untrusted input need a **VM or container-backed runner**.

## Verification commands

```bash
# From lazykimi-plugin/ after npm run build.
node dist/index.js load-check     # package readiness
node dist/index.js doctor         # package health
node dist/index.js verify --must-pass   # aggregate gate
```

The expected package evidence is respectively `PACKAGE_READINESS=full`,
`Doctor check: ALL PASS`, and aggregate JSON containing `"all_pass":true`.

## CI workflow

The CI workflow at `.github/workflows/ci.yml` runs on every push and pull
request to `main`:

```yaml
jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '22'
      - run: cd lazykimi-plugin && npm install
      - run: cd lazykimi-plugin && npm run build
      - run: cd lazykimi-plugin && bash scripts/lazykimi-verify.sh
```

CI runs on macOS-latest with Node 22, matching the package's verified scope.
A failed build or failed verify gate blocks merge.

## Release boundary

Normal CI is self-contained: it does not require a sibling repository.
Documentation and contract parity with LazyBuddy and LazyTrae are release-only
paired parity checks, run only when both absolute roots are explicitly
supplied. That keeps the shared safety contract auditable without creating a
runtime, installer, or CI dependency between packages.

The final host layer is intentionally manual. A Kimi Code CLI or Kimi Work
session must show the selected plugin surface, hook behavior where relevant,
and MCP connection before those facts are claimed. Current package evidence
is verified on macOS only.

## Verification matrix

| Check | Scope | What it proves | What it does not prove |
| --- | --- | --- | --- |
| `npm run build` | TypeScript compilation | The CLI compiles without type errors. | Runtime behavior or host loading. |
| `load-check` | Package inventory | Copied assets, declarations, and executable scripts are present. | Host discovery or MCP connection. |
| `doctor` | Package health | Manifests, JSON, and tooling contract are valid. | Live host session. |
| `verify --must-pass` | Aggregate gate | All package checks pass with bounded status. | Host integration or hook execution. |
| MCP protocol regression | JSON-RPC stream | Endpoints handle malformed input and recover. | Host process launched or connected. |
| Hook pipeline | Hook scripts | Scripts execute and apply policy on fixtures. | Host loaded `~/.kimi-code/config.toml`. |
| Manual host observation | Live session | Skill, hook, and MCP are loaded in the host. | Every package check passed. |

## How to read a regression by boundary

The shell regressions are intentionally named by the boundary they attack,
not by an implementation detail:

| Regression family | Fixture/action | Failure it prevents |
| --- | --- | --- |
| package/readiness | copied package root and manifest checks | Source checkout assumptions or missing shipped assets. |
| hook/security | structured tool payloads and secret-like paths | Treating arbitrary text as a write target or command authority. |
| MCP params/SSRF | malformed JSON-RPC and attacker-controlled metadata | Stream poisoning or registry metadata becoming a network target. |
| bounded verifier | timeout and process fixtures | Reporting timeout as success or claiming guaranteed cleanup. |

When a regression fails, start from its fixture and expected assertion, then
follow the smallest source function named in the failure. Do not "fix" a
release check by weakening its assertion: each assertion encodes a published
ownership or evidence contract.
