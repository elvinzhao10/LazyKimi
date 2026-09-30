# Hook policy reference

Status: v1.3.3. Kimi Code CLI exposes a 16-event hook surface. LazyKimi ships
one consumer script per event under `hooks/` and ports the lazyzcode v1.3.3
hardened hook semantics onto both Kimi registration routes. This page is the
Kimi-native policy reference; there is no lazyzcode counterpart because the
event sets differ.

## The 16 events and their consumers

| Event | Script | Registration | Class |
| --- | --- | --- | --- |
| `SessionStart` | `session-start.sh` | critical (TOML) + manifest | Bootstrap `.lazykimi/` state tree, run load-check, report `SESSIONSTART_READINESS=full\|degraded`; strict-JSON `additionalContext` on stdout, diagnostics on stderr, always exit 0. |
| `UserPromptSubmit` | `user-prompt-submit.sh` | critical (TOML) + manifest | Adaptive intake: surface run state and context-pressure signals on every prompt. |
| `PreToolUse` (matcher `Bash`) | `pre-tool-use.sh` | critical (TOML) + manifest | The v1.3.3 hardening gate (see below). Deny = exit 2 with a stderr reason. |
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

The authoritative event-to-consumer table is the contract
`contracts/kimi-hook-consumers.v1.json`; this page must not drift from it.

## The critical-8 TOML split

Kimi Code CLI has two registration routes and they are intentionally unequal:

1. **Plugin manifest route** (`kimi.plugin.json`, inline `hooks`): declares all
   16 events with `./hooks/<script>.sh` paths. Active when the host loads the
   plugin manifest.
2. **Project TOML route** (`lazykimi init` + `scripts/install-hooks.sh`):
   appends exactly the **critical 8** `[[hooks]]` entries to
   `~/.kimi-code/config.toml` — `SessionStart`, `UserPromptSubmit`,
   `PreToolUse` (matcher `Bash`), `PostToolUse`, `PostToolUseFailure`, `Stop`,
   `PermissionRequest`, `PermissionResult`.

The critical 8 are the events that carry v1.3.3 gating semantics (state
bootstrap, prompt intake, the pre-tool hardening gate, ledger appends, the
stop gate, and the permission ledger). The remaining 8 advisory events are
only declared through the plugin manifest; the TOML route deliberately does
not install them. The installer is idempotent, never overwrites existing
entries, and never touches provider/model/permission configuration.

## The PreToolUse hardening gate (v1.3.3 semantics)

`pre-tool-use.sh` ports the lazyzcode v1.3.3 policy set:

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
- Defense in depth stays: read-only roles carry `disallowed: [Edit, Write]`
  agent frontmatter (a denylist encoding the intended allowlist), and the
  Stop gate re-checks scope at completion.
- Deny semantics (exit 2) are verified for the TOML route at the protocol
  level; whether the plugin-manifest route enforces exit 2 identically is a
  host-verification item.
- Every claim on this page that depends on a live host session (hook firing,
  deny enforcement, payload shape) is `documented-untested` until the host
  observation pass records an observation receipt.

Cross-reference: [host-routes.md](host-routes.md) for how each registration
route is installed, and [state-model.md](state-model.md) for the run-ledger
locations the hook consumers write to.
