# LazyKimi Spec Compliance & Kimi Work Support — v2

## TL;DR
> Summary: Fix all CRITICAL/MAJOR audit findings from the official Kimi Code CLI docs (manifest location, mcp.json paths, plugin hooks inlining, marketplace schema, missing schemas, README accuracy) and add Kimi Work as a documented, scriptable secondary host.
> Deliverables: corrected `kimi.plugin.json` manifest, fixed `.kimi-code/mcp.json` with `./`-relative paths, inlined plugin hooks, v2 marketplace.json, 4 JSON schema files, corrected README/docs, Kimi Work setup script + docs, refreshed regression tests, updated root AGENTS.md.
> Effort: Medium
> Risk: Low — all changes are local to lazykimi-plugin/ and root docs; no source/ edits, no managed-block edits.

## Scope

### Must have
- Move plugin manifest from `.kimi-code/plugin.json` to `lazykimi-plugin/kimi.plugin.json` (plugin root) per Kimi spec.
- Rewrite manifest with correct schema: `name`, `version`, `description`, `author`, `homepage`, `license`, `interface` (displayName, shortDescription, longDescription, developerName, websiteURL), `skills` (`./skills/`), `sessionStart.skill`, `skillInstructions`, `mcpServers` (inline object map), `hooks` (inline array), `commands` (`./commands/`).
- Fix `.kimi-code/mcp.json` to remove `${KIMI_PLUGIN_ROOT}` interpolation (not supported in mcp.json). Use absolute paths resolved at install time OR `./`-relative paths if the file lives inside the plugin root. Since `.kimi-code/mcp.json` is project-level (not plugin-level), use absolute paths baked by `lazykimi init`.
- Inline plugin hooks in `kimi.plugin.json` `hooks` array (event/matcher/command/timeout). Hook commands use `./hooks/<script>.sh` (relative to plugin root, per spec). Delete `hooks-config.toml` (superseded).
- Fix `scripts/install-hooks.sh` to write `[[hooks]]` entries to `~/.kimi-code/config.toml` for project-level hook installation (the plugin manifest path is for plugin-installed hooks; users who clone the repo also need a config.toml route).
- Rewrite `lazykimi-plugin/.kimi-code/marketplace.json` (currently missing) with v2 schema: `{"version": "2", "plugins": [{"id", "displayName", "source"}]}`.
- Create 4 missing JSON Schema files at `lazykimi-plugin/.lazykimi/schemas/`: `boulder.schema.json`, `evidence.schema.json`, `sessions.schema.json`, `active-loop.schema.json`. Copy patterns from `.lazykimi/schemas/` if present, else from LazyBuddy `contracts/`.
- Update `lazykimi-plugin/src/commands/init.ts` to copy the 4 schema files into target `.lazykimi/schemas/`.
- Add 8 more hook scripts for full Kimi event coverage where useful: `post-tool-use-failure.sh`, `session-end.sh`, `subagent-start.sh`, `stop-failure.sh`, `interrupt.sh`, `permission-request.sh`, `permission-result.sh`, `notification.sh`. Update manifest `hooks` array to 16 entries.
- Fix README MCP per-server tool counts: run-ledger=8, verification=4, status-dashboard=1, context-graph=2, code-intel=3, docs=1 (total 19).
- Fix README hook behavior descriptions: `post-tool-use.sh` is advisory only (no run-ledger writes); `subagent-stop.sh` warns once (no retry logic).
- Add "honest-claims discipline" sentences to README, AGENTS.md, evaluation: "Package evidence proves copied files and declarations, not plugin loading, SessionStart, hooks, or an MCP connection."
- Add Kimi Work support: `lazykimi-plugin/scripts/install-kimi-work.sh` that copies skills to `~/.kimi-work/skills/` (best-effort path, documented as unverified), prints manual MCP setup instructions.
- Add `lazykimi-plugin/docs/11-kimi-work-setup.md` documenting Kimi Work as secondary host: install path, skills import, MCP manual config, limitations (no plugin manifest support, no hooks).
- Update root `AGENTS.md` (non-managed block) to add Kimi Work onboard/offboard route alongside Kimi Code CLI.
- Update `lazykimi-plugin/.kimi-code/AGENTS.md` to document Kimi Work limitations.
- Fix `code-intel/server.py` file handle leak (use `with open(...)`).
- Fix `package.json` `files` array (remove `schemas` and `templates` if absent, OR create the dirs).
- Fix `verify.ts` evidence gate mapping (plan-reread → `plan-reread.md`, manual-qa → `manual-qa.md`, distinct files).
- Update regression tests: add `v002-plugin-manifest-regression.sh` (verify `kimi.plugin.json` at plugin root, correct fields), `v002-mcp-paths-regression.sh` (verify no `${KIMI_PLUGIN_ROOT}` in mcp.json), `v002-hooks-inline-regression.sh` (verify hooks inlined in manifest).
- Update existing `v001-plugin-boundary-regression.sh` if it referenced old manifest path.
- Final integration test: `lazykimi-integration-test.sh` must still PASS with kimi steps SKIP.

### Must NOT have (guardrails, anti-slop, scope boundaries)
- No edits to `sources/` (read-only references).
- No edits to `.trae/` or `.lazytrae/` managed blocks.
- No Kimi Work binary downloads or local inference.
- No `${KIMI_PLUGIN_ROOT}` in `.kimi-code/mcp.json` (it is an env var, not a mcp.json interpolation token).
- No `publisher` field in manifest (use `author`).
- No arrays of paths for `skills`/`commands` in manifest (use `./` path strings or arrays of `./` strings per spec).
- No `hooks-config.toml` (delete it — plugin hooks are inlined in manifest).
- No `git add -A` / `git add .` — stage only changed files.
- No emojis in code/commits.
- No claim of Kimi Work plugin support (Kimi Work has no public plugin spec; we only support skill import + manual MCP).
- No backwards-compat shims for the old manifest location.

