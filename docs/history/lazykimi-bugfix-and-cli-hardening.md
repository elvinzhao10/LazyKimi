# LazyKimi Bug-Fix and CLI Hardening Plan

## TL;DR
> Summary:      Fix the critical state-management and hook-installation bugs discovered in LazyKimi 0.2.0, harden the CLI so `doctor`/`verify` are meaningful in both source and installed layouts, and add the missing `tooling` CLI command plus two high-value MCP workflow tools. All changes stay inside `lazykimi-plugin/` and root docs; no edits to `sources/`, `.trae/`, or `.lazytrae/`.
> Deliverables: Schema-valid seed state, non-corrupting session logging, working hook uninstall, plugin-root doctor, aligned active-loop path, content-aware evidence gates, richer `init` copies, `lazykimi tooling` command, two new run-ledger workflow tools.
> Effort:       Medium-Large
> Risk:         Medium — touches state schemas, hook uninstall semantics, and MCP server behavior.

## Scope

### Must have
- Fix `src/commands/init.ts` seed `boulder.json` to match `.lazykimi/schemas/boulder.schema.json`.
- Fix `hooks/session-end.sh` so it no longer corrupts `.lazykimi/state/sessions.json`.
- Fix `src/lib/hooks-config.ts` so `lazykimi uninstall` can remove hooks installed by `scripts/install-hooks.sh`.
- Remove or restore the dead `appendHooksToConfig` code path.
- Make `lazykimi doctor`/`verify` useful when run from `lazykimi-plugin/` source root.
- Align `active-loop` storage path and shape across schema, MCP servers, and hooks.
- Strengthen `lazykimi verify` evidence gates to inspect file content, not just existence.
- Extend `lazykimi init` to copy `commands/`, `contracts/`, `tooling/`, and `kimi.plugin.json`.
- Correct stale hook count in `lazykimi-evaluation.md`.
- Add `lazykimi tooling` CLI command that exposes the existing Python capability broker.
- Add `run-ledger` MCP tools `get_active_plan` and `generate_handoff`.

### Must NOT have (guardrails, anti-slop, scope boundaries)
- No new optional MCP servers (LSP, CodeGraph, grep_app, Context7, Playwright).
- No new agent role definitions or skill rewrites.
- No changes to the 16 hook event set or hook blocking rules.
- No Kimi Work-specific implementation; only Kimi Code CLI primary host.
- No backwards-compat shims for old manifest paths.
- No `git add -A` / `git add .`.
- No edits to `sources/` (read-only references).
- No edits to `.trae/` or `.lazytrae/` managed blocks.

## Verification strategy
- Test decision: tests-after + framework = bash regression scripts + TypeScript `npm run build`.
- QA policy: every task has agent-executed bash scenarios; Manual-QA artifacts are terminal output captures.
- Evidence: `.lazykimi/evidence/task-<N>-<slug>.md` plus `.lazykimi/logs/start-work-ledger.jsonl`.

## Execution strategy

### Parallel execution waves

**Wave 1 (critical bugs, no dependencies):**
- Task 1: Fix boulder seed state to match schema
- Task 2: Fix session-end hook JSON corruption
- Task 3: Fix uninstall hook removal to match install-hooks.sh
- Task 4: Fix doctor/verify for plugin-root layout
- Task 8: Fix evaluation.md hook count

**Wave 2 (state alignment and verification, depends on Wave 1):**
- Task 5: Align active-loop path and shape
- Task 6: Strengthen verify evidence gates
- Task 7: Extend init to copy commands/contracts/tooling/manifest

**Wave 3 (CLI and MCP feature gaps, depends on Wave 2):**
- Task 9: Add `lazykimi tooling` CLI command
- Task 10: Add run-ledger workflow tools

### Dependency matrix

