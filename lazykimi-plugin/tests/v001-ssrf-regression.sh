#!/usr/bin/env bash
# v001-ssrf-regression.sh
# Verify docs MCP server rejects non-registry URLs (code review + runtime test).
# v1.3.3 port: the docs server is the family (LazyZCode-derived) curl-based
# implementation — protections are the fixed-URL whitelist plus hardened curl
# flags (HTTPS-only proto, redirects refused), checked before any fetch.
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/lazykimi-ssrf.XXXXXX")"

cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

DOCS="$PLUGIN_ROOT/mcp/docs/server.py"
[ -f "$DOCS" ] || fail "docs server.py missing"

# 1. Code review: SSRF protections are present in the source.
grep -q 'registry\.npmjs\.org' "$DOCS" || fail "missing npm registry whitelist"
grep -q 'pypi\.org' "$DOCS" || fail "missing pypi registry whitelist"
grep -qE '_NPM_REGISTRY_URL|_PYPI_REGISTRY_URL' "$DOCS" || fail "missing URL whitelist regex"
grep -q '_NPM_PACKAGE\|_PYPI_PACKAGE' "$DOCS" || fail "missing package-name validation regex"
grep -q 'only fixed package registry URLs are allowed' "$DOCS" || fail "missing pre-fetch whitelist rejection"
# curl must be invoked with hardened flags: https-only, no redirects.
grep -q '"--proto", "=https"' "$DOCS" || fail "missing https-only curl proto flag"
grep -q '"--proto-redir", "=https"' "$DOCS" || fail "missing https-only redirect proto flag"
grep -q '"--max-redirs", "0"' "$DOCS" || fail "redirects must be refused (--max-redirs 0)"

# 2. Runtime: hostile library names are rejected before any fetch (no network).
rpc() {
  local library="$1"
  python3 -c 'import json,sys; print(json.dumps({"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"get_library_docs","arguments":{"library":sys.argv[1],"registry":"auto"}}}))' "$library" \
    | CWD="$TMP" python3 "$DOCS" >"$TMP/resp" 2>&1 || true
  grep -q '"error"' "$TMP/resp" || fail "hostile library not rejected: $library"
}

for hostile in 'http://127.0.0.1:9/' 'https://registry.npmjs.org/redirect' \
  'name?url=http://127.0.0.1:9/' 'name#fragment' 'name\path' 'name with space' \
  '/absolute' '../escape' 'scope/name'; do
  rpc "$hostile"
done

# 3. Monkeypatch-free unit check (no network): valid names resolve ONLY to
#    whitelisted HTTPS registry URLs, hostile names produce no URL, and a
#    non-whitelist URL is rejected inside fetch() before curl is touched.
python3 - "$DOCS" <<'PYEOF'
import importlib.util, re, sys
path = sys.argv[1]
spec = importlib.util.spec_from_file_location("lazykimi_docs", path)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)  # __name__ != __main__, so serve() is not called

npm_re = re.compile(r"^https://registry\.npmjs\.org/(?:@[a-z0-9][a-z0-9._-]*/)?[a-z0-9][a-z0-9._-]*/latest$")
pypi_re = re.compile(r"^https://pypi\.org/pypi/[a-z0-9]+(?:[-._][a-z0-9]+)*/json$", re.I)

# Valid names produce whitelisted URLs only.
assert mod.npm_package_url("react") and npm_re.match(mod.npm_package_url("react")), "npm url not whitelisted"
assert mod.pypi_package_url("fastapi") and pypi_re.match(mod.pypi_package_url("fastapi")), "pypi url not whitelisted"

# Hostile names produce no URL (so no fetch can happen).
for h in ["http://127.0.0.1:9/", "name?url=http://x", "name#frag", "name\\path", "/abs", "../esc"]:
    assert mod.npm_package_url(h) is None, "npm hostile produced url: %r" % h
    assert mod.pypi_package_url(h) is None, "pypi hostile produced url: %r" % h

# fetch rejects non-whitelist URLs before any curl invocation (no network use).
body, err = mod.fetch("http://127.0.0.1:9/evil")
assert body is None and err == "only fixed package registry URLs are allowed", (body, err)
print("ssrf unit checks: OK")
PYEOF

echo "v001 ssrf regression: PASS"
