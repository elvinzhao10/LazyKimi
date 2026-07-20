#!/usr/bin/env bash
# LazyKimi v0.3 SSRF boundary regression test.
# Verifies whitelist enforcement and redirect blocking in the docs MCP server.
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
spec.loader.exec_module(mod)  # __name__ != __main__, so serve() is not called

npm_re = re.compile(r"^https://registry\.npmjs\.org/(?:@[a-z0-9][a-z0-9._-]*/)?[a-z0-9][a-z0-9._-]*/latest$")
pypi_re = re.compile(r"^https://pypi\.org/pypi/[a-z0-9]+(?:[-._][a-z0-9]+)*/json$", re.I)

# Valid names produce exactly whitelisted HTTPS registry URLs.
for name, builder, pattern in (("react", mod._npm_url, npm_re),
                                ("@types/node", mod._npm_url, npm_re),
                                ("fastapi", mod._pypi_url, pypi_re),
                                ("urllib3", mod._pypi_url, pypi_re)):
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
    assert mod._npm_url(h) is None, f"npm hostile produced url: {h!r}"
for h in pypi_hostiles:
    assert mod._pypi_url(h) is None, f"pypi hostile produced url: {h!r}"

# _fetch_json rejects non-whitelisted URLs before any network opener is invoked.
opened = []

class FakeResp:
    status = 200
    def read(self): return b'{"version":"1.0.0","readme":"x","info":{}}'
    def __enter__(self): return self
    def __exit__(self, *a): return False

class FakeOpener:
    def open(self, req, timeout=None):
        opened.append(req.full_url)
        return FakeResp()

real = mod._OPENER
mod._OPENER = FakeOpener()
try:
    data, err = mod._fetch_json("http://127.0.0.1:9/evil")
    assert data is None and err and "whitelist" in err, f"non-whitelist url not rejected: {err!r}"
    assert opened == [], f"non-whitelist url reached opener: {opened!r}"

    opened.clear()
    data, err = mod._fetch_json("https://example.com/foo")
    assert data is None and err and "whitelist" in err, f"external https url not rejected: {err!r}"
    assert opened == [], f"external https url reached opener: {opened!r}"

    opened.clear()
    data, err = mod._fetch_json("https://registry.npmjs.org/react/latest")
    assert err is None, f"whitelist npm url failed: {err!r}"
    assert opened == ["https://registry.npmjs.org/react/latest"], f"unexpected fetches: {opened!r}"

    opened.clear()
    data, err = mod._fetch_json("https://pypi.org/pypi/fastapi/json")
    assert err is None, f"whitelist pypi url failed: {err!r}"
    assert opened == ["https://pypi.org/pypi/fastapi/json"], f"unexpected fetches: {opened!r}"
finally:
    mod._OPENER = real

# The custom no-redirect handler blocks redirects by returning None.
handler = mod._NoRedirectHandler()
assert handler.redirect_request(None, None, 302, "Found", {}, "http://evil") is None, \
    "NoRedirectHandler did not block redirect"

print("PASS: v003 ssrf boundary regression")
PYEOF
