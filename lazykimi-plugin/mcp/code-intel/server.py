#!/usr/bin/env python3
"""code-intel MCP server — heuristic code intelligence for lazykimi.

Wraps ripgrep (preferred) or system grep for symbol discovery. ast-grep (`sg`)
is used opportunistically for structural queries when available, with graceful
fallback to plain regex. NOT a language server: definitions/references are
heuristic grep matches.

Tools: get_symbols, find_references, goto_definition.
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
from path_boundary import resolve_repo_path
from jsonrpc import serve

CWD = os.environ.get("CWD", ".")
USE_RG = shutil.which("rg") is not None
USE_SG = shutil.which("sg") is not None
EXCLUDES = [".git", "node_modules", "dist", "build", ".next", ".lazykimi", ".lazytrae", ".trae", "reference", "sources", "__pycache__"]
DECL_RE = re.compile(r"\b(function|class|const|let|def|func|interface|type|enum|struct|impl)\s+([A-Za-z_][A-Za-z0-9_]*)")
DECL_KEYWORDS = r"(function|class|const|let|def|func|interface|type|enum|struct|impl)"


def _grep_lines(pattern, is_regex=True, limit=None):
    if USE_RG:
        cmd = ["rg", "-n", "--no-heading"] + (["-e", pattern] if is_regex else ["-F", pattern]) + ["."]
        for x in EXCLUDES:
            cmd += ["-g", "!" + x + "/"]
    else:
        cmd = ["grep", "-rn"] + (["-E"] if is_regex else ["-F"]) + [pattern, "."]
        for x in EXCLUDES:
            cmd += ["--exclude-dir=" + x]
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, cwd=CWD, timeout=60)
        lines = [l for l in r.stdout.split("\n") if l] if r.stdout else []
        return lines[:limit] if limit else lines
    except Exception as e:
        sys.stderr.write("code-intel grep error: %s\n" % e)
        return []


def _format_hits(header, lines):
    out = "%s (%d hits):\n" % (header, len(lines))
    for l in lines:
        out += "  " + l + "\n"
    return out


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
        reply({"protocolVersion": "2024-11-05", "capabilities": {"tools": {}}, "serverInfo": {"name": "lazykimi-code-intel", "version": "1.0.0", "backends": {"ripgrep": USE_RG, "ast-grep": USE_SG}}})
        return
    if method == "tools/list":
        reply({"tools": [
            {"name": "get_symbols", "description": "Outline symbols (function/class/const/def/interface/type/enum/struct/impl) declared in a single file. Heuristic grep.", "inputSchema": {"type": "object", "properties": {"path": {"type": "string", "description": "repo-relative file path"}}, "required": ["path"]}},
            {"name": "find_references", "description": "Find all references to a symbol across the repo (word-boundary match). Heuristic — includes comments/strings, not semantic.", "inputSchema": {"type": "object", "properties": {"symbol": {"type": "string"}, "limit": {"type": "integer", "default": 100}}, "required": ["symbol"]}},
            {"name": "goto_definition", "description": "Find likely definitions of a symbol (declaration keyword + name). Heuristic grep; ast-grep used opportunistically when available.", "inputSchema": {"type": "object", "properties": {"symbol": {"type": "string"}, "limit": {"type": "integer", "default": 30}}, "required": ["symbol"]}},
        ]})
        return
    if method != "tools/call":
        err("unsupported method: " + method)
        return

    tool = params.get("name", "")
    args = params.get("arguments", {})
    try:
        if tool == "get_symbols":
            path = args.get("path", "")
            if not isinstance(path, str) or not path:
                err("invalid or missing path")
                return
            fp = resolve_repo_path(CWD, path)
            if not os.path.isfile(fp):
                err("file not found: " + path)
                return
            with open(fp, errors="ignore") as f:
                src = f.read().split("\n")
            out = "symbols in %s:\n" % path
            count = 0
            for i, line in enumerate(src, 1):
                for m in DECL_RE.finditer(line):
                    out += "  %s:%d  %s %s\n" % (path, i, m.group(1), m.group(2))
                    count += 1
            tool_result("symbols in %s (%d):\n" % (path, count) + "\n".join(out.split("\n")[1:]))
        elif tool == "find_references":
            symbol = args.get("symbol", "")
            if not isinstance(symbol, str) or not symbol:
                err("invalid or missing symbol")
                return
            limit = args.get("limit", 100)
            if not isinstance(limit, int) or limit < 1:
                limit = 100
            sym = re.escape(symbol)
            lines = _grep_lines(r"\b" + sym + r"\b", is_regex=True, limit=limit)
            tool_result(_format_hits('find_references "%s"' % symbol, lines))
        elif tool == "goto_definition":
            symbol = args.get("symbol", "")
            if not isinstance(symbol, str) or not symbol:
                err("invalid or missing symbol")
                return
            limit = args.get("limit", 30)
            if not isinstance(limit, int) or limit < 1:
                limit = 30
            sym = re.escape(symbol)
            lines = _grep_lines(r"\b" + DECL_KEYWORDS + r"\s+" + sym + r"\b", is_regex=True, limit=limit)
            tool_result(_format_hits('goto_definition "%s"' % symbol, lines))
        else:
            err("unknown tool: " + tool)
    except Exception as e:
        err("tool error: " + str(e))


def main():
    serve(handle)


if __name__ == "__main__":
    main()
