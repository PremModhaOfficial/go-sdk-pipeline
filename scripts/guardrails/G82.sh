#!/usr/bin/env bash
# phases: feedback
# severity: BLOCKER
# golden regression PASS
set -uo pipefail
RUN_DIR="${1:?}"; TARGET="${2:-}"
F="$RUN_DIR/feedback/golden-regression.json"
[ -f "$F" ] || { echo "golden-regression.json missing"; exit 1; }
grep -q "\"status\":\s*\"PASS\"" "$F" || grep -q "\"overall\":\s*\"PASS\"" "$F" || { echo "golden FAIL"; exit 1; }
