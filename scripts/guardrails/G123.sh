#!/usr/bin/env bash
# phases: testing
# severity: BLOCKER
# Python supply-chain — pip-audit (PyPI advisories) + safety (commercial DB)
set -uo pipefail
RUN_DIR="${1:?}"; TARGET="${2:-}"
[ -n "$TARGET" ] || exit 0
[ -f "$TARGET/pyproject.toml" ] || { echo "G123 SKIP: no pyproject.toml"; exit 0; }
fail=0
( cd "$TARGET" && pip-audit --strict --progress-spinner off 2>&1 | tail -40 ) || { echo "G123 pip-audit FAIL"; fail=1; }
# safety can be auth-gated; skip without failing if it ERRORs out at registration
( cd "$TARGET" && safety check --full-report 2>&1 | tail -40 ) || echo "G123 WARN: safety unavailable or auth-gated; pip-audit verdict still authoritative"
[ "$fail" -eq 0 ] || exit 1
