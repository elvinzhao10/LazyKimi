#!/usr/bin/env bash
# publication-regression.sh — publication-boundary regression for LazyKimi.
# Ported from lazyzcode v1.3.4 tests/publication-regression.sh and adapted to
# the lazykimi layout: docs live inside lazykimi-plugin/docs (the repo-root
# docs/ is a tracked symlink onto it), there is ONE marketplace.json v2 inside
# the plugin tree, and the publication set additionally pins the marketplace
# identity, the version matrix, and the packaging boundary.
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
REPOSITORY_ROOT="${REPOSITORY_ROOT:-$(d="$(cd "$PLUGIN_ROOT/.." && pwd -P)"; \
    while [ "$d" != "/" ]; do [ -d "$d/.github" ] && break; d="$(dirname "$d")"; done; \
    if [ -d "$d/.github" ]; then printf '%s' "$d"; else printf '%s' "$(cd "$PLUGIN_ROOT/.." && pwd -P)"; fi)}"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/lazykimi-publication-regression.XXXXXX")"

cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

required_root_docs=(
    # No docs/README.md index: the lazykimi learner route starts at
    # 00-learning-path.md (deviation from the LZ list).
    'docs/00-learning-path.md'
    'docs/01-mental-model.md'
    'docs/02-first-task.md'
    'docs/03-install-and-host-verification.md'
    'docs/04-workflow-playbooks.md'
    'docs/05-evidence-and-completion.md'
    'docs/06-capabilities-and-approvals.md'
    'docs/07-package-map.md'
    'docs/08-safe-removal.md'
    'docs/09-test-and-release-verification.md'
    'docs/11-kimi-work-setup.md'
    'docs/reference/state-model.md'
)

check_required_pages() {
    local relative_path
    for relative_path in "${required_root_docs[@]}"; do
        [ -f "$REPOSITORY_ROOT/$relative_path" ] || {
            printf 'FAIL: required root doc is missing: %s\n' "$relative_path" >&2
            return 1
        }
    done
}

check_local_links() {
    local publication_files=(
        "$REPOSITORY_ROOT/README.md"
        "$REPOSITORY_ROOT/AGENTS.md"
        "$REPOSITORY_ROOT/lazykimi-evaluation.md"
    )
    local source
    while IFS= read -r source; do
        publication_files+=("$source")
    done < <(find -L "$REPOSITORY_ROOT/docs" -type f -name '*.md' -print | LC_ALL=C sort)

    python3 - "$REPOSITORY_ROOT" "${publication_files[@]}" <<'PY'
from pathlib import Path
import re
import sys

repository_root = Path(sys.argv[1]).resolve()
link_pattern = re.compile(r"\[[^\]]*\]\(([^)]*)\)")

for source_arg in sys.argv[2:]:
    source = Path(source_arg).resolve()
    for raw_target in link_pattern.findall(source.read_text(encoding="utf-8")):
        target = raw_target.strip()
        if not target:
            raise SystemExit(f"empty: {source.relative_to(repository_root)}")
        if target.startswith("#") or re.match(r"(?:https?://|mailto:)", target):
            continue
        resolved = (source.parent / target.split("#", 1)[0]).resolve()
        try:
            resolved.relative_to(repository_root)
        except ValueError:
            raise SystemExit(f"escapes repository: {source.relative_to(repository_root)} -> {target}") from None
        if not resolved.exists():
            raise SystemExit(f"missing: {source.relative_to(repository_root)} -> {target}")
PY
}

for publication in README.md AGENTS.md lazykimi-evaluation.md; do
    [ -s "$REPOSITORY_ROOT/$publication" ] || fail "required publication is missing or empty: $publication"
done
check_required_pages || fail 'root learner route is incomplete'
check_local_links || fail 'root documentation contains an invalid local link'

publication_paths=(
    "$REPOSITORY_ROOT/README.md"
    "$REPOSITORY_ROOT/AGENTS.md"
    "$REPOSITORY_ROOT/lazykimi-evaluation.md"
    "$REPOSITORY_ROOT/docs"
)
grep -Eriq 'package readiness' "${publication_paths[@]}" || fail 'public docs must distinguish package readiness'
grep -Eriq 'host (verification|proof|session|integration)' "${publication_paths[@]}" || fail 'public docs must distinguish host verification'
grep -Eriq 'independent' "${publication_paths[@]}" || fail 'public docs must describe the independent runtime boundary'
if grep -Eriq '(requires|depends on)[^.]*(LazyZCodex|OmO)' "${publication_paths[@]}"; then
    fail 'public docs must not claim a LazyZCodex or OmO runtime dependency'
