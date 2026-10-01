# Contributing to LazyKimi

Thank you for improving LazyKimi. Keep changes focused, preserve the package
boundary, and avoid adding host configuration, credentials, or generated local
state to commits.

## Before opening an issue

Search existing issues first. For a bug report, include the LazyKimi version,
Kimi Code CLI version, host (Kimi Code CLI or Kimi Work), operating system,
exact reproduction steps, and sanitized output from the verification command.
Do not paste tokens, credentials, API keys, or private workspace paths.

## Development setup

LazyKimi requires Node.js 20 or later and Python 3.10+ (resolved
automatically by `scripts/lazykimi-python-resolver.sh`) for the MCP servers
and pytest suite. The package builds with the TypeScript compiler; no
bundler is used.

```bash
git clone https://github.com/elvinzhao10/LazyKimi.git
cd LazyKimi/lazykimi-plugin
npm install
npm run build
```

The build emits `dist/index.js`, which is the `lazykimi` CLI entry point.
Run it directly with `node dist/index.js <command>` during development.

## Test commands

The family test stack lives under `lazykimi-plugin/`: `tests/*.test.js`
(node:test), `tests/test_lazykimi_*.py` + `tooling/test_lazykimi_*.py`
(pytest), and `tests/v*.sh` + `tests/publication-regression.sh` (bash
regressions). Run these checks from `lazykimi-plugin/` before requesting
review:

```bash
# Build the TypeScript CLI.
npm run build

# Package readiness: inventories, declarations, executable scripts.
node dist/index.js load-check

# Package health diagnostics.
node dist/index.js doctor

# Node test suite (32 files).
node --test tests/*.test.js

# Pytest suite (26 files; uses the resolved python3.10+ interpreter).
python3 -m pytest tests/ tooling/ -q

# Aggregate verification gate, suite selector core | lifecycle | all.
LAZYKIMI_VERIFY_SUITE=all bash scripts/lazykimi-verify.sh
```

The pytest interpreter is resolved from `LAZYKIMI_PYTHON` or the newest
available python3.10+ on PATH; the system `python3` may be older, in which
case the resolver falls back to an explicit `python3.13`/`3.12`/`3.11`/`3.10`.

The CI workflow at `.github/workflows/ci.yml` runs the supported-floor check
plus `npm run build` and `LAZYKIMI_VERIFY_SUITE=core bash
scripts/lazykimi-verify.sh` on every pull request to `main` on macOS with
Node 22 / Python 3.13.

## Contract parity rules

`lazykimi-plugin/contracts/` carries family-shared byte-identical contracts
copied verbatim from LazyZCode v1.3.4. They are untouchable except via a
family-wide decision:

- Copy with `cp`, never retype; verify with `cmp`
  (`tests/v103-automatic-tooling-contract-parity.sh` gates this).
- The only lazykimi-modified contracts are `model-routing-policy.v1.json`
  (the `kimi` host entry), `model-routing.js`, and the per-host set
  (`kimi-*` files, lifecycle schemas with kimi enums, per-host fixtures).
- If a family contract needs a change, record a deviation note in the
  CHANGELOG instead of editing the shared file.
- Regenerate the marketplace route contract after ANY edit under `skills/`,
  `commands/`, `agents/`, `hooks/`, `mcp/`, or `kimi.plugin.json`:
  `node scripts/lazykimi-regenerate-marketplace-contract.js`.

## Pull requests

Create one focused branch and describe the user-visible change, compatibility
impact, and verification in the pull request template. Keep pull requests
small and update documentation or `lazykimi-plugin/CHANGELOG.md` when public
behavior changes.

### Commit conventions

Use Conventional Commits format with atomic commits:

- `feat:` a new feature
- `fix:` a bug fix
- `docs:` documentation only
- `refactor:` code restructuring with no behavior change
- `test:` test additions or corrections
- `chore:` tooling, build, or dependency changes

Stage only the files you explicitly changed. Never use `git add -A` or
`git add .` — this prevents accidentally staging secrets (`.env`,
credentials) or large binaries. Each commit should reference the plan task
it implements when one exists.

## Releases

Use a version tag in the form `vX.Y.Z` only after the default-branch CI is
green and the changelog documents the user-facing change. Review the
generated notes before publishing a prerelease or major release. Stable
releases use `v1.x` and later tags; `v0.x` entries are the pre-stable
development record.

## Boundaries

- Root community files and `docs/` are regular publication copies of the
  payload documents. Update both copies together and rebase relative links
  for their location. Never replace them with symlinks: durable onboarding
  refuses unowned or linked publication content.

- `sources/` is an optional, git-ignored area of local read-only reference
  checkouts used during the v0.x port. It is never committed, never a build
  dependency, and may be deleted freely: a fresh checkout builds and tests
  without it.
- Do not edit files under `sources/` — they are immutable references.
- Do not present package readiness as Kimi host connection. Package checks
  prove copied assets and declarations; a live host session is a separate
  observation.
- Do not enable optional tooling (codegraph, lsp, context7) during init-deep
  or planning.
- Do not add hooks that block completion; use CLI/MCP gates instead.
- Do not collapse planner and implementer into one agent — the five evidence
  gates depend on the separation.

Report vulnerabilities privately according to [SECURITY.md](SECURITY.md).