| Task | Depends on | Blocks | Can parallelize with |
|------|------------|--------|----------------------|
| 1    | none       | none   | 2, 3, 4, 8          |
| 2    | none       | none   | 1, 3, 4, 8          |
| 3    | none       | none   | 1, 2, 4, 8          |
| 4    | none       | none   | 1, 2, 3, 8          |
| 5    | 1          | 10     | 6, 7                |
| 6    | 1          | none   | 5, 7                |
| 7    | none       | none   | 5, 6                |
| 8    | none       | none   | 1, 2, 3, 4          |
| 9    | none       | none   | 10                  |
| 10   | 5          | none   | 9                   |

## Todos

- [x] 1. Fix boulder seed state to match schema
  What to do:
  - Rewrite `src/commands/init.ts` `defaultBoulderState()` to emit a schema-valid object:
    ```json
    {
      "schema_version": 2,
      "active_work_id": null,
      "works": {}
    }
    ```
  - Bump `schema_version` from 1 to 2 to match `.lazykimi/schemas/boulder.schema.json`.
  - Update `src/commands/doctor.ts` `checkBoulderState` to validate required fields (`active_work_id`, `works`) in addition to parsing.
  - Update `tests/v001-cli-doctor-regression.sh` if it asserts the old shape.
  Must NOT do: Do not change the schema itself; only fix the seed to match it. Do not migrate existing user boulder files.
  References:
  - `lazykimi-plugin/src/commands/init.ts:116-118`
  - `lazykimi-plugin/src/commands/doctor.ts:66-84`
  - `lazykimi-plugin/.lazykimi/schemas/boulder.schema.json`
  Acceptance criteria:
  - [ ] `node -e "const b=require('./lazykimi-plugin/.lazykimi/state/boulder.json'); console.log(b.schema_version, b.active_work_id, Array.isArray(b.works)?'array':typeof b.works)"` prints `2 null object` after init.
  - [ ] `cd lazykimi-plugin && npm run build` exits 0.
  - [ ] `node dist/index.js init --target /tmp/lazykimi-boulder-test && node -e "JSON.parse(require('fs').readFileSync('/tmp/lazykimi-boulder-test/.lazykimi/state/boulder.json','utf8')); console.log('valid JSON')"` exits 0.
  QA scenarios:
  - Scenario: schema-valid seed | Tool: bash | Steps: `rm -rf /tmp/lazykimi-boulder-test && node lazykimi-plugin/dist/index.js init --target /tmp/lazykimi-boulder-test && cat /tmp/lazykimi-boulder-test/.lazykimi/state/boulder.json` | Expected: output contains `schema_version": 2`, `active_work_id`, `works`.
  - Scenario: doctor validates boulder | Tool: bash | Steps: `cd /tmp/lazykimi-boulder-test && node /Users/Admin/Desktop/lazykimi/lazykimi-plugin/dist/index.js doctor` | Expected: `[PASS] .lazykimi/state/boulder.json`.
  Commit: YES | Message: `fix(state): emit schema-valid boulder seed with schema_version 2` | Files: [lazykimi-plugin/src/commands/init.ts, lazykimi-plugin/src/commands/doctor.ts, lazykimi-plugin/tests/v001-cli-doctor-regression.sh]

