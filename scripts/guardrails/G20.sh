#!/usr/bin/env bash
# phases: intake
# severity: BLOCKER
# tprd.md has all 14 required sections non-empty
set -uo pipefail
RUN_DIR="${1:?}"; TARGET="${2:-}"
F="$RUN_DIR/intake/tprd.md"
[ -f "$F" ] || { echo "tprd.md missing"; exit 1; }
for s in "Request Type" "Scope" "Motivation" "Functional Requirements" "Non-Functional" "Dependencies" "Config + API" "Observability" "Resilience" "Security" "Testing" "Breaking-Change" "Rollout" "Open Questions"; do
  grep -q "^## .* $s" "$F" || grep -q "^## [0-9]*\. $s" "$F" || { echo "missing section: $s"; exit 1; }
done
