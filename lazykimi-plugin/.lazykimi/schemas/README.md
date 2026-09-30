# .lazykimi/ state schemas — v0.x → v1.3.3 mapping

This directory ships the v0.x state schemas that `lazykimi sync` and the
legacy loop bridge still read. The v1.3.3 family run-state model does not
introduce new JSON-Schema files here (the family enforces run-state shape in
`scripts/state/validate-state.sh`, mirroring LazyZCode v1.3.3); this note is
the old→new mapping.

## v1.3.3 state tree

    .lazykimi/
      plans/            family work plans (TL;DR + ## TODOs + ## Final Verification Wave)
      context/          run digests and context index
      drafts/           planner drafts
      rules/            durable run rules
      ulw-loop/         ultrawork loop state
      runs/<run_id>/
        state.json      run state (schema_version "2")
        events.jsonl    append-only event ledger
        checkpoints/    timestamped state.json/plan.md snapshots + plan-revision.md
        evidence/ verification/ review/ agent_outputs/ artifacts/ memory_updates/

`runs/`, per-run directories, and the transaction journal are created by
`scripts/state/create-run.sh` (also used by the `lazykimi-run-ledger` MCP
server's `create_run` tool); the top-level directories are bootstrapped by the
`session-start` hook.

## Old → new mapping

| v0.x artifact | v1.3.3 successor |
| --- | --- |
| `.lazykimi/state/boulder.json` (`boulder.schema.json`) | `.lazykimi/runs/<id>/state.json` (task/progress state; validated by `scripts/state/validate-state.sh`) |
| `.lazykimi/state/sessions.json` (`sessions.schema.json`) | run `session_ids` + `scripts/state/bind-session.py` |
| `.lazykimi/state/active-loop.json` (`active-loop.schema.json`) | `.lazykimi/ulw-loop/` + `scripts/loop/run-cycle.sh` |
| `.lazykimi/evidence/*.md` (`evidence.schema.json`) | `.lazykimi/runs/<id>/evidence/` |

`lazykimi sync` remains the bridge for v0.x projects; the v0.x artifacts are
deprecated (CHANGELOG v1.3.3 migration note) and have no automatic migration.