- [x] 2. Fix session-end hook JSON corruption
  What to do:
  - Decide format: treat `.lazykimi/state/sessions.json` as a JSON object with a `sessions` array, seeded by `init` as `{"sessions":[]}`.
  - Rewrite `hooks/session-end.sh` to read the existing object (if present), append a JSON record to `sessions`, and write the object back atomically (`.tmp` + `mv`). Use `python3` for JSON parsing/writing; fail open on errors.
  - Update `src/commands/init.ts` to seed `sessions.json`.
  - Update `.lazykimi/schemas/sessions.schema.json` to match the object-with-array shape if needed.
  Must NOT do: Do not block SessionEnd. Do not write plain text. Do not require `jq`.
  References:
  - `lazykimi-plugin/hooks/session-end.sh`
  - `lazykimi-plugin/.lazykimi/schemas/sessions.schema.json`
  - `lazykimi-plugin/src/commands/init.ts`
  Acceptance criteria:
  - [ ] `bash -n lazykimi-plugin/hooks/session-end.sh` exits 0.
  - [ ] After simulating SessionEnd twice, `sessions.json` parses as valid JSON and `sessions.length === 2`.
  - [ ] `node dist/index.js init --target /tmp/lazykimi-sessions-test && test -f /tmp/lazykimi-sessions-test/.lazykimi/state/sessions.json` passes.
  QA scenarios:
  - Scenario: session-end keeps JSON valid | Tool: bash | Steps: `rm -rf /tmp/lazykimi-sessions-test && node lazykimi-plugin/dist/index.js init --target /tmp/lazykimi-sessions-test && echo '{"hook_event_name":"SessionEnd"}' | bash lazykimi-plugin/hooks/session-end.sh && echo '{"hook_event_name":"SessionEnd"}' | bash lazykimi-plugin/hooks/session-end.sh && python3 -c "import json; d=json.load(open('/tmp/lazykimi-sessions-test/.lazykimi/state/sessions.json')); print(len(d['sessions']))"` | Expected: prints `2`.
  Commit: YES | Message: `fix(hooks): make session-end.sh write valid JSON instead of corrupting sessions.json` | Files: [lazykimi-plugin/hooks/session-end.sh, lazykimi-plugin/src/commands/init.ts, lazykimi-plugin/.lazykimi/schemas/sessions.schema.json]

- [x] 3. Fix uninstall hook removal to match install-hooks.sh
  What to do:
  - Rewrite `src/lib/hooks-config.ts` `removeHooksFromConfig(configPath)` to parse `[[hooks]]` entries in `~/.kimi-code/config.toml` and remove entries whose `command` points to `.kimi-code/hooks/*.sh` inside the current project.
  - Keep `isHooksInstalled` as a helper that detects at least one LazyKimi hook entry.
  - Delete `appendHooksToConfig` (or keep as no-op returning `changed:false, reason:'not used'`) since `hooks-config.toml` no longer exists.
  - Update `src/commands/uninstall.ts` to pass the project root to `removeHooksFromConfig` so it can match absolute hook paths.
  - Update `tests/v001-security-regression.sh` or add a new `v003-hook-uninstall-regression.sh`.
  Must NOT do: Do not reintroduce `hooks-config.toml`. Do not remove non-LazyKimi hooks.
  References:
  - `lazykimi-plugin/src/lib/hooks-config.ts`
  - `lazykimi-plugin/src/commands/uninstall.ts`
  - `lazykimi-plugin/scripts/install-hooks.sh:130-166`
  Acceptance criteria:
  - [ ] `npm run build` exits 0.
  - [ ] In an isolated HOME, running `install-hooks.sh` then `lazykimi uninstall --yes` leaves `config.toml` with zero LazyKimi `[[hooks]]` entries.
  - [ ] Non-LazyKimi `[[hooks]]` entries are preserved.
  QA scenarios:
  - Scenario: uninstall removes installed hooks | Tool: bash | Steps: `rm -rf /tmp/lazykimi-hooks-uninstall && mkdir -p /tmp/lazykimi-hooks-uninstall && HOME=/tmp/lazykimi-hooks-uninstall node lazykimi-plugin/dist/index.js init --target /tmp/lazykimi-hooks-uninstall/proj && HOME=/tmp/lazykimi-hooks-uninstall bash lazykimi-plugin/scripts/install-hooks.sh --project-root /tmp/lazykimi-hooks-uninstall/proj && grep -c '\\[\\[hooks\\]\\]' /tmp/lazykimi-hooks-uninstall/.kimi-code/config.toml && cd /tmp/lazykimi-hooks-uninstall/proj && HOME=/tmp/lazykimi-hooks-uninstall node /Users/Admin/Desktop/lazykimi/lazykimi-plugin/dist/index.js uninstall --yes && grep -c 'lazykimi' /tmp/lazykimi-hooks-uninstall/.kimi-code/config.toml || true` | Expected: before uninstall `8` hooks; after uninstall `0` matches.
  - Scenario: foreign hooks preserved | Tool: bash | Steps: `printf '[[hooks]]\nevent = "SessionStart"\ncommand = "bash /some/other/hook.sh"\n' >> /tmp/lazykimi-hooks-uninstall/.kimi-code/config.toml && cd /tmp/lazykimi-hooks-uninstall/proj && HOME=/tmp/lazykimi-hooks-uninstall node /Users/Admin/Desktop/lazykimi/lazykimi-plugin/dist/index.js uninstall --yes && grep -c '/some/other/hook.sh' /tmp/lazykimi-hooks-uninstall/.kimi-code/config.toml` | Expected: `1`.
  Commit: YES | Message: `fix(uninstall): parse config.toml [[hooks]] entries to remove hooks installed by install-hooks.sh` | Files: [lazykimi-plugin/src/lib/hooks-config.ts, lazykimi-plugin/src/commands/uninstall.ts]

