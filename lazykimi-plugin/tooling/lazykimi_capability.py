#!/usr/bin/env python3
"""LazyKimi capability broker: receipt-owned detect/install/verify/status.

Installs land in an explicit empty caller-selected absolute tooling root;
JSON receipts are written into tooling_root/receipts/. Python stdlib only.
"""
from __future__ import annotations

import json
import os
import shutil
import stat
import subprocess
import time
from pathlib import Path
from typing import Final, NoReturn

from lazykimi_detector import detect_all
from lazykimi_policy import (
    CONTRACT_VERSION,
    PolicyError,
    contract_digest,
    fail,
    requires_explicit_provider_selection,
    timeout_for,
    validate_tooling_root,
)

PLUGIN_ROOT: Final = Path(__file__).resolve().parent.parent
CAPABILITIES_FILE: Final = PLUGIN_ROOT / "tooling" / "capabilities.json"
RECEIPTS_DIR_NAME: Final = "receipts"
PROVIDERS_DIR_NAME: Final = "providers"
ALLOWED_ROOT_ENTRIES: Final = frozenset({RECEIPTS_DIR_NAME, PROVIDERS_DIR_NAME})

# Map capability -> default provider command used for PATH detection.
CAPABILITY_TO_COMMAND: Final = {
    "local_search": "rg",
    "structural_search": "sg",
    "code_navigation": "typescript-language-server",
    "architecture_search": "codegraph",
    "documentation_search": "context7",
    "web_search": "web",
    "external_code_search": "grep_app",
    "browser_automation": "playwright",
    "filesystem_read": "filesystem",
}

# Capabilities that can be staged from a host-installed binary into the
# receipt-owned tooling root. Remote/host-governed capabilities are not
# auto-installable and require explicit provider selection.
LOCALLY_INSTALLABLE: Final = frozenset({
    "local_search",
    "structural_search",
    "code_navigation",
    "architecture_search",
    "browser_automation",
})


