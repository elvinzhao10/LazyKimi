# LazyKimi Recreate — Port LazyBuddy/LazyTrae to Kimi Code CLI

## TL;DR
> Summary:      Build `lazykimi-plugin/` — a Kimi-native evidence-led agent workflow harness porting LazyBuddy (CodeBuddy) + LazyTrae (Trae) design to Kimi Code CLI, leveraging native `/swarm` (300 agents), `/goal` (persistent autonomous goals), `/plan`, SKILL.md system, 16 hook events, and MCP support. lazycodex is the canonical design reference.
> Deliverables: lazykimi-plugin/ package with 17 skills, 11 agent role definitions, 8 hook scripts, 6 local MCP servers, lazykimi CLI installer (TS), .lazykimi/ state model, verification suite, docs.
> Effort:       Large
> Risk:         Medium — Kimi Code CLI plugin/hook model is well-documented and maps 1:1 to Trae; main risk is hook event semantics and MCP server stdio contract differences.

## Scope

### Must have
- `lazykimi-plugin/` package at repo root with TypeScript CLI + Bash hooks + Python MCP servers.
- 17 skills as `.kimi-code/skills/lazy-*/SKILL.md` (project-level) with YAML frontmatter matching Kimi Code CLI spec.
- 11 agent role definitions as `agents/*.md` (atlas, prometheus, sisyphus, oracle, hephaestus, metis, momus, explorer, librarian, cleaner, migration-planner) mapped to Kimi's `coder`/`explore`/`plan` sub-agents.
- 8 hook scripts (Bash) + `[[hooks]]` config entries for Kimi's `SessionStart`, `UserPromptSubmit`, `PreToolUse`, `PostToolUse`, `Stop`, `SubagentStop`, `PreCompact`, `PostCompact` events.
- 6 local MCP servers (run-ledger, verification, status-dashboard, context-graph, code-intel, docs) using stdio JSON-RPC, registered via `/mcp-config`.
- `lazykimi` CLI (TypeScript, npm `lazykimi-ai`) with `init`, `doctor`, `verify`, `load-check`, `uninstall`, `mcp` commands.
- `.lazykimi/` state model: `state/boulder.json`, `evidence/*.md`, `plans/*.md`, `schemas/*.json`.
- Kimi-native integration: `/swarm` for parallel execution, `/goal` for persistent autonomous goals, `/plan` for plan mode — documented in skills and AGENTS.md.
- Plugin manifest for Kimi Code CLI `/plugins` system.
- Verification suite: bash regression tests + smoke tests + `lazykimi verify` gate.
- Root `AGENTS.md` updated with LazyKimi onboarding/offboard protocols (preserving LazyTrae managed block).
- NOTICE attributing upstream: LazyBuddy (elvinzhao10), LazyTrae (elvinzhao10), lazycodex/OmO (code-yeongyu). MIT license.

