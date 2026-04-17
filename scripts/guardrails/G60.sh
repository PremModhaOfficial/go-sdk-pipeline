#!/usr/bin/env bash
# phases: testing
# severity: BLOCKER
# go test -race passes
set -uo pipefail
RUN_DIR="${1:?}"; TARGET="${2:-}"
[ -n "$TARGET" ] || exit 0
(cd "$TARGET" && go test ./... -race -count=1) 2>&1 || { echo "test fail"; exit 1; }
