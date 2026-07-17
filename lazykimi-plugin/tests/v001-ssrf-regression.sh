#!/usr/bin/env bash
# v001-ssrf-regression.sh
# Verify docs MCP server rejects non-registry URLs (code review + runtime test).
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/lazykimi-ssrf.XXXXXX")"

cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

DOCS="$PLUGIN_ROOT/mcp/docs/server.py"
[ -f "$DOCS" ] || fail "docs server.py missing"

# 1. Code review: SSRF protections are present in the source.
grep -q 'NoRedirectHandler' "$DOCS" || fail "missing no-redirect handler class"
grep -q 'redirect_request' "$DOCS" || fail "missing redirect_request override (redirects blocked)"
grep -q 'registry\.npmjs\.org' "$DOCS" || fail "missing npm registry whitelist"
grep -q 'pypi\.org' "$DOCS" || fail "missing pypi registry whitelist"
grep -qE '_NPM_URL_OK|_PYPI_URL_OK' "$DOCS" || fail "missing URL whitelist regex"
grep -qE 'https://' "$DOCS" || fail "no HTTPS scheme in server"
# The server must fetch via urllib.request (stdlib) and never shell out to curl/subprocess.
grep -q 'urllib.request' "$DOCS" || fail "docs server must use urllib.request"
! grep -qE 'subprocess|os\.system|os\.popen|Popen' "$DOCS" \
  || fail "docs server must not invoke subprocess/curl"

# 2. Runtime: hostile library names are rejected before any fetch (no network).
rpc() {
  local library="$1"
  python3 -c 'import json,sys; print(json.dumps({"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"lookup_docs","arguments":{"library":sys.argv[1],"registry":"auto"}}}))' "$library" \
    | python3 "$DOCS" >"$TMP/resp" 2>&1 || true
  grep -q '"error"' "$TMP/resp" || fail "hostile library not rejected: $library"
}

for hostile in 'http://127.0.0.1:9/' 'https://registry.npmjs.org/redirect' \
  'name?url=http://127.0.0.1:9/' 'name#fragment' 'name\path' 'name with space' \
  '/absolute' '../escape' 'scope/name'; do
  rpc "$hostile"
done

# 3. Monkeypatch: a valid name resolves ONLY to a whitelisted HTTPS registry URL,
#    and a non-whitelist URL is rejected before the opener is touched (no network).
python3 - "$DOCS" <<'PYEOF'
import importlib.util, re, sys
path = sys.argv[1]
spec = importlib.util.spec_from_file_location("lazykimi_docs", path)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)  # __name__ != __main__, so serve() is not called

npm_re = re.compile(r"^https://registry\.npmjs\.org/(?:@[a-z0-9][a-z0-9._-]*/)?[a-z0-9][a-z0-9._-]*/latest$")
pypi_re = re.compile(r"^https://pypi\.org/pypi/[a-z0-9]+(?:[-._][a-z0-9]+)*/json$", re.I)

# Valid names produce whitelisted URLs only.
assert mod._npm_url("react") and npm_re.match(mod._npm_url("react")), "npm url not whitelisted"
assert mod._pypi_url("fastapi") and pypi_re.match(mod._pypi_url("fastapi")), "pypi url not whitelisted"

# Hostile names produce no URL (so no fetch can happen).
for h in ["http://127.0.0.1:9/", "name?url=http://x", "name#frag", "name\\path", "/abs", "../esc"]:
    assert mod._npm_url(h) is None, "npm hostile produced url: %r" % h
    assert mod._pypi_url(h) is None, "pypi hostile produced url: %r" % h

# fetch_json rejects non-whitelist URLs before any opener call.
opened = []
class FakeResp:
    status = 200
    def read(self): return b'{"version":"1.0","readme":"x","info":{}}'
    def __enter__(self): return self
    def __exit__(self, *a): return False
class FakeOpener:
    def open(self, req, timeout=None):
        opened.append(req.full_url); return FakeResp()

real = mod._OPENER
mod._OPENER = FakeOpener()
try:
    _, err = mod._fetch_json("http://127.0.0.1:9/evil")
    assert err and "whitelist" in err, "non-whitelist url fetched: %r" % err
    assert opened == [], "non-whitelist url reached opener: %r" % opened
    # Whitelist URL goes through the opener and ONLY that URL.
    opened.clear()
    data, err = mod._fetch_json("https://registry.npmjs.org/react/latest")
    assert err is None, "whitelist url failed: %r" % err
    assert opened == ["https://registry.npmjs.org/react/latest"], "unexpected fetch: %r" % opened
finally:
    mod._OPENER = real
print("ssrf monkeypatch: OK")
PYEOF

echo "v001 ssrf regression: PASS"
