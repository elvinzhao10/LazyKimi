# LazyKimi v0.3.0 Capability Hardening

## TL;DR
> Summary:      Close the highest-friction gaps between LazyKimi's declared capabilities and its actual implementation, plus port the most valuable low-risk features from LazyBuddy and LazyTrae that Kimi Code CLI can actually use.
> Deliverables: Project rules file, `sync`/`handoff`/`completion-status` CLI commands, optional-MCP lifecycle, dynamic rule matching, post-compact recovery hook, expanded regression tests, clean empty directories.
> Effort:       Medium-Large
> Risk:         Medium — touches CLI dispatch, hook events, MCP declarations, and user-facing docs; all changes are additive or fix inaccurate claims.

## Scope

### Must have
- Create `.kimi-code/rules/lazykimi.md` so the skills that reference it have a real rules file.
- Add `lazykimi sync` CLI command that updates an existing target's managed `.kimi-code/` and `.lazykimi/` templates without overwriting user-owned files.
- Add `lazykimi handoff` CLI command that generates `.lazykimi/evidence/handoff.md` from boulder + active-loop + recent evidence.
- Add `lazykimi completion-status` CLI command that prints PASS/FAIL per evidence gate before a human claims done.
- Add optional-MCP capability lifecycle: `lazykimi tooling enable <capability>` / `disable` for the six optional placeholder MCP servers (grep_app, context7, filesystem, git, playwright, ast_grep, lsp), writing `.kimi-code/mcp.json` safely.
- Add dynamic rule matching to `hooks/post-tool-use.sh`: after a write, suggest relevant `.kimi-code/rules/*.md` files based on changed file extensions.
- Add post-compact recovery to `hooks/session-start.sh` and `hooks/pre-compact.sh`: record a rules-hash + recovery flag, and re-inject context on next session start if compaction occurred.
- Expand regression tests to cover SSRF boundary, MCP path traversal, hook uninstall foreign-hook preservation, and `sync`/`handoff`/`completion-status` commands.
- Seed `.lazykimi/logs/` during `init`; remove or document the empty `lazykimi-plugin/schemas/` and `lazykimi-plugin/templates/` directories.

### Must NOT have (guardrails, anti-slop, scope boundaries)
- No new optional MCP server implementations (only enable/disable placeholders and lifecycle wrappers).
- No new agent role definitions; reuse existing 11 Greek-myth roles.
- No changes to the 16 hook event set; only enhance existing hook scripts.
- No Kimi Work-specific implementation beyond what already exists.
- No backwards-compat shims for old manifest paths.
- No `git add -A` / `git add .` in any script.
- No edits to `sources/` (read-only references).
- No edits to `.trae/` or `.lazytrae/` managed blocks.

## Verification strategy
- Test decision: tests-after + framework = bash regression scripts + TypeScript `npm run build`.
- QA policy: every task has agent-executed bash scenarios; Manual-QA artifacts are terminal output captures.
- Evidence: `.lazykimi/evidence/task-<N>-<slug>.md` plus `.lazykimi/logs/start-work-ledger.jsonl`.

## Execution strategy

### Parallel execution waves

**Wave 1 (documentation and CLI surface, no dependencies):**
- Task 1: Create `.kimi-code/rules/lazykimi.md`
- Task 2: Add `lazykimi sync` CLI command
- Task 3: Add `lazykimi handoff` CLI command
- Task 4: Add `lazykimi completion-status` CLI command
- Task 8: Expand regression tests (framework only)

**Wave 2 (hooks and lifecycle, depends on Wave 1 docs):**
- Task 5: Add optional-MCP capability lifecycle
- Task 6: Add dynamic rule matching to post-tool-use hook
- Task 7: Add post-compact recovery hook

**Wave 3 (cleanup and final verification, depends on Waves 1-2):**
- Task 9: Seed logs dir and clean empty schemas/templates dirs
- Task 10: Final verification wave

### Dependency matrix

