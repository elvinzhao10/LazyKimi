# Security policy

Please do not report security vulnerabilities in public issues. Use GitHub's
private vulnerability reporting for this repository, or contact the maintainer
privately through the repository owner profile. Include a minimal reproduction,
affected version, impact, and any suggested mitigation. Do not include live
credentials, API keys, or personal data.

We will acknowledge reports, assess severity, and coordinate a fix before
public disclosure where practical. The supported release line is the latest
published stable version.

## Scope

The following are considered security-relevant:

- Path traversal or symlink escape in MCP servers, hook scripts, or the CLI.
- SSRF in the `docs` MCP server (it must only contact the fixed npm/PyPI
  registry endpoints and must not follow redirects or metadata URLs).
- Secret-target handling in structured `Write` and `Edit` operations.
- Hook injection where untrusted text is evaluated as shell syntax.
- Receipt forgery that lets an uninstall command remove assets it did not
  create.

The following are not security issues:

- A host failing to load a declared plugin, hook, or MCP server. That is a
  host integration question, not a package vulnerability.
- Package readiness reporting a degraded state. That is honest reporting,
  not a defect.
