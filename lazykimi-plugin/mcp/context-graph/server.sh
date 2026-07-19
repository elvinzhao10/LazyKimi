#!/usr/bin/env bash
# context-graph MCP server launcher — execs the Python stdio JSON-RPC server.
exec python3 "$(dirname "$0")/server.py" "$@"