| Task | Depends on | Blocks | Can parallelize with |
|------|------------|--------|----------------------|
| 1    | none       | none   | 2, 3, 4, 8          |
| 2    | none       | 9      | 1, 3, 4, 8          |
| 3    | none       | 9      | 1, 2, 4, 8          |
| 4    | none       | 9      | 1, 2, 3, 8          |
| 5    | none       | none   | 6, 7                |
| 6    | 1          | none   | 5, 7                |
| 7    | 1          | none   | 5, 6                |
| 8    | none       | 10     | 1, 2, 3, 4          |
| 9    | 2, 3, 4    | 10     | none                |
| 10   | 5, 6, 7, 8, 9 | none | none             |

## Todos

- [x] 1. Create `.kimi-code/rules/lazykimi.md`
  What to do:
  - Create `lazykimi-plugin/.kimi-code/rules/lazykimi.md` with Kimi Code CLI-specific operating rules.
  - Cover: slash-command conventions (`/skill:<name>`, `/swarm`, `/goal`, `/plan on|off`), sub-agent channel mapping (`coder`/`explore`/`plan`), evidence-gate expectations, no-emojis, English agent-to-agent traffic, and the five mandatory gates.
  - Keep it under 150 lines and telegraphic; match the style of `lazykimi-plugin/.kimi-code/rules/` if any exist.
  - Update `lazykimi-plugin/src/commands/init.ts` to copy `rules/` -> `.kimi-code/rules/` during init.
  - Update `lazykimi-plugin/scripts/lazykimi-smoke.sh` to assert `.kimi-code/rules/lazykimi.md` exists after init.
  Must NOT do: Do not create rules for other languages (TS/Python/CSS) in this task; do not rewrite existing agent prompts.
  References:
  - `lazykimi-plugin/.kimi-code/skills/lazy-start-work/SKILL.md` (references `rules/lazykimi.md`)
  - `lazykimi-plugin/.kimi-code/skills/lazy-ulw-loop/SKILL.md`
  - `lazykimi-plugin/.kimi-code/skills/lazy-librarian/SKILL.md`
  - `lazykimi-plugin/src/commands/init.ts:130-180`
  - `sources/LazyTrae/lazytrae-plugin/.trae/rules/lazytrae.md`
  Acceptance criteria:
  - [ ] File `lazykimi-plugin/.kimi-code/rules/lazykimi.md` exists and is non-empty.
  - [ ] `node dist/index.js init --target /tmp/lazykimi-rules-test && test -f /tmp/lazykimi-rules-test/.kimi-code/rules/lazykimi.md` passes.
  - [ ] `bash scripts/lazykimi-smoke.sh` passes.
  QA scenarios:
  - Scenario: rules file copied | Tool: bash | Steps: `rm -rf /tmp/lazykimi-rules-test && node lazykimi-plugin/dist/index.js init --target /tmp/lazykimi-rules-test && head -20 /tmp/lazykimi-rules-test/.kimi-code/rules/lazykimi.md` | Expected: file exists and contains rules header.
  Commit: YES | Message: `feat(rules): add Kimi Code CLI project rules file` | Files: [lazykimi-plugin/.kimi-code/rules/lazykimi.md, lazykimi-plugin/src/commands/init.ts, lazykimi-plugin/scripts/lazykimi-smoke.sh]