def _load_capabilities() -> list[dict[str, object]]:
    try:
        data = json.loads(CAPABILITIES_FILE.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        fail("CAPABILITY_NOT_FOUND", f"capabilities.json is unreadable: {error}")
    capabilities = data.get("capabilities") if isinstance(data, dict) else None
    if not isinstance(capabilities, list):
        fail("CAPABILITY_NOT_FOUND", "capabilities.json has no capabilities array")
    return capabilities


def detect_capability(name: str) -> dict[str, object]:
    """Check if the tool backing the capability is on PATH."""
    if name not in CAPABILITY_TO_COMMAND:
        fail("CAPABILITY_NOT_FOUND", f"unknown capability {name!r}")
    detected = detect_all()
    command = CAPABILITY_TO_COMMAND[name]
    explicit = requires_explicit_provider_selection(name)
    # code_navigation may be served by either LSP command.
    candidates = ("typescript-language-server", "basedpyright") if name == "code_navigation" else (command,)
    for candidate in candidates:
        info = detected.get(candidate)
        if info and info.get("available"):
            return {
                "capability": name,
                "command": candidate,
                "available": True,
                "path": str(info.get("path", "")),
                "version": str(info.get("version", "")),
                "requires_explicit_provider_selection": explicit,
            }
    return {
        "capability": name,
        "command": command,
        "available": False,
        "path": "",
        "version": "",
        "requires_explicit_provider_selection": explicit,
    }


def _ensure_empty_tooling_root(tooling_root: Path) -> Path:
    root = validate_tooling_root(tooling_root)
    if root.exists():
        if not root.is_dir():
            fail("TOOLING_ROOT_NOT_EMPTY", "tooling root must be a directory")
        unexpected = [e.name for e in root.iterdir() if e.name not in ALLOWED_ROOT_ENTRIES]
        if unexpected:
            fail("TOOLING_ROOT_NOT_EMPTY", f"tooling root contains unexpected entries: {sorted(unexpected)}")
    root.mkdir(mode=0o700, parents=True, exist_ok=True)
    os.chmod(root, 0o700)
    return root


def _receipt_path(tooling_root: Path, capability: str) -> Path:
    return tooling_root / RECEIPTS_DIR_NAME / f"{capability}.receipt.json"


def _write_receipt(tooling_root: Path, capability: str, payload: dict[str, object]) -> Path:
    receipts = tooling_root / RECEIPTS_DIR_NAME
    receipts.mkdir(mode=0o700, parents=True, exist_ok=True)
    os.chmod(receipts, 0o700)
    target = _receipt_path(tooling_root, capability)
    temporary = target.with_suffix(f".tmp.{os.getpid()}")
    descriptor = os.open(temporary, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
    with os.fdopen(descriptor, "w", encoding="utf-8") as output:
        json.dump(payload, output, indent=2, sort_keys=True)
        output.write("\n")
    os.replace(temporary, target)
    os.chmod(target, 0o600)
    return target


def install_capability(name: str, tooling_root: str | Path) -> dict[str, object]:
    """Install the capability's provider into the receipt-owned tooling root."""
    if name not in CAPABILITY_TO_COMMAND:
        fail("CAPABILITY_NOT_FOUND", f"unknown capability {name!r}")
    if name not in LOCALLY_INSTALLABLE:
        fail("NETWORK_NOT_ALLOWED", f"capability {name!r} is not auto-installable; configure its provider explicitly")
    root = _ensure_empty_tooling_root(Path(tooling_root))
    digest = contract_digest()
    detection = detect_capability(name)
    if not detection["available"]:
        fail("PROVIDER_NOT_AVAILABLE", f"host provider for {name!r} is not on PATH")
    source = Path(str(detection["path"]))
    providers_bin = root / PROVIDERS_DIR_NAME / "bin"
    providers_bin.mkdir(mode=0o700, parents=True, exist_ok=True)
    os.chmod(providers_bin, 0o700)
    destination = providers_bin / source.name
    if destination.is_symlink() or destination.exists():
        destination.unlink()
    try:
        os.symlink(source, destination)
    except OSError:
        shutil.copy2(source, destination)
    os.chmod(destination, 0o700)
    payload = {
        "schema_version": 1,
        "owner": "lazykimi-capability-broker",
        "capability": name,
        "command": detection["command"],
        "source_path": str(source),
        "source_version": detection["version"],
        "installed_path": str(destination),
        "tooling_root": str(root),
        "contract_digest": digest,
        "contract_version": CONTRACT_VERSION,
        "installed_at": int(time.time()),
    }
    receipt = _write_receipt(root, name, payload)
    return {"capability": name, "installed": True, "receipt": str(receipt), "installed_path": str(destination)}


def verify_capability(name: str, tooling_root: str | Path) -> dict[str, object]:
    """Verify that the installed provider still works after install."""
    if name not in CAPABILITY_TO_COMMAND:
        fail("CAPABILITY_NOT_FOUND", f"unknown capability {name!r}")
    root = validate_tooling_root(Path(tooling_root))
    receipt = _receipt_path(root, name)
    if not receipt.is_file():
        fail("RECEIPT_MISMATCH", f"no receipt found for {name!r} in {root}")
    if receipt.is_symlink() or stat.S_IMODE(receipt.stat().st_mode) != 0o600:
        fail("RECEIPT_MISMATCH", f"receipt for {name!r} must be a non-symlink mode 0600 file")
    try:
        payload = json.loads(receipt.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        fail("RECEIPT_MISMATCH", f"receipt for {name!r} is unreadable")
    if payload.get("contract_version") != CONTRACT_VERSION:
        fail("CONTRACT_VERSION_MISMATCH", "receipt contract version does not match broker version")
    declared_digest = payload.get("contract_digest")
    if not isinstance(declared_digest, str) or declared_digest != contract_digest():
        fail("RECEIPT_MISMATCH", "receipt contract digest does not match the live contract")
    installed_path = Path(str(payload.get("installed_path", "")))
    if not installed_path.is_file() or not os.access(installed_path, os.X_OK):
        fail("PROVIDER_NOT_AVAILABLE", f"installed provider for {name!r} is missing or not executable")
    timeout = timeout_for(name)
    try:
        result = subprocess.run(
            [str(installed_path), "--version"],
            capture_output=True,
            text=True,
            timeout=timeout,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        fail("PROVIDER_NOT_AVAILABLE", f"installed provider for {name!r} failed to run")
    version_lines = (result.stdout or result.stderr or "").strip().splitlines()
    version = version_lines[0] if version_lines else ""
    return {
        "capability": name,
        "verified": True,
        "receipt": str(receipt),
        "installed_path": str(installed_path),
        "version": version,
    }


def get_status() -> dict[str, object]:
    """Return the overall status of all capabilities."""
    detected = detect_all()
    capabilities_status: list[dict[str, object]] = []
    for name in CAPABILITY_TO_COMMAND:
        detection = detect_capability(name)
        capabilities_status.append({
            "capability": name,
            "available": detection["available"],
            "path": detection["path"],
            "version": detection["version"],
            "requires_explicit_provider_selection": detection["requires_explicit_provider_selection"],
            "auto_installable": name in LOCALLY_INSTALLABLE,
        })
    try:
        digest = contract_digest()
    except PolicyError:
        digest = ""
    return {
        "contract_version": CONTRACT_VERSION,
        "contract_digest": digest,
        "capabilities": capabilities_status,
        "detected_tools": detected,
    }


def main() -> int:
    print(json.dumps(get_status(), indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
