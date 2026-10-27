# Hook policy reference

Status: v1.4.0 (T8 rescan 2026-10-18). Kimi Code CLI documents a 20-event hook
surface ([hooks reference](https://www.kimi.com/code/docs/en/kimi-code-cli/customization/hooks.html),
re-verified 2026-10-18; the four events beyond the original 16 shipped in CLI
0.32.0, 2026-08-04). LazyKimi ships one consumer script per **adopted** event
under `hooks/` — 19 events — and ports the lazyzcode v1.3.4 hardened hook
semantics onto both Kimi registration routes. This page is the Kimi-native
policy reference; there is no lazyzcode counterpart because the event sets
differ.

`SessionHeartbeat` is documented but deliberately **not adopted**: it fires
every 60 seconds while a session is alive, so a consumer would add per-minute
process spawns and ledger noise with no gating consumer to justify them
(classified stable-documented, deferred; revisit when a staleness consumer
exists). Adopted events remain `documented-untested` until a live host
observation receipt lands.

## The 19 adopted events and their consumers

| Event | Script | Registration | Class |
| --- | --- | --- | --- |
| `SessionStart` | `session-start.sh` | critical (TOML) + manifest | Bootstrap `.lazykimi/` state tree, run load-check, report `SESSIONSTART_READINESS=full\|degraded`; strict-JSON `additionalContext` on stdout, diagnostics on stderr, always exit 0. |
| `UserPromptSubmit` | `user-prompt-submit.sh` | critical (TOML) + manifest | Adaptive intake: surface run state and context-pressure signals on every prompt. |
| `PreToolUse` (matcher `Write|Edit|Bash`) | `pre-tool-use.sh` | critical (TOML) + manifest | The v1.3.4 hardening gate (see below). Deny = exit 2 with a stderr reason. |
| `PostToolUse` | `post-tool-use.sh` | critical (TOML) + manifest | Append a redacted tool-use summary event to `runs/<id>/events.jsonl`. |
| `PostToolUseFailure` | `post-tool-use-failure.sh` | critical (TOML) + manifest | Append a failure event to the run ledger. |
| `Stop` | `stop-gate.sh` | critical (TOML) + manifest | Unchecked-plan-task detection against `.lazykimi/plans/` and run state; advisory `additionalContext` reminder. |
| `PermissionRequest` | `permission-request.sh` | critical (TOML) + manifest | Record the approval request as a ledger event. |
| `PermissionResult` | `permission-result.sh` | critical (TOML) + manifest | Record the approval decision as a ledger event. |
| `SubagentStart` | `subagent-start.sh` | manifest only (advisory) | Dispatch ledger event. |
| `SubagentStop` | `subagent-stop.sh` | manifest only (advisory) | Executor-evidence gate reminder (append evidence-reminder context; the authoritative gate stays in the review skills). |
| `PreCompact` | `pre-compact.sh` | manifest only (advisory) | Context-recovery checkpoint into `runs/<id>/checkpoints/`. |
| `PostCompact` | `post-compact.sh` | manifest only (advisory) | Context-recovery checkpoint after compaction. |
| `SessionEnd` | `session-end.sh` | manifest only (advisory) | Ledger-close event. |
| `StopFailure` | `stop-failure.sh` | manifest only (advisory) | Stop-failure ledger event. |
| `Interrupt` | `interrupt.sh` | manifest only (advisory) | Interrupt ledger event. |
| `Notification` | `notification.sh` | manifest only (advisory) | No-op logger. |
| `TurnStarted` | `turn-started.sh` | manifest only (advisory) | Turn ledger event (structural `turn_id`/`origin_kind` only; the prompt text is never ledgered). Adopted 2026-10-18 from the CLI hooks reference (0.32.0, 2026-08-04). |
| `UserPromptQueued` | `user-prompt-queued.sh` | manifest only (advisory) | Queue ledger event (structural `prompt_id`/`queue_length` only; the queued prompt text is never ledgered). Adopted 2026-10-18 from the CLI hooks reference (0.32.0, 2026-08-04). |
| `TaskStarted` | `task-started.sh` | manifest only (advisory) | Task ledger event (structural `task_id`/`detached` only; the description is never ledgered). Adopted 2026-10-18 from the CLI hooks reference (0.32.0, 2026-08-04). |

The authoritative event-to-consumer table is the contract
`contracts/kimi-hook-consumers.v1.json`; this page must not drift from it.

## The critical-8 TOML split

Kimi Code CLI has two registration routes and they are intentionally unequal:

1. **Plugin manifest route** (`kimi.plugin.json`, inline `hooks`): declares all
   19 adopted events with `./hooks/<script>.sh` paths. Active when the host
   loads the plugin manifest.
2. **Project TOML route** (`lazykimi init` + `scripts/install-hooks.sh`):
   appends exactly the **critical 8** `[[hooks]]` entries to
   `~/.kimi-code/config.toml` — `SessionStart`, `UserPromptSubmit`,
   `PreToolUse` (matcher `Write|Edit|Bash`), `PostToolUse`, `PostToolUseFailure`, `Stop`,
   `PermissionRequest`, `PermissionResult`.

The critical 8 are the events that carry v1.3.4 gating semantics (state
bootstrap, prompt intake, the pre-tool hardening gate, ledger appends, the
stop gate, and the permission ledger). The remaining 11 advisory events are
only declared through the plugin manifest; the TOML route deliberately does
not install them. The installer is idempotent, never overwrites existing
entries, and never touches provider/model/permission configuration.

## The PreToolUse hardening gate (v1.3.4 semantics)

`pre-tool-use.sh` ports the lazyzcode v1.3.4 policy set:

- **1 MiB input cap** — payloads above the cap are rejected as oversized
  input rather than truncated or parsed partially.
- **Malformed-payload rejection** — structurally invalid input is rejected
  without policy evaluation.
- **Identity normalization and wrapper resolution** — agent identity in the
  payload is normalized defensively, and `bash <script>` wrappers and
  symlinks are resolved to the underlying command before policy checks
  (mirrors the `execution-context-security` contract and
  `execution-context-wrappers` tests).
- **Role-scoped writes** — when the host supplies agent identity, writes are
  scoped to the dispatched paths: implementer roles write only their
  dispatched files, the orchestrator only `.lazykimi/`, verifiers only
  verification reports.
- **Secret-like path patterns** — structured and generic secret paths are
  denied.
- **Destructive operations** — destructive recursive deletes, destructive git
  operations (`push --force`, `reset --hard` against shared refs), and
  external publish commands are denied.
- **Deny protocol** — a deny is exit 2 with the reason on stderr. Internal
  errors fail open (exit 0) so a broken policy script cannot wedge the host;
  only positive violations deny.

Hooks parse both key styles (`tool_name` and `toolName`) because the exact
Kimi payload shape is only partially verified; see the host-verification
items below.

## Matcher verification status (honest boundaries)

- The `PreToolUse` matcher matches **`Write|Edit|Bash`**. The Write/Edit tool
  names were confirmed from a real host session transcript (T21 item 5
  receipt in `lazykimi-evaluation.md`: `tools.set_active_tools` and
  `llm.tools_snapshot` list exactly `Write` and `Edit`), so the plan's T9
  contingency ("extend once verified") has been applied on both registration
  routes — the inline manifest entry and the TOML critical-8. Live *firing*
  of the hook on Write/Edit events still requires an auth'd session and
  remains `documented-untested`.
- Read-only agents use supported native `tools`, `disallowedTools`, and
  `subagents` restrictions; ignored `disallowed` frontmatter is not enforcement.
  The Stop gate also re-checks scope at completion. See
  [native-adapter.md](native-adapter.md) for the current agent contract.
- Deny semantics (exit 2) are verified for the TOML route at the protocol
  level; whether the plugin-manifest route enforces exit 2 identically is a
  host-verification item.
- Every claim on this page that depends on a live host session (hook firing,
  deny enforcement, payload shape) is `documented-untested` until the host
  observation pass records an observation receipt.
- 2026-10-18 rescan notes: the host hooks reference documents
  snake_case event-specific payload fields for the adopted events
  (`turn_id`/`origin_kind`, `prompt_id`/`queue_length`,
  `task_id`/`detached`), states only `PreToolUse`, `Stop`, and
  `UserPromptSubmit` returns affect the main flow (everything else,
  including all three adopted events, is observation-only), and CLI 2.2.0
  (2026-10-14) fixed UserPromptSubmit hook text-injection issues on the host
  side. LazyKimi's strict-JSON `additionalContext` contract is unchanged.

Cross-reference: [host-routes.md](host-routes.md) for how each registration
route is installed, and [state-model.md](state-model.md) for the run-ledger
locations the hook consumers write to.
