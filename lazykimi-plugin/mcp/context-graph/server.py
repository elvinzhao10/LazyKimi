#!/usr/bin/env python3
"""context-graph MCP server — heuristic context search for lazykimi.

Provides repo-wide heuristic context via grep (ripgrep if available, else
system grep). NOT a semantic search or a real call graph: results are literal
text matches with junk directories excluded.

Tools: search_context, get_references.
"""
import json
import os
import re
import shutil
import subprocess
import sys

MCP_ROOT = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
if MCP_ROOT not in sys.path:
    sys.path.insert(0, MCP_ROOT)
from path_boundary import PathBoundaryError, resolve_repo_path
from jsonrpc import serve

CWD = os.environ.get("CWD", ".")
USE_RG = shutil.which("rg") is not None
EXCLUDES = [".git", "node_modules", "dist", "build", ".next", ".lazykimi", ".lazytrae", ".trae", "reference", "sources", "__pycache__"]


def _grep_lines(pattern, is_regex=True, limit=None, path_filter=None):
    """Return matching lines across the repo, excluding junk dirs.

    If path_filter is given (repo-relative file or dir), the search is
    restricted to that target after path-boundary validation. Returns [] when
    the filter escapes the project root.
    """
    search_target = "."
    if path_filter:
        try:
            resolve_repo_path(CWD, path_filter)
        except PathBoundaryError:
            return []
        search_target = path_filter
    if USE_RG:
        cmd = ["rg", "-n", "--no-heading"] + (["-e", pattern] if is_regex else ["-F", pattern]) + [search_target]
        for x in EXCLUDES:
            cmd += ["-g", "!" + x + "/"]
    else:
        cmd = ["grep", "-rn"] + (["-E"] if is_regex else ["-F"]) + [pattern, search_target]
        for x in EXCLUDES:
            cmd += ["--exclude-dir=" + x]
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, cwd=CWD, timeout=60)
        lines = [l for l in r.stdout.split("\n") if l] if r.stdout else []
        return lines[:limit] if limit else lines
    except Exception as e:
        sys.stderr.write("context-graph grep error: %s\n" % e)
        return []


def _format_hits(header, lines):
    out = "%s (%d hits):\n" % (header, len(lines))
    for l in lines:
        out += "  " + l + "\n"
    return out


def _path_filter(args):
    """Extract an optional repo-relative path filter from tool arguments."""
    path = args.get("path", "")
    return path if isinstance(path, str) and path else None


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
        reply({"protocolVersion": "2024-11-05", "capabilities": {"tools": {}}, "serverInfo": {"name": "lazykimi-context-graph", "version": "1.0.0"}})
        return
    if method == "tools/list":
        reply({"tools": [
            {"name": "search_context", "description": "Heuristic repo-wide text search (ripgrep if available, else grep). NOT semantic search. Returns matching file:line:text entries. Use to locate code by literal or regex pattern. Optional path restricts the search to a repo-relative file or directory.", "inputSchema": {"type": "object", "properties": {"query": {"type": "string"}, "is_regex": {"type": "boolean", "default": False}, "path": {"type": "string", "description": "optional repo-relative file or directory to restrict the search"}, "limit": {"type": "integer", "default": 100}}, "required": ["query"]}},
            {"name": "get_references", "description": "Find references to a symbol across the repo using word-boundary matching (ripgrep if available, else grep). Heuristic — includes comments/strings. Optional path restricts the search to a repo-relative file or directory.", "inputSchema": {"type": "object", "properties": {"symbol": {"type": "string"}, "path": {"type": "string", "description": "optional repo-relative file or directory to restrict the search"}, "limit": {"type": "integer", "default": 100}}, "required": ["symbol"]}},
        ]})
        return
    if method != "tools/call":
        err("unsupported method: " + method)
        return

    tool = params.get("name", "")
    args = params.get("arguments", {})
    try:
        if tool == "search_context":
            query = args.get("query", "")
            if not isinstance(query, str) or not query:
                err("invalid or missing query")
                return
            is_regex = bool(args.get("is_regex", False))
            limit = args.get("limit", 100)
            if not isinstance(limit, int) or limit < 1:
                limit = 100
            lines = _grep_lines(query, is_regex=is_regex, limit=limit, path_filter=_path_filter(args))
            tool_result(_format_hits('search_context "%s"' % query, lines))
        elif tool == "get_references":
            symbol = args.get("symbol", "")
            if not isinstance(symbol, str) or not symbol:
                err("invalid or missing symbol")
                return
            limit = args.get("limit", 100)
            if not isinstance(limit, int) or limit < 1:
                limit = 100
            sym = re.escape(symbol)
            lines = _grep_lines(r"\b" + sym + r"\b", is_regex=True, limit=limit, path_filter=_path_filter(args))
            tool_result(_format_hits('get_references "%s"' % symbol, lines))
        else:
            err("unknown tool: " + tool)
    except Exception as e:
        err("tool error: " + str(e))


def main():
    serve(handle)


if __name__ == "__main__":
    main()
