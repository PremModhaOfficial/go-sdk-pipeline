#!/usr/bin/env bash
# phases: design
# severity: BLOCKER
# api.go.stub compiles (go build)
set -uo pipefail
RUN_DIR="${1:?}"; TARGET="${2:-}"
F="$RUN_DIR/design/api.go.stub"
[ -f "$F" ] || { echo "api.go.stub missing"; exit 1; }
TMP=$(mktemp -d)
cp "$F" "$TMP/api.go"
cd "$TMP" && go mod init stubcheck >/dev/null 2>&1 || true
go build ./... 2>&1 || { echo "compile fail"; exit 1; }
