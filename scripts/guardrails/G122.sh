#!/usr/bin/env bash
# phases: impl testing
# severity: BLOCKER
# Python lint + format — ruff check + ruff format --check; mypy --strict
set -uo pipefail
RUN_DIR="${1:?}"; TARGET="${2:-}"
[ -n "$TARGET" ] || exit 0
[ -f "$TARGET/pyproject.toml" ] || { echo "G122 SKIP: no pyproject.toml"; exit 0; }
fail=0
( cd "$TARGET" && ruff check . 2>&1 | tail -30 ) || { echo "G122 ruff-check FAIL"; fail=1; }
( cd "$TARGET" && ruff format --check . 2>&1 | tail -10 ) || { echo "G122 ruff-format FAIL"; fail=1; }
( cd "$TARGET" && mypy --strict src 2>&1 | tail -30 ) || { echo "G122 mypy-strict FAIL"; fail=1; }
[ "$fail" -eq 0 ] || exit 1