## Verification strategy
- Test decision: tests-after + framework = bash regression scripts (existing pattern).
- QA policy: every task has agent-executed bash scenarios.
- Evidence: `.lazytrae/evidence/task-<N>-<slug>.md`

## Execution strategy

### Parallel execution waves

**Wave 1 (critical spec fixes, no dependencies):**
- Task 1: Move + rewrite plugin manifest at `lazykimi-plugin/kimi.plugin.json`
- Task 2: Fix `.kimi-code/mcp.json` — remove `${KIMI_PLUGIN_ROOT}`, use `./`-relative paths (move file into plugin root if needed)
- Task 3: Inline plugin hooks in manifest, delete `hooks-config.toml`, fix `install-hooks.sh`

**Wave 2 (spec compliance, depends on Wave 1):**
- Task 4: Create v2 `marketplace.json` at plugin root
- Task 5: Create 4 missing JSON Schema files at `lazykimi-plugin/.lazykimi/schemas/` + update `init.ts`
- Task 6: Add 8 more hook scripts for full 16-event coverage + update manifest
- Task 7: Fix README (MCP counts, hook behavior, honest-claims sentences)

**Wave 3 (Kimi Work + polish, depends on Wave 2):**
- Task 8: Add Kimi Work setup script + docs page
- Task 9: Fix code-intel leak, package.json files array, verify.ts evidence mapping
- Task 10: Update root AGENTS.md + `.kimi-code/AGENTS.md` with Kimi Work routes

**Wave 4 (verification, depends on Wave 3):**
- Task 11: Add 3 new v002 regression tests, update v001 if needed
- Task 12: Final integration test refresh + verify runner

### Dependency matrix

| Task | Depends on | Blocks | Can parallelize with |
|------|------------|--------|----------------------|
| 1    | none       | 3,4,6  | 2                    |
| 2    | none       | 11     | 1,3                  |
| 3    | 1          | 11     | 2                    |
| 4    | 1          | 11     | 5,6,7                |
| 5    | none       | 11     | 4,6,7                |
| 6    | 1          | 11     | 4,5,7                |
| 7    | none       | 12     | 4,5,6                |
| 8    | none       | 10,12  | 9                    |
| 9    | none       | 11     | 8,10                 |
| 10   | 8          | 12     | 9                    |
| 11   | 1,2,3,4,5,6,9 | 12  | 10                   |
| 12   | 7,10,11    | F1-F4  | none                 |

## Todos

- [x] 1. Move + rewrite plugin manifest at lazykimi-plugin/kimi.plugin.json
  What to do:
  - Read current `lazykimi-plugin/.kimi-code/plugin.json` to extract existing metadata.
  - Read `lazykimi-plugin/.kimi-code/mcp.json` to extract MCP server definitions (will be inlined into manifest).
  - Create `lazykimi-plugin/kimi.plugin.json` at plugin root with corrected schema:
    ```json
    {
      "name": "lazykimi",
      "version": "0.2.0",
      "description": "Kimi-native evidence-led agent workflow harness for Kimi Code CLI and Kimi Work.",
      "author": "LazyKimi contributors",
      "homepage": "https://github.com/elvinzhao10/LazyKimi",
      "license": "MIT",
      "keywords": ["kimi", "kimi-code", "kimi-work", "agent-workflow", "evidence-led"],
      "interface": {
        "displayName": "LazyKimi",
        "shortDescription": "Evidence-led agent workflow harness for Kimi hosts",
        "longDescription": "LazyKimi recreates the LazyBuddy/LazyTrae evidence-led agent workflow harness design as a Kimi-native package. Primary host: Kimi Code CLI. Secondary host: Kimi Work (skills import only).",
        "developerName": "LazyKimi contributors",
        "websiteURL": "https://github.com/elvinzhao10/LazyKimi"
      },
      "skills": "./.kimi-code/skills/",
      "sessionStart": { "skill": "lazy-init-deep" },
      "skillInstructions": "LazyKimi skills use the lazy-* namespace and the .lazykimi/ state directory. Run /lazy-init-deep on first use.",
      "mcpServers": { ... inline from current mcp.json, paths converted to ./ ... },
      "hooks": [ ... inline from current hooks-config.toml, commands as ./hooks/<name>.sh ... ],
      "commands": "./.kimi-code/commands/"
    }
    ```
  - Convert MCP server paths from `${KIMI_PLUGIN_ROOT}/mcp/<name>/server.sh` to `./mcp/<name>/server.sh`.
  - Convert hook commands from `bash .kimi-code/hooks/<name>.sh` to `bash ./hooks/<name>.sh`.
  - Delete `lazykimi-plugin/.kimi-code/plugin.json` (old location).
  - Keep `lazykimi-plugin/.kimi-code/mcp.json` as a project-level manifest (NOT plugin manifest) — see Task 2.
  Must NOT do: Do not use `publisher` field. Do not use `${KIMI_PLUGIN_ROOT}` in manifest. Do not use arrays of path strings for `skills` (use single `./` path). Do not edit sources/ or managed blocks.
  References:
  - https://www.kimi.com/code/docs/kimi-code-cli/customization/plugins.html#plugin-manifest (manifest schema)
  - sources/LazyBuddy/lazybuddy-plugin/.codebuddy-plugin/plugin.json (pattern)
  Acceptance criteria:
  - [ ] `lazykimi-plugin/kimi.plugin.json` exists at plugin root
  - [ ] `node -e "const m=require('./lazykimi-plugin/kimi.plugin.json'); console.log(m.name, m.version, m.author, m.interface.displayName)"` prints `lazykimi 0.2.0 LazyKimi contributors LazyKimi`
  - [ ] `node -e "const m=require('./lazykimi-plugin/kimi.plugin.json'); console.log(typeof m.mcpServers, Array.isArray(m.hooks), m.skills, m.commands)"` prints `object true ./.kimi-code/skills/ ./.kimi-code/commands/`
  - [ ] `grep -c '\${KIMI_PLUGIN_ROOT}' lazykimi-plugin/kimi.plugin.json` returns 0
  - [ ] `grep -c 'publisher' lazykimi-plugin/kimi.plugin.json` returns 0
  - [ ] `lazykimi-plugin/.kimi-code/plugin.json` no longer exists
  QA scenarios:
  - Scenario: manifest valid JSON | Tool: bash | Steps: `node -e "JSON.parse(require('fs').readFileSync('lazykimi-plugin/kimi.plugin.json','utf8'))"` | Expected: exit 0
  - Scenario: name matches regex | Tool: bash | Steps: `node -e "const m=require('./lazykimi-plugin/kimi.plugin.json'); /^[a-z0-9][a-z0-9_-]{0,63}$/.test(m.name) || process.exit(1)"` | Expected: exit 0
  Commit: YES | Message: `fix(manifest): move plugin manifest to kimi.plugin.json at plugin root with correct Kimi spec schema` | Files: [lazykimi-plugin/kimi.plugin.json, lazykimi-plugin/.kimi-code/plugin.json (deleted)]

