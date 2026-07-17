#!/usr/bin/env python3
"""LazyKimi tooling detector.

Detects the availability, path, and version of host-installed tools that back
the receipt-owned tooling capabilities. Uses shutil.which() for PATH lookup and
subprocess.run() for version probes. Python stdlib only.
"""
from __future__ import annotations

import shutil
import subprocess
from typing import Final

# Tool name -> command used for both `which` lookup and `--version` probe.
TOOLS: Final = (
    "rg",
    "sg",
    "typescript-language-server",
    "basedpyright",
    "codegraph",
    "playwright",
)

VERSION_TIMEOUT_SECONDS: Final = 5


def _detect_one(command: str) -> dict[str, object]:
    path = shutil.which(command)
    if path is None:
        return {"available": False, "path": "", "version": ""}
    try:
        result = subprocess.run(
            [command, "--version"],
            capture_output=True,
            text=True,
            timeout=VERSION_TIMEOUT_SECONDS,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return {"available": True, "path": path, "version": ""}
    output = (result.stdout or result.stderr or "").strip()
    version = output.splitlines()[0] if output else ""
    return {"available": True, "path": path, "version": version}


def detect_all() -> dict[str, dict[str, object]]:
    """Return a dict of tool_name -> {available, path, version} for all tools."""
    return {name: _detect_one(name) for name in TOOLS}


def main() -> int:
    import json

    print(json.dumps(detect_all(), indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
