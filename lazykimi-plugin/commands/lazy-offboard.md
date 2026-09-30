---
description: "Guide receipt-safe LazyKimi removal through four independently approved scopes, preserving other plugins, host configuration, and credentials."
argument-hint: "[--project <absolute-project-root>] [--tooling-root <absolute-path>]"
---

Work through this guided removal in order. Each scope is an independent
removal decision: confirm every scope with the user before touching it, and
skip any scope the user does not approve. Never guess or scan for host-managed
installation paths.

$ARGUMENTS

# /lazy-offboard

## Usage

```
/lazy-offboard [--project <absolute-project-root>] [--tooling-root <absolute-path>]
```

Triggers: `offboard`, `uninstall LazyKimi`, `remove the plugin`, `clean up`.

## Guided procedure

1. **Inventory what exists (read-only).** Check which scopes apply: the Kimi
   Code CLI plugin install (inspect `/plugins` in a session) or the project
   route (the eight critical `[[hooks]]` entries in
   `~/.kimi-code/config.toml` whose `command` references
   `.kimi-code/hooks/`),
   a receipt-owned tooling root (only a user-supplied absolute path), the
   project-local `.lazykimi/` state directory, and a durable lifecycle
   install (`node "<install-root>/LazyKimi/launcher.js" status`). Report the
   list before removing anything.
2. **Scope 1 — Kimi host install (host UI, receipt-safe).** LazyKimi keeps
   no host-side state beyond its own registrations, so removal through the
   host is safe:
   - Manifest route: uninstall the `lazykimi` plugin through `/plugins`.
   - Project route: remove the eight critical `[[hooks]]` entries from
     `~/.kimi-code/config.toml` (those whose `command` references
     `.kimi-code/hooks/`) and remove each `lazykimi-*` MCP server via
     `/mcp-config`; `lazykimi uninstall --yes` removes the copied project
     assets receipt-safely first.
   - Kimi Work: delete `~/.kimi-work/skills/lazy-*/` and remove each
     `lazykimi-*` MCP server through the Kimi Work MCP configuration UI.
   Never edit the host's private configuration beyond the documented
   uninstall paths.
3. **Scope 2 — receipt-owned tooling root (optional, only with an explicit
   root).** If the user passes `--tooling-root <absolute-path>` (or names one),
   run:

   ```bash
   bash lazykimi-plugin/scripts/lazykimi-tooling.sh uninstall \
     --tooling-root <absolute-path>
   ```

   The command removes only an unmodified, receipt-owned installation and
   preserves modified, linked, foreign, caller-owned, project, global, and
   host-managed paths. If the tooling root owns a project index, the
   receipt-gated index uninstall must remove that index first; the root
   uninstall refuses until it is gone.
4. **Scope 3 — project-local `.lazykimi/` state (explicit user choice per
   project).** Run state, evidence, handoffs, and the decision ledger live in
   `<project>/.lazykimi/`. After the plugin is uninstalled, a user may delete
   `.lazykimi/` from individual projects to drop their run history. Ask per
   project; never delete it silently, and never delete it while a removal of
   another scope is still pending confirmation.
5. **Scope 4 — durable lifecycle install (only for the launcher route).** For
   a durable onboard, remove exact receipt-owned state with the plan-first
   offboard:

   ```bash
   node "<install-root>/LazyKimi/launcher.js" offboard
   ```

   The first run prints a confirmation plan; rerun with `--yes` after the user
   approves it. The bootstrap checkout may be deleted independently; it is not
   itself a host installer.
6. **Confirm the result.** After the host UI action, observe in a fresh session
   that the plugin's skills, commands, and MCP entries are gone (or disabled,
   for a pause). If that observation is unavailable, report host removal as
   pending. The copied repository may be deleted after the durable route is
   verified or removed independently; it is not the installed bundle.

## Do not touch

- Other plugins, their marketplaces, and their enable states.
- Host configuration beyond LazyKimi's own documented registrations
  (`~/.kimi-code/config.toml` entries the package did not install,
  `.kimi-code/local.toml`) and `AGENTS.md` content you did not generate.
- Another host's MCP configuration, credentials, OAuth values, private
  registry settings, or trust settings.
- Project files, global tools, and any path not proven by a receipt.

Removing a tooling root does not authorize removal of a plugin, marketplace
installation, MCP registration, or credential state.

## Success criteria

- Every applied scope was independently approved by the user, in the order
  above.
- The host removal (if requested) was performed through the documented
  route steps and confirmed in a fresh host session.
- Receipt-gated uninstalls either completed with their receipt check or
  refused and preserved the root.
- The final report separates package removal from the observed host result.

Do not claim completion without verification.

## Package entry points

- `lazykimi-plugin/scripts/lazykimi-tooling.sh` — receipt-gated tooling
  uninstall (`uninstall --tooling-root <absolute-path>`; see also the LSP and
  project-index uninstall subcommands).
- `lazykimi-plugin/scripts/lazykimi-lifecycle.js` — durable lifecycle CLI
  (`status` and plan-first `offboard`; `--yes` after user approval).
- `<install-root>/LazyKimi/launcher.js` — stable durable launcher for
  `update`, `status`, and plan-first `offboard`.
- `docs/08-safe-removal.md` — the receipt-scoped removal protocol this command
  follows.