- [x] 4. Fix doctor/verify for plugin-root layout
  What to do:
  - Add a helper in `src/lib/paths.ts` to detect whether CWD is the plugin source root (presence of `package.json` + `kimi.plugin.json` + `src/`).
  - Update `src/commands/doctor.ts` `runDoctor` to fall back to source-layout paths when run from the plugin root:
    - skills/agents/hooks source: `.kimi-code/skills/`, `.kimi-code/agents/`, `.kimi-code/hooks/` if present, else `skills/`, `agents/`, `hooks/`.
    - boulder: `.lazykimi/state/boulder.json` (project root) or `../.lazykimi/state/boulder.json` if plugin root.
  - Update `src/commands/verify.ts` similarly, or have it call `runDoctor` with a resolved target.
  - Update README/docs only if the fix changes the recommended commands.
  Must NOT do: Do not change the installed-layout behavior. Do not make doctor automatically run init.
  References:
  - `lazykimi-plugin/src/commands/doctor.ts`
  - `lazykimi-plugin/src/commands/verify.ts:87-91`
  - `lazykimi-plugin/src/lib/paths.ts`
  Acceptance criteria:
  - [ ] `cd lazykimi-plugin && node dist/index.js doctor` reports PASS for skills, agents, hooks, mcp.json, boulder.
  - [ ] `cd lazykimi-plugin && node dist/index.js verify --must-pass` exits 0.
  - [ ] In an installed target, doctor still expects `.kimi-code/` under the target.
  QA scenarios:
  - Scenario: doctor from plugin root | Tool: bash | Steps: `cd lazykimi-plugin && node dist/index.js doctor` | Expected: 0 FAIL, counts match 17/11/16/6.
  - Scenario: verify from plugin root | Tool: bash | Steps: `cd lazykimi-plugin && node dist/index.js verify --must-pass` | Expected: exit 0.
  Commit: YES | Message: `fix(cli): make doctor and verify work from lazykimi-plugin source root` | Files: [lazykimi-plugin/src/commands/doctor.ts, lazykimi-plugin/src/commands/verify.ts, lazykimi-plugin/src/lib/paths.ts]

- [x] 5. Align active-loop path and shape
  What to do:
  - Make `.lazykimi/state/active-loop.json` the canonical location with schema shape `{loop_id, objective, mode, started_at, turn_count, status}`.
  - Update `mcp/run-ledger/server.py` to read/write `state/active-loop.json` with the schema shape; keep a fallback read of `loop/active-loop.json` for one release if needed.
  - Update `mcp/status-dashboard/server.py` to read `state/active-loop.json`.
  - Update `hooks/pre-compact.sh` to snapshot `state/active-loop.json`.
  - Update `src/commands/init.ts` to seed `state/active-loop.json`.
  - Remove or repurpose `.lazykimi/loop/` creation in init (keep dir for backwards compat but no active-loop file there).
  Must NOT do: Do not change the active-loop schema fields. Do not break `create_run` run-ledger behavior.
  References:
  - `lazykimi-plugin/mcp/run-ledger/server.py:24-28`
  - `lazykimi-plugin/mcp/status-dashboard/server.py`
  - `lazykimi-plugin/hooks/pre-compact.sh`
  - `lazykimi-plugin/.lazykimi/schemas/active-loop.schema.json`
  Acceptance criteria:
  - [ ] `create_run` writes `state/active-loop.json` matching the schema.
  - [ ] `status-dashboard.get_status` returns the active loop from `state/active-loop.json`.
  - [ ] `npm run build` exits 0 (if TS changes) and all MCP servers pass `py_compile`.
  QA scenarios:
  - Scenario: active loop at schema path | Tool: bash | Steps: `rm -rf /tmp/lazykimi-loop-test && node lazykimi-plugin/dist/index.js init --target /tmp/lazykimi-loop-test && echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"create_run","arguments":{"run_id":"r1","objective":"test"}}}' | python3 lazykimi-plugin/mcp/run-ledger/server.sh` | Expected: `/tmp/lazykimi-loop-test/.lazykimi/state/active-loop.json` exists and contains `loop_id`, `objective`, `mode`, `started_at`, `turn_count`, `status`.
  Commit: YES | Message: `fix(state): align active-loop path with schema at .lazykimi/state/active-loop.json` | Files: [lazykimi-plugin/mcp/run-ledger/server.py, lazykimi-plugin/mcp/status-dashboard/server.py, lazykimi-plugin/hooks/pre-compact.sh, lazykimi-plugin/src/commands/init.ts]

