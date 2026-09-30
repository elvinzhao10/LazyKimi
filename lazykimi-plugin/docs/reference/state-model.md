# State model reference

Status: v1.3.3 port, intermediate state. This page documents the run-state
model mapping while the state/orchestration wave lands; it is extended by the
documentation wave into the full state-artifact reference.

## Two schema sets

LazyKimi v1.3.3 carries two schema sets during the port:

1. **Project-route payload schemas** — shipped at
   `.lazykimi/schemas/{boulder,evidence,sessions,active-loop}.schema.json`
   (v0.x state model, Draft 2020-12). `lazykimi init` copies these into the
   target project.
2. **Family run-state schemas** — the v1.3.3 family model
   (`schemas/active-run.schema.json` at the plugin root, plus the
   run-state/events schemas added by the state wave).

## Old-to-new mapping

| v0.x artifact | v1.3.3 family artifact | Notes |
| --- | --- | --- |
| `.lazykimi/state/boulder.json` (boulder.schema.json) | `.lazykimi/runs/<run_id>/state.json` + `schemas/active-run.schema.json` | The boulder's "active work + task index" becomes per-run state; the plan checkbox is the source of truth for task completion. |
| `.lazykimi/state/sessions.json` (sessions.schema.json) | `.lazykimi/runs/<run_id>/events.jsonl` | The append-only event ledger replaces the session log; `lazykimi sync` remains the bridge during migration. |
| `.lazykimi/state/active-loop.json` (active-loop.schema.json) | `.lazykimi/ulw-loop/` loop state | Loop tiers and continuation state move under the ulw-loop tree. |
| `.lazykimi/evidence/*.md` (+ evidence.schema.json) | `.lazykimi/runs/<run_id>/evidence/` + verification store | Run-scoped, revision-bound evidence; the adversarial gate file is `adversarial-qa.md`. |

The v0.x schemas are not auto-migrated; the manual mapping above applies and
the deprecation is noted in CHANGELOG. `lazykimi sync` bridges user-managed
blocks forward.
