#!/usr/bin/env python3
"""status-dashboard MCP server — single-pane status for lazykimi.

Returns a combined status snapshot: the boulder (project goal/state), the
active loop pointer, and an evidence summary. Reads only from the `.lazykimi/`
state tree; never mutates.

Tools: get_status.
"""
import json
import os
import sys

MCP_ROOT = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
if MCP_ROOT not in sys.path:
    sys.path.insert(0, MCP_ROOT)
from jsonrpc import serve

CWD = os.environ.get("CWD", ".")
LAZYKIMI = os.path.join(CWD, ".lazykimi")
BOULDER_FILE = os.path.join(LAZYKIMI, "state", "boulder.json")
ACTIVE_LOOP_FILE = os.path.join(LAZYKIMI, "state", "active-loop.json")
RUN_INDEX_FILE = os.path.join(LAZYKIMI, "state", "index.json")
EVIDENCE_FILE = os.path.join(LAZYKIMI, "evidence", "evidence.jsonl")
COMPLETION_FILE = os.path.join(LAZYKIMI, "evidence", "completion.json")
CONFIG_FILE = os.path.join(LAZYKIMI, "config.json")


def _load_json(path):
    try:
        with open(path) as f:
            return json.load(f)
    except (OSError, ValueError):
        return None


def _load_evidence():
    if not os.path.isfile(EVIDENCE_FILE):
        return []
    out = []
    try:
        with open(EVIDENCE_FILE) as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    out.append(json.loads(line))
                except ValueError:
                    continue
    except OSError:
        return []
    return out


def _summarize_boulder():
    data = _load_json(BOULDER_FILE)
    if data is None:
        return {"present": False, "note": "no boulder.json found at .lazykimi/state/boulder.json"}
    tasks = data.get("tasks", []) if isinstance(data, dict) else []
    done = sum(1 for t in tasks if isinstance(t, dict) and t.get("status") == "completed")
    return {
        "present": True,
        "goal": data.get("goal", data.get("objective", "")) if isinstance(data, dict) else "",
        "status": data.get("status", "") if isinstance(data, dict) else "",
        "tasks_done": done,
        "tasks_total": len(tasks),
        "updated_at": data.get("updated_at", "") if isinstance(data, dict) else "",
    }


def _summarize_active_loop():
    data = _load_json(ACTIVE_LOOP_FILE)
    if data is None:
        return {"present": False, "note": "no active-loop.json found"}
    if not isinstance(data, dict):
        return {"present": False, "note": "active-loop.json is not a JSON object"}
    summary = {
        "present": True,
        "loop_id": data.get("loop_id", ""),
        "objective": data.get("objective", ""),
        "mode": data.get("mode", ""),
        "status": data.get("status", ""),
        "turn_count": data.get("turn_count", 0),
        "started_at": data.get("started_at", ""),
    }
    return summary


def _summarize_evidence():
    evidence = _load_evidence()
    passed = sum(1 for e in evidence if isinstance(e, dict) and e.get("status") == "passed")
    failed = sum(1 for e in evidence if isinstance(e, dict) and e.get("status") == "failed")
    gates = {}
    for e in evidence:
        if not isinstance(e, dict):
            continue
        gate = e.get("gate", "?")
        gates.setdefault(gate, {"passed": 0, "failed": 0})
        if e.get("status") == "passed":
            gates[gate]["passed"] += 1
        elif e.get("status") == "failed":
            gates[gate]["failed"] += 1
    return {"records": len(evidence), "passed": passed, "failed": failed, "gates": gates}


def _summarize_completion():
    data = _load_json(COMPLETION_FILE)
    if data is None or not isinstance(data, dict):
        return {"present": False}
    scopes = {s: entry.get("status", "?") for s, entry in data.items() if isinstance(entry, dict)}
    return {"present": True, "scopes": scopes}


def _build_status():
    return {
        "boulder": _summarize_boulder(),
        "active_loop": _summarize_active_loop(),
        "evidence": _summarize_evidence(),
        "completion": _summarize_completion(),
    }


def _format_text(status):
    lines = ["=== lazykimi status ==="]
    b = status["boulder"]
    if b["present"]:
        lines.append("boulder: %s  status=%s  tasks=%d/%d  updated=%s" % (
            b.get("goal", "")[:60], b.get("status", "?"), b.get("tasks_done", 0), b.get("tasks_total", 0), b.get("updated_at", "")))
    else:
        lines.append("boulder: (none) — %s" % b.get("note", ""))
    al = status["active_loop"]
    if al["present"]:
        lines.append("active loop: loop_id=%s  objective=%s  mode=%s  status=%s  turn_count=%s  started_at=%s" % (
            al.get("loop_id", ""), al.get("objective", "")[:60], al.get("mode", "?"),
            al.get("status", "?"), al.get("turn_count", "?"), al.get("started_at", "")))
    else:
        lines.append("active loop: (none) — %s" % al.get("note", ""))
    ev = status["evidence"]
    lines.append("evidence: %d records  passed=%d  failed=%d  gates=%d" % (ev["records"], ev["passed"], ev["failed"], len(ev["gates"])))
    cp = status["completion"]
    if cp["present"]:
        lines.append("completion: %s" % ", ".join("%s=%s" % kv for kv in cp["scopes"].items()))
    else:
        lines.append("completion: (none)")
    return "\n".join(lines)


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
        reply({"protocolVersion": "2024-11-05", "capabilities": {"tools": {}}, "serverInfo": {"name": "lazykimi-status-dashboard", "version": "1.0.0"}})
        return
    if method == "tools/list":
        reply({"tools": [
            {"name": "get_status", "description": "Return a combined status snapshot: boulder (project goal/state), active loop, and evidence summary. Read-only.", "inputSchema": {"type": "object", "properties": {"format": {"type": "string", "enum": ["text", "json"], "default": "text"}}}},
        ]})
        return
    if method != "tools/call":
        err("unsupported method: " + method)
        return

    tool = params.get("name", "")
    args = params.get("arguments", {})
    try:
        if tool == "get_status":
            fmt = args.get("format", "text")
            status = _build_status()
            if fmt == "json":
                tool_result(json.dumps(status, indent=2))
            else:
                tool_result(_format_text(status))
        else:
            err("unknown tool: " + tool)
    except Exception as e:
        err("tool error: " + str(e))


def main():
    serve(handle)


if __name__ == "__main__":
    main()