fi
if grep -Eriq 'marketplace add[[:space:]]+https://github\.com/' "${publication_paths[@]}"; then
    fail 'public docs must not provide a mutable marketplace command'
fi
if grep -Eriq 'guaranteed descendant cleanup|guarantees all descendants|timeout cleans all descendants' "${publication_paths[@]}"; then
    fail 'public docs must not overstate timeout descendant cleanup'
fi
if grep -Eriq 'alignment candidate|no longer maintained|practice project' "${publication_paths[@]}"; then
    fail 'public docs retain obsolete project framing'
fi
if grep -Erq 'tests/v017-documentation-regression\.sh' "${publication_paths[@]}"; then
    fail 'public docs reference the deleted documentation regression'
fi
if grep -Erq 'git clone[[:space:]]+https://github\.com/elvinzhao10/LazyKimi(\.git)?([[:space:]]|$)' "${publication_paths[@]}"; then
    fail 'public docs contain an unpinned LazyKimi clone command'
fi
pass 'current root learner publications satisfy semantic and link checks'

# Given the checked-in marketplace artifacts, when identity and version are
# read as machine data, then the single marketplace.json v2 entry matches the
# plugin manifest and the route contract pins both artifact digests. Contract
# artifact keys are release-root relative; the marketplace and manifest files
# live inside the plugin tree.
python3 - "$PLUGIN_ROOT" "$REPOSITORY_ROOT" <<'PY' || fail 'marketplace identity or version matrix drifted'
import hashlib
import json
import sys
from pathlib import Path

plugin_root = Path(sys.argv[1]).resolve()
repository_root = Path(sys.argv[2]).resolve()
marketplace = json.loads((plugin_root / "marketplace.json").read_text(encoding="utf-8"))
manifest = json.loads((plugin_root / "kimi.plugin.json").read_text(encoding="utf-8"))
contract = json.loads((plugin_root / "contracts" / "marketplace-route-contract.v1.json").read_text(encoding="utf-8"))

assert marketplace.get("version") == "2", "marketplace must stay on the v2 shape"
assert len(marketplace.get("plugins", [])) == 1, "marketplace must expose exactly one plugin"
entry = marketplace["plugins"][0]
assert entry["id"] == manifest["name"] == "lazykimi", "marketplace entry id must match the manifest name"
assert entry["source"] == "./", "marketplace entry must point at the plugin root"
assert manifest["version"] == contract["version"] == "1.3.4", "manifest and contract versions must agree"

for relative, expected in contract["artifacts"].items():
    artifact = repository_root / relative
    actual = hashlib.sha256(artifact.read_bytes()).hexdigest()
    assert actual == expected, f"route-contract digest drift: {relative}"
sidecar = (plugin_root / "contracts" / "marketplace-route-contract.v1.json.sha256").read_text(encoding="utf-8")
assert hashlib.sha256(
    (plugin_root / "contracts" / "marketplace-route-contract.v1.json").read_bytes()
).hexdigest() in sidecar, "contract digest sidecar must match the contract bytes"
PY
pass 'single marketplace artifact and version matrix stay pinned'

# Given the release-version classifier, when it runs against the repository
# root, then the full version matrix classifies clean (no drift, no unlabelled
# previous-version references).
node "$PLUGIN_ROOT/scripts/release-version-classifier.js" "$REPOSITORY_ROOT" >/dev/null \
    || fail 'release-version classifier reports version drift'
pass 'release version matrix classifies clean'

# Given the packaging boundary, when the publication tree is inspected, then
# the vendored sources/ tree and build outputs never ship as plugin payload.
[ -d "$REPOSITORY_ROOT/sources" ] && {
    git -C "$REPOSITORY_ROOT" ls-files -- "sources/*" | grep -q . \
        && fail 'vendored sources/ tree must stay untracked' || true
}
git -C "$REPOSITORY_ROOT" ls-files -- "lazykimi-plugin/dist/*" "*/node_modules/*" | grep -q . \
    && fail 'build outputs or dependencies must not be committed'
pass 'packaging boundary keeps sources, dist, and node_modules out of the payload'

# Given a copied learner route with one required page missing, when publication
# verification runs, then it rejects the incomplete route.
COPIED_REPOSITORY="$TMP/missing-page"
mkdir -p "$COPIED_REPOSITORY"
cp -RL "$REPOSITORY_ROOT/docs" "$COPIED_REPOSITORY/docs"
rm "$COPIED_REPOSITORY/docs/09-test-and-release-verification.md"
if (REPOSITORY_ROOT="$COPIED_REPOSITORY"; check_required_pages) > "$TMP/missing-page.out" 2>&1; then
    fail 'copied documentation with missing learner page was accepted'
