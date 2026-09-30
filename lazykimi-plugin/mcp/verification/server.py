#!/usr/bin/env python3
"""verification MCP server entry — plugin-manifest route.

The Kimi plugin manifest invokes every inline MCP server as
`python3 ./mcp/<server>/server.py`, while the project `.kimi-code/mcp.json`
route invokes `bash .../mcp/<server>/server.sh`. The v1.3.3 verification
implementation is the bash JSON-RPC loop in server.sh (delegating to
scripts/state/*, scripts/loop/*, and scripts/runtime-freshness-entry.js);
this entry execs that launcher with the same stdin/stdout/stderr so both
routes run identical code. No env plumbing exists on the manifest route, so
the profile gate stays at its orchestrated default (all six servers active).
"""
import os
import sys

HERE = os.path.dirname(os.path.realpath(__file__))
os.execvp("bash", ["bash", os.path.join(HERE, "server.sh")] + sys.argv[1:])
