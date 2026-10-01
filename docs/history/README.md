# History — v0.x planning artifacts (superseded)

This directory preserves the unique planning artifacts from LazyKimi's v0.x
development. They are **historical records only**: they describe the original
LazyBuddy/LazyTrae-derived design process and are superseded by the v1.3.4
family plan format (TL;DR + `## TODOs` + `## Final Verification Wave`, as in
`.lazyzcode/plans/lazykimi-v1.3.4-full-port.md`).

| File | Origin | What it is |
| --- | --- | --- |
| `lazykimi-recreate.md` | `.lazytrae/plans/` (LazyTrae planning infra, removed in v1.3.4) | The original v0.1 plan that recreated the harness for Kimi. |
| `lazykimi-spec-compliance.md` | `.lazytrae/plans/` | The v0.2.0 Kimi-spec-compliance plan (manifest move, 16 inline hooks, placeholder rewrite). |
| `lazykimi-bugfix-and-cli-hardening.md` | root `.lazykimi/plans/` (v0.x runtime state, removed in v1.3.4) | The bug-fix/CLI-hardening round between v0.2.0 and v0.3.0. |
| `lazykimi-v0.3.0-capability-hardening.md` | root `.lazykimi/plans/` | The unreleased v0.3.0 plan (see the reconciled CHANGELOG entry). |

The v0.x per-task run evidence (`.lazykimi/evidence/*.md`) was tracked in git
and remains retrievable from the pre-v1.3.4 history (through commit
`69450fd`); it was not copied here because it is run output, not planning
provenance. The canonical LazyTrae content lives in
`/Users/Admin/Desktop/lazyseries/LazyTrae` upstream (the `.trae/`/
`.lazytrae/` copies that existed in this repo root during v0.x development
were untracked LazyTrae-managed infrastructure and were deleted).