- [x] 2. Add `lazykimi sync` CLI command
  What to do:
  - Create `lazykimi-plugin/src/commands/sync.ts` with logic to update an existing target's managed assets:
    - Copy missing/new files from `.kimi-code/` and `.lazykimi/` templates.
    - Skip files that are user-owned (outside `<!-- lazykimi:managed:start -->` / `<!-- lazykimi:managed:end -->` blocks).
    - Update managed blocks in place where present.
    - Do not overwrite `.lazykimi/state/` files.
  - Wire the command into `lazykimi-plugin/src/index.ts`.
  - Add `--dry-run` support.
  - Add a regression test `v003-sync-regression.sh`.
  Must NOT do: Do not reimplement `init`; reuse copy helpers. Do not sync runtime state.
  References:
  - `lazykimi-plugin/src/commands/init.ts`
  - `lazykimi-plugin/src/index.ts`
  - `sources/LazyTrae/lazytrae-plugin/packages/cli/src/commands/sync.js`
  Acceptance criteria:
  - [ ] `node dist/index.js sync --help` prints usage.
  - [ ] Running `sync` on a target missing `commands/` adds `.kimi-code/commands/` without touching user files.
  - [ ] `npm run build` exits 0.
  QA scenarios:
  - Scenario: sync adds missing assets | Tool: bash | Steps: `rm -rf /tmp/lazykimi-sync-test && node lazykimi-plugin/dist/index.js init --target /tmp/lazykimi-sync-test && rm -rf /tmp/lazykimi-sync-test/.kimi-code/commands && cd /tmp/lazykimi-sync-test && node /Users/Admin/Desktop/lazykimi/lazykimi-plugin/dist/index.js sync && ls .kimi-code/commands/` | Expected: commands directory restored.
  Commit: YES | Message: `feat(cli): add lazykimi sync command for managed template updates` | Files: [lazykimi-plugin/src/commands/sync.ts, lazykimi-plugin/src/index.ts, lazykimi-plugin/tests/v003-sync-regression.sh]

- [x] 3. Add `lazykimi handoff` CLI command
  What to do:
  - Create `lazykimi-plugin/src/commands/handoff.ts` that reads `.lazykimi/state/boulder.json` and `.lazykimi/state/active-loop.json` and recent evidence files, then writes `.lazykimi/evidence/handoff.md`.
  - Output sections: Active Work, Active Loop, Recent Evidence, Next Steps.
  - Wire into `lazykimi-plugin/src/index.ts`.
  - Add `--stdout` option to print instead of write.
  - Reuse run-ledger MCP `generate_handoff` logic if possible; otherwise implement locally in TS.
  Must NOT do: Do not add state-mutation; handoff is read-only + write to evidence dir.
  References:
  - `lazykimi-plugin/mcp/run-ledger/server.py`
  - `lazykimi-plugin/commands/lazy-handoff.md`
  - `lazykimi-plugin/src/index.ts`
  Acceptance criteria:
  - [ ] `node dist/index.js handoff --stdout` exits 0 and prints Markdown.
  - [ ] `node dist/index.js handoff` creates/updates `.lazykimi/evidence/handoff.md`.
  - [ ] On a fresh init target with no active work, handoff says "(none)" for active sections.
  QA scenarios:
  - Scenario: handoff markdown | Tool: bash | Steps: `rm -rf /tmp/lazykimi-handoff-test && node lazykimi-plugin/dist/index.js init --target /tmp/lazykimi-handoff-test && cd /tmp/lazykimi-handoff-test && node /Users/Admin/Desktop/lazykimi/lazykimi-plugin/dist/index.js handoff --stdout` | Expected: output contains "## Active Work" and "## Recent Evidence".
  Commit: YES | Message: `feat(cli): add lazykimi handoff command` | Files: [lazykimi-plugin/src/commands/handoff.ts, lazykimi-plugin/src/index.ts]

- [x] 4. Add `lazykimi completion-status` CLI command
  What to do:
  - Create `lazykimi-plugin/src/commands/completion-status.ts` that runs doctor, regression tests, and evidence-gate checks, then prints per-gate status and an overall READY/NOT READY.
  - This is similar to `verify` but focused on completion readiness and returns a structured table.
  - Wire into `lazykimi-plugin/src/index.ts`.
  - Add `--json` option.
  Must NOT do: Do not duplicate `verify.ts` logic blindly; extract shared helpers if needed. Do not make the command mutate state.
  References:
  - `lazykimi-plugin/src/commands/verify.ts`
  - `lazykimi-plugin/src/commands/doctor.ts`
  - `sources/LazyTrae/lazytrae-plugin/packages/cli/src/commands/completion-status.js`
  Acceptance criteria:
  - [ ] `node dist/index.js completion-status --help` prints usage.
  - [ ] `node dist/index.js completion-status` exits 0 when all gates pass.
  - [ ] `node dist/index.js completion-status --json` prints valid JSON.
  QA scenarios:
  - Scenario: completion-status passes | Tool: bash | Steps: `cd lazykimi-plugin && node dist/index.js completion-status` | Expected: exit 0, output contains "READY".
  Commit: YES | Message: `feat(cli): add lazykimi completion-status command` | Files: [lazykimi-plugin/src/commands/completion-status.ts, lazykimi-plugin/src/index.ts, lazykimi-plugin/src/lib/completion.ts]