### Must NOT have (guardrails, anti-slop, scope boundaries)
- No marketing website (lazycodex `packages/web/` is out of scope).
- No Node.js MCP server (LazyTrae's `packages/mcp/`) — use Python stdio JSON-RPC (LazyBuddy pattern) for simplicity.
- No Kimi Work desktop agent wiring (documented as secondary host, not implemented).
- No Kimi K3 model weight downloads or local inference — API-only via Kimi Code CLI's provider config.
- No `git add -A` / `git add .` — stage only changed files.
- No edits to `sources/` (read-only references).
- No edits to `.trae/` or `.lazytrae/` managed blocks (LazyTrae planning infra).
- No optional tooling auto-enablement during init (codegraph, lsp, context7 require explicit `lazykimi tooling enable`).
- No claim of Kimi host connection from package checks alone.
- No backwards-compat shims for LazyTrae/LazyBuddy — LazyKimi is a fresh port.
- No emojis in code/commits (lazycodex convention).

## Verification strategy
- Test decision: tests-after + framework = bash regression scripts (LazyBuddy pattern) + `node --test` for CLI (LazyTrae pattern).
- QA policy: every task has agent-executed scenarios (bash smoke + `lazykimi verify` + `kimi /status`).
- Evidence: `.lazytrae/evidence/task-<N>-<slug>.{md,json,log}`

## Execution strategy

### Parallel execution waves

**Wave 1 (scaffold, no dependencies):**
- Task 1: Scaffold `lazykimi-plugin/` structure + package.json + tsconfig + base configs
- Task 2: Create `.lazykimi/` state model + JSON schemas + config templates

**Wave 2 (core content, depends on Wave 1):**
- Task 3: Port 17 skills as `.kimi-code/skills/lazy-*/SKILL.md`
- Task 4: Port 11 agent role definitions + Kimi sub-agent mapping
- Task 5: Port 8 hook scripts + `[[hooks]]` config entries
- Task 6: Port 6 local MCP servers (Python stdio JSON-RPC)

**Wave 3 (CLI + integration, depends on Wave 2):**
- Task 7: Build `lazykimi` CLI installer (TypeScript) — init/doctor/verify/load-check/uninstall/mcp
- Task 8: Build plugin manifest for Kimi Code CLI `/plugins` + marketplace.json
- Task 9: Build receipt-owned tooling lifecycle (capability broker/detector/policy)

**Wave 4 (verification + docs, depends on Wave 3):**
- Task 10: Write verification suite (bash regression tests + smoke tests)
- Task 11: Write documentation (README, AGENTS.md update, NOTICE, LICENSE, evaluation)
- Task 12: Final integration smoke test (`kimi /init` + `/skill:lazy-*` + `/swarm` + `/goal`)

### Dependency matrix

| Task | Depends on | Blocks | Can parallelize with |
|------|------------|--------|----------------------|
| 1    | none       | 3,4,5,6,7 | 2                |
| 2    | none       | 3,7      | 1                |
| 3    | 1,2        | 7,10,12  | 4,5,6            |
| 4    | 1          | 7,10,12  | 3,5,6            |
| 5    | 1          | 7,10,12  | 3,4,6            |
| 6    | 1          | 7,10,12  | 3,4,5            |
| 7    | 3,4,5,6    | 8,9,10,11,12 | none          |
| 8    | 7          | 12       | 9,10,11          |
| 9    | 7          | 10,12    | 8,10,11          |
| 10   | 7,9        | 12       | 8,11             |
| 11   | 7          | 12       | 8,9,10           |
| 12   | 8,9,10,11  | F1-F4    | none             |

## Todos

- [x] 1. Scaffold lazykimi-plugin/ structure + package.json + tsconfig + base configs
  What to do:
  - Create `lazykimi-plugin/` at repo root with subdirs: `src/`, `skills/`, `agents/`, `hooks/`, `mcp/`, `commands/`, `schemas/`, `templates/`, `scripts/`, `tooling/`, `tests/`.
  - Create `lazykimi-plugin/package.json` (name: `lazykimi-ai`, version: `0.1.0`, bin: `lazykimi`, type: commonjs, engines: node>=18, scripts: test/build).
  - Create `lazykimi-plugin/tsconfig.json` (strict, ES2022, outDir: dist).
  - Create `lazykimi-plugin/.kimi-code/` dir (project-level skill home, mirrors what installer copies).
  - Create `lazykimi-plugin/NOTICE` attributing LazyBuddy, LazyTrae, lazycodex/OmO.
  - Create `lazykimi-plugin/LICENSE` (MIT).
  - Create `lazykimi-plugin/.gitignore` (node_modules, dist, .lazykimi/state/, *.pyc).
  Must NOT do: No source code yet (just structure). No dependencies installed. No edits to sources/.
  References:
  - sources/LazyBuddy/lazybuddy-plugin/ (structure pattern)
  - sources/LazyTrae/lazytrae-plugin/packages/cli/package.json (package.json pattern)
  - sources/lazycodex/plugins/omo/.codex-plugin/plugin.json (manifest pattern)
  Acceptance criteria:
  - [ ] `lazykimi-plugin/` exists with all 10 subdirectories
  - [ ] `cat lazykimi-plugin/package.json` shows name `lazykimi-ai`, bin `lazykimi`, version `0.1.0`
  - [ ] `cat lazykimi-plugin/NOTICE` mentions LazyBuddy, LazyTrae, lazycodex, OmO
  - [ ] `cat lazykimi-plugin/LICENSE` is MIT
  QA scenarios:
  - Scenario: structure created | Tool: bash | Steps: `ls -la lazykimi-plugin/` | Expected: 10 subdirs + 4 root files
  - Scenario: package.json valid | Tool: bash | Steps: `node -e "JSON.parse(require('fs').readFileSync('lazykimi-plugin/package.json','utf8'))"` | Expected: exit 0
  Commit: YES | Message: `feat(scaffold): create lazykimi-plugin/ structure with package.json, tsconfig, NOTICE, LICENSE` | Files: [lazykimi-plugin/**]

- [x] 2. Create .lazykimi/ state model + JSON schemas + config templates
  What to do:
  - Create `.lazykimi/` at repo root with subdirs: `state/`, `evidence/`, `plans/`, `schemas/`, `loop/`, `team/`.
  - Create `.lazykimi/schemas/boulder.schema.json` (JSON Schema for boulder state: active_goal_id, tasks[], blockers[], schema_version).
  - Create `.lazykimi/schemas/evidence.schema.json` (schema for evidence files: gate, status, reason, timestamp).
  - Create `.lazykimi/schemas/sessions.schema.json` (schema for session state).
  - Create `.lazykimi/schemas/active-loop.schema.json` (schema for /goal + /swarm loop state).
  - Create `.lazykimi/state/boulder.json` (empty initial state: `{schema_version: 1, active_goal_id: null, tasks: [], blockers: []}`).
  - Create `.lazykimi/config.json` (default config: host=kimi-code-cli, model=kimi-k3, state_dir=.lazykimi).
  - Create `.lazykimi/evidence/` placeholder files: completion.md, handoff.md, oracle-review.md, reviewer.md, test-runs.md, verifier.md (each with `# <name> evidence` header).
  Must NOT do: No runtime code. No edits to .lazytrae/ (separate planning state). No edits to sources/.
  References:
  - sources/LazyTrae/lazytrae-plugin/.lazytrae/schemas/ (schema patterns)
  - sources/LazyTrae/lazytrae-plugin/.lazytrae/config.json (config pattern)
  - sources/LazyBuddy/lazybuddy-plugin/schemas/ (schema patterns)
  Acceptance criteria:
  - [ ] `.lazykimi/` exists with 6 subdirectories
  - [ ] `ls .lazykimi/schemas/*.schema.json` shows 4 schema files
  - [ ] `node -e "JSON.parse(require('fs').readFileSync('.lazykimi/state/boulder.json','utf8'))"` exits 0
  - [ ] `node -e "JSON.parse(require('fs').readFileSync('.lazykimi/schemas/boulder.schema.json','utf8'))"` exits 0
  - [ ] `.lazykimi/evidence/` has 6 placeholder .md files
  QA scenarios:
  - Scenario: schemas valid JSON | Tool: bash | Steps: `for f in .lazykimi/schemas/*.json .lazykimi/state/*.json .lazykimi/config.json; do node -e "JSON.parse(require('fs').readFileSync('$f','utf8'))" || echo "FAIL: $f"; done` | Expected: no FAIL output
  Commit: YES | Message: `feat(state): add .lazykimi/ state model with boulder, evidence, schemas, config` | Files: [.lazykimi/**]

- [x] 3. Port 17 skills as .kimi-code/skills/lazy-*/SKILL.md
  What to do:
  - Create `lazykimi-plugin/.kimi-code/skills/lazy-<name>/SKILL.md` for each of 17 skills: init-deep, ulw-plan, ulw-loop, start-work, ultrawork, review-work, reviewer, verifier, debugging, programming, git-master, frontend, ast-grep, librarian, migration-planner, remove-ai-slops, coding-agent-sessions, lcx-report-bug.
  - Each SKILL.md has YAML frontmatter: `name`, `description`, `type: prompt`, `whenToUse`, `arguments` (where applicable).
  - Adapt content from LazyTrae's `.trae/skills/` + LazyBuddy's `lazybuddy-plugin/skills/` + lazycodex's `plugins/omo/skills/`.
  - Kimi-specific adaptations:
    - Replace Trae team mode references with `/swarm <task>` (300-agent swarm).
    - Replace custom ULW loop references with `/goal <objective>` (persistent autonomous goals).
    - Replace `.trae/` paths with `.kimi-code/` paths.
    - Replace `.lazytrae/` paths with `.lazykimi/`.
    - Replace `lazytrae` CLI with `lazykimi` CLI.
    - `lazy-ulw-loop` skill: first user-visible line MUST be `ULTRAWORK MODE ENABLED!`.
    - `lazy-ulw-plan` skill: planner identity constraint NON-NEGOTIABLE (never implements).
  - Each skill body uses `$ARGUMENTS`, `${KIMI_SKILL_DIR}` placeholders where applicable.
  Must NOT do: No copy-paste without adaptation (Trae→Kimi). No `git add -A`. No emojis. No default exports in any TS.
  References:
  - sources/LazyTrae/lazytrae-plugin/.trae/skills/lazy-*/SKILL.md (17 skills, primary source)
  - sources/LazyBuddy/lazybuddy-plugin/skills/lazy-*/SKILL.md (Bash-flavored variants)
  - sources/lazycodex/plugins/omo/skills/ultrawork/SKILL.md (canonical ultrawork directive)
  - sources/lazycodex/plugins/omo/components/ultrawork/directive.md (binding ultrawork contract)
  - https://www.kimi.com/code/docs/kimi-code-cli/customization/skills.html (Kimi SKILL.md spec)
  Acceptance criteria:
  - [ ] `ls lazykimi-plugin/.kimi-code/skills/lazy-*/SKILL.md | wc -l` returns 17
  - [ ] Each SKILL.md has `name:` and `description:` in frontmatter (required by Kimi spec for directory-form skills)
  - [ ] `grep -r "\.trae/" lazykimi-plugin/.kimi-code/skills/` returns no matches (all paths adapted to .kimi-code/)
  - [ ] `grep -r "\.lazytrae/" lazykimi-plugin/.kimi-code/skills/` returns no matches (all paths adapted to .lazykimi/)
  - [ ] `grep -l "ULTRAWORK MODE ENABLED!" lazykimi-plugin/.kimi-code/skills/lazy-ulw-loop/SKILL.md` matches
  - [ ] `grep -l "NON-NEGOTIABLE" lazykimi-plugin/.kimi-code/skills/lazy-ulw-plan/SKILL.md` matches (planner identity)
  - [ ] `grep -r "/swarm" lazykimi-plugin/.kimi-code/skills/` returns matches (swarm integration documented)
  - [ ] `grep -r "/goal" lazykimi-plugin/.kimi-code/skills/` returns matches (goal mode documented)
  QA scenarios:
  - Scenario: all 17 skills present | Tool: bash | Steps: `ls lazykimi-plugin/.kimi-code/skills/ | grep -c "^lazy-"` | Expected: 17
  - Scenario: frontmatter valid | Tool: bash | Steps: `for f in lazykimi-plugin/.kimi-code/skills/lazy-*/SKILL.md; do head -1 "$f" | grep -q "^---" || echo "FAIL: $f"; done` | Expected: no FAIL output
  - Scenario: no Trae path leakage | Tool: bash | Steps: `grep -rl "\.trae/" lazykimi-plugin/.kimi-code/skills/` | Expected: no output
  Commit: YES | Message: `feat(skills): port 17 lazy-* skills to Kimi Code CLI SKILL.md format with /swarm + /goal integration` | Files: [lazykimi-plugin/.kimi-code/skills/**]

- [x] 4. Port 11 agent role definitions + Kimi sub-agent mapping
  What to do:
  - Create `lazykimi-plugin/agents/lazykimi-<role>.md` for 11 roles: orchestrator (sisyphus), planner (prometheus), implementer (hephaestus), verifier (oracle), reviewer (momus), explorer, librarian, metis (gap analyst), cleaner, atlas (context recovery), migration-planner.
  - Each agent .md has: role description, Kimi sub-agent mapping (coder/explore/plan), tools allowed/disallowed, isolation flag, model routing (kimi-k3 for deep, kimi-k2.7-code for coding).
  - Create `lazykimi-plugin/.kimi-code/AGENTS.md` (project-level agent instructions) with:
    - LazyKimi overview (1 paragraph)
    - Agent role catalog (11 roles → Kimi sub-agent mapping table)
    - Workflow phases (Explore → Plan → Implement → Verify → Review → Librarian → Handoff)
    - Evidence gate requirements (5 gates)
    - Kimi-native mode usage (`/swarm`, `/goal`, `/plan`)
  - Map Greek-myth agents to Kimi's 3 sub-agents:
    - `coder` sub-agent: hephaestus (implementer), cleaner, migration-planner
    - `explore` sub-agent: explorer, librarian, atlas, metis
    - `plan` sub-agent: prometheus (planner), momus (reviewer)
    - Main agent: sisyphus (orchestrator), oracle (verifier)
  Must NOT do: No custom sub-agent binaries (use Kimi's built-in 3). No model downloads. No edits to sources/.
  References:
  - sources/LazyTrae/lazytrae-plugin/.trae/agents/*.md (11 agents, primary)
  - sources/LazyBuddy/lazybuddy-plugin/agents/lazybuddy-*.md (13 agents, alternate)
  - sources/lazycodex/plugins/omo/components/ultrawork/agents/*.toml (5 canonical TOML roles)
  - https://www.kimi.com/code/docs/kimi-code-cli/customization/agents.html (Kimi sub-agent spec)
  Acceptance criteria:
  - [ ] `ls lazykimi-plugin/agents/lazykimi-*.md | wc -l` returns 11
  - [ ] `cat lazykimi-plugin/.kimi-code/AGENTS.md` contains "coder", "explore", "plan" (Kimi sub-agent mapping)
  - [ ] `grep -l "sisyphus\|orchestrator" lazykimi-plugin/agents/lazykimi-orchestrator.md` matches
  - [ ] `grep -l "prometheus\|planner" lazykimi-plugin/agents/lazykimi-planner.md` matches
  - [ ] `grep -l "NON-NEGOTIABLE" lazykimi-plugin/agents/lazykimi-planner.md` matches (planner identity)
  - [ ] `grep -l "read-only\|disallowed" lazykimi-plugin/agents/lazykimi-explorer.md` matches
  QA scenarios:
  - Scenario: 11 agent files | Tool: bash | Steps: `ls lazykimi-plugin/agents/lazykimi-*.md | wc -l` | Expected: 11
  - Scenario: Kimi sub-agent mapping documented | Tool: bash | Steps: `grep -E "coder|explore|plan" lazykimi-plugin/.kimi-code/AGENTS.md | head -5` | Expected: 5+ matches
  Commit: YES | Message: `feat(agents): port 11 agent roles with Kimi sub-agent mapping (coder/explore/plan)` | Files: [lazykimi-plugin/agents/**, lazykimi-plugin/.kimi-code/AGENTS.md]

- [x] 5. Port 8 hook scripts + [[hooks]] config entries
  What to do:
  - Create 8 Bash hook scripts in `lazykimi-plugin/hooks/`:
    1. `session-start.sh` — SessionStart: load .kimi-code/AGENTS.md, detect .lazykimi/ state, print readiness
    2. `user-prompt-submit.sh` — UserPromptSubmit: detect `ultrawork`/`ulw` keywords, inject skill pointer; detect context pressure
    3. `pre-tool-use.sh` — PreToolUse: deny secrets/destructive ops (rm -rf, git push --force), enforce path boundaries
    4. `post-tool-use.sh` — PostToolUse: check for file drift, recommend tools
    5. `stop-gate.sh` — Stop: verify completion evidence before allowing stop (exit 2 if gates unmet)
    6. `subagent-stop.sh` — SubagentStop: verify sub-agent evidence
    7. `pre-compact.sh` — PreCompact: snapshot .lazykimi/ state
    8. `post-compact.sh` — PostCompact: restore context markers
  - Each script: `#!/usr/bin/env bash`, `set -euo pipefail`, reads JSON from stdin, exits 0/2 per Kimi spec.
  - Create `lazykimi-plugin/hooks/hooks-config.toml` (template `[[hooks]]` entries users append to `~/.kimi-code/config.toml`):
    ```toml
    [[hooks]]
    event = "SessionStart"
    command = "bash .kimi-code/hooks/session-start.sh"
    timeout = 10
    # ... 8 entries
    ```
  - Create `lazykimi-plugin/scripts/install-hooks.sh` (appends hooks to ~/.kimi-code/config.toml idempotently).
  Must NOT do: Hooks must be fail-open (exit 0 on error, never block except deliberate exit 2). No network calls from hooks. No edits to sources/. Each hook script ≤ 100 lines.
  References:
  - sources/LazyBuddy/lazybuddy-plugin/scripts/hooks/ (12 hook scripts, primary Bash pattern)
  - sources/LazyTrae/lazytrae-plugin/.trae/hooks/ (8 hook scripts)
  - sources/LazyTrae/lazytrae-plugin/.trae/hooks.json (hook event mapping)
  - https://www.kimi.com/code/docs/kimi-code-cli/customization/hooks.html (Kimi 16 hook events spec)
  - https://www.kimi.com/code/docs/kimi-code-cli/configuration/config-files.html (config.toml [[hooks]] format)
  Acceptance criteria:
  - [ ] `ls lazykimi-plugin/hooks/*.sh | wc -l` returns 8 hook scripts + 1 install-hooks.sh
  - [ ] `cat lazykimi-plugin/hooks/hooks-config.toml` contains 8 `[[hooks]]` entries
  - [ ] Each hook script starts with `#!/usr/bin/env bash` and `set -euo pipefail`
  - [ ] `for f in lazykimi-plugin/hooks/*.sh; do wc -l "$f" | awk '$1>100{print "FAIL: "$2}'; done` returns no FAIL
  - [ ] `grep -l "exit 2" lazykimi-plugin/hooks/stop-gate.sh` matches (deliberate block)
  - [ ] `bash -n lazykimi-plugin/hooks/*.sh` exits 0 (all scripts syntactically valid)
  QA scenarios:
  - Scenario: hooks syntactically valid | Tool: bash | Steps: `for f in lazykimi-plugin/hooks/*.sh; do bash -n "$f" || echo "FAIL: $f"; done` | Expected: no FAIL output
  - Scenario: hook blocks dangerous command | Tool: bash | Steps: `echo '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"rm -rf /"}}' | bash lazykimi-plugin/hooks/pre-tool-use.sh; echo "exit=$?"` | Expected: exit=2
  - Scenario: hook allows safe command | Tool: bash | Steps: `echo '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"ls -la"}}' | bash lazykimi-plugin/hooks/pre-tool-use.sh; echo "exit=$?"` | Expected: exit=0
  Commit: YES | Message: `feat(hooks): port 8 hook scripts to Kimi Code CLI [[hooks]] format with fail-open semantics` | Files: [lazykimi-plugin/hooks/**, lazykimi-plugin/scripts/install-hooks.sh]

- [x] 6. Port 6 local MCP servers (Python stdio JSON-RPC)
  What to do:
  - Create 6 MCP server dirs in `lazykimi-plugin/mcp/`:
    1. `run-ledger/` — tools: create_run, list_runs, latest_run, read_state, append_event, update_task, create_checkpoint, recover_run (manages .lazykimi/runs/<run_id>/)
    2. `verification/` — tools: record_evidence, get_evidence, mark_complete, get_completion_status
    3. `status-dashboard/` — tools: get_status (returns boulder + active loop + evidence summary); serves dashboard.html
    4. `context-graph/` — tools: search_context (heuristic grep, NOT semantic), get_references
    5. `code-intel/` — tools: get_symbols, find_references, goto_definition (wraps ripgrep/ast-grep if available)
    6. `docs/` — tools: lookup_docs (fixed npm/PyPI registry fetches only, no redirects, no metadata URLs — SSRF-safe)
  - Each server has: `server.sh` (bash launcher), `server.py` (Python stdio JSON-RPC loop).
  - Create `lazykimi-plugin/mcp/jsonrpc.py` (shared line-protocol JSON-RPC loop).
  - Create `lazykimi-plugin/mcp/path_boundary.py` (shared path canonicalization, rejects symlinks/absolute paths).
  - Create `lazykimi-plugin/.kimi-code/mcp.json` (MCP server declarations for Kimi Code CLI `/mcp-config`).
  - All servers `required: false` (opt-in, never auto-start).
  Must NOT do: No semantic CodeGraph (context-graph is heuristic grep only). No network calls except fixed npmjs.org/pypi.org HTTPS in docs server. No edits to sources/. Each server.py ≤ 250 lines.
  References:
  - sources/LazyBuddy/lazybuddy-plugin/mcp/run-ledger/server.sh (primary pattern, 268 lines)
  - sources/LazyBuddy/lazybuddy-plugin/mcp/jsonrpc.py (shared JSON-RPC loop)
  - sources/LazyBuddy/lazybuddy-plugin/mcp/path_boundary.py (path canonicalization)
  - sources/LazyBuddy/lazybuddy-plugin/mcp/docs/server.py (SSRF-safe docs server)
  - sources/LazyTrae/lazytrae-plugin/packages/mcp/src/index.js (15 MCP tool definitions)
  - https://www.kimi.com/code/docs/kimi-code-cli/customization/mcp.html (Kimi MCP spec)
  Acceptance criteria:
  - [ ] `ls -d lazykimi-plugin/mcp/*/ | wc -l` returns 6 server dirs
  - [ ] Each server dir has `server.sh` and `server.py`
  - [ ] `cat lazykimi-plugin/.kimi-code/mcp.json` declares 6 servers with `required: false`
  - [ ] `python3 -c "import json; json.load(open('lazykimi-plugin/.kimi-code/mcp.json'))"` exits 0
  - [ ] `for f in lazykimi-plugin/mcp/*/server.py; do python3 -m py_compile "$f" || echo "FAIL: $f"; done` returns no FAIL
  - [ ] `bash -n lazykimi-plugin/mcp/*/server.sh` exits 0 for all
  QA scenarios:
  - Scenario: MCP config valid | Tool: bash | Steps: `python3 -c "import json; d=json.load(open('lazykimi-plugin/.kimi-code/mcp.json')); print(len(d.get('mcpServers',{})))"` | Expected: 6
  - Scenario: run-ledger responds to initialize | Tool: bash | Steps: `echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' | python3 lazykimi-plugin/mcp/run-ledger/server.py 2>/dev/null | head -1` | Expected: JSON response with "result"
  - Scenario: docs server rejects redirects | Tool: bash | Steps: review docs/server.py for redirect-following code | Expected: no redirect handling (rejects non-200)
  Commit: YES | Message: `feat(mcp): port 6 local MCP servers with stdio JSON-RPC, path boundaries, SSRF-safe docs` | Files: [lazykimi-plugin/mcp/**, lazykimi-plugin/.kimi-code/mcp.json]

- [x] 7. Build lazykimi CLI installer (TypeScript)
  What to do:
  - Create `lazykimi-plugin/src/index.ts` (CLI entry, shebang `#!/usr/bin/env node`, command router).
  - Create `lazykimi-plugin/src/commands/` with 6 command modules:
    1. `init.ts` — copies `.kimi-code/` (skills, agents, AGENTS.md, mcp.json, hooks) + `.lazykimi/` (state, schemas) into target project; writes hooks into `~/.kimi-code/config.toml` idempotently.
    2. `doctor.ts` — checks: .kimi-code/ present, skills count (17), agents count (11), hooks count (8), mcp.json valid, .lazykimi/ state valid, kimi binary on PATH.
    3. `verify.ts` — runs doctor + regression test suite + evidence gate check; `--must-pass` enforces completion gates.
    4. `load-check.ts` — package readiness check (skills/agents/hooks/mcp counts); reports host-ready vs missing.
    5. `uninstall.ts` — removes copied .kimi-code/ and .lazykimi/ from target; preserves modified/user-owned files; `--soft`/`--purge-state` flags.
    6. `mcp.ts` — prints MCP server declarations for `/mcp-config` import; `--json` output.
  - Create `lazykimi-plugin/src/lib/` shared utils: `paths.ts`, `json.ts`, `hooks-config.ts`, `receipt.ts`.
  - Compile to `dist/` via `npm run build` (`tsc`).
  - `lazykimi-plugin/package.json` bin: `{ "lazykimi": "dist/index.js" }`.
  Must NOT do: No edits to host config beyond idempotent `[[hooks]]` append. No `npm install -g` (user runs it). No network calls. No edits to sources/. CLI files ≤ 250 lines each.
  References:
  - sources/LazyTrae/lazytrae-plugin/packages/cli/src/index.js (CLI router pattern, 17 commands)
  - sources/LazyTrae/lazytrae-plugin/packages/cli/src/commands/init.js (init pattern)
  - sources/LazyTrae/lazytrae-plugin/packages/cli/src/commands/doctor.js (doctor pattern)
  - sources/LazyTrae/lazytrae-plugin/packages/cli/src/commands/verify.js (verify pattern)
  - sources/LazyBuddy/lazybuddy-plugin/scripts/lazybuddy-verify.sh (verification suite pattern)
  Acceptance criteria:
  - [ ] `cd lazykimi-plugin && npm run build` exits 0
  - [ ] `node lazykimi-plugin/dist/index.js --help` lists 6 commands
  - [ ] `node lazykimi-plugin/dist/index.js doctor` runs and reports status
  - [ ] `node lazykimi-plugin/dist/index.js load-check` reports 17/17 skills, 11/11 agents, 8/8 hooks
  - [ ] `for f in lazykimi-plugin/src/commands/*.ts; do wc -l "$f" | awk '$1>250{print "FAIL: "$2}'; done` returns no FAIL
  - [ ] `node lazykimi-plugin/dist/index.js init --dry-run` previews install without writing
  QA scenarios:
  - Scenario: CLI builds | Tool: bash | Steps: `cd lazykimi-plugin && npm run build` | Expected: exit 0, dist/ created
  - Scenario: CLI help works | Tool: bash | Steps: `node lazykimi-plugin/dist/index.js --help` | Expected: lists init, doctor, verify, load-check, uninstall, mcp
  - Scenario: doctor detects missing skills | Tool: bash | Steps: `cd /tmp && mkdir test-proj && cd test-proj && node /Users/Admin/Desktop/lazykimi/lazykimi-plugin/dist/index.js doctor` | Expected: reports missing .kimi-code/
  Commit: YES | Message: `feat(cli): build lazykimi CLI installer with init/doctor/verify/load-check/uninstall/mcp commands` | Files: [lazykimi-plugin/src/**, lazykimi-plugin/package.json, lazykimi-plugin/tsconfig.json]

- [x] 8. Build plugin manifest for Kimi Code CLI /plugins + marketplace.json
  What to do:
  - Create `lazykimi-plugin/.kimi-code/plugin.json` (Kimi Code CLI plugin manifest):
    - `name: lazykimi`, `version: 0.1.0`, `description`, `skills` (array of paths to 17 skill dirs), `agents` (array of paths to 11 agent .md files), `hooks` (path to hooks-config.toml), `mcpServers` (path to mcp.json), `commands` (array of slash command .md files if any).
  - Create `.kimi-code/marketplace.json` at repo root (marketplace entry: publisher `LazyKimi`, plugin source `./lazykimi-plugin`, version `0.1.0`).
  - Create `lazykimi-plugin/commands/` with 9 slash command .md files (lazy-init-deep, lazy-ulw-plan, lazy-ulw-loop, lazy-start-work, lazy-review-work, lazy-remove-ai-slops, lazy-handoff, lazy-stop-continuation, lazy-ralph-loop) — thin stubs pointing to matching skills.
  - Each command .md has YAML frontmatter: `description`.
  Must NOT do: No edits to sources/. No marketplace publishing (user does `codex plugin marketplace add` equivalent manually).
  References:
  - sources/LazyBuddy/lazybuddy-plugin/.codebuddy-plugin/plugin.json (plugin manifest pattern)
  - sources/LazyBuddy/.codebuddy-plugin/marketplace.json (marketplace entry pattern)
  - sources/lazycodex/plugins/omo/.codex-plugin/plugin.json (Codex plugin manifest pattern)
  - sources/LazyTrae/lazytrae-plugin/.trae/commands/lazy-*.md (9 command stubs)
  - https://www.kimi.com/code/docs/kimi-code-cli/customization/plugins.html (Kimi plugin manifest spec)
  Acceptance criteria:
  - [ ] `cat lazykimi-plugin/.kimi-code/plugin.json` is valid JSON with name, version, skills, agents, hooks, mcpServers
  - [ ] `python3 -c "import json; d=json.load(open('lazykimi-plugin/.kimi-code/plugin.json')); print(len(d.get('skills',[])))"` returns 17
  - [ ] `cat .kimi-code/marketplace.json` is valid JSON with publisher, plugin, version
  - [ ] `ls lazykimi-plugin/commands/lazy-*.md | wc -l` returns 9
  QA scenarios:
  - Scenario: plugin manifest valid | Tool: bash | Steps: `python3 -c "import json; d=json.load(open('lazykimi-plugin/.kimi-code/plugin.json')); assert d['name']=='lazykimi'; assert len(d['skills'])==17; print('OK')"` | Expected: OK
  - Scenario: marketplace entry valid | Tool: bash | Steps: `python3 -c "import json; d=json.load(open('.kimi-code/marketplace.json')); print(d['publisher'])"` | Expected: LazyKimi
  Commit: YES | Message: `feat(plugin): add Kimi Code CLI plugin manifest, marketplace entry, 9 slash commands` | Files: [lazykimi-plugin/.kimi-code/plugin.json, .kimi-code/marketplace.json, lazykimi-plugin/commands/**]

- [x] 9. Build receipt-owned tooling lifecycle (capability broker/detector/policy)
  What to do:
  - Create `lazykimi-plugin/tooling/capabilities.json` (declares 9 capabilities: local_search, structural_search, code_navigation, architecture_search, documentation_search, web_search, external_code_search, browser_automation, filesystem_read — each with provider, fallback chain, permissions).
  - Create `lazykimi-plugin/tooling/lazykimi_capability.py` (capability broker: detect/install/verify each capability into receipt-owned root).
  - Create `lazykimi-plugin/tooling/lazykimi_detector.py` (detect available tools: rg, sg, typescript-language-server, basedpyright, codegraph).
  - Create `lazykimi-plugin/tooling/lazykumi_policy.py` (policy: default deny, network explicit_provider_selection, timeouts, 8 typed error codes).
  - Create `lazykimi-plugin/contracts/automatic-tooling-contract.v1.json` (contract_version 1.1.0, providers, capabilities, fallback chains, permissions, timeouts, error codes) + `.sha256` sidecar.
  - Tooling installed ONLY into explicit empty caller-selected absolute tooling root; receipts written + verified on uninstall.
  Must NOT do: No host MCP config modification. No target repo lockfile modification. No global path modification. No auto-enable during init. No edits to sources/.
  References:
  - sources/LazyBuddy/lazybuddy-plugin/tooling/capabilities.json (capability declaration)
  - sources/LazyBuddy/lazybuddy-plugin/tooling/lazybuddy_capability.py (capability broker)
  - sources/LazyBuddy/lazybuddy-plugin/tooling/lazybuddy_detector.py (detector)
  - sources/LazyBuddy/lazybuddy-plugin/tooling/lazybuddy_policy.py (policy)
  - sources/LazyBuddy/lazybuddy-plugin/contracts/automatic-tooling-contract.v1.json (contract)
  - sources/LazyTrae/lazytrae-plugin/packages/cli/contracts/lazyseries-capability-readiness.v1.json (readiness contract)
  Acceptance criteria:
  - [ ] `cat lazykimi-plugin/tooling/capabilities.json` declares 9 capabilities
  - [ ] `cat lazykimi-plugin/contracts/automatic-tooling-contract.v1.json` has contract_version 1.1.0
  - [ ] `ls lazykimi-plugin/contracts/automatic-tooling-contract.v1.json.sha256` exists
  - [ ] `python3 -m py_compile lazykimi-plugin/tooling/lazykimi_capability.py` exits 0
  - [ ] `python3 -m py_compile lazykimi-plugin/tooling/lazykimi_detector.py` exits 0
  - [ ] `shasum -a 256 lazykimi-plugin/contracts/automatic-tooling-contract.v1.json | cut -d' ' -f1` matches the .sha256 sidecar
  QA scenarios:
  - Scenario: contract sha256 valid | Tool: bash | Steps: `cd lazykimi-plugin/contracts && shasum -a 256 -c automatic-tooling-contract.v1.json.sha256` | Expected: OK
  - Scenario: 9 capabilities declared | Tool: bash | Steps: `python3 -c "import json; d=json.load(open('lazykimi-plugin/tooling/capabilities.json')); print(len(d.get('capabilities',[])))"` | Expected: 9
  Commit: YES | Message: `feat(tooling): add receipt-owned tooling lifecycle with capability broker, detector, policy, contract` | Files: [lazykimi-plugin/tooling/**, lazykimi-plugin/contracts/**]

- [x] 10. Write verification suite (bash regression tests + smoke tests)
  What to do:
  - Create `lazykimi-plugin/tests/` with bash regression scripts (v0NN-<topic>-regression.sh naming):
    - `v001-package-boundary-regression.sh` — verify no files outside lazykimi-plugin/ and .lazykimi/
    - `v001-skill-count-regression.sh` — verify 17 skills present with valid frontmatter
    - `v001-agent-count-regression.sh` — verify 11 agents present
    - `v001-hook-syntax-regression.sh` — verify 8 hooks pass `bash -n`
    - `v001-mcp-config-regression.sh` — verify mcp.json valid with 6 servers
    - `v001-tooling-contract-regression.sh` — verify contract sha256 valid
    - `v001-security-regression.sh` — verify no secrets, no destructive ops in hooks
    - `v001-cli-build-regression.sh` — verify `npm run build` succeeds
    - `v001-cli-doctor-regression.sh` — verify `lazykimi doctor` runs
    - `v001-ssrf-regression.sh` — verify docs MCP server rejects redirects/non-registry URLs
  - Create `lazykimi-plugin/scripts/lazykimi-verify.sh` (master verification runner: doctor + smoke + security + mcp + hooks + regression inventory; emits bounded JSON; exit 0 only when ALL_PASS=true).
  - Create `lazykimi-plugin/scripts/lazykimi-smoke.sh` (smoke test: init in temp dir, doctor, load-check, verify).
  - Each regression script: `set -euo pipefail`, `mktemp -d`, `trap cleanup EXIT`, `fail()`/`expect_rejected()` helpers.
  Must NOT do: No network calls in tests. No edits to sources/. No tests that depend on Kimi host connection (package-level only).
  References:
  - sources/LazyBuddy/lazybuddy-plugin/tests/v0*-regression.sh (36 regression scripts, primary pattern)
  - sources/LazyBuddy/lazybuddy-plugin/scripts/lazybuddy-verify.sh (master verify runner, 344 lines)
  - sources/LazyBuddy/lazybuddy-plugin/tests/v015-security-regression.sh (security test pattern)
  - sources/LazyBuddy/lazybuddy-plugin/tests/v018-docs-ssrf-regression.sh (SSRF test pattern)
  - sources/LazyTrae/lazytrae-plugin/packages/cli/tools/test-fixture-runner.js (test runner)
  Acceptance criteria:
  - [ ] `ls lazykimi-plugin/tests/v001-*-regression.sh | wc -l` returns 10
  - [ ] `bash lazykimi-plugin/scripts/lazykimi-verify.sh` exits 0 with ALL_PASS=true
  - [ ] Each regression script passes: `for f in lazykimi-plugin/tests/v001-*.sh; do bash "$f" || echo "FAIL: $f"; done` returns no FAIL
  - [ ] `bash lazykimi-plugin/scripts/lazykimi-smoke.sh` exits 0
  QA scenarios:
  - Scenario: full verify suite passes | Tool: bash | Steps: `bash lazykimi-plugin/scripts/lazykimi-verify.sh 2>&1 | tail -5` | Expected: contains "ALL_PASS=true" or "all_pass: true"
  - Scenario: smoke test passes | Tool: bash | Steps: `bash lazykimi-plugin/scripts/lazykimi-smoke.sh` | Expected: exit 0
  - Scenario: security regression catches secrets | Tool: bash | Steps: `echo 'API_KEY=sk-xxx' > /tmp/test-secret && bash lazykimi-plugin/tests/v001-security-regression.sh` | Expected: detects and reports (test designed to catch)
  Commit: YES | Message: `test(verify): add 10 bash regression tests + master verify runner + smoke test` | Files: [lazykimi-plugin/tests/**, lazykimi-plugin/scripts/lazykimi-verify.sh, lazykimi-plugin/scripts/lazykimi-smoke.sh]

- [x] 11. Write documentation (README, AGENTS.md update, NOTICE, LICENSE, evaluation)
  What to do:
  - Create `lazykimi-plugin/README.md` (overview, install, usage, Kimi-native modes /swarm /goal /plan, skill list, agent list, hook list, MCP list, verification, safe removal).
  - Create `lazykimi-plugin/CHANGELOG.md` (v0.1.0 entry).
  - Create `lazykimi-plugin/CONTRIBUTING.md` (dev setup, test commands, commit conventions).
  - Create `lazykimi-plugin/SECURITY.md` (private vulnerability reporting).
  - Create `lazykimi-plugin/CODE_OF_CONDUCT.md` (standard).
  - Create `lazykimi-evaluation.md` at repo root (public capability-by-capability comparison with LazyBuddy/LazyTrae/lazycodex, documenting what is implemented and where it differs).
  - Update root `AGENTS.md` user-owned header (preserve LazyTrae managed block byte-for-byte) to add LazyKimi onboarding/offboard protocols analogous to the LazyTrae block.
  - Create `lazykimi-plugin/docs/` with: 00-learning-path.md, 01-mental-model.md, 02-first-task.md, 03-install-and-host-verification.md, 04-workflow-playbooks.md, 05-evidence-and-completion.md, 06-capabilities-and-approvals.md, 07-package-map.md, 08-safe-removal.md, 09-test-and-release-verification.md.
  - Create `.github/workflows/ci.yml` (macOS, Node 22, runs `npm run build` + `lazykimi-verify.sh`).
  Must NOT do: No marketing site. No emojis. No claims of Kimi host connection from package checks. No edits to managed block in AGENTS.md.
  References:
  - sources/LazyBuddy/README.md (README pattern)
  - sources/LazyBuddy/lazybuddy-evaluation.md (evaluation pattern)
  - sources/LazyBuddy/AGENTS.md (onboarding protocol pattern)
  - sources/LazyBuddy/docs/00-learning-path.md (docs pattern)
  - sources/LazyBuddy/.github/workflows/ci.yml (CI pattern)
  Acceptance criteria:
  - [ ] `ls lazykimi-plugin/README.md lazykimi-plugin/CHANGELOG.md lazykimi-plugin/CONTRIBUTING.md lazykimi-plugin/SECURITY.md` all exist
  - [ ] `ls lazykimi-evaluation.md` exists at repo root
  - [ ] `ls lazykimi-plugin/docs/*.md | wc -l` returns 10
  - [ ] `ls .github/workflows/ci.yml` exists
  - [ ] `grep -c "lazytrae:managed:start:onboarding" AGENTS.md` returns 1 (managed block intact)
  - [ ] `grep -c "lazytrae:managed:end:onboarding" AGENTS.md` returns 1 (managed block intact)
  - [ ] `grep "LazyKimi" AGENTS.md` returns matches (LazyKimi onboarding added in user-owned section)
  QA scenarios:
  - Scenario: managed block preserved | Tool: bash | Steps: `grep -c "lazytrae:managed:start:onboarding" AGENTS.md && grep -c "lazytrae:managed:end:onboarding" AGENTS.md` | Expected: 1 and 1
  - Scenario: CI workflow valid | Tool: bash | Steps: `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))"` | Expected: exit 0
  Commit: YES | Message: `docs: add README, CHANGELOG, CONTRIBUTING, SECURITY, evaluation, 10 docs pages, CI workflow` | Files: [lazykimi-plugin/README.md, lazykimi-plugin/CHANGELOG.md, lazykimi-plugin/CONTRIBUTING.md, lazykimi-plugin/SECURITY.md, lazykimi-plugin/CODE_OF_CONDUCT.md, lazykimi-evaluation.md, AGENTS.md, lazykimi-plugin/docs/**, .github/workflows/ci.yml]

- [x] 12. Final integration smoke test (kimi /init + /skill:lazy-* + /swarm + /goal)
  What to do:
  - Create `lazykimi-plugin/scripts/lazykimi-integration-test.sh` that:
    1. Creates a temp project dir
    2. Runs `node lazykimi-plugin/dist/index.js init` in temp dir
    3. Verifies `.kimi-code/skills/`, `.kimi-code/AGENTS.md`, `.kimi-code/mcp.json`, `.lazykimi/` created
    4. Runs `node lazykimi-plugin/dist/index.js doctor` — must PASS
    5. Runs `node lazykimi-plugin/dist/index.js load-check` — must report 17/17 skills, 11/11 agents, 8/8 hooks
    6. Runs `node lazykimi-plugin/dist/index.js verify --must-pass` — must exit 0
    7. Runs `kimi -p "/status"` in temp dir (if kimi available) — must show session active
    8. Runs `kimi -p "/skill:lazy-init-deep"` smoke (if kimi available) — must invoke skill
    9. Runs `kimi -p "/swarm test task"` smoke (if kimi available, with timeout 60s) — must start swarm
    10. Runs `kimi -p "/goal test objective"` smoke (if kimi available, with timeout 60s) — must start goal mode
  - If `kimi` binary not available or not logged in, skip steps 7-10 with a SKIPPED notice (do not fail).
  - Run the integration test against the actual lazykimi workspace.
  Must NOT do: No destructive ops. No edits to sources/. No network calls. Fail-open if kimi not configured (report SKIPPED, not FAIL).
  References:
  - sources/LazyBuddy/lazybuddy-plugin/scripts/lazybuddy-verify.sh (verify runner pattern)
  - https://www.kimi.com/code/docs/kimi-code-cli/reference/slash-commands.html (kimi slash commands)
  - https://platform.kimi.com/docs/guide/kimi-code-support.md (kimi CLI setup)
  Acceptance criteria:
  - [ ] `bash lazykimi-plugin/scripts/lazykimi-integration-test.sh` exits 0
  - [ ] Test output shows init/doctor/load-check/verify all PASS
  - [ ] Test output shows kimi steps either PASS or SKIPPED (not FAIL)
  - [ ] Temp dir cleaned up (no leftover .kimi-code/ in /tmp)
  QA scenarios:
  - Scenario: integration test passes | Tool: bash | Steps: `bash lazykimi-plugin/scripts/lazykimi-integration-test.sh 2>&1 | tail -20` | Expected: contains "PASS" or "SKIPPED", no "FAIL", exit 0
  - Scenario: temp dir cleaned | Tool: bash | Steps: `ls /tmp/lazykimi-integration-* 2>/dev/null | wc -l` | Expected: 0 (after test)
  Commit: YES | Message: `test(integration): add final integration smoke test with kimi /init, /skill, /swarm, /goal` | Files: [lazykimi-plugin/scripts/lazykimi-integration-test.sh]

## Final verification wave

- [x] F1. Plan compliance audit
  What to do: Re-read `.lazytrae/plans/lazykimi-recreate.md`; verify every task 1-12 has References + Acceptance + QA + Commit; verify dependency matrix is consistent (no circular deps); verify all 12 tasks completed and committed.
  Acceptance: All 12 tasks have commit evidence; no unchecked boxes; dependency matrix acyclic.

- [x] F2. Code quality review
  What to do: Run `lazykimi verify --must-pass`; review largest files for slop (no unused vars, no any, no default exports in TS); verify hook scripts ≤ 100 lines; verify CLI files ≤ 250 lines; verify no `git add -A` in any script.
  Acceptance: `lazykimi verify --must-pass` exits 0; no slop markers found.

- [x] F3. Real manual QA
  What to do: In the lazykimi workspace, run `kimi` (if available); type `/status`; type `/skill:lazy-init-deep`; verify skill loads; type `/plan on`; verify plan mode; type `/swarm test`; verify swarm starts; type `/goal test objective`; verify goal mode starts. If kimi unavailable, document as SKIPPED with evidence.
  Acceptance: kimi session active; at least one skill loads; at least one Kimi-native mode (/swarm or /goal) starts; OR documented SKIPPED with reason.

- [x] F4. Scope fidelity
  What to do: Verify all Must-have items present; verify no Must-NOT-have violations (no marketing site, no Node MCP, no Kimi Work wiring, no source edits, no managed block edits); verify NOTICE attributes all upstreams; verify MIT license.
  Acceptance: All Must-have checked; no Must-NOT-have violations; NOTICE complete; LICENSE MIT.

## Commit strategy
- Conventional Commits, atomic, one logical change per commit.
- Each task = one commit (12 task commits + 0 amend commits).
- Stage only changed files (no `git add -A` / `git add .`).
- Commit message format: `<type>(<scope>): <summary>` (e.g. `feat(skills): port 17 lazy-* skills...`).
- No `--no-verify`. No force pushes. No WIP commits on final branch.
- Final commit footer: `Plan: .lazytrae/plans/lazykimi-recreate.md` when plan exists.
