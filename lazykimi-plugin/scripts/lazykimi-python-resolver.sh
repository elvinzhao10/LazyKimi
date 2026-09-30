# lazykimi-python-resolver.sh — canonical Python interpreter resolution.
#
# Source this file, then use "$LAZYKIMI_PYTHON_RESOLVED". Consumers that must
# stay self-contained (lazykimi-verify.sh, lazykimi-plugin-doctor.sh) keep
# their own inline copy of the same candidate list — keep the lists in sync.
#
# Resolution order:
#   1. LAZYKIMI_PYTHON (explicit override)
#   2. python3 when it is 3.10+
#   3. python3.13 / python3.12 / python3.11 / python3.10
# Resolves to the empty string when no candidate meets the 3.10 floor.

if [ -n "${LAZYKIMI_PYTHON:-}" ]; then
    LAZYKIMI_PYTHON_RESOLVED="$LAZYKIMI_PYTHON"
else
    LAZYKIMI_PYTHON_RESOLVED=""
    _lk_pv="$(command -v python3 >/dev/null 2>&1 && python3 -c 'import sys; print("%d%02d" % sys.version_info[:2])' 2>/dev/null || true)"
    if [ -n "$_lk_pv" ] && [ "$_lk_pv" -ge 310 ]; then
        LAZYKIMI_PYTHON_RESOLVED="python3"
    else
        for _lk_cand in python3.13 python3.12 python3.11 python3.10; do
            command -v "$_lk_cand" >/dev/null 2>&1 || continue
            _lk_cv="$("$_lk_cand" -c 'import sys; print("%d%02d" % sys.version_info[:2])' 2>/dev/null || true)"
            if [ -n "$_lk_cv" ] && [ "$_lk_cv" -ge 310 ]; then
                LAZYKIMI_PYTHON_RESOLVED="$_lk_cand"
                break
            fi
        done
    fi
    unset _lk_pv _lk_cand _lk_cv
fi