- [x] 2. Fix .kimi-code/mcp.json to remove ${KIMI_PLUGIN_ROOT} interpolation
  What to do:
  - Read current `lazykimi-plugin/.kimi-code/mcp.json`.
  - Replace all `${KIMI_PLUGIN_ROOT}/mcp/<name>/server.sh` paths. Since `.kimi-code/mcp.json` is the project-level MCP config (loaded when a user opens the project in Kimi Code CLI), paths must be absolute (resolved at install time) OR use a `command` that's on PATH.
  - Strategy: change `command` to `bash` and `args` to `[<absolute-path-to-mcp-server.sh>]` where the absolute path is resolved by `lazykimi init` at install time. The plugin source ships with a template using `__KIMI_PLUGIN_ROOT__/mcp/<name>/server.sh` placeholder; `init.ts` replaces `__KIMI_PLUGIN_ROOT__` with the actual plugin root path.
  - Alternative simpler strategy: ship `.kimi-code/mcp.json` with `./`-relative paths assuming Kimi resolves them from project root. Test which works.
  - Update `lazykimi-plugin/src/commands/init.ts` to rewrite `.kimi-code/mcp.json` paths to absolute on install.
  - Update `lazykimi-plugin/src/commands/mcp.ts` output to document the path resolution strategy.
  Must NOT do: Do not use `${KIMI_PLUGIN_ROOT}` in `.kimi-code/mcp.json`. Do not assume Kimi interpolates env vars in mcp.json (it does not, per docs).
  References:
  - https://www.kimi.com/code/docs/kimi-code-cli/customization/mcp.html (mcp.json schema)
  - sources/LazyBuddy/lazybuddy-plugin/.mcp.json (uses `${CODEBUDDY_PLUGIN_ROOT}` — but CodeBuddy may interpolate; Kimi does not for mcp.json)
  Acceptance criteria:
  - [ ] `grep -c '\${KIMI_PLUGIN_ROOT}' lazykimi-plugin/.kimi-code/mcp.json` returns 0
  - [ ] `node -e "const m=require('./lazykimi-plugin/.kimi-code/mcp.json'); Object.values(m.mcpServers).forEach(s => { if (s.command !== 'bash' && !s.command.startsWith('/')) throw new Error('non-absolute command: '+s.command) })"` exits 0 OR uses `./` paths
  - [ ] After `lazykimi init` in a temp project, the generated `.kimi-code/mcp.json` has absolute paths to the actual server.sh files
  QA scenarios:
  - Scenario: no interpolation tokens | Tool: bash | Steps: `grep -c '\${' lazykimi-plugin/.kimi-code/mcp.json` | Expected: 0
  - Scenario: init rewrites paths | Tool: bash | Steps: run `lazykimi init` in temp dir, grep mcp.json for the temp plugin root path | Expected: matches
  Commit: YES | Message: `fix(mcp): remove ${KIMI_PLUGIN_ROOT} interpolation from mcp.json; init.ts now bakes absolute paths` | Files: [lazykimi-plugin/.kimi-code/mcp.json, lazykimi-plugin/src/commands/init.ts, lazykimi-plugin/src/commands/mcp.ts]

