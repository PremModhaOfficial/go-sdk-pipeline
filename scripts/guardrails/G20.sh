#!/usr/bin/env bash
# phases: intake
# severity: BLOCKER
# TPRD completeness — every required topic area is covered. Header naming is
# flexible (TPRDs may use "Purpose" instead of "Request Type", "Goals" instead
# of "Scope", etc).
set -uo pipefail
RUN_DIR="${1:?}"; TARGET="${2:-}"
F="$RUN_DIR/tprd.md"
[ -f "$F" ] || { echo "tprd.md missing at $F"; exit 1; }

# Each entry: a pipe-separated list of acceptable header keywords for the topic.
REQUIRED=(
  "Request Type|Purpose|Overview"
  "Scope|Goals"
  "Motivation|Rationale|Purpose"
  "Functional Requirement|API Surface|API"
  "Non-Functional|Perf Target|NFR"
  "Dependencies|Compat Matrix"
  "Config"
  "Observability|OTel|Tracing|Metrics"
  "Resilience|Error Model|Reliability"
  "Security"
  "Testing|Test Strategy"
  "Breaking-Change|Semver"
  "Rollout|Milestone|Deployment"
  "Clarification|Open Question|Risk"
)

FAIL=0
for topic in "${REQUIRED[@]}"; do
  if ! grep -qiE "^#+[[:space:]]*[§0-9.[:space:]]*($topic)" "$F"; then
    echo "MISSING topic: $topic"
    FAIL=$((FAIL+1))
  fi
done

# Manifests
if ! grep -qiE "^#+[[:space:]]*[§0-9.[:space:]]*Skills-?Manifest" "$F"; then
  echo "NOTE: §Skills-Manifest absent (G23 will WARN, non-blocking)"
fi
if ! grep -qiE "^#+[[:space:]]*[§0-9.[:space:]]*Guardrails-?Manifest" "$F"; then
  echo "MISSING section: §Guardrails-Manifest"
  FAIL=$((FAIL+1))
fi

[ $FAIL -eq 0 ] || exit 1
exit 0
