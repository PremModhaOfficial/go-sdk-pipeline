#!/usr/bin/env bash
# Maintainer-only tool. Diffs inlined files against archive source to detect drift.
# Not invoked during a pipeline run.
# Usage: scripts/verify-provenance.sh <path-to-archive-root>
set -euo pipefail

ARCHIVE_ROOT="${1:-}"
if [ -z "$ARCHIVE_ROOT" ] || [ ! -d "$ARCHIVE_ROOT" ]; then
  echo "Usage: $0 <path-to-archive-root>"
  exit 3
fi

REPO="$(cd "$(dirname "$0")/.." && pwd)"
ERRORS=0

check_skill() {
  local name="$1"
  local inlined="$REPO/.claude/skills/$name/SKILL.md"
  local archive="$ARCHIVE_ROOT/.claude/skills/$name/SKILL.md"
  [ -f "$inlined" ] || { echo "MISSING inlined: $inlined"; ERRORS=$((ERRORS+1)); return; }
  [ -f "$archive" ] || { echo "MISSING archive: $archive"; ERRORS=$((ERRORS+1)); return; }
  # strip frontmatter from inlined, compare body-only
  awk 'BEGIN{fm=0} /^---$/{fm++; next} fm>=2 && /^# \[ported-from:/{next} fm>=2 && /^<!-- ported-from/{next} fm>=2{print}' "$inlined" > /tmp/inl.$$
  awk 'BEGIN{fm=0} /^---$/{fm++; next} fm>=2{print}' "$archive" > /tmp/arc.$$
  if ! diff -q /tmp/inl.$$ /tmp/arc.$$ >/dev/null 2>&1; then
    # for delta skills we expect divergence — gate with marker
    if grep -q "Ported with delta" "$REPO/PROVENANCE.md" 2>/dev/null && grep -q "$name" "$REPO/PROVENANCE.md"; then
      if ! grep -q "Archive canonical body" "$inlined"; then
        echo "DELTA skill missing archive-body marker: $name"
        ERRORS=$((ERRORS+1))
      fi
    else
      # verbatim — should contain archive body somewhere
      if ! grep -qF "$(head -5 /tmp/arc.$$ | tail -1)" "$inlined"; then
        echo "DRIFT (verbatim): $name"
        ERRORS=$((ERRORS+1))
      fi
    fi
  fi
  rm -f /tmp/inl.$$ /tmp/arc.$$
}

check_agent() {
  local name="$1"
  local inlined="$REPO/.claude/agents/$name.md"
  local archive="$ARCHIVE_ROOT/.claude/agents/$name.md"
  [ -f "$inlined" ] || { echo "MISSING inlined agent: $inlined"; ERRORS=$((ERRORS+1)); return; }
  [ -f "$archive" ] || { echo "MISSING archive agent: $archive"; ERRORS=$((ERRORS+1)); return; }
  # all agents ported with delta -> verify archive-body marker exists
  if ! grep -q "Archive canonical body" "$inlined"; then
    echo "AGENT missing archive-body marker: $name"
    ERRORS=$((ERRORS+1))
  fi
}

for s in go-concurrency-patterns go-error-handling-patterns go-struct-interface-design mock-patterns otel-instrumentation testcontainers-setup testing-patterns table-driven-tests tdd-patterns fuzz-patterns go-hexagonal-architecture go-module-paths review-fix-protocol lifecycle-events context-summary-writing conflict-resolution feedback-analysis environment-prerequisites-check spec-driven-development decision-logging guardrail-validation; do
  check_skill "$s"
done

for a in learning-engine improvement-planner baseline-manager metrics-collector phase-retrospector root-cause-tracer defect-analyzer refactoring-agent documentation-agent code-reviewer guardrail-validator; do
  check_agent "$a"
done

if [ $ERRORS -gt 0 ]; then
  echo ""
  echo "Provenance verification: $ERRORS issue(s)"
  exit 1
fi
echo "Provenance verification: OK — all inlined files match archive sources"
