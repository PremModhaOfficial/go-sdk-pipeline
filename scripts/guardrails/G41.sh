#!/usr/bin/env bash
# phases: impl testing
# severity: BLOCKER
# go build ./... passes
set -uo pipefail
RUN_DIR="${1:?}"; TARGET="${2:-}"
[ -n "$TARGET" ] || exit 0
(cd "$TARGET" && go build ./...) 2>&1 || { echo "build fail"; exit 1; }