- [x] 5. Add optional-MCP capability lifecycle
  What to do:
  - Extend `lazykimi-plugin/src/commands/tooling.ts` with subcommands:
    - `enable <capability>` — copy the placeholder MCP declaration from a template into `.kimi-code/mcp.json`, enabling the server.
    - `disable <capability>` — remove the MCP declaration from `.kimi-code/mcp.json`.
    - `list` — show enabled/disabled optional capabilities.
  - Supported capabilities (placeholders only): `grep_app`, `context7`, `filesystem`, `git`, `playwright`, `ast_grep`, `lsp`.
  - Keep the existing `detect`/`status`/`policy` subcommands.
  - Add validation that the capability name is in the allow-list.
  - Add regression test `v003-tooling-capability-regression.sh`.
  Must NOT do: Do not implement the actual optional MCP servers (LSP, CodeGraph, etc.). Do not auto-enable anything during init.
  References:
  - `lazykimi-plugin/src/commands/tooling.ts`
  - `lazykimi-plugin/.kimi-code/mcp.json`
  - `sources/LazyTrae/lazytrae-plugin/.trae/mcp.json`
  - `sources/LazyTrae/lazytrae-plugin/packages/cli/src/commands/tooling.js`
  Acceptance criteria:
  - [ ] `node dist/index.js tooling enable lsp` exits 0 and `.kimi-code/mcp.json` contains a `lazykimi-lsp` server.
  - [ ] `node dist/index.js tooling disable lsp` exits 0 and `.kimi-code/mcp.json` no longer contains it.
  - [ ] `node dist/index.js tooling list` shows enabled/disabled status.
  QA scenarios:
  - Scenario: enable/disable lifecycle | Tool: bash | Steps: `rm -rf /tmp/lazykimi-cap-test && node lazykimi-plugin/dist/index.js init --target /tmp/lazykimi-cap-test && cd /tmp/lazykimi-cap-test && node /Users/Admin/Desktop/lazykimi/lazykimi-plugin/dist/index.js tooling enable lsp && grep -c 'lazykimi-lsp' .kimi-code/mcp.json && node /Users/Admin/Desktop/lazykimi/lazykimi-plugin/dist/index.js tooling disable lsp && grep -c 'lazykimi-lsp' .kimi-code/mcp.json || true` | Expected: enable returns 1, disable returns 0.
  Commit: YES | Message: `feat(cli): add optional-MCP enable/disable lifecycle to tooling command` | Files: [lazykimi-plugin/src/commands/tooling.ts, lazykimi-plugin/.kimi-code/mcp.json, lazykimi-plugin/tests/v003-tooling-capability-regression.sh]

