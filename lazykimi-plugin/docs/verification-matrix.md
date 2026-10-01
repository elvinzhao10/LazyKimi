# LazyKimi package verification contract

This public, package-owned matrix lets a copied `lazykimi-plugin/` discover
its checks without repository-root documentation. It reports package evidence
and names the host observation required before a user-facing integration claim
(the `lazykimi-verification` MCP server's `discover_checks` tool parses this
file: `## <section>` headings plus `| Verification Step | Command | Expected | Artifact |` rows).

## Package checks

| Verification Step | Command | Expected | Artifact |
| --- | --- | --- | --- |
| MCP integration | `bash scripts/lazykimi-mcp-test.sh` | `MCP test: ALL PASS` (6 servers, 32 tools, state round-trip) | command output |
| MCP params robustness | `bash tests/v103-mcp-params-regression.sh` | Every server rejects malformed `tools/call` params without ending the session | command output |
| MCP path boundary | `bash tests/v003-mcp-path-traversal-regression.sh` | Path escapes and symlink escapes are rejected | command output |
| MCP SSRF boundary | `bash tests/v003-ssrf-boundary-regression.sh` and `bash tests/v001-ssrf-regression.sh` | Only fixed HTTPS registry URLs are fetched; hostile names produce no fetch | command output |
| Package verification | `bash scripts/lazykimi-verify.sh` | JSON with `"all_pass":true` | command output |
| Security acceptance | `bash tests/v001-security-regression.sh` | Package boundary and secret hygiene hold | command output |

## Host observation (required before any host-readiness claim)

| Verification Step | Command | Expected | Artifact |
| --- | --- | --- | --- |
| Kimi Code CLI MCP connections | `/mcp` in a project with `lazykimi init` applied | Six `lazykimi-*` servers connect with rewritten absolute paths | host observation receipt |
| Kimi plugin-manifest route | `/plugins marketplace` install of `lazykimi-plugin/marketplace.json` | Observe skills, agents and hooks; unbound MCP launchers refuse until a supported project binding exists | host observation receipt |
| Kimi TOML hook route | `scripts/install-hooks.sh --project-root <absolute-project>` then restart | The 8 critical `[[hooks]]` entries fire; removal targets only that project's established hook ownership | host observation receipt |

Host observation rows stay **documented-untested** until recorded through the
observation-receipt machinery; doctor keeps reporting `HOST_READINESS=pending`
absent such receipts.
