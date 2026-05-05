#!/usr/bin/env bash
# phases: impl testing
# severity: BLOCKER
# Python build — pyproject.toml must produce a wheel/sdist with no errors
set -uo pipefail
RUN_DIR="${1:?}"; TARGET="${2:-}"
[ -n "$TARGET" ] || exit 0
[ -f "$TARGET/pyproject.toml" ] || { echo "G120 SKIP: no pyproject.toml at $TARGET"; exit 0; }
( cd "$TARGET" && python3 -m pip install --quiet --upgrade build >/dev/null 2>&1 && python3 -m build --wheel --sdist --outdir /tmp/g120-build-"$$" ) 2>&1 | tail -20
rc=${PIPESTATUS[0]}
rm -rf /tmp/g120-build-"$$"
[ "$rc" -eq 0 ] || { echo "G120 FAIL: python -m build exited $rc"; exit 1; }
