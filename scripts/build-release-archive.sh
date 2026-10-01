#!/usr/bin/env bash
set -euo pipefail

REPOSITORY_ROOT="$(cd -P "$(dirname "$0")/.." && pwd -P)"
REVISION="${1:?usage: build-release-archive.sh <revision> <output.tar.gz> [--working-tree]}"
OUTPUT="${2:?output archive required}"
SOURCE_MODE="${3:-revision}"
case "$OUTPUT" in /*) ;; *) OUTPUT="$PWD/$OUTPUT" ;; esac
case "$SOURCE_MODE" in revision|--working-tree) ;; *) exit 2 ;; esac
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/lazykimi-release-archive.XXXXXX")"
trap 'rm -rf -- "$STAGE"' EXIT
mkdir "$STAGE/payload" "$STAGE/extracted"

if [ "$SOURCE_MODE" = --working-tree ]; then
    # Local candidate verification includes new source files before commit.
    git -C "$REPOSITORY_ROOT" ls-files --cached --others --exclude-standard -z > "$STAGE/files"
    (cd "$REPOSITORY_ROOT" && tar -cf - --null -T "$STAGE/files") | tar -xf - -C "$STAGE/payload"
else
    git -C "$REPOSITORY_ROOT" archive "$REVISION" | tar -xf - -C "$STAGE/payload"
fi

test -f "$REPOSITORY_ROOT/lazykimi-plugin/dist/index.js"
cp -R "$REPOSITORY_ROOT/lazykimi-plugin/dist" "$STAGE/payload/lazykimi-plugin/dist"
if find "$STAGE/payload" \( -name node_modules -o -name '*.pyc' -o -name __pycache__ \) -print -quit | grep -q .; then
    echo 'Release payload contains dependency directories or Python bytecode.' >&2
    exit 1
fi
ARCHIVE_EPOCH="$(git -C "$REPOSITORY_ROOT" show -s --format=%ct "$REVISION")"
python3 - "$OUTPUT" "$STAGE/payload" "$ARCHIVE_EPOCH" <<'PY'
import gzip
import os
from pathlib import Path
import sys
import tarfile

output, payload, epoch_text = sys.argv[1:]
root = Path(payload)
epoch = int(epoch_text)
entries = []
for current, directories, files in os.walk(root, followlinks=False):
    for name in directories + files:
        entries.append(Path(current) / name)

with open(output, 'wb') as raw:
    with gzip.GzipFile(filename='', mode='wb', fileobj=raw, mtime=epoch) as compressed:
        with tarfile.open(fileobj=compressed, mode='w', format=tarfile.PAX_FORMAT) as archive:
            for entry in [root] + sorted(entries, key=lambda item: item.relative_to(root).as_posix()):
                relative = entry.relative_to(root).as_posix()
                name = '.' if entry == root else './' + relative
                info = archive.gettarinfo(str(entry), arcname=name)
                info.mtime = epoch
                info.uid = info.gid = 0
                info.uname = info.gname = ''
                if entry == root:
                    info.mode = 0o755
                if info.isfile():
                    with entry.open('rb') as content:
                        archive.addfile(info, content)
                else:
                    archive.addfile(info)
PY
tar -xzf "$OUTPUT" -C "$STAGE/extracted"
PLUGIN="$STAGE/extracted/lazykimi-plugin"
node "$PLUGIN/dist/index.js" --help
node "$PLUGIN/dist/index.js" load-check
node --test --test-concurrency=1 "$PLUGIN/tests/lifecycle-ownership.test.js" "$PLUGIN/tests/native-project-mcp.test.js" "$PLUGIN/tests/agent-frontmatter-policy.test.js"
echo "PASS: extracted release archive CLI, lifecycle, native restrictions, and project binding: $OUTPUT"
