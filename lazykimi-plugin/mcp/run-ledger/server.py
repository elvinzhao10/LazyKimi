#!/usr/bin/env python3
"""run-ledger MCP server — autonomous run state ledger for lazykimi.

Manages per-run state under `.lazykimi/state/runs/<run_id>/` and the active-loop
pointer at `.lazykimi/state/active-loop.json`. Replaces the LazyBuddy runs/ dir
layout with a state/+runs/ split as required by the Kimi Code CLI port.

Tools: create_run, list_runs, latest_run, read_state, append_event,
       update_task, create_checkpoint, recover_run, get_active_plan,
       generate_handoff.
"""
import json
import os
import re
import sys
import time

MCP_ROOT = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
if MCP_ROOT not in sys.path:
    sys.path.insert(0, MCP_ROOT)
from jsonrpc import serve

CWD = os.environ.get("CWD", ".")
LAZYKIMI = os.path.join(CWD, ".lazykimi")
STATE_DIR = os.path.join(LAZYKIMI, "state")
RUNS_DIR = os.path.join(STATE_DIR, "runs")
INDEX_FILE = os.path.join(STATE_DIR, "index.json")
ACTIVE_LOOP_FILE = os.path.join(STATE_DIR, "active-loop.json")
BOULDER_FILE = os.path.join(STATE_DIR, "boulder.json")
EVIDENCE_DIR = os.path.join(LAZYKIMI, "evidence")
SAFE_RUN_ID = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.-]*$")


def _now():
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


def _load_json(path):
    try:
        with open(path) as f:
            return json.load(f)
    except (OSError, ValueError):
        return None


def _recent_evidence(limit=5):
    try:
        entries = os.listdir(EVIDENCE_DIR)
    except OSError:
        return []
    files = []
    for name in entries:
        if name.endswith(".md"):
            p = os.path.join(EVIDENCE_DIR, name)
            try:
                st = os.stat(p)
                files.append((st.st_mtime, name))
            except OSError:
                continue
    files.sort(reverse=True)
    return [name for _, name in files[:limit]]


def _get_active_plan():
    boulder = _load_json(BOULDER_FILE)
    active_loop = _load_json(ACTIVE_LOOP_FILE)
    work_id = None
    if isinstance(boulder, dict):
        work_id = boulder.get("active_work_id") or None
    if work_id is None and isinstance(active_loop, dict):
        work_id = active_loop.get("loop_id") or None
    if not work_id:
        return None
    works = boulder.get("works", {}) if isinstance(boulder, dict) else {}
    work = works.get(work_id)
    if not isinstance(work, dict):
        return None
    return {
        "plan_path": work.get("active_plan", ""),
        "plan_name": work.get("plan_name", ""),
        "work_id": work.get("work_id", work_id),
    }


def _generate_handoff():
    lines = ["# LazyKimi Handoff", ""]
    plan = _get_active_plan()
    boulder = _load_json(BOULDER_FILE)
    active_loop = _load_json(ACTIVE_LOOP_FILE)
    lines.append("## Active Work")
    if plan:
        work = {}
        if isinstance(boulder, dict):
            work = boulder.get("works", {}).get(plan["work_id"], {})
        lines.append("- work_id: %s" % plan["work_id"])
        lines.append("- plan_path: %s" % plan["plan_path"])
        lines.append("- plan_name: %s" % plan["plan_name"])
        lines.append("- status: %s" % work.get("status", ""))
    else:
        lines.append("- (none)")
    lines.append("")
    lines.append("## Active Loop")
    if isinstance(active_loop, dict):
        for key in ("loop_id", "objective", "mode", "status", "turn_count", "started_at"):
            lines.append("- %s: %s" % (key, active_loop.get(key, "")))
    else:
        lines.append("- (none)")
    lines.append("")
    lines.append("## Recent Evidence")
    recent = _recent_evidence()
    if recent:
        for name in recent:
            lines.append("- %s" % name)
    else:
        lines.append("- (none)")
    lines.append("")
    return "\n".join(lines)


def _run_dir(run_id):
    if not isinstance(run_id, str) or not SAFE_RUN_ID.match(run_id):
        return None
    return os.path.join(RUNS_DIR, run_id)


def _load_index():
    try:
        with open(INDEX_FILE) as f:
            data = json.load(f)
        return data if isinstance(data, dict) else {}
    except (OSError, ValueError):
        return {}


