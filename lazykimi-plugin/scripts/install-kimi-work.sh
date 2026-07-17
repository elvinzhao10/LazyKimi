#!/usr/bin/env bash
set -euo pipefail

# install-kimi-work.sh — Install LazyKimi skills into Kimi Work (secondary host).
#
# Kimi Work is a desktop agent (Beta, 2026-06-03) with Agent Swarm + built-in
# Skills system. It has NO plugin manifest support — only skills can be
# imported. MCP servers must be configured manually through Kimi Work's UI.
#
# This script copies lazy-* skill directories from lazykimi-plugin/.kimi-code/skills/
# into the detected Kimi Work skills directory. It is idempotent: existing
# skills with identical SKILL.md content are skipped.

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_SRC="${PROJECT_ROOT}/.kimi-code/skills"

# --help
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<EOF
Usage: bash install-kimi-work.sh [--help]

Copies LazyKimi skills (lazy-* directories) from
  ${SKILLS_SRC}
into the detected Kimi Work skills directory.

Kimi Work has no plugin manifest support. Only skills are imported. MCP
servers must be configured manually through Kimi Work's MCP configuration UI
(see docs/11-kimi-work-setup.md for the 6 server commands).

Idempotent: skills with identical SKILL.md content are skipped.

Limitations:
  - No plugin manifest (no hooks, no sessionStart.skill).
  - No /plugins install route.
  - MCP servers must be added manually.

Restart Kimi Work after running this script to activate imported skills.
EOF
  exit 0
fi

# Detect Kimi Work skills directory (best-effort, macOS-first)
CANDIDATES=(
  "${HOME}/.kimi-work/skills"
  "${HOME}/.kimiwork/skills"
  "${HOME}/Library/Application Support/Kimi Work/skills"
  "${HOME}/Library/Application Support/kimi-work/skills"
)

KIMI_WORK_SKILLS_DIR=""
for cand in "${CANDIDATES[@]}"; do
  if [[ -d "$(dirname "${cand}")" ]]; then
    KIMI_WORK_SKILLS_DIR="${cand}"
    break
  fi
done

if [[ -z "${KIMI_WORK_SKILLS_DIR}" ]]; then
  # Default to first candidate; user can create the dir
  KIMI_WORK_SKILLS_DIR="${HOME}/.kimi-work/skills"
  echo "WARN: No existing Kimi Work directory detected." >&2
  echo "WARN: Defaulting to ${KIMI_WORK_SKILLS_DIR}" >&2
  echo "WARN: Create the directory first if it does not exist:" >&2
  echo "WARN:   mkdir -p ${KIMI_WORK_SKILLS_DIR}" >&2
fi

echo "Kimi Work skills directory: ${KIMI_WORK_SKILLS_DIR}"
echo "Source skills directory:    ${SKILLS_SRC}"
echo ""

if [[ ! -d "${SKILLS_SRC}" ]]; then
  echo "ERROR: Source skills directory not found: ${SKILLS_SRC}" >&2
  exit 1
fi

mkdir -p "${KIMI_WORK_SKILLS_DIR}"

# Copy each lazy-* skill directory
copied=0
skipped=0
for skill_dir in "${SKILLS_SRC}"/lazy-*/; do
  [[ -d "${skill_dir}" ]] || continue
  skill_name=$(basename "${skill_dir}")
  target_dir="${KIMI_WORK_SKILLS_DIR}/${skill_name}"
  src_skill_md="${skill_dir}SKILL.md"
  tgt_skill_md="${target_dir}/SKILL.md"

  if [[ -f "${tgt_skill_md}" && -f "${src_skill_md}" ]]; then
    if diff -q "${src_skill_md}" "${tgt_skill_md}" >/dev/null 2>&1; then
      echo "SKIP  ${skill_name} (SKILL.md unchanged)"
      skipped=$((skipped + 1))
      continue
    fi
  fi

  mkdir -p "${target_dir}"
  cp -R "${skill_dir}/." "${target_dir}/"
  echo "COPY  ${skill_name}"
  copied=$((copied + 1))
done

echo ""
echo "Done: ${copied} copied, ${skipped} skipped."
echo ""
echo "Manual MCP setup required (Kimi Work does not auto-load .kimi-code/mcp.json)."
echo "Add each of these 6 MCP servers through Kimi Work's MCP configuration UI:"
echo ""
# Print the 6 server.sh paths from mcp.json
PLUGIN_ROOT="${PROJECT_ROOT}"
for server in run-ledger verification status-dashboard context-graph code-intel docs; do
  echo "  lazykimi-${server}:  bash ${PLUGIN_ROOT}/mcp/${server}/server.sh"
done
echo ""
echo "Limitations:"
echo "  - No plugin manifest support (no hooks, no sessionStart.skill)."
echo "  - Only skills are imported."
echo ""
echo "Restart Kimi Work to activate imported skills."