fi
grep -Fq 'docs/09-test-and-release-verification.md' "$TMP/missing-page.out" || fail 'missing-page failure did not identify the learner page'
pass 'missing learner page fixture is rejected'

copy_publication_fixture() {
    local fixture_root="$1"
    mkdir -p "$fixture_root/lazykimi-plugin/contracts"
    # Reproduce the real publication shape: docs live in the plugin tree and
    # the repo root exposes them through the tracked docs symlink.
    mkdir -p "$fixture_root/lazykimi-plugin/docs"
    cp -RL "$PLUGIN_ROOT/docs/." "$fixture_root/lazykimi-plugin/docs/"
    ln -s lazykimi-plugin/docs "$fixture_root/docs"
    cp "$REPOSITORY_ROOT/README.md" "$REPOSITORY_ROOT/AGENTS.md" "$REPOSITORY_ROOT/CONTRIBUTING.md" \
        "$REPOSITORY_ROOT/SECURITY.md" "$REPOSITORY_ROOT/RELEASE_NOTES.md" \
        "$REPOSITORY_ROOT/lazykimi-evaluation.md" "$fixture_root/"
    cp "$REPOSITORY_ROOT/LICENSE" "$REPOSITORY_ROOT/NOTICE" "$fixture_root/"
    cp "$PLUGIN_ROOT/README.md" "$fixture_root/lazykimi-plugin/README.md"
    cp "$PLUGIN_ROOT/LICENSE" "$PLUGIN_ROOT/NOTICE" "$fixture_root/lazykimi-plugin/"
    if [ -f "$REPOSITORY_ROOT/lazykimi-banner.png" ]; then
        cp "$REPOSITORY_ROOT/lazykimi-banner.png" "$fixture_root/"
    fi
}

assert_bad_link() {
    local fixture_name="$1" markdown="$2" expected="$3"
    local fixture_root="$TMP/$fixture_name"
    copy_publication_fixture "$fixture_root"
    printf '%s\n' "$markdown" >> "$fixture_root/docs/00-learning-path.md"
    if (REPOSITORY_ROOT="$fixture_root"; check_local_links) > "$TMP/$fixture_name.out" 2>&1; then
        fail "$fixture_name link fixture was accepted"
    fi
    grep -Fq "$expected" "$TMP/$fixture_name.out" || fail "$fixture_name fixture did not report $expected"
    pass "$fixture_name fixture is rejected"
}

# Given malformed copied documentation, when the publication walker sees an
# empty, missing, or escaping destination, then each invalid target is rejected.
# (The escape fixture needs three levels: docs resolves through the plugin-tree
# symlink, so ../../ lands inside the repository root.)
assert_bad_link empty-link '[empty]()' 'empty'
assert_bad_link missing-link '[missing](not-a-page.md)' 'missing'
assert_bad_link escaping-link '[escape](../../../outside.md)' 'escapes repository'

assert_bad_root_link() {
    local publication="$1"
    local fixture_name="broken-${publication%.md}"
    local fixture_root="$TMP/$fixture_name"
    copy_publication_fixture "$fixture_root"
    printf '%s\n' '[missing](missing-root-publication-target.md)' >> "$fixture_root/$publication"
    if (REPOSITORY_ROOT="$fixture_root"; check_local_links) > "$TMP/$fixture_name.out" 2>&1; then
        fail "$publication broken link fixture was accepted"
    fi
    grep -Fq "$publication" "$TMP/$fixture_name.out" || fail "$publication broken link fixture did not identify its source"
    pass "$publication broken link fixture is rejected"
}

# Given each required root publication has a broken local link, when the
# publication walker runs, then it rejects the link and identifies its source.
for publication in README.md AGENTS.md lazykimi-evaluation.md; do
    assert_bad_root_link "$publication"
done

# Given an existing directory target, when the publication walker resolves it,
# then the directory is a valid local destination.
DIRECTORY_FIXTURE="$TMP/directory-link"
copy_publication_fixture "$DIRECTORY_FIXTURE"
printf '%s\n' '[reference](reference/)' >> "$DIRECTORY_FIXTURE/docs/00-learning-path.md"
(REPOSITORY_ROOT="$DIRECTORY_FIXTURE"; check_local_links) || fail 'existing directory link target was rejected'
pass 'existing directory link fixture is accepted'
