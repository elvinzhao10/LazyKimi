#!/usr/bin/env python3
"""docs MCP server — SSRF-safe just-in-time library docs for lazykimi.

Resolves a library name to its registry metadata and README via fixed HTTPS
registry fetches ONLY. Uses Python stdlib urllib.request (no curl, no
third-party packages). SSRF protections:

  * Only HTTPS URLs to registry.npmjs.org and pypi.org are permitted.
  * URLs are built from validated package names (never taken raw from input).
  * The final URL is re-checked against a strict regex whitelist before fetch.
  * Redirects are NEVER followed (custom no-redirect opener).
  * Only HTTP 200 responses are accepted; everything else is rejected.
  * No metadata/search URLs, no arbitrary hosts, no redirect chains.

Tools: lookup_docs.
"""
import json
import os
import re
import sys
from urllib.error import HTTPError, URLError
from urllib.parse import quote
from urllib.request import HTTPRedirectHandler, Request, build_opener

MCP_ROOT = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
if MCP_ROOT not in sys.path:
    sys.path.insert(0, MCP_ROOT)
from jsonrpc import serve

# Strict URL whitelist: only fixed registry package URLs over HTTPS.
# npm:  https://registry.npmjs.org/<@scope/name|name>/latest
# pypi: https://pypi.org/pypi/<name>/json
_NPM_PACKAGE = re.compile(r"(?:@[a-z0-9][a-z0-9._-]*/)?[a-z0-9][a-z0-9._-]*$")
_PYPI_PACKAGE = re.compile(r"[a-z0-9]+(?:[-._][a-z0-9]+)*$", re.I)
_NPM_URL_OK = re.compile(r"^https://registry\.npmjs\.org/(?:@[a-z0-9][a-z0-9._-]*/)?[a-z0-9][a-z0-9._-]*/latest$")
_PYPI_URL_OK = re.compile(r"^https://pypi\.org/pypi/[a-z0-9]+(?:[-._][a-z0-9]+)*/json$", re.I)
_USER_AGENT = "lazykimi-docs/1.0.0"


class _NoRedirectHandler(HTTPRedirectHandler):
    """Block all redirects — redirect_request returns None -> urllib raises."""

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


_OPENER = build_opener(_NoRedirectHandler)


def _invalid_package_name(library):
    return (
        not isinstance(library, str)
        or not library
        or any(ch.isspace() or ord(ch) < 32 or ord(ch) == 127 for ch in library)
        or any(ch in library for ch in ("?", "#", "\\"))
        or "://" in library
    )


def _npm_url(library):
    if _invalid_package_name(library) or not _NPM_PACKAGE.fullmatch(library):
        return None
    return "https://registry.npmjs.org/" + quote(library, safe="@/") + "/latest"


def _pypi_url(library):
    if _invalid_package_name(library) or "/" in library or not _PYPI_PACKAGE.fullmatch(library):
        return None
    return "https://pypi.org/pypi/" + quote(library, safe="") + "/json"


def _fetch_json(url, timeout=20):
    """Fetch JSON from a whitelisted registry URL. Never follows redirects."""
    if not (_NPM_URL_OK.match(url) or _PYPI_URL_OK.match(url)):
        return None, "URL not on registry whitelist"
    req = Request(url, headers={"User-Agent": _USER_AGENT, "Accept": "application/json"})
    try:
        with _OPENER.open(req, timeout=timeout) as resp:
            if resp.status != 200:
                return None, "non-200 response: %d" % resp.status
            body = resp.read().decode("utf-8", errors="replace")
    except HTTPError as e:
        return None, "HTTP %d (redirects blocked, non-200 rejected)" % e.code
    except (URLError, TimeoutError, OSError) as e:
        return None, "fetch error: %s" % e
    try:
        return json.loads(body), None
    except ValueError as e:
        return None, "not JSON: %s" % e


def _section(readme, topic):
    if not readme or not topic:
        return None
    lines = readme.split("\n")
    pat = re.compile(r"^#+\s*" + re.escape(topic), re.I)
    start = next((i for i, l in enumerate(lines) if pat.match(l)), None)
    if start is None:
        return None
    out = [lines[start]]
    for l in lines[start + 1:]:
        if re.match(r"^#+\s", l) and not re.match(r"^#+\s*" + re.escape(topic), l, re.I):
            break
        out.append(l)
    return "\n".join(out).strip()


