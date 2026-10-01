# Native adapter and lifecycle boundaries

Kimi's [agent documentation](https://www.kimi.com/code/docs/kimi-code-cli/customization/agents.html)
defines `tools`, `disallowedTools`, and `subagents` as native restrictions.
LazyKimi ships those fields, and rejects unsupported header keys rather than
presenting ignored model/effort/maxTurns/isolation/disallowed fields as
enforcement. Read-only workers cannot use Bash or mutation/delegation tools.
Verifier Bash/Write access supports running tests and writing evidence; its
shell permission boundary remains enforced separately by hooks.

The [plugin documentation](https://www.kimi.com/code/docs/kimi-code-cli/customization/plugins.html)
binds stdio launch cwd to the managed plugin root. It does not supply the
user's project directory. LazyKimi's manifest launchers therefore fail closed
without binding. The supported project-init route writes absolute plugin and
project paths into `kimi-project-mcp.js` arguments; the adapter validates the
project before invoking the shared server. Neither plugin cwd nor host-global
environment identifies a project. Concurrent projects have separate processes
and state. Full native-host activation remains pending live observation.

`init` preserves unknown and modified files, merges receipt-owned MCP keys,
and seeds only missing state. It records ownership for individual MCP keys,
so foreign declarations survive uninstall. An invalid existing receipt is
preserved and newly copied files are not adopted into it. Missing, empty,
malformed, unsupported, or unsafe receipts authorize no deletion. All receipt
entries, digests, sizes, path components, symlinks, and hardlinks are checked
before deletion begins. Modified entries stay in place. `--purge-state`
preserves state without receipt ownership. Host configuration follows
`KIMI_CODE_HOME`, defaulting to `~/.kimi-code`.