- [x] 6. Strengthen verify evidence gates
  What to do:
  - Extend `src/commands/verify.ts` `checkEvidenceGates` to validate each evidence Markdown file contains at least one non-empty section under the expected heading (`## Acceptance Criteria`, `## QA Scenarios`, `## Evidence`, etc.) or a non-placeholder line.
  - Keep existence as a baseline; a file that only contains `(none yet)` should FAIL.
  - Update `init.ts` evidence templates to include empty section stubs instead of `(none yet)` placeholders.
  - Update `scripts/lazykimi-integration-test.sh` to seed evidence with real section content or adjust expectations.
  Must NOT do: Do not require exact evidence schema JSON inside Markdown. Do not break the smoke test.
  References:
  - `lazykimi-plugin/src/commands/verify.ts:36-49`
  - `lazykimi-plugin/src/commands/init.ts:82-95`
  - `lazykimi-plugin/scripts/lazykimi-integration-test.sh`
  Acceptance criteria:
  - [ ] `verify --must-pass` FAILS when evidence files are empty/placeholder-only.
  - [ ] `verify --must-pass` PASSES when evidence files contain at least one non-placeholder section.
  - [ ] `bash scripts/lazykimi-smoke.sh` still passes.
  QA scenarios:
  - Scenario: empty evidence fails | Tool: bash | Steps: `rm -rf /tmp/lazykimi-evidence-test && node lazykimi-plugin/dist/index.js init --target /tmp/lazykimi-evidence-test && cd /tmp/lazykimi-evidence-test && node /Users/Admin/Desktop/lazykimi/lazykimi-plugin/dist/index.js verify --must-pass; echo exit=$?` | Expected: exit=1 (placeholder-only evidence).
  - Scenario: populated evidence passes | Tool: bash | Steps: `printf '## Evidence\n- Ran tests\n' >> /tmp/lazykimi-evidence-test/.lazykimi/evidence/test-runs.md && cd /tmp/lazykimi-evidence-test && node /Users/Admin/Desktop/lazykimi/lazykimi-plugin/dist/index.js verify --must-pass; echo exit=$?` | Expected: exit=0.
  Commit: YES | Message: `fix(verify): evidence gates require non-placeholder content, not just file existence` | Files: [lazykimi-plugin/src/commands/verify.ts, lazykimi-plugin/src/commands/init.ts, lazykimi-plugin/scripts/lazykimi-integration-test.sh]

