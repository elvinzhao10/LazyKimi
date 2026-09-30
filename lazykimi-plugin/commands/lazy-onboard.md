---
description: "Guide LazyKimi onboarding: verify the package, install through one of the three Kimi routes (plugin manifest, project init, Kimi Work skills), and keep host readiness explicitly PENDING until a fresh session proves it."
argument-hint: "[--project <absolute-project-root>]"
---

Work through this guided onboarding in order. Stop at the first step that
cannot be completed and report honestly what is missing. Never simulate a host
result and never edit host-owned configuration.

$ARGUMENTS

# /lazy-onboard

## Usage

```
/lazy-onboard [--project <absolute-project-root>]
```

Triggers: `onboard`, `install LazyKimi`, `set up the plugin`, `verify the install`.

## Guided procedure

1. **Detect the current install state (read-only).** If
   `~/.kimi-code/config.toml` is readable, look read-only for the eight
   critical `[[hooks]]` entries whose `command` references
   `.kimi-code/hooks/` (the project route) and check `/plugins` output for a
   `lazykimi` plugin entry (the manifest route). Treat an unreadable or
   missing file as "not detectable" and say so. This is a look, never a
   write: NEVER create, edit, or repair host configuration — all install and
   update actions happen through the Kimi UI or the package's own installer
   scripts.
2. **Verify the package from the repo checkout.** Run, from the repository
   root:
   - `bash lazykimi-plugin/scripts/lazykimi-load-check.sh` — must end with
     `PACKAGE_READINESS=full` (package-level checks only).
   - `node lazykimi-plugin/dist/index.js doctor` — the package doctor must
     pass (run `npm install && npm run build` in `lazykimi-plugin/` first).
   If any check fails, fix the named package file first; do not continue.
3. **Pick exactly one Kimi Code CLI route** (never both — coexistence is
   unsupported and may double-fire hook events). Give only one host action at
   a time after the applicable approval:
   1. **Plugin manifest route (`kimi-plugin-manifest`, default full route):**
      in a Kimi Code CLI session, add the repository through
      `/plugins marketplace` using `lazykimi-plugin/marketplace.json` (v2),
      then install the `lazykimi` plugin as a separate approved action. This
      route delivers skills, commands, agents, the 16 inline hooks, and the
      6 inline `mcpServers`.
   2. **Project init route (`project-init-route`, manual project route):**
      from the target project, run `lazykimi init` (copies `.kimi-code/` and
      `.lazykimi/`, rewrites `__KIMI_PLUGIN_ROOT__` to absolute paths in
      `.kimi-code/mcp.json`), then run
      `bash lazykimi-plugin/scripts/install-hooks.sh` to append the eight
      critical `[[hooks]]` entries to `~/.kimi-code/config.toml`.
   3. **Kimi Work fallback (`kimi-work-skills-fallback`, skills only):** run
      `bash lazykimi-plugin/scripts/install-kimi-work.sh` to copy the
      `lazy-*` skills into `~/.kimi-work/skills/`, restart Kimi Work, and add
      each `lazykimi-*` MCP server manually through the Kimi Work MCP
      configuration UI. No commands, agents, or hooks on this route; see
      `docs/11-kimi-work-setup.md`.
4. **Optional durable route (only when the user passed
   `--project <absolute-project-root>`).** Run the durable lifecycle onboard:

   ```bash
   node lazykimi-plugin/dist/index.js lifecycle onboard \
     --source https://github.com/elvinzhao10/LazyKimi.git \
     --project <absolute-project-root> \
     [--install-root <absolute-path>]
   ```

   The default install root is the lifecycle's own resolution
   (`~/Library/Application Support/LazySeries/LazyKimi` on macOS). This step
   fetches from the official origin; until that origin exists it must fail
   honestly rather than fabricate a release. On failure, print the
   lifecycle's error verbatim, keep package readiness as the only readiness
   claim, and do not retry by editing receipts or state.
5. **Verify host readiness in a fresh session.** Host activation can only be
   observed in a NEW Kimi Code CLI (or Kimi Work) session. Ask the user to
   start one and confirm each item of the fresh-session checklist:
   - One real skill loads (invoked as `/skill:<name>` or `/<name>`, for
     example `lazy-ulw-plan`).
   - One command appears as a slash menu entry (for example `/lazy-status`).
   - All six MCP connections are visible via `/mcp`: `run-ledger`,
     `verification`, `status-dashboard`, `context-graph`, `code-intel`, and
     `docs`, each with the rewritten absolute server paths on the project
     route.
   - Hooks are active (SessionStart additionalContext appears; a destructive
     Bash command is denied by PreToolUse exit 2).
   - The MCP profile mode is recorded in `.lazykimi/config.json` (set via
     `lazykimi init --mcp-mode`; unset defaults to `orchestrated`).
6. **Report readiness honestly.** Print exactly:
   - `PACKAGE READINESS: full` — only if step 2 passed.
   - `HOST READINESS: PENDING` — until a fresh session has observed one real
     skill or command plus all six MCP connections. Package checks, doctor
     output, and install receipts never prove host activation.

## Success criteria

- Package checks ran and the load-check reported `PACKAGE_READINESS=full`.
- The user received the exact route steps (manifest marketplace add, project
  init + hook install, or Kimi Work skills import) for the one chosen route.
- The durable onboard (if requested) either completed with its receipt or its
  honest error was reported verbatim.
- The fresh-session checklist was handed to the user, and the final report
  ends with `HOST READINESS: PENDING` until that observation exists.

Do not claim completion without verification.

## Package entry points

- `lazykimi-plugin/scripts/lazykimi-load-check.sh` — package-readiness gate
  (`PACKAGE_READINESS=full`).
- `node lazykimi-plugin/dist/index.js doctor` — package doctor
  (host=package).
- `node lazykimi-plugin/dist/index.js lifecycle <onboard|update|status|offboard|recover-bootstrap-lock>` —
  durable lifecycle CLI (targets the v1.3.3 lifecycle wave).
- `lazykimi-plugin/scripts/install-hooks.sh` — project-route hook installer
  (eight critical `[[hooks]]` TOML entries).
- `lazykimi-plugin/scripts/install-kimi-work.sh` — Kimi Work skills fallback
  installer.
- `contracts/marketplace-route-contract.v1.json` — the authoritative route
  inventory this command follows.