- [x] 3. Inline plugin hooks in manifest, delete hooks-config.toml, fix install-hooks.sh
  What to do:
  - Read current `lazykimi-plugin/hooks/hooks-config.toml`.
  - Convert each `[[hooks]]` TOML block to a JSON object in `kimi.plugin.json` `hooks` array: `{"event": "...", "matcher": "..." (if present), "command": "bash ./hooks/<name>.sh", "timeout": <int>}`.
  - Per Kimi spec, plugin hook commands run with CWD = plugin root, so `./hooks/<name>.sh` resolves correctly. `KIMI_PLUGIN_ROOT` env var is also set on hook processes.
  - Delete `lazykimi-plugin/hooks/hooks-config.toml` (superseded by manifest).
  - Fix `lazykimi-plugin/scripts/install-hooks.sh`:
    - For users who clone the repo WITHOUT using the plugin manifest (e.g. `lazykimi init` then manual config), the script should append `[[hooks]]` entries to `~/.kimi-code/config.toml` with ABSOLUTE paths to `<project>/.kimi-code/hooks/<name>.sh`.
    - Add `--project-root` flag (default: CWD) so users can specify the project.
    - Idempotent: skip entries that already exist (grep for the command string).
  - Update `lazykimi-plugin/src/commands/init.ts` to NOT auto-append hooks to config.toml (the plugin manifest handles that when installed as a plugin); instead, print a message telling users to either `/plugins install` (manifest route) OR run `install-hooks.sh` (config.toml route).
  Must NOT do: Do not keep `hooks-config.toml` as a separate file. Do not use project-relative paths in `~/.kimi-code/config.toml` entries (CWD may differ).
  References:
  - https://www.kimi.com/code/docs/kimi-code-cli/customization/plugins.html#插件中的-hooks (plugin hooks spec)
  - https://www.kimi.com/code/docs/kimi-code-cli/customization/hooks.html (config.toml [[hooks]] spec)
  Acceptance criteria:
  - [ ] `lazykimi-plugin/hooks/hooks-config.toml` no longer exists
  - [ ] `node -e "const m=require('./lazykimi-plugin/kimi.plugin.json'); console.log(m.hooks.length, m.hooks[0].event, m.hooks[0].command)"` prints `8 SessionStart bash ./hooks/session-start.sh` (or similar)
  - [ ] `grep -c 'hooks-config.toml' lazykimi-plugin/ -r` returns 0 (no references to deleted file)
  - [ ] `bash lazykimi-plugin/scripts/install-hooks.sh --help` exits 0 and documents `--project-root` flag
  QA scenarios:
  - Scenario: manifest has inline hooks | Tool: bash | Steps: `node -e "const m=require('./lazykimi-plugin/kimi.plugin.json'); if(!Array.isArray(m.hooks)||m.hooks.length<8) process.exit(1)"` | Expected: exit 0
  - Scenario: install-hooks.sh idempotent | Tool: bash | Steps: run twice in temp HOME, count [[hooks]] entries | Expected: same count both times
  Commit: YES | Message: `fix(hooks): inline plugin hooks in kimi.plugin.json manifest; delete hooks-config.toml; fix install-hooks.sh paths` | Files: [lazykimi-plugin/kimi.plugin.json, lazykimi-plugin/hooks/hooks-config.toml (deleted), lazykimi-plugin/scripts/install-hooks.sh, lazykimi-plugin/src/commands/init.ts]

- [x] 4. Create v2 marketplace.json at plugin root
  What to do:
  - Read current `lazykimi-plugin/.kimi-code/marketplace.json` (if present — audit said missing).
  - Create `lazykimi-plugin/marketplace.json` at plugin root with v2 schema:
    ```json
    {
      "version": "2",
      "plugins": [
        {
          "id": "lazykimi",
          "displayName": "LazyKimi",
          "source": "./lazykimi-plugin"
        }
      ]
    }
    ```
  - This file is for users who want to add LazyKimi as a marketplace entry via `/plugins marketplace <path-to-marketplace.json>`.
  - Remove any old `.kimi-code/marketplace.json` if it exists.
  - Document marketplace installation in README.
  Must NOT do: Do not use v1 schema. Do not put marketplace.json inside `.kimi-code/` (it should be at repo root or plugin root for marketplace discovery).
  References:
  - https://www.kimi.com/code/docs/kimi-code-cli/customization/plugins.html#自定义-marketplace-json (v2 schema)
  - sources/LazyBuddy/.codebuddy-plugin/marketplace.json (pattern)
  Acceptance criteria:
  - [ ] `lazykimi-plugin/marketplace.json` exists
  - [ ] `node -e "const m=require('./lazykimi-plugin/marketplace.json'); console.log(m.version, m.plugins[0].id, m.plugins[0].source)"` prints `2 lazykimi ./lazykimi-plugin`
  - [ ] `lazykimi-plugin/.kimi-code/marketplace.json` does not exist
  QA scenarios:
  - Scenario: v2 schema | Tool: bash | Steps: `node -e "const m=require('./lazykimi-plugin/marketplace.json'); if(m.version !== '2' || !Array.isArray(m.plugins)) process.exit(1)"` | Expected: exit 0
  Commit: YES | Message: `feat(marketplace): add v2 marketplace.json at plugin root for /plugins marketplace discovery` | Files: [lazykimi-plugin/marketplace.json]

