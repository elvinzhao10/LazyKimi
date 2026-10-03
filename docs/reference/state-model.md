# State model reference

Status: v1.3.5. This page is the state-artifact reference for the `.lazykimi/`
run-state model: what each artifact is, who writes it, and how the v0.x state
maps onto the family model.


## Two schema sets

LazyKimi v1.3.5 carries two schema sets during the port:

1. **Project-route payload schemas** — shipped at
   `.lazykimi/schemas/{boulder,evidence,sessions,active-loop}.schema.json`
   (v0.x state model, Draft 2020-12). `lazykimi init` copies these into the
   target project.
2. **Family run-state schemas** — the v1.3.4 family model
   (`schemas/active-run.schema.json` at the plugin root, plus the
   run-state/events schemas added by the state wave).

## Old-to-new mapping

| v0.x artifact | v1.3.4 family artifact | Notes |
| --- | --- | --- |
| `.lazykimi/state/boulder.json` (boulder.schema.json) | `.lazykimi/runs/<run_id>/state.json` + `schemas/active-run.schema.json` | The boulder's "active work + task index" becomes per-run state; the plan checkbox is the source of truth for task completion. |
| `.lazykimi/state/sessions.json` (sessions.schema.json) | `.lazykimi/runs/<run_id>/events.jsonl` | The append-only event ledger replaces the session log; `lazykimi sync` remains the bridge during migration. |
| `.lazykimi/state/active-loop.json` (active-loop.schema.json) | `.lazykimi/ulw-loop/` loop state | Loop tiers and continuation state move under the ulw-loop tree. |
| `.lazykimi/evidence/*.md` (+ evidence.schema.json) | `.lazykimi/runs/<run_id>/evidence/` + verification store | Run-scoped, revision-bound evidence; the adversarial gate file is `adversarial-qa.md`. |

The v0.x schemas are not auto-migrated; the manual mapping above applies and
the deprecation is noted in CHANGELOG. `lazykimi sync` bridges user-managed
blocks forward.

## The v1.3.4 run-state tree

The session-start hook and `scripts/state/create-run.sh` bootstrap the same
tree; MCP servers, hooks, and the CLI share the scripts under
`scripts/state/`:

```
.lazykimi/
├── plans/                 # family plan files (TL;DR + ## TODOs + ## Final Verification Wave)
├── context/               # knowledge base written by init-deep / context roles
├── drafts/                # planner's durable drafts
├── rules/                 # project-local rule supplements
├── ulw-loop/              # durable loop state (tiers, continuation)
├── config.json            # project route config (e.g. "mcpMode")
└── runs/<run_id>/
    ├── state.json         # run state (schemas/active-run.schema.json)
    ├── events.jsonl       # append-only event ledger (hooks, MCP, CLI append)
    ├── checkpoints/       # compact-recovery and explicit checkpoints
    ├── evidence/          # run-scoped, revision-bound evidence
    ├── verification/      # criterion/gate results (verification server store)
    ├── review/            # review-panel output
    ├── agent_outputs/     # per-dispatch subagent outputs
    ├── artifacts/         # manual-QA and adversarial-QA artifacts
    └── memory_updates/    # librarian findings destined for durable memory
```

| Artifact | Writer | Reader |
| --- | --- | --- |
| `runs/<id>/state.json` | state scripts (`create-run.sh`, `update-task.sh`) | orchestrator, `lazy-status`, dashboard |
| `runs/<id>/events.jsonl` | hook consumers, state scripts, MCP run-ledger | verifier, telemetry |
| `runs/<id>/checkpoints/` | `checkpoint.sh`, pre/post-compact hooks | recovery (`recover-run.sh`) |
| `runs/<id>/verification/` | verification server, verifier role | review panel, completion-status CLI |
| `plans/<slug>.md` | planner (plan channel) | every role; checkbox state is the task source of truth |

## Loop and failure semantics

`scripts/loop/` implements the failure-to-repair loop over that tree:
`next-task.sh` selects the first unchecked `T<n>` respecting the plan's
dependency/wave structure; `classify-failure.sh` emits the family failure
classes; `create-repair-task.sh` appends a repair task (also exposed as the
verification server tool of the same name); `run-cycle.sh` drives one
orchestration cycle; `finalize-run.sh` produces the terminal report.
`sync-plan-state.sh` and `update-plan-checkbox.sh` keep plan checkboxes and
run state aligned — the checkbox is authoritative for completion.

Cross-reference: [hook-policy.md](hook-policy.md) for which hook consumers
append to `events.jsonl`, and [host-routes.md](host-routes.md) for which
routes install the hook consumers that write here.