def _save_index(idx):
    os.makedirs(STATE_DIR, exist_ok=True)
    tmp = INDEX_FILE + ".tmp"
    with open(tmp, "w") as f:
        json.dump(idx, f, separators=(",", ":"))
    os.replace(tmp, INDEX_FILE)


def _load_state(run_dir):
    try:
        with open(os.path.join(run_dir, "state.json")) as f:
            return json.load(f)
    except (OSError, ValueError):
        return None


def _save_state(run_dir, state):
    os.makedirs(run_dir, exist_ok=True)
    state["updated_at"] = _now()
    tmp = os.path.join(run_dir, "state.json.tmp")
    with open(tmp, "w") as f:
        json.dump(state, f, separators=(",", ":"))
    os.replace(tmp, os.path.join(run_dir, "state.json"))


def _set_active(run_id, objective):
    os.makedirs(STATE_DIR, exist_ok=True)
    tmp = ACTIVE_LOOP_FILE + ".tmp"
    with open(tmp, "w") as f:
        json.dump({
            "loop_id": run_id,
            "objective": objective,
            "mode": "goal",
            "started_at": _now(),
            "turn_count": 0,
            "status": "active",
        }, f, separators=(",", ":"))
    os.replace(tmp, ACTIVE_LOOP_FILE)


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
        reply({"protocolVersion": "2024-11-05", "capabilities": {"tools": {}}, "serverInfo": {"name": "lazykimi-run-ledger", "version": "1.0.0"}})
        return
    if method == "tools/list":
        reply({"tools": [
            {"name": "create_run", "description": "Create a new autonomous run with an objective.", "inputSchema": {"type": "object", "properties": {"run_id": {"type": "string"}, "objective": {"type": "string"}}, "required": ["run_id", "objective"]}},
            {"name": "list_runs", "description": "List all runs with status.", "inputSchema": {"type": "object", "properties": {}}},
            {"name": "latest_run", "description": "Get the most recently updated active run id.", "inputSchema": {"type": "object", "properties": {}}},
            {"name": "read_state", "description": "Read full state.json for a run.", "inputSchema": {"type": "object", "properties": {"run_id": {"type": "string"}}, "required": ["run_id"]}},
            {"name": "append_event", "description": "Append an event to events.jsonl.", "inputSchema": {"type": "object", "properties": {"run_id": {"type": "string"}, "event_type": {"type": "string"}, "payload": {"type": "object"}}, "required": ["run_id", "event_type"]}},
            {"name": "update_task", "description": "Update a task status in state.json.", "inputSchema": {"type": "object", "properties": {"run_id": {"type": "string"}, "task_id": {"type": "string"}, "status": {"type": "string"}}, "required": ["run_id", "task_id", "status"]}},
            {"name": "create_checkpoint", "description": "Snapshot current state under checkpoints/.", "inputSchema": {"type": "object", "properties": {"run_id": {"type": "string"}}, "required": ["run_id"]}},
            {"name": "recover_run", "description": "Restore state from the latest checkpoint.", "inputSchema": {"type": "object", "properties": {"run_id": {"type": "string"}}, "required": ["run_id"]}},
            {"name": "get_active_plan", "description": "Return the active plan path/name/work_id from boulder + active-loop, or null if none.", "inputSchema": {"type": "object", "properties": {}}},
            {"name": "generate_handoff", "description": "Generate a Markdown handoff summary of active work, active loop, and recent evidence.", "inputSchema": {"type": "object", "properties": {}}},
        ]})
        return
    if method != "tools/call":
        err("unsupported method: " + method)
        return

    tool = params.get("name", "")
    args = params.get("arguments", {})
    try:
        if tool == "create_run":
            run_id = _req_str(args, "run_id")
            objective = _req_str(args, "objective")
            rdir = _run_dir(run_id)
            if rdir is None:
                err("invalid or unsafe run_id")
            elif os.path.exists(os.path.join(rdir, "state.json")):
                err("run already exists: %s" % run_id)
            else:
                state = {"run_id": run_id, "objective": objective, "status": "active", "created_at": _now(), "updated_at": _now(), "tasks": [], "iteration_count": 0, "last_checkpoint": ""}
                _save_state(rdir, state)
                idx = _load_index()
                idx[run_id] = {"status": "active", "updated_at": state["updated_at"], "objective": objective}
                _save_index(idx)
                _set_active(run_id, objective)
                tool_result("created run %s\nobjective: %s" % (run_id, objective))
        elif tool == "list_runs":
            idx = _load_index()
            runs = sorted(idx.items(), key=lambda kv: kv[1].get("updated_at", ""), reverse=True)
            out = "runs (%d):\n" % len(runs)
            for run_id, meta in runs:
                out += "  %s  %s  %s\n" % (run_id, meta.get("status", "?"), meta.get("objective", "")[:60])
            tool_result(out)
        elif tool == "latest_run":
            idx = _load_index()
            if not idx:
                err("no runs found")
            else:
                tool_result(max(idx.items(), key=lambda kv: kv[1].get("updated_at", ""))[0])
        elif tool == "read_state":
            rdir = _run_dir(_req_str(args, "run_id"))
            if rdir is None or not os.path.isfile(os.path.join(rdir, "state.json")):
                err("run not found")
            else:
                tool_result(json.dumps(_load_state(rdir), indent=2))
        elif tool == "append_event":
            rdir = _run_dir(_req_str(args, "run_id"))
            payload = args.get("payload", {})
            if rdir is None or not os.path.isdir(rdir):
                err("run not found")
            elif not isinstance(payload, dict):
                err("payload must be an object")
            else:
                event = {"ts": _now(), "run_id": args["run_id"], "event_type": _req_str(args, "event_type"), "payload": payload}
                with open(os.path.join(rdir, "events.jsonl"), "a") as f:
                    f.write(json.dumps(event, separators=(",", ":")) + "\n")
                tool_result("event appended: %s" % event["event_type"])
        elif tool == "update_task":
            run_id = _req_str(args, "run_id")
            rdir = _run_dir(run_id)
            task_id = _req_str(args, "task_id")
            status = _req_str(args, "status")
            if rdir is None or not os.path.isdir(rdir):
                err("run not found")
            else:
                state = _load_state(rdir)
                if state is None:
                    err("run state missing")
                else:
                    tasks = state.get("tasks", [])
                    for t in tasks:
                        if t.get("id") == task_id:
                            t["status"] = status
                            break
                    else:
                        tasks.append({"id": task_id, "title": task_id, "status": status, "depends_on": []})
                        state["tasks"] = tasks
                    _save_state(rdir, state)
                    idx = _load_index()
                    if run_id in idx:
                        idx[run_id]["updated_at"] = state["updated_at"]
                        _save_index(idx)
                    tool_result("task %s -> %s" % (task_id, status))
        elif tool == "create_checkpoint":
            rdir = _run_dir(_req_str(args, "run_id"))
            if rdir is None or not os.path.isdir(rdir):
                err("run not found")
            else:
                state = _load_state(rdir)
                if state is None:
                    err("run state missing")
                else:
                    cp_dir = os.path.join(rdir, "checkpoints")
                    os.makedirs(cp_dir, exist_ok=True)
                    ts = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())
                    cp_file = os.path.join(cp_dir, "%s.json" % ts)
                    with open(cp_file, "w") as f:
                        json.dump(state, f, separators=(",", ":"))
                    state["last_checkpoint"] = cp_file
                    _save_state(rdir, state)
                    tool_result("checkpoint: %s" % cp_file)
        elif tool == "recover_run":
            rdir = _run_dir(_req_str(args, "run_id"))
            if rdir is None or not os.path.isdir(rdir):
                err("run not found")
            else:
                cp_dir = os.path.join(rdir, "checkpoints")
                cps = sorted(os.listdir(cp_dir)) if os.path.isdir(cp_dir) else []
                if not cps:
                    err("no checkpoints found")
                else:
                    with open(os.path.join(cp_dir, cps[-1])) as f:
                        _save_state(rdir, json.load(f))
                    tool_result("recovered from %s" % cps[-1])
        elif tool == "get_active_plan":
            tool_result(json.dumps(_get_active_plan()))
        elif tool == "generate_handoff":
            tool_result(_generate_handoff())
        else:
            err("unknown tool: " + tool)
    except Exception as e:
        err("tool error: " + str(e))


def main():
    serve(handle)


if __name__ == "__main__":
    main()
