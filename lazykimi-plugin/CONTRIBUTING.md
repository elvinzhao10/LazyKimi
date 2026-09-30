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

LazyKimi requires Node.js 18 or later and Python 3 for the MCP servers. The
package builds with the TypeScript compiler; no bundler is used.

```bash
git clone https://github.com/elvinzhao10/LazyKimi.git
cd LazyKimi/lazykimi-plugin
npm install
npm run build
```

The build emits `dist/index.js`, which is the `lazykimi` CLI entry point.
Run it directly with `node dist/index.js <command>` during development.

## Test commands

Run these checks from the `lazykimi-plugin/` directory before requesting
review:

```bash
# Build the TypeScript CLI.
npm run build

# Package readiness: inventories, declarations, executable scripts.
node dist/index.js load-check

# Package health diagnostics.
node dist/index.js doctor

# Aggregate verification gate (doctor + load-check + MCP + hooks).
bash scripts/lazykimi-verify.sh
```

The CI workflow at `.github/workflows/ci.yml` runs `npm run build` and
`bash scripts/lazykimi-verify.sh` on every pull request to `main` on
macOS-latest with Node 22.

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
