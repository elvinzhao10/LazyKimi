#!/usr/bin/env bash
# LazyKimi v1.3.4 SSRF boundary regression test.
# Verifies whitelist enforcement and redirect blocking in the docs MCP server
# (family port: curl-based implementation with package_url builders).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DOCS="${PLUGIN_ROOT}/mcp/docs/server.py"

fail() { echo "FAIL: $1" >&2; exit 1; }

[ -f "${DOCS}" ] || fail "docs server.py missing"

python3 - "${DOCS}" <<'PYEOF'
import importlib.util, re, sys
path = sys.argv[1]
spec = importlib.util.spec_from_file_location("lazykimi_docs", path)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)  # __name__ != "__main__", so serve() is not called

npm_re = re.compile(r"^https://registry\.npmjs\.org/(?:@[a-z0-9][a-z0-9._-]*/)?[a-z0-9][a-z0-9._-]*/latest$")
pypi_re = re.compile(r"^https://pypi\.org/pypi/[a-z0-9]+(?:[-._][a-z0-9]+)*/json$", re.I)

# Valid names produce exactly whitelisted HTTPS registry URLs.
for name, builder, pattern in (("react", mod.npm_package_url, npm_re),
                                ("@types/node", mod.npm_package_url, npm_re),
                                ("fastapi", mod.pypi_package_url, pypi_re),
                                ("urllib3", mod.pypi_package_url, pypi_re)):
    url = builder(name)
    assert url and pattern.match(url), f"{name!r} did not produce whitelisted url: {url!r}"

# Hostile inputs produce no URL for npm or pypi.
npm_hostiles = [
    "http://127.0.0.1:9/",
    "https://registry.npmjs.org/redirect",
    "name?url=http://127.0.0.1:9/",
    "name#fragment",
    "name\\path",
    "/absolute",
    "../escape",
    "scope/name",  # npm scope without @ is invalid
    "name with space",
    "",
]
pypi_hostiles = [
    "http://127.0.0.1:9/",
    "name?url=http://x",
    "name#frag",
    "name\\path",
    "/abs",
    "../esc",
    "scope/name",  # pypi names may not contain /
    "name with space",
    "",
]
for h in npm_hostiles:
    assert mod.npm_package_url(h) is None, f"npm hostile produced url: {h!r}"
for h in pypi_hostiles:
    assert mod.pypi_package_url(h) is None, f"pypi hostile produced url: {h!r}"
PYEOF

echo "v003 ssrf-boundary regression: PASS"