- [x] 6. Add dynamic rule matching to post-tool-use hook
  What to do:
  - Extend `lazykimi-plugin/hooks/post-tool-use.sh` to read `.kimi-code/rules/*.md` after a tool writes files.
  - Match changed file extensions against rule file names (e.g., `typescript.md` for `.ts`/`.tsx`, `python.md` for `.py`).
  - Print a short advisory listing the most relevant rule file(s) to the session transcript (stdout), prefixed with `RULE:` so downstream tooling can parse it.
  - Fail open if `.kimi-code/rules/` is missing or empty.
  - Add regression test `v003-dynamic-rules-regression.sh`.
  Must NOT do: Do not block tool execution; this hook must remain advisory (exit 0). Do not hard-code language lists outside the rule-matching function.
  References:
  - `lazykimi-plugin/hooks/post-tool-use.sh`
  - `sources/LazyTrae/lazytrae-plugin/.trae/hooks/post-tool-use.sh`
  - `sources/LazyTrae/lazytrae-plugin/.trae/hooks/dynamic-rules.sh`
  Acceptance criteria:
  - [ ] `bash -n lazykimi-plugin/hooks/post-tool-use.sh` exits 0.
  - [ ] Simulating a write to a `.ts` file in a project with `.kimi-code/rules/typescript.md` prints `RULE: typescript.md`.
  - [ ] Hook still exits 0 when `.kimi-code/rules/` does not exist.
  QA scenarios:
  - Scenario: dynamic rule hint | Tool: bash | Steps: `rm -rf /tmp/lazykimi-rules-hook-test && node lazykimi-plugin/dist/index.js init --target /tmp/lazykimi-rules-hook-test && mkdir -p /tmp/lazykimi-rules-hook-test/.kimi-code/rules && echo '# TS Rules' > /tmp/lazykimi-rules-hook-test/.kimi-code/rules/typescript.md && cd /tmp/lazykimi-rules-hook-test && printf '{"hook_event_name":"PostToolUse","changed_files":["src/foo.ts"]}\n' | bash /Users/Admin/Desktop/lazykimi/lazykimi-plugin/hooks/post-tool-use.sh` | Expected: output contains "RULE: typescript.md".
  Commit: YES | Message: `feat(hooks): dynamic rule matching in post-tool-use` | Files: [lazykimi-plugin/hooks/post-tool-use.sh, lazykimi-plugin/tests/v003-dynamic-rules-regression.sh]

- [x] 7. Add post-compact recovery hook
  What to do:
  - Update `lazykimi-plugin/hooks/pre-compact.sh` to write a `post_compact_recovery_needed` flag and a hash of `.kimi-code/rules/` into `.lazykimi/state/sessions.json` before compaction.
  - Update `lazykimi-plugin/hooks/session-start.sh` to check that flag; if set, print a compact recovery hint (rule file list, active plan path from boulder) and clear the flag.
  - Use Python for JSON manipulation (fail open on errors).
  - Add regression test `v003-compact-recovery-regression.sh`.
  Must NOT do: Do not block SessionStart. Do not require `jq`.
  References:
  - `lazykimi-plugin/hooks/pre-compact.sh`
  - `lazykimi-plugin/hooks/session-start.sh`
  - `sources/LazyTrae/lazytrae-plugin/.trae/hooks/context-recovery.sh`
  - `sources/LazyTrae/lazytrae-plugin/.trae/hooks/session-start.sh`
  Acceptance criteria:
  - [ ] `bash -n lazykimi-plugin/hooks/pre-compact.sh` and `bash -n lazykimi-plugin/hooks/session-start.sh` exit 0.
  - [ ] After simulating PreCompact then SessionStart, the recovery flag is cleared and a hint is printed.
  - [ ] Hook fails open if `sessions.json` is missing.
  QA scenarios:
  - Scenario: compact recovery | Tool: bash | Steps: `rm -rf /tmp/lazykimi-compact-test && node lazykimi-plugin/dist/index.js init --target /tmp/lazykimi-compact-test && cd /tmp/lazykimi-compact-test && printf '{"hook_event_name":"PreCompact"}\n' | bash /Users/Admin/Desktop/lazykimi/lazykimi-plugin/hooks/pre-compact.sh && python3 -c "import json; d=json.load(open('.lazykimi/state/sessions.json')); print(d.get('post_compact_recovery_needed'))" && printf '{"hook_event_name":"SessionStart"}\n' | bash /Users/Admin/Desktop/lazykimi/lazykimi-plugin/hooks/session-start.sh` | Expected: recovery flag true after pre-compact, hint printed after session-start, flag cleared.
  Commit: YES | Message: `feat(hooks): post-compact recovery flag and session-start hint` | Files: [lazykimi-plugin/hooks/pre-compact.sh, lazykimi-plugin/hooks/session-start.sh, lazykimi-plugin/tests/v003-compact-recovery-regression.sh]

