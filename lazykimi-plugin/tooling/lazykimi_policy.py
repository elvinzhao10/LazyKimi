#!/usr/bin/env python3
"""LazyKimi tooling policy engine.

Default-deny policy for the receipt-owned tooling lifecycle.
- Network access requires explicit provider selection.
- Filesystem reads are allowed by default within the workspace.
- Shell execution is denied by default.
- Default timeout is 30s; network operations use 10s.

Python stdlib only.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Final, NoReturn

DEFAULT_TIMEOUT_SECONDS: Final = 30
NETWORK_TIMEOUT_SECONDS: Final = 10

CONTRACT_VERSION: Final = "1.1.0"
PLUGIN_ROOT: Final = Path(__file__).resolve().parent.parent
CONTRACT: Final = PLUGIN_ROOT / "contracts" / "automatic-tooling-contract.v1.json"
SIDECAR: Final = CONTRACT.with_suffix(CONTRACT.suffix + ".sha256")

PERMISSION_DEFAULTS: Final = {
    "filesystem_read": "default_allow",
    "network": "default_deny",
    "shell_exec": "default_deny",
}

# Capabilities that touch the network or host-governed resources and so
# require an explicit provider selection before invocation.
EXPLICIT_PROVIDER_CAPABILITIES: Final = frozenset({
    "architecture_search",
    "documentation_search",
    "web_search",
    "external_code_search",
    "browser_automation",
})

# 8 typed error codes for the tooling lifecycle.
ERROR_CODES: Final = {
    "CAPABILITY_NOT_FOUND": "requested capability is not declared in the canonical contract",
    "PROVIDER_NOT_AVAILABLE": "no provider for the capability is available on PATH or in the tooling root",
    "PERMISSION_DENIED": "policy denied the requested capability or provider invocation",
    "TIMEOUT_EXCEEDED": "provider invocation exceeded the configured timeout",
    "NETWORK_NOT_ALLOWED": "network access requires explicit provider selection",
    "TOOLING_ROOT_NOT_EMPTY": "tooling root must be empty or receipt-owned before install",
    "RECEIPT_MISMATCH": "tooling root receipt is stale, modified, or mismatched",
    "CONTRACT_VERSION_MISMATCH": "contract version does not match the broker's expected version",
}


class PolicyError(Exception):
    """Typed policy failure carrying one of the ERROR_CODES keys."""

    def __init__(self, code: str, message: str) -> None:
        self.code = code
        self.message = message
        super().__init__(message)


def fail(code: str, message: str) -> NoReturn:
    raise PolicyError(code, message)


def contract_digest() -> str:
    """Return the sha256 of the contract file, validating the sidecar first."""
    try:
        raw = CONTRACT.read_bytes()
        declared = SIDECAR.read_text(encoding="utf-8").split()[0]
        value = json.loads(raw)
    except (FileNotFoundError, IndexError, json.JSONDecodeError):
        fail("CONTRACT_VERSION_MISMATCH", "contract or sha256 sidecar is unreadable")
    if hashlib.sha256(raw).hexdigest() != declared:
        fail("RECEIPT_MISMATCH", "contract sha256 sidecar does not match the contract file")
    if value.get("contract_version") != CONTRACT_VERSION:
        fail(
            "CONTRACT_VERSION_MISMATCH",
            f"contract version {value.get('contract_version')!r} != expected {CONTRACT_VERSION!r}",
        )
    return declared


def is_allowed(action: str) -> bool:
    return PERMISSION_DEFAULTS.get(action, "default_deny") == "default_allow"


def requires_explicit_provider_selection(capability: str) -> bool:
    return capability in EXPLICIT_PROVIDER_CAPABILITIES


def timeout_for(capability: str) -> int:
    if requires_explicit_provider_selection(capability):
        return NETWORK_TIMEOUT_SECONDS
    return DEFAULT_TIMEOUT_SECONDS


def validate_tooling_root(tooling_root: Path) -> Path:
    """Validate that the tooling root is absolute, traversal-free, and not a symlink."""
    path = Path(tooling_root)
    if not path.is_absolute() or ".." in path.parts:
        fail("PERMISSION_DENIED", "tooling root must be an absolute traversal-free path")
    if path.is_symlink():
        fail("PERMISSION_DENIED", "tooling root must not be a symlink")
    return path.resolve()


def authorize(capability: str, action: str = "filesystem_read") -> None:
    """Authorize a capability invocation under the default-deny policy."""
    if action == "network" and not is_allowed("network"):
        if requires_explicit_provider_selection(capability):
            fail("NETWORK_NOT_ALLOWED", f"capability {capability!r} requires explicit provider selection")
    if action == "shell_exec" and not is_allowed("shell_exec"):
        fail("PERMISSION_DENIED", "shell execution is denied by default")


def error_codes() -> list[dict[str, str]]:
    return [{"code": code, "description": desc} for code, desc in ERROR_CODES.items()]


def main() -> int:
    print(json.dumps({
        "contract_version": CONTRACT_VERSION,
        "permissions": PERMISSION_DEFAULTS,
        "timeouts": {"default_seconds": DEFAULT_TIMEOUT_SECONDS, "network_seconds": NETWORK_TIMEOUT_SECONDS},
        "error_codes": error_codes(),
    }, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
