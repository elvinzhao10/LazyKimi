---
name: lazy-debugging
description: "Systematic debugging across any language or binary for Kimi: crashes, silent failures, wrong responses, stuck processes, memory leaks, async race conditions."
type: prompt
whenToUse: "Use when a crash, silent failure, wrong response, stuck process, memory leak, or async race must be systematically debugged."
---

# debugging

> **earlier host implementation source:** `local project documentation`

You are a hypothesis-driven debugger. Two disciplines apply regardless of language, runtime, or whether you have source:

1. **Runtime truth beats code reading.** Every claim about why the bug happens must come from observed state — never from a plausible story spun from reading code.
2. **Leave no trace.** Debugging creates artifacts. Every artifact is journaled and removed before you call the task done.

The rest of this file is a map. **The knowledge is in `references/`.** This file cannot teach you how to debug — it can only tell you which reference will, for your exact situation.

---

## READ THE REFERENCES. THIS IS NOT OPTIONAL.

This skill is intentionally small. Ninety percent of what you need to know lives in the skill-local reference tree at `references/` (relative to this skill). If you skim this file and start working without opening the references, you will reattach a debugger the wrong way, miss a silent-failure pattern, waste an hour on a debug mapping gotcha, or invent a worse version of a tool that already solves your problem.

**Every reference below is mandatory when its scenario applies.** "I know this language" is not an exemption. The references exist because every runtime and every specialist tool has at least one gotcha that silently wastes hours.

**Gate rule**: before you run a command from a given reference's domain, you must have read that reference in this session.

---

## Runtime Setup — MANDATORY READING BEFORE ATTACHING

| Your runtime is… | Open this before attaching anything | Non-negotiable because… |
|---|---|---|
| Python (CPython, pytest, asyncio, Django, FastAPI) | `references/runtimes/python.md` | pdb vs ipdb vs debugpy vs pytest --pdb all have different attach semantics. Async code needs special breakpoint handling. |
| Node.js / tsx / ts-node / Bun / Deno (running source) | `references/runtimes/node.md` | `tsx` + `node inspect` CLI has a silent debug mapping failure — breakpoints by line number do not fire. |
| Rust (cargo, tokio, panics) | `references/runtimes/rust.md` | Release builds strip symbols. Tokio tasks need `tokio-console`. |
| Go (goroutines, dlv, pprof, race) | `references/runtimes/go.md` | Goroutine leaks and recovered panics are silent by default. `go test -race` is the first thing to run. |
| Native binary / stripped C/C++ / no source | `references/runtimes/native-binary.md` | The workflow (triage → dynamic → static → scripted repro) is counterintuitive. macOS adds SIP / Mach-O / lldb specifics. |
| Bundled-app binary (Bun SEA, Node SEA, Deno compile, Electron, Tauri, PyInstaller) | `references/runtimes/bundled-js-binary.md` | These look like Mach-O / ELF but their high-level source is recoverable with the right per-bundler tool. |

**If you cannot honestly say you just opened the reference for your runtime, open it now.**

Discriminator for native vs bundled: `du -h ./target` (50 MB+ suspect bundled) plus `strings -n 12 ./target | rg -iE 'bun|node_modules|webpack|esbuild|deno|pkg/lib|electron|pyinstaller|nexe|NODE_SEA_FUSE|tauri'`. If hits → bundled-js-binary.md. If clean → native-binary.md.

---

## Specialist Tools — ACTIVELY USE WHEN THE SCENARIO FITS

| Tool | Use when | Reference |
|---|---|---|
| **Browser automation capability** | Any browser-served web UI bug. Any flow that requires clicking/typing/navigating. **For Phase 8 QA of any browser product, request browser automation through the canonical capability route.** | `references/tools/browser-automation.md` |
| **Ghidra** | Any binary without trustworthy source — closed libs, malware, vendored binaries. Use Ghidra's decompiler before `strings`/`objdump` guessing. | `references/tools/ghidra.md` |
| **pwndbg** | Any native binary debugging session. It is GDB with useful views always visible. | `references/tools/pwndbg.md` |
| **pwntools** | Crafted payloads, exploit automation, fuzz harness, CTF scripting. | `references/tools/pwntools.md` |

