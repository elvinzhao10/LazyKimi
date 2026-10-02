# Kimi Work setup

Kimi Work supports the full plugin definition: skills, MCP, agents, hooks,
commands, and system instructions. See the [official plugin overview](https://www.kimi.com/en/help/plugins-and-skills/overview).
LazyKimi's full-plugin route remains experimental until a fresh Work session
proves discovery, loading, hook behavior, native tool restrictions, and project
binding. Package load-check cannot establish those observations.

The `scripts/install-kimi-work.sh` helper is a skills-only recovery route;
its limited output does not describe the host's overall plugin capabilities.
Review its target directory before invoking it. Imported skills alone do not
activate this package's agents, hooks, commands, or MCP servers.

For manually configured local MCP servers, use the same explicit binding as
the project init route. For each of run-ledger, verification, status-dashboard,
context-graph, code-intel, and docs, configure `node` with arguments:

```text
<absolute-plugin>/scripts/kimi-project-mcp.js <server> --project <absolute-project> --mode orchestrated
```

Confirm that the host supports local stdio and observe each connection before
claiming readiness. The global manifest cannot infer a user project from its
managed plugin working directory: unbound launches exit with a diagnostic.
Never set invented host environment variables to work around that boundary.

Remove only assets whose ownership is established by a valid receipt or the
host's plugin manager. Preserve modified and unknown skill directories and
remove manually configured connectors through the host UI.

## Product identity and current acceptance

Kimi Work is Work mode in the general Kimi desktop client. Kimi Code Desktop is a separate coding application. Full plugin support in Work is an upstream capability; this package's full Work integration remains experimental. The fallback helper imports skills only, with explicit project-bound manual MCP connectors. See [the reviewed product surfaces](reference/kimi-product-surfaces.md) and [2026-10-02 audit](reference/platform-status-2026-10-02.md).