- [x] 7. Extend init to copy commands, contracts, tooling, and manifest
  What to do:
  - Add `copyDir` calls in `src/commands/init.ts` for:
    - `commands/` -> `.kimi-code/commands/`
    - `contracts/` -> `.kimi-code/contracts/`
    - `tooling/` -> `.kimi-code/tooling/`
    - `kimi.plugin.json` -> `.kimi-code/kimi.plugin.json`
  - Ensure `kimi.plugin.json` copied this way has relative paths that resolve from the project root, or document that project-config route is for config.toml + skills only.
  - Update `tests/v001-package-boundary-regression.sh` to assert these directories are inside `lazykimi-plugin/` (they already are, but verify no leakage).
  - Update smoke test to check copied files.
  Must NOT do: Do not copy `dist/`, `node_modules/`, or `tests/` into target. Do not rewrite manifest paths unless necessary.
  References:
  - `lazykimi-plugin/src/commands/init.ts:130-143`
  - `lazykimi-plugin/src/lib/paths.ts`
  Acceptance criteria:
  - [ ] After `init`, target `.kimi-code/commands/`, `.kimi-code/contracts/`, `.kimi-code/tooling/`, `.kimi-code/kimi.plugin.json` exist.
  - [ ] `npm run build` exits 0.
  - [ ] `bash scripts/lazykimi-smoke.sh` passes.
  QA scenarios:
  - Scenario: init copies extra assets | Tool: bash | Steps: `rm -rf /tmp/lazykimi-init-copy-test && node lazykimi-plugin/dist/index.js init --target /tmp/lazykimi-init-copy-test && ls /tmp/lazykimi-init-copy-test/.kimi-code/commands/ /tmp/lazykimi-init-copy-test/.kimi-code/contracts/ /tmp/lazykimi-init-copy-test/.kimi-code/tooling/ /tmp/lazykimi-init-copy-test/.kimi-code/kimi.plugin.json` | Expected: all four paths exist.
  Commit: YES | Message: `feat(init): copy commands, contracts, tooling, and plugin manifest during init` | Files: [lazykimi-plugin/src/commands/init.ts, lazykimi-plugin/src/lib/paths.ts, lazykimi-plugin/scripts/lazykimi-smoke.sh]

- [x] 8. Fix lazykimi-evaluation.md hook count
  What to do:
  - Update `lazykimi-evaluation.md` line 138 from `8` to `16` hooks.
  - Scan the same file for other stale counts (MCP tools, skills, agents) and fix any mismatches.
  - Update `lazykimi-plugin/README.md` if it has similar stale counts.
  Must NOT do: Do not rewrite the entire evaluation file; only correct stale counts.
  References:
  - `lazykimi-evaluation.md:138`
  - `lazykimi-plugin/README.md`
  Acceptance criteria:
  - [ ] `grep -c 'Hooks.*8' lazykimi-evaluation.md` returns 0.
  - [ ] `grep -c '16' lazykimi-evaluation.md` returns at least 1 in the capability table.
  QA scenarios:
  - Scenario: hook count accurate | Tool: bash | Steps: `grep -A1 'Hooks' lazykimi-evaluation.md | grep -c '16'` | Expected: 1.
  Commit: YES | Message: `docs(evaluation): correct hook count from 8 to 16` | Files: [lazykimi-evaluation.md]

- [x] 9. Add lazykimi tooling CLI command
  What to do:
  - Create `src/commands/tooling.ts` with subcommands:
    - `detect` — print capability detection results by invoking `tooling/lazykimi_detector.py`.
    - `status` — print status from `tooling/lazykimi_capability.py`.
    - `policy` — print policy digest from `tooling/lazykimi_policy.py`.
    - `--help` usage.
  - Wire the command into `src/index.ts`.
  - Ensure the command shells out to `python3` and parses stdout as JSON/text.
  - Add a regression test `v003-tooling-command-regression.sh`.
  Must NOT do: Do not implement full install/uninstall in this task (only detect/status/policy). Do not add npm dependencies.
  References:
  - `lazykimi-plugin/tooling/lazykimi_detector.py`
  - `lazykimi-plugin/tooling/lazykimi_capability.py`
  - `lazykimi-plugin/tooling/lazykimi_policy.py`
  - `lazykimi-plugin/src/index.ts`
  Acceptance criteria:
  - [x] `node dist/index.js tooling --help` lists detect/status/policy.
  - [x] `node dist/index.js tooling detect` exits 0 and prints capability JSON or table.
  - [x] `node dist/index.js tooling policy` exits 0.
  QA scenarios:
  - Scenario: tooling command works | Tool: bash | Steps: `cd lazykimi-plugin && node dist/index.js tooling detect` | Expected: exit 0, output contains detected tool names.
  Commit: YES | Message: `feat(cli): add lazykimi tooling command (detect, status, policy)` | Files: [lazykimi-plugin/src/commands/tooling.ts, lazykimi-plugin/src/index.ts, lazykimi-plugin/tests/v003-tooling-command-regression.sh]

