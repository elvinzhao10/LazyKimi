#!/usr/bin/env bash
# LazyKimi — SessionEnd hook
# Records a SessionEnd event as valid JSON in .lazykimi/state/sessions.json.
# Fails open: never blocks session end.
set -euo pipefail

state_dir="$PWD/.lazykimi/state"
sessions_file="$state_dir/sessions.json"
tmp_file="$state_dir/sessions.json.tmp.$$"
trap 'rm -f "${tmp_file:-}" 2>/dev/null; exit 0' ERR

# No stdin (tty) -> nothing to record
[ -t 0 ] && exit 0

payload=$(cat)
truncated=${payload:0:200}
ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Only act if the project state directory already exists; never create it.
[ -d "$state_dir" ] || exit 0

python3 - "$sessions_file" "$tmp_file" "$ts" "$truncated" <<'PY'
import sys, json, os

sessions_file, tmp_file, ts, payload = sys.argv[1:5]

data = {"sessions": []}
if os.path.exists(sessions_file):
    try:
        with open(sessions_file, "r", encoding="utf-8") as f:
            loaded = json.load(f)
        if isinstance(loaded, dict) and isinstance(loaded.get("sessions"), list):
            data = loaded
    except Exception:
        data = {"sessions": []}

data["sessions"].append({
    "timestamp": ts,
    "event": "SessionEnd",
    "payload": payload,
})

with open(tmp_file, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
    f.write("\n")

os.replace(tmp_file, sessions_file)
PY

echo "[${ts}] SessionEnd: ${truncated}" >&2
exit 0