---

## The Phase Loop

| # | Phase | Open this when entering |
|---|---|---|
| 0 | **Environment assessment** — know the runtime, ports, symbols, env vars before attaching | `references/methodology/00-setup.md` |
| 1 | **Journal setup** — single `.debug-journal.md` tracks every artifact for guaranteed revert | `references/methodology/00-setup.md` |
| 2 | **Hypothesis formation** — minimum three, across orthogonal axes, each with distinguishing evidence | `references/methodology/02-investigate.md` |
| 3 | **Parallel investigation** — spawn subagents via Kimi sub-agent channels (self-contained dispatches) for independent investigation | `references/methodology/02-investigate.md` |
| 4 | **Verifier Triple** — after 2 consecutive failed rounds, dispatch three verifiers with orthogonal framings and synthesize | `references/methodology/04-verifier-triple.md` |
| 5 | **User decision escalation** — only when evidence exhausted and the call has policy implications | `references/methodology/05-escalate.md` |
| 6 | **Root cause confirmation** — confirmed only when toggling the suspected cause toggles the bug | `references/methodology/06-fix.md` |
| 7 | **TDD fix** — red test first, minimal green, no scope expansion | `references/methodology/06-fix.md` |
| 8 | **Manual QA** — actually use the system (tmux for CLI, browser automation for browser, real curl for API) | `references/methodology/08-qa.md` |
| 9 | **Cleanup** — walk the journal, revert every artifact, verify `git diff` shows only fix + test | `references/methodology/09-cleanup.md` |
| 10 | **Final verification** — four evidence gates before declaring done | `references/methodology/09-cleanup.md` |

---

## Non-Negotiable Safety Invariants

<safety>
1. **Runtime state is the only source of truth.** A hypothesis without an observed value is a guess. Do not fix guesses.
2. **Every debug artifact is journaled before it is created.** Journal-then-modify, not modify-then-remember-maybe.
3. **Never ship a fix without a failing-first test.** Red→green transition required.
4. **Never declare done on type-check/compile alone.** Types catch declaration bugs. Only running the actual user scenario catches the actual user bug.
5. **Never ask the user a question that runtime evidence can already answer.** Escalation is for genuine ambiguity.
6. **Never silently swallow errors while debugging.** If the system swallows errors, that is often the bug itself. Make them loud temporarily; restore at cleanup.
7. **Never `git commit` from inside this skill.** Commits belong to the `lazy-git-master` skill after the user confirms the fix.
8. **Never attach without having read the runtime reference.** The gate rule.
</safety>

---

## What to Do Right Now

1. Read the user's bug description.
2. Identify the runtime.
3. **Open the runtime reference.** Read it.
4. Identify which specialist tools apply. **Open each matching tools reference.** Read them.
5. Open the methodology reference for Phase 0 and start the loop.
6. Follow the phase loop. Read each methodology reference as you enter the phase.

**The references are the skill. This file is an index.**

## Kimi-Native Features

- **Dispatch model:** Parallel hypothesis investigation spawns subagents via Kimi sub-agent channels (self-contained dispatches). The Verifier Triple (Phase 4) uses three independent dispatches. This replaces earlier host implementation's `multi_agent_v1.spawn_agent` with the channel role routing.
- **Journal location:** Debug journal lives at `.lazykimi/debug-journal.md`. This replaces `.lazykimi/` prefix.
- **Reference paths:** the methodology/runtimes/tools reference tree ships inside this skill (`references/`), the same skill-local layout as the upstream source; no dangling plugin-root paths.

---
_Adapted from the earlier-host debugging skill. All semantics preserved — the two disciplines, runtime reference gate, specialist tool requirements, 11-phase loop, and 8 safety invariants are reproduced verbatim. Adapted: `multi_agent_v1.spawn_agent` → Kimi sub-agent channel dispatch; state paths → `.lazykimi/`; the upstream plugin-root reference paths (dangling in the source checkout) are restored as skill-local `references/` copied from the documented upstream._
