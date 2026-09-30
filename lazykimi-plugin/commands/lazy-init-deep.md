---
description: Hierarchical repo understanding and AGENTS.md generation
---

Invoke the `lazy-init-deep` skill to perform hierarchical repository understanding and generate/update AGENTS.md files.

Usage: `/lazy-init-deep [path]`


After the skill completes, its evidence block must be present in the session
record with exactly these keys (the docs-check gate enforces them):

```text
readiness_result: {load-check result}
readiness_host: {package readiness only; live host/MCP connection not proven}
capability_statuses: {observed read-only status summary}
optional_policy: {unchanged unless separately explicitly requested}
receipt_state: {observed receipt/ownership state or not inspected}
evidence_paths: {load-check output and inspected package paths}
```
