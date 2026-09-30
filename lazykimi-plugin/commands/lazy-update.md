---
description: "Guide a LazyKimi plugin update: compare installed and repo versions, walk the Kimi route update flow, and re-verify host readiness in a fresh session."
argument-hint: "[--project <absolute-project-root>]"
---

Work through this guided update in order. An agent with approved computer-use
access may perform the documented host UI steps and observe the result. Never
edit Kimi's private config, plugin cache, or hook entries through files.

$ARGUMENTS

# /lazy-update

## Usage

```
/lazy-update [--project <absolute-project-root>]
```

Triggers: `update LazyKimi`, `upgrade the plugin`, `refresh the install`.

## Guided procedure

1. **Read the installed version (best-effort).** If a Kimi plugin cache
   manifest for `lazykimi` is present and readable, read the installed
   `version` from it. On the project route, the copied
   `.kimi-code/`/`.lazykimi/` assets carry the installed version instead. A
   missing or unreadable source means "installed version not detectable" —
   say so honestly instead of guessing. Never write to the cache directory.
2. **Read the repo manifest version** from
   `lazykimi-plugin/kimi.plugin.json` and compare the two:
   - Installed < repo → an update is available; continue.
   - Equal → the install is current; still offer the re-verification checklist.
   - Installed > repo → the repo checkout is older than the install; say so
     before recommending anything.
3. **Show the changelog delta.** Point the user at `CHANGELOG.md` for what
   changes between versions, and at `RELEASE_NOTES.md`
   for the release's verification scope.
4. **Check prerequisites.** Node.js LTS 20+ (24 recommended, 22 supported) and
   Git on `PATH` for the local launchers.
5. **Walk the documented host update flow for the installed route** (the
   durable launcher route is separate):
   1. In the repository: bump the `version` in
      `lazykimi-plugin/kimi.plugin.json` and `lazykimi-plugin/package.json`
      (release builds do this; a plain source checkout update is just
      `git pull`).
   2. Manifest route: refresh the marketplace through `/plugins`, then
      update the `lazykimi` plugin when offered. If the version is
      unchanged, report that the host may not offer an update; uninstall and
      reinstall after the fixed revision lands, then verify in a fresh
      session.
   3. Project route: re-run `lazykimi init` in the project (idempotent
      re-rewrite of assets and the `__KIMI_PLUGIN_ROOT__` MCP paths) and
      re-run `scripts/install-hooks.sh` if hook entries changed. Source
      edits are not hot reload — a fresh session must load the new assets.
6. **Re-verify the package.** From the repository root run
   `bash lazykimi-plugin/scripts/lazykimi-load-check.sh` (expect
   `PACKAGE_READINESS=full`) and `bash lazykimi-plugin/scripts/lazykimi-plugin-doctor.sh`
   (host=package). With `--project <absolute-project-root>`, the durable
   launcher route updates separately:
   `node "<install-root>/LazyKimi/launcher.js" update` (a moved same-version
   ref requires `--confirm-revision <full-sha>`).
7. **Re-verify host readiness in a fresh session.** After the update, ask the
   user to start a NEW Kimi session and confirm the checklist:
   - One real skill loads (invoked as `/skill:<name>` or `/<name>`).
   - One command appears as a slash menu entry (for example `/lazy-status`).
   - All six MCP connections are visible: `run-ledger`, `verification`,
     `status-dashboard`, `context-graph`, `code-intel`, `docs`.
   - Hooks are active with the plugin enabled.
   - The `mcp_mode` plugin user setting is visible (empty defers the profile
     gate, which defaults to `orchestrated`).
8. **Report readiness honestly.** `PACKAGE READINESS: full` only from the
   checks in step 6; `HOST READINESS: PENDING` until the fresh-session
   observation in step 7 exists. Package checks never prove host activation.

## Success criteria

- Both versions were read and compared (or the missing one was named honestly).
- The user received the exact UI update flow and the changelog pointer.
- No host-owned path was edited by the agent.
- The final report ends with `HOST READINESS: PENDING` until the fresh-session
  re-verification is observed.

Do not claim completion without verification.

## Package entry points

- `lazykimi-plugin/scripts/lazykimi-load-check.sh` — package-readiness gate
  (`PACKAGE_READINESS=full`).
- `lazykimi-plugin/scripts/lazykimi-plugin-doctor.sh` — package doctor
  (host=package).
- `lazykimi-plugin/scripts/lazykimi-lifecycle.js` — durable lifecycle CLI
  (`update` requires an installed bundle; `--source` official origin only).
- `<install-root>/LazyKimi/launcher.js` — stable durable launcher for
  `update`, `status`, and plan-first `offboard`.
- `CHANGELOG.md` — version delta for the update being applied.
