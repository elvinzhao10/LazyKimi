#!/usr/bin/env python3
"""verification MCP server — evidence ledger and completion gating for lazykimi.

Stores evidence in `.lazykimi/evidence/evidence.jsonl` (append-only) and
completion status in `.lazykimi/evidence/completion.json`. Replaces the
LazyBuddy per-run verification gates with a single project-level evidence
ledger suitable for the Kimi Code CLI port.

Tools: record_evidence, get_evidence, mark_complete, get_completion_status.
"""
import json
import os
import sys
import time

MCP_ROOT = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
if MCP_ROOT not in sys.path:
    sys.path.insert(0, MCP_ROOT)
from jsonrpc import serve

CWD = os.environ.get("CWD", ".")
EVIDENCE_DIR = os.path.join(CWD, ".lazykimi", "evidence")
EVIDENCE_FILE = os.path.join(EVIDENCE_DIR, "evidence.jsonl")
COMPLETION_FILE = os.path.join(EVIDENCE_DIR, "completion.json")
SAFE_KEY = __import__("re").compile(r"^[A-Za-z0-9][A-Za-z0-9_.\-/]*$")


def _now():
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


def _safe_key(value):
    return isinstance(value, str) and bool(SAFE_KEY.match(value))


def _load_evidence():
    if not os.path.isfile(EVIDENCE_FILE):
        return []
    out = []
    with open(EVIDENCE_FILE) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                out.append(json.loads(line))
            except ValueError:
                continue
    return out


def _append_evidence(record):
    os.makedirs(EVIDENCE_DIR, exist_ok=True)
    with open(EVIDENCE_FILE, "a") as f:
        f.write(json.dumps(record, separators=(",", ":")) + "\n")


def _load_completion():
    try:
        with open(COMPLETION_FILE) as f:
            data = json.load(f)
        return data if isinstance(data, dict) else {}
    except (OSError, ValueError):
        return {}


def _save_completion(data):
    os.makedirs(EVIDENCE_DIR, exist_ok=True)
    tmp = COMPLETION_FILE + ".tmp"
    with open(tmp, "w") as f:
        json.dump(data, f, separators=(",", ":"))
    os.replace(tmp, COMPLETION_FILE)


def _req_str(args, name):
    v = args.get(name)
    if not isinstance(v, str) or not v:
        raise ValueError("invalid or missing string argument: %s" % name)
    return v


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
        reply({"protocolVersion": "2024-11-05", "capabilities": {"tools": {}}, "serverInfo": {"name": "lazykimi-verification", "version": "1.0.0"}})
        return
    if method == "tools/list":
        reply({"tools": [
            {"name": "record_evidence", "description": "Append a structured evidence record (gate/test/qa artifact) to the evidence ledger.", "inputSchema": {"type": "object", "properties": {"gate": {"type": "string"}, "status": {"type": "string", "enum": ["passed", "failed"]}, "result": {"type": "string"}, "artifact": {"type": "string"}}, "required": ["gate", "status"]}},
            {"name": "get_evidence", "description": "Return recorded evidence, optionally filtered by gate name.", "inputSchema": {"type": "object", "properties": {"gate": {"type": "string"}}}},
            {"name": "mark_complete", "description": "Mark the project (or a named scope) as complete with a summary.", "inputSchema": {"type": "object", "properties": {"scope": {"type": "string"}, "summary": {"type": "string"}, "status": {"type": "string", "enum": ["complete", "blocked", "in_progress"]}}, "required": ["summary"]}},
            {"name": "get_completion_status", "description": "Return the current completion status and evidence summary.", "inputSchema": {"type": "object", "properties": {"scope": {"type": "string"}}}},
        ]})
        return
    if method != "tools/call":
        err("unsupported method: " + method)
        return

    tool = params.get("name", "")
    args = params.get("arguments", {})
    try:
        if tool == "record_evidence":
            gate = _req_str(args, "gate")
            status = _req_str(args, "status")
            if status not in ("passed", "failed"):
                err("status must be 'passed' or 'failed'")
                return
            if not _safe_key(gate):
                err("invalid gate name")
                return
            record = {"ts": _now(), "gate": gate, "status": status,
                      "result": args.get("result", ""), "artifact": args.get("artifact", "")}
            _append_evidence(record)
            tool_result("evidence recorded: %s=%s" % (gate, status))
        elif tool == "get_evidence":
            gate_filter = args.get("gate", "")
            evidence = _load_evidence()
            if gate_filter:
                if not _safe_key(gate_filter):
                    err("invalid gate name")
                    return
                evidence = [e for e in evidence if e.get("gate") == gate_filter]
            out = "evidence (%d records):\n" % len(evidence)
            for e in evidence:
                out += "  %s  %s=%s  %s\n" % (e.get("ts", ""), e.get("gate", ""), e.get("status", ""), e.get("result", "")[:80])
            tool_result(out)
        elif tool == "mark_complete":
            summary = _req_str(args, "summary")
            status = args.get("status", "complete")
            if status not in ("complete", "blocked", "in_progress"):
                err("status must be complete|blocked|in_progress")
                return
            scope = args.get("scope", "default")
            if not _safe_key(scope):
                err("invalid scope")
                return
            data = _load_completion()
            data[scope] = {"status": status, "summary": summary, "updated_at": _now()}
            _save_completion(data)
            _append_evidence({"ts": _now(), "gate": "completion:%s" % scope, "status": "passed" if status == "complete" else "failed", "result": summary, "artifact": COMPLETION_FILE})
            tool_result("marked %s: %s" % (scope, status))
        elif tool == "get_completion_status":
            scope = args.get("scope", "")
            data = _load_completion()
            evidence = _load_evidence()
            passed = sum(1 for e in evidence if e.get("status") == "passed")
            failed = sum(1 for e in evidence if e.get("status") == "failed")
            if scope:
                if not _safe_key(scope):
                    err("invalid scope")
                    return
                entry = data.get(scope)
                if entry is None:
                    err("scope not found: %s" % scope)
                    return
                out = "completion %s: %s\nsummary: %s\nupdated: %s\nevidence: %d passed, %d failed" % (
                    scope, entry.get("status", "?"), entry.get("summary", ""), entry.get("updated_at", ""), passed, failed)
            else:
                out = "completion status (%d scopes):\n" % len(data)
                for s, entry in data.items():
                    out += "  %s: %s\n" % (s, entry.get("status", "?"))
                out += "evidence totals: %d passed, %d failed across %d records\n" % (passed, failed, len(evidence))
            tool_result(out)
        else:
            err("unknown tool: " + tool)
    except Exception as e:
        err("tool error: " + str(e))


def main():
    serve(handle)


if __name__ == "__main__":
    main()
