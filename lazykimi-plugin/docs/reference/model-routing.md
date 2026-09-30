# Model routing

Status: v1.3.3, ported from the lazyzcode family reference and adapted to the
`kimi` host entry. LazyKimi describes task intent. Kimi chooses and bills the
model. A package alias or recommendation is not proof of a concrete backing
model, account availability, host loading, or a particular rate.

LazyKimi's declared agents pin `model: kimi-k3` and an `effort` budget in
their Kimi frontmatter, and the routing policy's `kimi` host entry maps every
profile tier (economy/balanced/strong) to the `kimi-k3` alias with
`agent-frontmatter` dispatch. The observed Kimi effort scale on `kimi-k3` is
`low|high|max` with `default_effort = "high"` (T21 host receipt 2026-09-30:
`[models."kimi-code/k3"] support_efforts` in `~/.kimi-code/config.toml`, real
CLI v0.27.0), so agent effort values are restricted to that scale: family
`low` maps to `low`, the family middle intent to `high` (Kimi has no middle
tier), and family `max` to `max`. The policy entry itself still carries no
per-tier `effort` mappings: frontmatter effort remains package metadata, and
whether a live session honors it is a separate host observation. Before
dispatch, propose delegation and any model switches in the plan, remind the
user that switching can change quality, latency, and cost, and record the
decision. If the plan is silent, keep the same model across all subagents and
retries.

| Task class | Optional plan choice | Use |
| --- | --- | --- |
| Mechanical work | economy tier, `low` effort | Repository indexing, bounded search, and routine memory maintenance. |
| Default work | `inherit` | All roles keep the current parent-session model unless the plan explicitly enables a switch. |
| Quality-focused work | strong tier, `max` effort | Planning, review, security review, final gates, and verification. |

The strong tier is a provisional choice for those roles. It does not claim a
specific model or a quality guarantee. Kimi exposes model and effort selection
through its own agent frontmatter and UI; package metadata alone does not
prove the host applied a tier. The routing policy declares the `kimi` profiles
as documented-host-alias bindings; they are advisory until the current session
visibly honors them.

## Produce a recommendation

The shared helper is a read-only recommendation surface. It does not query a
host, select a model, write settings, or contact a provider:

```bash
node contracts/model-routing.js --host kimi --task mechanical --list
node contracts/model-routing.js --host kimi --task architecture --risk high
node contracts/model-routing.js --host kimi --task review --failed-attempts 1
node contracts/model-routing.js --host kimi --task mechanical --allow-switch
```

Supported task classes are `mechanical`, `implementation`, `architecture`,
`review`, `security`, and `visual`. Always pass `--host kimi`; the policy also
carries the other LazySeries family host ids for cross-repo parity, but
LazyKimi's own surface is `kimi`. Without a catalog, the recommendation is a
tier with `chosenModel: null`. With a caller catalog it may recommend a
qualified `chosenModel`, but it never binds an alias or catalog model behind
the user's back: a recommendation remains **unobserved** until the current
host visibly offers and accepts a selection. The orchestrator consults it
once before a task's first dispatch, records the result in the handoff, and
reuses it for retries. Without `--allow-switch`, `chosenModel` is null and
dispatch is `inherit`. Re-evaluate only when the plan's switching decision,
task class, risk, failed attempts, or explicit user choice changes.

`--failed-attempts` means completed task-acceptance failures. It does not
count an expected test-first red state, a missing host catalog, or an
unavailable host. An explicit user model choice takes precedence when it
meets the required tier, declared availability, and required capabilities.
The helper refuses an underqualified choice; it does not silently substitute
another model. `inherit` roles deliberately retain the accepted session
choice; do not invent a model argument for a dispatch.

## Discover the current selection

Kimi surfaces the current model and per-agent `model`/`effort` choices in its
own UI and agent definitions. Snapshots published by the host document client
version, account availability, service updates, parameters, and displayed
rates, and can differ from the current session. Check the host before acting
on a recommendation.

Per-agent overrides are user-owned: set `model` or `effort` in the agent
definition or the host's agent settings. LazyKimi never writes host settings.

## Custom models

Use a custom model only after the user has configured and validated it
through Kimi's supported UI. A validated custom model can then remain the
parent-session selection for `inherit` roles.

After the plan enables switching, a documented host alias can be passed as
`--model` with `--allow-switch` and no catalog. An explicit direct or custom
ID requires safe-catalog input. The file is non-secret availability input and
does not query Kimi:

```json
{
  "schema_version": 1,
  "host": "kimi",
  "models": [
    {
      "id": "custom:example/review-model-v1",
      "origin": "custom",
      "tier": "strong",
      "available": true,
      "capabilities": ["tools", "code"],
      "costRank": 2
    }
  ]
}
```

Use it only with the exact current visible ID:

```bash
node contracts/model-routing.js --host kimi --task review \
  --allow-switch --catalog safe.json --model "custom:example/review-model-v1"
```

`costRank` is a declared relative rank, never a price or provider bill.
Supplying an entry does not register it with Kimi or prove it is visible in
the current task/session. If no current visible catalog entry is supplied,
the user-selected session model remains authoritative. The shared catalog
schema also permits an optional `subagentSupported` boolean; it is accepted
as caller-declared metadata for every host, but the current routing policy
uses it only for Trae.

Custom-provider costs are billed by the provider and cannot be compared
safely with host-billed rates.

## Native testing boundary

Run package tests for frontmatter and helper behavior locally
(`tests/agent-frontmatter-policy.test.js`, `tests/model-routing.test.js`).
Listing a real account catalog, selecting a tier/direct/custom model, and
observing a per-agent override are host- and user-owned checks. A given
checkout may have no Kimi account catalog evidence, so it makes no
availability claim. The Kimi effort scale is now observed at the config
layer (`low|high|max` on `kimi-k3`, T21 receipt 2026-09-30), but per-agent
effort application inside a live session remains host-owned and
`documented-untested`; the `kimi` policy entry therefore stays effort-free.