- [x] 10. Add run-ledger workflow tools
  What to do:
  - Extend `mcp/run-ledger/server.py` with two new tools:
    - `get_active_plan` — returns `{plan_path, plan_name, work_id}` from boulder + active-loop, or null if none.
    - `generate_handoff` — returns a Markdown handoff string summarizing boulder active work, active loop, and recent evidence.
  - Register the tools in the `tools/list` response.
  - Update `lazykimi-plugin/.kimi-code/AGENTS.md` MCP table to list the two new tools.
  Must NOT do: Do not add state-mutation tools (mark_task_done, add_blocker) in this task. Do not change existing run-ledger tool signatures.
  References:
  - `lazykimi-plugin/mcp/run-ledger/server.py`
  - `lazykimi-plugin/.kimi-code/AGENTS.md`
  Acceptance criteria:
  - [x] `tools/list` from run-ledger includes `get_active_plan` and `generate_handoff`.
  - [x] Calling `get_active_plan` on a fresh init project returns null without error.
  - [x] Calling `generate_handoff` on a fresh init project returns a Markdown string.
  QA scenarios:
  - Scenario: new tools exist | Tool: bash | Steps: `echo '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | python3 lazykimi-plugin/mcp/run-ledger/server.sh | grep -c 'get_active_plan'` | Expected: 1.
  Commit: YES | Message: `feat(mcp): add get_active_plan and generate_handoff tools to run-ledger` | Files: [lazykimi-plugin/mcp/run-ledger/server.py, lazykimi-plugin/.kimi-code/AGENTS.md]

## Final verification wave

- [x] F1. Plan compliance audit
  What to do: Re-read this plan; verify every task 1-10 has References + Acceptance + QA + Commit; verify dependency matrix is consistent; verify all checkboxes completed.
  Acceptance: All tasks have commit evidence; no unchecked boxes; dependency matrix acyclic.

- [x] F2. Code quality review
  What to do: Run `npm run build`, `bash scripts/lazykimi-verify.sh`, and `bash scripts/lazykimi-smoke.sh`; review changed files for slop (no `any`, no unused vars, no default exports in TS); verify hook scripts ≤ 100 lines; verify CLI files ≤ 250 lines; verify no `git add -A` in any script.
  Acceptance: `npm run build` exit 0; verify runner `all_pass: true`; smoke pass; no slop markers.

- [x] F3. Real manual QA
  What to do: From `lazykimi-plugin/`, run `node dist/index.js load-check`, `node dist/index.js doctor`, `node dist/index.js verify --must-pass`. Run `node dist/index.js init --target /tmp/lazykimi-final-qa && cd /tmp/lazykimi-final-qa && node /Users/Admin/Desktop/lazykimi/lazykimi-plugin/dist/index.js doctor && node /Users/Admin/Desktop/lazykimi/lazykimi-plugin/dist/index.js verify --must-pass`.
  Acceptance: Both plugin-root and installed-target doctor/verify exit 0.

- [x] F4. Scope fidelity
  What to do: Verify all Must-have items present; verify no Must-NOT-have violations; verify `sources/`, `.trae/`, `.lazytrae/` unchanged; verify NOTICE/LICENSE intact.
  Acceptance: All Must-have checked; no Must-NOT-have violations.

## Commit strategy
- Conventional Commits, atomic, one logical change per commit.
- Each task = one commit (10 task commits).
- Stage only changed files (no `git add -A` / `git add .`).
- Commit message format: `<type>(<scope>): <summary>`.
- No `--no-verify`. No force pushes. No WIP commits on final branch.
- Final commit footer: `Plan: .lazykimi/plans/lazykimi-bugfix-and-cli-hardening.md`.
