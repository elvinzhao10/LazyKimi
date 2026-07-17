"""Shared JSON-RPC 2.0 line-protocol loop for lazykimi MCP servers.

Reads newline-delimited JSON-RPC requests from stdin, dispatches each to a
handler callable, and writes one JSON-RPC response per line to stdout.
Malformed input never crashes the loop; it produces a JSON-RPC error response.

A handler is `handler(request: dict, notification: bool)`. The handler is
responsible for emitting its own reply via stdout (so it can decide whether to
suppress replies for notifications). This keeps the loop minimal and the
handler in full control of response shaping.
"""
import json
import math
import sys


class JsonRpcLoop:
    """Line-delimited JSON-RPC 2.0 server loop over stdio."""

    def _error(self, code, message, request_id=None):
        sys.stdout.write(
            json.dumps(
                {"jsonrpc": "2.0", "id": request_id, "error": {"code": code, "message": message}},
                separators=(",", ":"),
            )
            + "\n"
        )
        sys.stdout.flush()

    @staticmethod
    def _valid_id(value):
        if value is None or isinstance(value, str):
            return True
        if isinstance(value, bool):
            return False
        return isinstance(value, int) or (isinstance(value, float) and math.isfinite(value))

    def _classify(self, line):
        try:
            request = json.loads(line)
        except (json.JSONDecodeError, ValueError):
            return None, "parse"
        if (
            not isinstance(request, dict)
            or request.get("jsonrpc") != "2.0"
            or not isinstance(request.get("method"), str)
            or request["method"].startswith("rpc.")
            or ("id" in request and not self._valid_id(request["id"]))
        ):
            return None, "invalid"
        return request, "notification" if "id" not in request else "request"

    def run(self, handler):
        for line in sys.stdin:
            line = line.strip()
            if not line:
                continue
            request, kind = self._classify(line)
            if kind == "parse":
                self._error(-32700, "Parse error")
                continue
            if kind == "invalid":
                self._error(-32600, "Invalid Request")
                continue
            if request["method"] == "tools/call":
                params = request.get("params")
                if (
                    not isinstance(params, dict)
                    or not isinstance(params.get("name"), str)
                    or not isinstance(params.get("arguments", {}), dict)
                ):
                    if "id" in request:
                        self._error(
                            -32602,
                            "tools/call requires object params with string name and object arguments",
                            request["id"],
                        )
                    continue
            try:
                handler(request, "id" not in request)
            except Exception as exc:  # never crash the loop
                if "id" in request:
                    self._error(-32603, "internal error: %s" % exc, request["id"])


def serve(handler):
    """Convenience entry point: run a JsonRpcLoop with the given handler."""
    JsonRpcLoop().run(handler)