def _npm_docs(library, topic):
    url = _npm_url(library)
    if not url:
        return None, "npm: invalid package name"
    data, err = _fetch_json(url)
    if err:
        return None, "npm: " + err
    readme = data.get("readme") or ""
    repo = data.get("repository", {})
    if isinstance(repo, dict):
        repo = repo.get("url", "")
    if topic:
        sec = _section(readme, topic)
        if sec:
            readme = sec
    return {"registry": "npm", "library": library, "version": data.get("version", ""),
            "description": data.get("description", ""), "homepage": data.get("homepage", ""),
            "repository": repo, "docs": (readme or "").strip()[:12000] or "(no readme available)"}, None


def _pypi_docs(library, topic):
    url = _pypi_url(library)
    if not url:
        return None, "pypi: invalid package name"
    data, err = _fetch_json(url)
    if err:
        return None, "pypi: " + err
    info = data.get("info", {})
    project_urls = info.get("project_urls") or {}
    readme = info.get("description") or ""
    if topic and readme:
        sec = _section(readme, topic)
        if sec:
            readme = sec
    return {"registry": "pypi", "library": library, "version": info.get("version", ""),
            "description": info.get("summary", ""), "homepage": info.get("home_page", ""),
            "repository": project_urls.get("Source") or project_urls.get("Repository") or "",
            "docs_url": project_urls.get("Documentation") or project_urls.get("Homepage") or "",
            "docs": (readme or info.get("summary", "")).strip()[:12000] or "(fetch homepage for full docs)"}, None


def handle(req, notification):
    method = req.get("method", "")
    rid = req.get("id", 0)
    params = req.get("params", {})

    def reply(j):
        if not notification:
            print(json.dumps({"jsonrpc": "2.0", "id": rid, "result": j}), flush=True)

    def err(m, code=-32603):
        if not notification:
            print(json.dumps({"jsonrpc": "2.0", "id": rid, "error": {"code": code, "message": m}}), flush=True)

    def tool_result(text):
        reply({"content": [{"type": "text", "text": text}]})

    if method == "initialize":
        reply({"protocolVersion": "2024-11-05", "capabilities": {"tools": {}}, "serverInfo": {"name": "lazykimi-docs", "version": "1.0.0"}})
        return
    if method == "tools/list":
        reply({"tools": [
            {"name": "lookup_docs", "description": "Fetch just-in-time docs for a library from npm and/or pypi registries. SSRF-safe: only fixed HTTPS registry URLs, no redirects, 200-only. Optional topic extracts a markdown section.", "inputSchema": {"type": "object", "properties": {"library": {"type": "string", "description": "package name (e.g. 'fastapi', 'zod', 'react')"}, "topic": {"type": "string", "description": "optional: extract the markdown section with this heading"}, "registry": {"type": "string", "enum": ["npm", "pypi", "auto"], "default": "auto"}}, "required": ["library"]}},
        ]})
        return
    if method != "tools/call":
        err("unsupported method: " + method)
        return

    tool = params.get("name", "")
    args = params.get("arguments", {})
    try:
        if tool == "lookup_docs":
            library = args.get("library", "")
            if not isinstance(library, str) or not library:
                err("invalid or missing library")
                return
            topic = args.get("topic", "") or ""
            registry = args.get("registry", "auto")
            if registry not in ("npm", "pypi", "auto"):
                err("registry must be npm|pypi|auto")
                return
            result, errors = None, []
            if registry in ("auto", "npm"):
                r, e = _npm_docs(library, topic)
                if r:
                    result = r
                else:
                    errors.append(e)
            if registry == "auto":
                r2, e2 = _pypi_docs(library, topic)
                if r2:
                    if result is None or len(r2.get("docs", "")) > len(result.get("docs", "")):
                        result = r2
                else:
                    errors.append(e2)
            elif registry == "pypi":
                r, e = _pypi_docs(library, topic)
                if r:
                    result = r
                else:
                    errors.append(e)
            if result is None:
                err("could not fetch docs for '%s': %s" % (library, "; ".join(errors)))
                return
            out = "## %s (%s registry, v%s)\n" % (library, result["registry"], result.get("version", "?"))
            if result.get("description"):
                out += result["description"] + "\n\n"
            if result.get("homepage") or result.get("docs_url"):
                out += "homepage: " + (result.get("homepage") or result.get("docs_url")) + "\n"
            if result.get("repository"):
                out += "repo: " + result["repository"] + "\n"
            if topic:
                out += "(section: %s)\n" % topic
            out += "\n--- docs ---\n" + result.get("docs", "")
            tool_result(out)
        else:
            err("unknown tool: " + tool)
    except Exception as e:
        err("tool error: " + str(e))


def main():
    serve(handle)


if __name__ == "__main__":
    main()