- [x] 8. Expand regression test coverage
  What to do:
  - Add `v003-ssrf-boundary-regression.sh` to exercise `mcp/docs/server.py` whitelist and redirect blocking.
  - Add `v003-mcp-path-traversal-regression.sh` to verify `mcp/path_boundary.py` rejects `..`, absolute paths, and symlink escapes.
  - Add `v003-hook-uninstall-corrupt-regression.sh` to verify `removeHooksFromConfig` handles malformed `[[hooks]]` blocks without corrupting `config.toml`.
  - Add `v003-evidence-gate-content-regression.sh` to verify placeholder evidence fails and non-placeholder evidence passes.
  - Ensure each new test follows the existing `PASS/FAIL` output convention.
  Must NOT do: Do not add external dependencies or network requirements beyond what the existing tests use.
  References:
  - `lazykimi-plugin/tests/v001-ssrf-regression.sh`
  - `lazykimi-plugin/tests/v003-hook-uninstall-regression.sh`
  - `lazykimi-plugin/mcp/path_boundary.py`
  - `lazykimi-plugin/src/commands/verify.ts`
  Acceptance criteria:
  - [ ] `bash scripts/lazykimi-verify.sh` still reports `all_pass: true` after adding tests.
  - [ ] Each new test exits 0 when run individually.
  QA scenarios:
  - Scenario: new tests pass | Tool: bash | Steps: `cd lazykimi-plugin && for f in tests/v003-*-regression.sh; do bash "$f"; done` | Expected: all print PASS.
  Commit: YES | Message: `test(regression): add SSRF, path-traversal, hook-uninstall, and evidence-gate regression tests` | Files: [lazykimi-plugin/tests/v003-ssrf-boundary-regression.sh, lazykimi-plugin/tests/v003-mcp-path-traversal-regression.sh, lazykimi-plugin/tests/v003-hook-uninstall-corrupt-regression.sh, lazykimi-plugin/tests/v003-evidence-gate-content-regression.sh]

- [x] 9. Seed logs dir and clean empty schema/template dirs
  What to do:
  - Update `lazykimi-plugin/src/commands/init.ts` to create `.lazykimi/logs/` during init.
  - Remove the empty `lazykimi-plugin/schemas/` directory or document why it exists.
  - Remove the empty `lazykimi-plugin/templates/` directory or add a placeholder README explaining its purpose.
  - Update `lazykimi-plugin/scripts/lazykimi-smoke.sh` to assert `.lazykimi/logs/` exists after init.
  Must NOT do: Do not delete non-empty directories. Do not change the location of the real schemas in `.lazykimi/schemas/`.
  References:
  - `lazykimi-plugin/src/commands/init.ts`
  - `lazykimi-plugin/scripts/lazykimi-smoke.sh`
  Acceptance criteria:
  - [ ] After `init`, target contains `.lazykimi/logs/`.
  - [ ] Empty `lazykimi-plugin/schemas/` and `lazykimi-plugin/templates/` are removed or documented.
  - [ ] `bash scripts/lazykimi-smoke.sh` passes.
  QA scenarios:
  - Scenario: logs dir seeded | Tool: bash | Steps: `rm -rf /tmp/lazykimi-logs-test && node lazykimi-plugin/dist/index.js init --target /tmp/lazykimi-logs-test && test -d /tmp/lazykimi-logs-test/.lazykimi/logs` | Expected: exit 0.
  Commit: YES | Message: `chore(init): seed .lazykimi/logs and clean empty schema/template directories` | Files: [lazykimi-plugin/src/commands/init.ts, lazykimi-plugin/scripts/lazykimi-smoke.sh]

## Final verification wave

- [x] F1. Plan compliance audit
  What to do: Re-read this plan; verify every task 1-9 has References + Acceptance + QA + Commit; verify dependency matrix is consistent; verify all checkboxes completed.
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
- Each task = one commit (9 task commits + 1 final verification commit).
- Stage only changed files (no `git add -A` / `git add .`).
- Commit message format: `<type>(<scope>): <summary>`.
- No `--no-verify`. No force pushes. No WIP commits on final branch.
- Final commit footer: `Plan: .lazykimi/plans/lazykimi-v0.3.0-capability-hardening.md`.
