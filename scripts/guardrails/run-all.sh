#!/usr/bin/env bash
# Run all guardrails for a given phase. Each check prints PASS <id> or FAIL <id>: <reason>.
# Usage: run-all.sh <phase> <run-dir> <target-dir>
#   phase   = bootstrap | intake | design | impl | testing | feedback | meta
#   run-dir = runs/<run-id>
#   target-dir = $SDK_TARGET_DIR (for file-scanning checks); optional for meta phase
set -uo pipefail
PHASE="${1:?phase required}"; RUN_DIR="${2:?run-dir required}"; TARGET="${3:-}"
FAIL=0
for f in "$(dirname "$0")"/G*.sh; do
  [ -x "$f" ] || continue
  id=$(basename "$f" .sh)
  # each check declares its applicable phases via header comment '# phases: bootstrap intake ...'
  phase_line=$(grep -m1 '^# phases:' "$f" || echo "# phases: meta")
  if ! echo "$phase_line" | grep -q " $PHASE"; then continue; fi
  out=$("$f" "$RUN_DIR" "$TARGET" 2>&1) || { echo "FAIL $id: $out"; FAIL=$((FAIL+1)); continue; }
  echo "PASS $id"
done
exit $FAIL
