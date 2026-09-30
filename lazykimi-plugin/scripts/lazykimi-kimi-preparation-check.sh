#!/usr/bin/env bash
# lazykimi-kimi-preparation-check.sh — ported from lazyzcode v1.3.3
# scripts/lazyzcode-zcode-preparation-check.sh, Kimi-adapted.
#
# Read-only preflight for the package inputs a Kimi host cache-preparation
# route would consume. This command never changes Kimi host state, and it
# never fabricates unobserved host cache layouts: the Kimi plugin-cache
# directory structure is a T21 host-verification item and stays explicitly
# unverified here.
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: bash lazykimi-plugin/scripts/lazykimi-kimi-preparation-check.sh --project-dir <absolute-project-root>

Read-only check for the package inputs used by a Kimi host's
cache-preparation route. This command never changes Kimi host state.
EOF
}

refuse_apply() {
    printf '%s\n' \
        "ERROR: --apply is unsupported: the Kimi host's plugin cache layout is an unverified, undocumented schema; no host state was changed." >&2
    exit 2
}

for argument in "$@"; do
    if [ "$argument" = '--apply' ]; then
        refuse_apply
    fi
done

PROJECT_DIR=
while [ "$#" -gt 0 ]; do
    case "$1" in
        --project-dir)
            if [ "$#" -lt 2 ] || [ -z "$2" ]; then
                printf 'ERROR: --project-dir requires an absolute project root\n' >&2
                exit 2
            fi
            PROJECT_DIR="$2"
            shift 2
            ;;
        --apply)
            refuse_apply
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            printf 'ERROR: unknown argument; run with --help for supported options\n' >&2
            usage >&2
            exit 2
            ;;
    esac
done

if [ -z "$PROJECT_DIR" ]; then
    printf 'ERROR: --project-dir is required\n' >&2
    usage >&2
    exit 2
