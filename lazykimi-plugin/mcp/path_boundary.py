"""Shared path-boundary enforcement for lazykimi MCP servers.

Canonicalizes a requested repo-relative path and rejects anything that escapes
the project root: absolute paths, Windows-style absolute paths, parent
traversal (`..`), and symlinks that point outside the project root.

Primary API:
    safeProjectPath(project_root, requested_path) -> str | None
        Returns the canonical safe absolute path, or None on rejection.

Compatibility API (matches the LazyBuddy reference):
    resolve_repo_path(root, raw_path) -> str   (raises PathBoundaryError)
    PathBoundaryError
"""
import ntpath
import os


class PathBoundaryError(ValueError):
    pass


def resolve_repo_path(root: str, raw_path: str) -> str:
    """Canonicalize `raw_path` under `root`, rejecting escapes and symlinks.

    Raises PathBoundaryError if the path is absolute, contains `..`, is a
    Windows-style absolute path, or resolves (via realpath, following symlinks)
    to a location outside `root`.
    """
    if not raw_path or os.path.isabs(raw_path) or ntpath.isabs(raw_path):
        raise PathBoundaryError("path is outside project root")
    if ".." in raw_path.replace("\\", "/").split("/"):
        raise PathBoundaryError("path is outside project root")
    canonical_root = os.path.realpath(root)
    candidate = os.path.realpath(os.path.join(canonical_root, raw_path))
    try:
        contained = os.path.commonpath((canonical_root, candidate)) == canonical_root
    except ValueError as exc:
        raise PathBoundaryError("path is outside project root") from exc
    if not contained:
        raise PathBoundaryError("path is outside project root")
    return candidate


def safeProjectPath(project_root: str, requested_path: str):
    """Return the canonical safe path under `project_root`, or None on rejection.

    Mirrors resolve_repo_path but returns None instead of raising, for callers
    that prefer a falsy sentinel. Rejects absolute paths that don't start with
    the project root, parent traversal, and symlinked escapes.
    """
    try:
        return resolve_repo_path(project_root, requested_path)
    except PathBoundaryError:
        return None
