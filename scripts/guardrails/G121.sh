#!/usr/bin/env bash
# phases: testing
# severity: BLOCKER
# Python tests — pytest must exit 0 (no failed/errored tests)
set -uo pipefail
RUN_DIR="${1:?}"; TARGET="${2:-}"
[ -n "$TARGET" ] || exit 0
[ -d "$TARGET/tests" ] || { echo "G121 SKIP: no tests/ dir at $TARGET"; exit 0; }
( cd "$TARGET" && python3 -m pytest -x --no-header -q tests/ 2>&1 | tail -40 )
rc=${PIPESTATUS[0]}
[ "$rc" -eq 0 ] || { echo "G121 FAIL: pytest exited $rc"; exit 1; }