fi
case "$PROJECT_DIR" in
    /*) ;;
    *)
        printf 'ERROR: project root must be an absolute path\n' >&2
        exit 2
        ;;
esac
if [ ! -d "$PROJECT_DIR" ]; then
    printf 'ERROR: project root directory is missing\n' >&2
    exit 1
fi
if ! PROJECT_ROOT="$(CDPATH= cd -- "$PROJECT_DIR" 2>/dev/null && pwd -P)"; then
    printf 'ERROR: project root directory is inaccessible\n' >&2
    exit 1
fi

if ! SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd -P)" \
    || ! PLUGIN_ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/.." 2>/dev/null && pwd -P)" \
    || ! RELEASE_ROOT="$(CDPATH= cd -- "$PLUGIN_ROOT/.." 2>/dev/null && pwd -P)"; then
    printf 'ERROR: LazyKimi package location is inaccessible\n' >&2
    exit 1
fi

if [ ! -f "$PLUGIN_ROOT/kimi.plugin.json" ] \
    || [ ! -f "$PLUGIN_ROOT/.kimi-code/mcp.json" ] \
    || [ ! -f "$PLUGIN_ROOT/marketplace.json" ]; then
    printf '%s\n' \
        'ERROR: LazyKimi plugin root is unavailable; keep this script under the v1.3.3 lazykimi-plugin/scripts directory.' >&2
    exit 1
fi

python3 -B - "$PLUGIN_ROOT" "$RELEASE_ROOT" "$PROJECT_ROOT" <<'PY'
import json
import os
from pathlib import Path
import stat
import sys

plugin_root = Path(sys.argv[1]).resolve()
release_root = Path(sys.argv[2]).resolve()
project_root = Path(sys.argv[3]).resolve()
version = "1.3.3"
server_names = (
    "lazykimi-run-ledger",
    "lazykimi-verification",
    "lazykimi-status-dashboard",
    "lazykimi-context-graph",
    "lazykimi-code-intel",
    "lazykimi-docs",
)

def load_object(path: Path, label: str):
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except OSError:
        raise ValueError(f"{label} is unavailable") from None
    except json.JSONDecodeError as exc:
        raise ValueError(
            f"{label} is invalid JSON at line {exc.lineno}, column {exc.colno}"
        ) from None
    if not isinstance(value, dict):
        raise ValueError(f"{label} must be a JSON object")
    return value

try:
    work_manifest = load_object(
        plugin_root / "kimi.plugin.json",
        "Kimi manifest",
    )
    if work_manifest.get("name") != "lazykimi" or work_manifest.get("version") != version:
        raise ValueError("Kimi manifest must identify lazykimi version 1.3.3")

    marketplace = load_object(
        plugin_root / "marketplace.json",
        "release marketplace",
    )
    entries = marketplace.get("plugins")
    if marketplace.get("version") != "2" or not isinstance(entries, list):
        raise ValueError("release marketplace must be the v2 shape with a plugins array")
    entry = next(
        (
            item
            for item in entries
            if isinstance(item, dict) and item.get("id") == "lazykimi"
        ),
        None,
    )
    if entry is None or entry.get("source") != "./":
        raise ValueError("release marketplace must contain lazykimi from ./")
    if (plugin_root / entry["source"]).resolve() != plugin_root:
        raise ValueError("release marketplace source does not resolve to this plugin root")

    source_mcp = load_object(plugin_root / ".kimi-code" / "mcp.json", "MCP configuration")
    if set(source_mcp) != {"mcpServers"}:
        raise ValueError("MCP configuration must contain only the mcpServers object")
    servers = source_mcp.get("mcpServers")
    if not isinstance(servers, dict) or tuple(servers) != server_names:
        raise ValueError("MCP configuration must declare the six lazykimi servers in canonical order")

    rendered = {}
    for name in server_names:
        source = servers[name]
        if not isinstance(source, dict):
            raise ValueError(f"MCP server {name} must be a JSON object")
        if set(source) != {"command", "args", "env", "cwd", "required"}:
            raise ValueError(
                f"MCP server {name} fields are unsupported; "
                "expected exactly command, args, env, cwd, and required"
            )
        bare = name[len("lazykimi-"):]
        expected_arg = f"__KIMI_PLUGIN_ROOT__/mcp/{bare}/server.sh"
        if source.get("command") != "bash" or source.get("args") != [expected_arg]:
            raise ValueError(f"MCP server {name} must use its package launcher template")
        source_env = source.get("env")
        expected_env = {
            "LAZYKIMI_MCP_MODE": "__KIMI_MCP_MODE__",
            "CWD": "__KIMI_PROJECT_ROOT__",
        }
        if source_env != expected_env:
            raise ValueError(f"MCP server {name} has invalid env process context")
        launcher = plugin_root / "mcp" / bare / "server.sh"
        try:
            launcher_mode = launcher.lstat().st_mode
        except OSError:
            raise ValueError(
                f"MCP server {name} launcher must be a regular, non-symlink executable"
            ) from None
        if (
            stat.S_ISLNK(launcher_mode)
            or not stat.S_ISREG(launcher_mode)
            or not os.access(launcher, os.X_OK)
        ):
            raise ValueError(
                f"MCP server {name} launcher must be a regular, non-symlink executable"
            )
        try:
            resolved_launcher = launcher.resolve(strict=True)
        except OSError:
            raise ValueError(
                f"MCP server {name} launcher must be a regular, non-symlink executable"
            ) from None
        if resolved_launcher != launcher:
            raise ValueError(
                f"MCP server {name} launcher path must not contain symlinks"
            )
        rendered[name] = {
            "command": "bash",
            "args": [str(launcher)],
            "cwd": str(project_root),
            "env": {
                "CWD": str(project_root),
                "LAZYKIMI_MCP_MODE": "orchestrated",
            },
        }

    print(
        "MCP_RENDER_JSON="
        + json.dumps({"mcpServers": rendered}, ensure_ascii=False, separators=(",", ":"))
    )
    print(
        "PATHS_JSON="
        + json.dumps(
            {
                "pluginRoot": str(plugin_root),
                "releaseRoot": str(release_root),
                "projectRoot": str(project_root),
                # The Kimi host's plugin-cache layout is not observed yet
                # (T21 item); report it as unverified instead of inventing it.
                "cacheTarget": "unverified-host-path (Kimi plugin cache layout pending host observation)",
                "registryTarget": "unverified-host-path (Kimi plugin registry pending host observation)",
            },
            ensure_ascii=False,
            separators=(",", ":"),
        )
    )
except ValueError as exc:
    print(f"ERROR: {exc}", file=sys.stderr)
    raise SystemExit(1)
PY

printf 'PACKAGE_PREPARATION=ready\n'
printf 'MCP_RENDER=ready (6 absolute launchers; cwd and CWD set; orchestrated default)\n'
printf 'HOST_PREPARATION=not-applied\n'
printf 'HOST_MUTATION=none\n'
printf 'HOST_READINESS=pending\n'