- [x] 5. Create 4 missing JSON Schema files at lazykimi-plugin/.lazykimi/schemas/
  What to do:
  - Create `lazykimi-plugin/.lazykimi/schemas/boulder.schema.json` — JSON Schema Draft 2020-12 for boulder state. Required fields: `schema_version` (integer), `active_work_id` (string|null), `works` (object). Works entries have: `work_id`, `active_plan`, `plan_name`, `session_ids` (array), `status` (enum: active|completed|paused|blocked), `tasks_completed` (array of integers), `tasks_remaining` (array of integers), `started_at`, `completed_at`.
  - Create `lazykimi-plugin/.lazykimi/schemas/evidence.schema.json` — for evidence files. Fields: `gate` (enum: plan-reread|automated-verification|manual-qa|adversarial-qa|cleanup), `status` (enum: pass|fail|skipped), `reason`, `timestamp`, `task_id`.
  - Create `lazykimi-plugin/.lazykimi/schemas/sessions.schema.json` — for session state. Fields: `session_id`, `started_at`, `host` (enum: kimi-code-cli|kimi-work), `model`, `work_ids` (array).
  - Create `lazykimi-plugin/.lazykimi/schemas/active-loop.schema.json` — for /goal + /swarm loop state. Fields: `loop_id`, `objective`, `mode` (enum: goal|swarm|ulw-loop), `started_at`, `turn_count`, `status` (enum: active|paused|completed|blocked).
  - Update `lazykimi-plugin/src/commands/init.ts` to copy the 4 schema files from `lazykimi-plugin/.lazykimi/schemas/` into target `<project>/.lazykimi/schemas/` during `lazykimi init`.
  - Update `lazykimi-plugin/.kimi-code/AGENTS.md` to reference the schema files with correct relative paths.
  Must NOT do: Do not edit sources/. Do not create schemas elsewhere (must be in `.lazykimi/schemas/`).
  References:
  - sources/LazyBuddy/lazybuddy-plugin/contracts/lazyseries-capability-readiness.v1.json (Draft 2020-12 pattern)
  - https://json-schema.org/draft/2020-12/schema (meta-schema)
  Acceptance criteria:
  - [ ] `ls lazykimi-plugin/.lazykimi/schemas/*.schema.json | wc -l` returns 4
  - [ ] `for f in lazykimi-plugin/.lazykimi/schemas/*.schema.json; do node -e "JSON.parse(require('fs').readFileSync('$f','utf8'))" || echo "FAIL: $f"; done` produces no FAIL
  - [ ] Each schema has `$schema`, `$id`, `title`, `type`, `properties`, `required` fields
  - [ ] After `lazykimi init` in temp project, `<temp>/.lazykimi/schemas/` has 4 files
  QA scenarios:
  - Scenario: all schemas valid | Tool: bash | Steps: `for f in lazykimi-plugin/.lazykimi/schemas/*.schema.json; do node -e "const s=JSON.parse(require('fs').readFileSync('$f','utf8')); if(!s.\$schema||!s.properties||!s.required) process.exit(1)"; done` | Expected: exit 0
  Commit: YES | Message: `feat(schemas): add 4 JSON Schema files for boulder, evidence, sessions, active-loop state` | Files: [lazykimi-plugin/.lazykimi/schemas/*.schema.json, lazykimi-plugin/src/commands/init.ts, lazykimi-plugin/.kimi-code/AGENTS.md]

- [x] 6. Add 8 more hook scripts for full 16-event coverage
  What to do:
  - Create 8 new hook scripts at `lazykimi-plugin/hooks/`:
    - `post-tool-use-failure.sh` — log tool failures to `.lazykimi/evidence/test-runs.md` (advisory).
    - `session-end.sh` — append session-end timestamp to `.lazykimi/state/sessions.json` (advisory).
    - `subagent-start.sh` — log subagent dispatch (advisory).
    - `stop-failure.sh` — log stop failures (advisory).
    - `interrupt.sh` — log user interrupts (advisory).
    - `permission-request.sh` — log permission requests (advisory).
    - `permission-result.sh` — log permission decisions (advisory).
    - `notification.sh` — log notifications (advisory).
  - Each script: shebang `#!/usr/bin/env bash`, `set -euo pipefail`, read JSON from stdin (guard with `[ -t 0 ] && exit 0`), exit 0 (advisory only), under 50 lines.
  - Add 8 new entries to `kimi.plugin.json` `hooks` array (total 16).
  - Update `lazykimi-plugin/.kimi-code/AGENTS.md` hook table to list all 16 events.
  - Update `lazykimi-plugin/src/commands/init.ts` to copy all 16 hook scripts.
  Must NOT do: Do not block in advisory hooks (only `pre-tool-use.sh`, `stop-gate.sh`, `user-prompt-submit.sh` may exit 2). Do not exceed 50 lines per new hook.
  References:
  - https://www.kimi.com/code/docs/kimi-code-cli/customization/hooks.html#事件一览 (16 events)
  - lazykimi-plugin/hooks/pre-tool-use.sh (pattern)
  Acceptance criteria:
  - [ ] `ls lazykimi-plugin/hooks/*.sh | wc -l` returns 16
  - [ ] `for f in lazykimi-plugin/hooks/*.sh; do bash -n "$f" || echo "FAIL: $f"; done` produces no FAIL
  - [ ] `node -e "const m=require('./lazykimi-plugin/kimi.plugin.json'); console.log(m.hooks.length)"` prints `16`
  - [ ] Each new hook exits 0 on empty stdin: `for f in lazykimi-plugin/hooks/{post-tool-use-failure,session-end,subagent-start,stop-failure,interrupt,permission-request,permission-result,notification}.sh; do echo '{}' | bash "$f" || echo "FAIL: $f"; done`
  QA scenarios:
  - Scenario: all 16 hooks syntax-valid | Tool: bash | Steps: `for f in lazykimi-plugin/hooks/*.sh; do bash -n "$f"; done` | Expected: exit 0
  Commit: YES | Message: `feat(hooks): add 8 advisory hook scripts for full 16-event Kimi coverage (PostToolUseFailure, SessionEnd, SubagentStart, StopFailure, Interrupt, PermissionRequest, PermissionResult, Notification)` | Files: [lazykimi-plugin/hooks/*.sh (8 new), lazykimi-plugin/kimi.plugin.json, lazykimi-plugin/.kimi-code/AGENTS.md, lazykimi-plugin/src/commands/init.ts]

- [x] 7. Fix README MCP counts, hook behavior, honest-claims discipline
  What to do:
  - Read `lazykimi-plugin/README.md`.
  - Fix MCP per-server tool counts table: run-ledger=8, verification=4, status-dashboard=1, context-graph=2, code-intel=3, docs=1 (total 19).
  - Fix hook behavior descriptions: `post-tool-use.sh` is advisory only (echoes to stderr, no run-ledger writes); `subagent-stop.sh` warns once on failure (no retry logic).
  - Add "Honest-claims discipline" section near top: "Package evidence proves copied files and declarations, not plugin loading, SessionStart, hooks, or an MCP connection. A Kimi Code CLI or Kimi Work session must confirm connection."
  - Add "Verified on macOS only" sentence to README header (matches LazyBuddy convention).
  - Update install section to reference both `/plugins install` (manifest route) and `lazykimi init` + `install-hooks.sh` (config.toml route).
  - Update verify section to clarify `lazykimi verify --must-pass` checks package readiness, not host readiness.
  Must NOT do: Do not claim Kimi Work plugin support (only skill import). Do not remove existing content unless inaccurate.
  References:
  - sources/LazyBuddy/README.md (honest-claims pattern, section ordering)
  - lazykimi-plugin/mcp/*/server.py (actual tool counts)
  Acceptance criteria:
  - [ ] `grep -c 'run-ledger.*8\|run-ledger.*4' lazykimi-plugin/README.md` returns matches for 8 only
  - [ ] `grep -c 'Honest-claims' lazykimi-plugin/README.md` returns at least 1
  - [ ] `grep -c 'Verified on macOS only' lazykimi-plugin/README.md` returns at least 1
  QA scenarios:
  - Scenario: MCP counts correct | Tool: bash | Steps: `grep -A1 'run-ledger' lazykimi-plugin/README.md | grep -c '8'` | Expected: 1
  Commit: YES | Message: `docs(readme): fix MCP per-server tool counts, hook behavior descriptions, add honest-claims discipline section` | Files: [lazykimi-plugin/README.md]

- [x] 8. Add Kimi Work setup script + docs page
  What to do:
  - Create `lazykimi-plugin/scripts/install-kimi-work.sh`:
    - Shebang, `set -euo pipefail`.
    - Detect Kimi Work skills directory: try `~/.kimi-work/skills/` (default), `~/.kimiwork/skills/`, `~/Library/Application Support/Kimi Work/skills/` (macOS). Print which path is used.
    - Copy `lazykimi-plugin/.kimi-code/skills/lazy-*/` into the detected skills directory.
    - Print manual MCP setup instructions: "Kimi Work does not auto-load `.kimi-code/mcp.json`. Add each lazykimi-* MCP server manually through Kimi Work's MCP configuration UI using these commands:" followed by the 6 server.sh paths.
    - Print limitations: "Kimi Work has no plugin manifest support (no hooks, no sessionStart.skill). Only skills are imported."
    - Idempotent: skip existing skills (compare SKILL.md content).
  - Create `lazykimi-plugin/docs/11-kimi-work-setup.md`:
    - H1: "Kimi Work Setup (Secondary Host)"
    - Overview paragraph: Kimi Work is a desktop agent (Beta, 2026-06-03) with Agent Swarm + built-in Skills system. LazyKimi supports Kimi Work as a secondary host via skill import only.
    - Limitations section: no plugin manifest, no hooks, no sessionStart, no /plugins install. Manual MCP configuration required.
    - Install steps: run `bash lazykimi-plugin/scripts/install-kimi-work.sh`, restart Kimi Work, verify skills appear.
    - MCP setup: manual configuration table for each of 6 servers.
    - Uninstall steps: delete `~/.kimi-work/skills/lazy-*/` directories, remove MCP servers from Kimi Work UI.
  - Update `lazykimi-plugin/docs/README.md` (if exists) or README to link to the new docs page.
  Must NOT do: Do not claim Kimi Work plugin support. Do not download Kimi Work binary. Do not write to `~/Library/Application Support/Kimi Work/` without detection (use best-effort path).
  References:
  - WebSearch results: "Kimi Work desktop agent skills system MCP agent swarm 2026" (Kimi Work description)
  - sources/LazyBuddy/lazybuddy-plugin/.workbuddy-plugin/plugin.json (secondary host pattern)
  Acceptance criteria:
  - [ ] `lazykimi-plugin/scripts/install-kimi-work.sh` exists, is executable, `bash -n` passes
  - [ ] `lazykimi-plugin/docs/11-kimi-work-setup.md` exists
  - [ ] `bash lazykimi-plugin/scripts/install-kimi-work.sh --help` exits 0
  - [ ] `grep -c 'Kimi Work' lazykimi-plugin/docs/11-kimi-work-setup.md` returns >= 5
  QA scenarios:
  - Scenario: script syntax valid | Tool: bash | Steps: `bash -n lazykimi-plugin/scripts/install-kimi-work.sh` | Expected: exit 0
  - Scenario: docs page exists | Tool: bash | Steps: `test -f lazykimi-plugin/docs/11-kimi-work-setup.md` | Expected: exit 0
  Commit: YES | Message: `feat(kimi-work): add Kimi Work setup script and docs page for secondary host support (skills import only)` | Files: [lazykimi-plugin/scripts/install-kimi-work.sh, lazykimi-plugin/docs/11-kimi-work-setup.md]

- [x] 9. Fix code-intel leak, package.json files array, verify.ts evidence mapping
  What to do:
  - Fix `lazykimi-plugin/mcp/code-intel/server.py` line ~99: change `src = open(fp, errors="ignore").read()` to `with open(fp, errors="ignore") as f: src = f.read()`.
  - Fix `lazykimi-plugin/package.json` `files` array: remove `"schemas"` and `"templates"` if those dirs don't exist at plugin root. Check with `ls lazykimi-plugin/schemas lazykimi-plugin/templates 2>&1` first. If they exist, keep; if not, remove from `files`.
  - Fix `lazykimi-plugin/src/commands/verify.ts` `EVIDENCE_FILES` map:
    - `plan-reread` → `.lazykimi/evidence/plan-reread.md`
    - `automated-verification` → `.lazykimi/evidence/test-runs.md`
    - `manual-qa` → `.lazykimi/evidence/manual-qa.md`
    - `adversarial-qa` → `.lazykimi/evidence/oracle-review.md`
    - `cleanup` → `.lazykimi/evidence/reviewer.md`
  - Update `lazykimi-plugin/src/commands/init.ts` to create the new evidence files (`plan-reread.md`, `manual-qa.md`) in target `.lazykimi/evidence/`.
  - Update existing evidence placeholder files in `lazykimi-plugin/.lazykimi/evidence/` if present.
  Must NOT do: Do not change evidence file content semantics. Do not break existing verify gate behavior.
  References:
  - lazykimi-plugin/mcp/code-intel/server.py:99 (file handle leak)
  - lazykimi-plugin/package.json:35-36 (files array)
  - lazykimi-plugin/src/commands/verify.ts:16-22 (EVIDENCE_FILES)
  Acceptance criteria:
  - [ ] `grep -c 'with open' lazykimi-plugin/mcp/code-intel/server.py` returns >= 1
  - [ ] `grep -c 'src = open' lazykimi-plugin/mcp/code-intel/server.py` returns 0
  - [ ] `node -e "const p=require('./lazykimi-plugin/package.json'); console.log(p.files.filter(f => !['schemas','templates'].includes(f)))"` does not list non-existent dirs
  - [ ] `grep -c "plan-reread.md" lazykimi-plugin/src/commands/verify.ts` returns >= 1
  - [ ] `grep -c "manual-qa.md" lazykimi-plugin/src/commands/verify.ts` returns >= 1
  QA scenarios:
  - Scenario: no file handle leak | Tool: bash | Steps: `grep -c 'with open' lazykimi-plugin/mcp/code-intel/server.py` | Expected: >= 1
  - Scenario: build passes | Tool: bash | Steps: `cd lazykimi-plugin && npm run build` | Expected: exit 0
  Commit: YES | Message: `fix: code-intel file handle leak, package.json files array, verify.ts evidence gate mapping` | Files: [lazykimi-plugin/mcp/code-intel/server.py, lazykimi-plugin/package.json, lazykimi-plugin/src/commands/verify.ts, lazykimi-plugin/src/commands/init.ts]

- [x] 10. Update root AGENTS.md + .kimi-code/AGENTS.md with Kimi Work routes
  What to do:
  - Read `/Users/Admin/Desktop/lazykimi/AGENTS.md` (non-managed block only — preserve managed block byte-for-byte).
  - Update the "LazyKimi onboard/offboard" section (non-managed, above the `<!-- lazytrae:managed -->` marker) to:
    - Add Kimi Work to the host selection table.
    - Add Kimi Work onboard route: run `bash lazykimi-plugin/scripts/install-kimi-work.sh`, restart Kimi Work, manually add MCP servers.
    - Add Kimi Work offboard route: delete `~/.kimi-work/skills/lazy-*/`, remove MCP servers from Kimi Work UI.
    - Add honest-claims sentence: "Package evidence proves copied files and declarations, not plugin loading, SessionStart, hooks, or an MCP connection."
  - Update `lazykimi-plugin/.kimi-code/AGENTS.md`:
    - Add "Kimi Work Limitations" section: no plugin manifest, no hooks, no sessionStart, manual MCP only.
    - Reference the new `docs/11-kimi-work-setup.md` page.
  - Preserve the LazyTrae managed block (between `<!-- lazytrae:managed:start:onboarding -->` and `<!-- lazytrae:managed:end:onboarding -->`) byte-for-byte.
  Must NOT do: Do not edit the managed block. Do not edit sources/. Do not claim Kimi Work has plugin support.
  References:
  - /Users/Admin/Desktop/lazykimi/AGENTS.md (existing non-managed block)
  - sources/LazyBuddy/AGENTS.md (onboard/offboard pattern)
  Acceptance criteria:
  - [ ] `grep -c 'Kimi Work' /Users/Admin/Desktop/lazykimi/AGENTS.md` returns >= 5
  - [ ] `grep -c 'install-kimi-work.sh' /Users/Admin/Desktop/lazykimi/AGENTS.md` returns >= 1
  - [ ] Managed block preserved: `diff <(sed -n '/lazytrae:managed:start/,/lazytrae:managed:end/p' AGENTS.md) <(git show HEAD:AGENTS.md | sed -n '/lazytrae:managed:start/,/lazytrae:managed:end/p')` returns no diff
  - [ ] `grep -c 'Kimi Work Limitations' lazykimi-plugin/.kimi-code/AGENTS.md` returns >= 1
  QA scenarios:
  - Scenario: managed block unchanged | Tool: bash | Steps: diff managed block before/after | Expected: no diff
  Commit: YES | Message: `docs(agents): add Kimi Work onboard/offboard routes to root AGENTS.md and .kimi-code/AGENTS.md limitations section` | Files: [/Users/Admin/Desktop/lazykimi/AGENTS.md, lazykimi-plugin/.kimi-code/AGENTS.md]

- [x] 11. Add 3 new v002 regression tests, update v001 if needed
  What to do:
  - Create `lazykimi-plugin/tests/v002-plugin-manifest-regression.sh`:
    - Verify `lazykimi-plugin/kimi.plugin.json` exists at plugin root.
    - Verify required fields: `name`, `version`, `description`, `author`, `interface.displayName`, `skills`, `mcpServers`, `hooks`, `commands`.
    - Verify `name` matches regex `^[a-z0-9][a-z0-9_-]{0,63}$`.
    - Verify no `publisher` field.
    - Verify no `${KIMI_PLUGIN_ROOT}` in manifest.
    - Verify `hooks` is an array with >= 8 entries.
  - Create `lazykimi-plugin/tests/v002-mcp-paths-regression.sh`:
    - Verify `lazykimi-plugin/.kimi-code/mcp.json` has no `${KIMI_PLUGIN_ROOT}` tokens.
    - Verify all server entries have `command` and `args`.
    - Verify 6 servers present.
  - Create `lazykimi-plugin/tests/v002-hooks-inline-regression.sh`:
    - Verify `lazykimi-plugin/hooks/hooks-config.toml` does NOT exist.
    - Verify `kimi.plugin.json` has inline `hooks` array.
    - Verify each hook has `event`, `command`, `timeout` fields.
    - Verify hook commands use `./hooks/` prefix.
  - Update `lazykimi-plugin/tests/v001-package-boundary-regression.sh` if it referenced old `.kimi-code/plugin.json` path.
  - Update `lazykimi-plugin/scripts/lazykimi-verify.sh` `CHECK_NAMES` and `CHECK_SCRIPTS` arrays to include the 3 new v002 tests (total 13 regression tests).
  Must NOT do: Do not break existing v001 tests. Do not test Kimi Work (covered in integration test).
  References:
  - lazykimi-plugin/tests/v001-package-boundary-regression.sh (pattern)
  - lazykimi-plugin/scripts/lazykimi-verify.sh (runner)
  Acceptance criteria:
  - [ ] `ls lazykimi-plugin/tests/v002-*.sh | wc -l` returns 3
  - [ ] Each v002 test passes standalone: `for t in lazykimi-plugin/tests/v002-*.sh; do bash "$t" || echo "FAIL: $t"; done`
  - [ ] `bash lazykimi-plugin/scripts/lazykimi-verify.sh 2>&1 | grep -c 'PASS'` returns >= 14 (smoke + 13 regressions)
  - [ ] `bash lazykimi-plugin/scripts/lazykimi-verify.sh 2>&1 | grep '"all_pass"'` returns `true`
  QA scenarios:
  - Scenario: all v002 tests pass | Tool: bash | Steps: `for t in lazykimi-plugin/tests/v002-*.sh; do bash "$t"; done` | Expected: exit 0
  - Scenario: verify runner all_pass | Tool: bash | Steps: `bash lazykimi-plugin/scripts/lazykimi-verify.sh` | Expected: exit 0, all_pass=true
  Commit: YES | Message: `test(v002): add 3 regression tests for plugin manifest, mcp paths, inline hooks; update verify runner` | Files: [lazykimi-plugin/tests/v002-*.sh (3 new), lazykimi-plugin/tests/v001-package-boundary-regression.sh, lazykimi-plugin/scripts/lazykimi-verify.sh]

- [x] 12. Final integration test refresh + verify runner
  What to do:
  - Read `lazykimi-plugin/scripts/lazykimi-integration-test.sh`.
  - Update to test:
    - `lazykimi init` creates `.kimi-code/`, `.lazykimi/`, AND `.lazykimi/schemas/` with 4 schema files.
    - `lazykimi doctor` reports 16 hooks (not 8) in fresh project.
    - `lazykimi load-check` reports 17/17 skills, 11/11 agents, 16/16 hooks, 6/6 MCP.
    - `lazykimi verify --must-pass` exits 0 in fresh project.
    - `install-kimi-work.sh --help` exits 0.
  - Update `lazykimi-plugin/src/commands/doctor.ts` `EXPECTED_HOOKS` from 8 to 16.
  - Update `lazykimi-plugin/src/commands/load-check.ts` (if it has hardcoded hook count) to 16.
  - Run full verify suite: `bash lazykimi-plugin/scripts/lazykimi-verify.sh` must report `all_pass: true`.
  - Run integration test: `bash lazykimi-plugin/scripts/lazykimi-integration-test.sh` must PASS with kimi steps SKIP.
  Must NOT do: Do not skip the verify runner. Do not claim Kimi Work integration test (only --help check).
  References:
  - lazykimi-plugin/scripts/lazykimi-integration-test.sh (existing)
  - lazykimi-plugin/src/commands/doctor.ts:9 (EXPECTED_HOOKS)
  Acceptance criteria:
  - [ ] `bash lazykimi-plugin/scripts/lazykimi-integration-test.sh 2>&1 | tail -5` shows "ALL PASS"
  - [ ] `bash lazykimi-plugin/scripts/lazykimi-verify.sh 2>&1 | grep '"all_pass"'` returns `true`
  - [ ] `grep -c 'EXPECTED_HOOKS = 16' lazykimi-plugin/src/commands/doctor.ts` returns 1
  QA scenarios:
  - Scenario: integration test passes | Tool: bash | Steps: `bash lazykimi-plugin/scripts/lazykimi-integration-test.sh` | Expected: exit 0, "ALL PASS"
  - Scenario: verify all_pass | Tool: bash | Steps: `bash lazykimi-plugin/scripts/lazykimi-verify.sh` | Expected: exit 0, all_pass=true
  Commit: YES | Message: `test(integration): update integration test for 16 hooks, 4 schemas, Kimi Work script; bump doctor EXPECTED_HOOKS to 16` | Files: [lazykimi-plugin/scripts/lazykimi-integration-test.sh, lazykimi-plugin/src/commands/doctor.ts, lazykimi-plugin/src/commands/load-check.ts]

## Final verification wave

- [x] F1. Plan compliance audit
  What to do: Re-read `.lazytrae/plans/lazykimi-spec-compliance.md`; verify every task 1-12 has References + Acceptance + QA + Commit; verify dependency matrix is consistent; verify all 12 tasks completed and committed.
  Acceptance: All 12 tasks have commit evidence; no unchecked boxes; dependency matrix acyclic.

- [x] F2. Code quality review
  What to do: Run `bash lazykimi-plugin/scripts/lazykimi-verify.sh`; review largest files for slop; verify hook scripts ≤ 100 lines; verify CLI files ≤ 250 lines; verify no `git add -A` in any script; verify `npm run build` exits 0.
  Acceptance: verify runner `all_pass: true`; no slop markers found; build exit 0.

- [x] F3. Real manual QA
  What to do: Run `kimi` (if authenticated); type `/plugins install <path-to-lazykimi-plugin>`; verify plugin loads; type `/skill:lazy-init-deep`; verify skill loads; type `/swarm test`; verify swarm starts. If kimi unavailable, document as SKIPPED with evidence.
  Acceptance: kimi session active; at least one skill loads; at least one Kimi-native mode (/swarm or /goal) starts; OR documented SKIPPED with reason.

- [x] F4. Scope fidelity
  What to do: Verify all Must-have items present; verify no Must-NOT-have violations (no sources/ edits, no managed block edits, no `${KIMI_PLUGIN_ROOT}` in mcp.json, no `publisher` field, no `hooks-config.toml`); verify NOTICE attributes all upstreams; verify MIT license; verify Kimi Work documentation present.
  Acceptance: All Must-have checked; no Must-NOT-have violations; NOTICE complete; LICENSE MIT; Kimi Work docs present.

## Commit strategy
- Conventional Commits, atomic, one logical change per commit.
- Each task = one commit (12 task commits).
- Stage only changed files (no `git add -A` / `git add .`).
- Commit message format: `<type>(<scope>): <summary>`.
- No `--no-verify`. No force pushes. No WIP commits on final branch.
- Final commit footer: `Plan: .lazytrae/plans/lazykimi-spec-compliance.md` when plan exists.
