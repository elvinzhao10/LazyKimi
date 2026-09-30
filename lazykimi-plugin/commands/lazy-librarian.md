---
description: "Maintain memory and documentation. Keep current package documentation and project memory accurate after accepted component changes."
argument-hint: "[--scope]"
---

Use the `lazy-librarian` skill for this request.

$ARGUMENTS

# /lazy-librarian

Memory and documentation maintenance agent. Updates current package documentation and project memory after every accepted change. Ensures documentation stays consistent and authoritative.

## Kimi mapping

LazyKimi's memory/doc maintenance complements **AGENTS.md** (the project-memory file Kimi Code CLI loads from `.kimi-code/AGENTS.md` on the project route). The `lazy-librarian` keeps the curated `kimi.md` project memory and package docs authoritative on top of the project `AGENTS.md`.

## Usage

```
/lazy-librarian [--scope=all|index|parity|gaps|memory]
```

## Inputs

- Current state of all docs in `docs/`
- Current skill, command, agent, and hook registrations in plugin manifest
- Latest implementation evidence and package checks
- Version changelog for the current release

## Outputs

- Updated package documentation and retained root guidance (`README.md`, `AGENTS.md`, and `kimi.md`) with relevant changes
- Updated project memory (`kimi.md`) if structural changes warrant

## Success Criteria

1. Current documentation matches actual implementation state
2. Handoff material identifies the authoritative package sources
3. Cross-references between tracked docs are consistent

## Constitution

This command is governed by its package-local skill contract below.

Do not claim completion without verification.

## Skill

See `../.kimi-code/skills/lazy-librarian/SKILL.md` for the full maintenance protocol, doc consistency checks, and parity verification procedure.
