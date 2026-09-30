#!/usr/bin/env bash
# LazyKimi v1.3.3 MCP path traversal regression test.
# Verifies resolve_repo_path() rejects escapes (family v1.3.3 API surface —
# path_boundary.py is the LazyZCode v1.3.3 implementation; the v0.x
# safeProjectPath alias was dropped upstream in favor of the raising API).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PATH_BOUNDARY="${PLUGIN_ROOT}/mcp/path_boundary.py"

fail() { echo "FAIL: $1" >&2; exit 1; }

[ -f "${PATH_BOUNDARY}" ] || fail "path_boundary.py missing"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/lazykimi-path.XXXXXX")"
cleanup() { rm -rf "${TMP}"; }
trap cleanup EXIT

mkdir -p "${TMP}/project/subdir"
ln -s /tmp "${TMP}/project/outside"
mkdir -p "${TMP}/outside-target"

python3 - "${PATH_BOUNDARY}" "${TMP}/project" <<'PYEOF'
import importlib.util, os, sys
path = sys.argv[1]
root = sys.argv[2]
spec = importlib.util.spec_from_file_location("lazykimi_path_boundary", path)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

def expect_rejected(raw):
    try:
        mod.resolve_repo_path(root, raw)
        raise AssertionError(f"resolve_repo_path should reject {raw!r}")
    except mod.PathBoundaryError:
        pass

def expect_accepted(raw, expected_suffix):
    resolved = mod.resolve_repo_path(root, raw)
    expected = os.path.realpath(os.path.join(root, expected_suffix))
    assert resolved == expected, f"resolve_repo_path({raw!r}) = {resolved!r}, expected {expected!r}"

# Absolute path is rejected.
expect_rejected("/etc/passwd")
expect_rejected(os.path.join(root, "subdir"))

# Parent traversal is rejected.
expect_rejected("../escape")
expect_rejected("foo/../../escape")
expect_rejected("subdir/../../../escape")

# Windows-style absolute path is rejected.
expect_rejected("C:\\Windows")
expect_rejected("D:/foo")

# Symlink that points outside the project root is rejected.
expect_rejected("outside")

# Normal relative path inside the project is accepted and canonical.
expect_accepted("subdir", "subdir")
expect_accepted("./subdir", "subdir")
expect_accepted("foo/bar", "foo/bar")

# Any literal ".." path component is rejected, even if it resolves inside.
expect_rejected("subdir/../subdir")

# The CLI boundary rejects escapes with exit 1 and accepts safe paths with 0.
import subprocess
ok = subprocess.run([sys.executable, path, root, "subdir"], capture_output=True, text=True)
assert ok.returncode == 0 and ok.stdout.strip() == os.path.realpath(os.path.join(root, "subdir")), ok
bad = subprocess.run([sys.executable, path, root, "../escape"], capture_output=True, text=True)
assert bad.returncode == 1 and "outside project root" in bad.stderr, bad

print("PASS: v003 mcp path traversal regression")
PYEOF
