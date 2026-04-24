#!/usr/bin/env bash
# validate-packages.sh — check .claude/package-manifests/ against filesystem reality.
#
# v0.4.0 scaffolding pass. No runtime consumer of the manifests exists yet; this
# script exists to keep the manifests honest as artifacts are added/removed.
#
# Enforces:
#   - every .claude/agents/*.md file is referenced in exactly one manifest
#   - every .claude/skills/*/ directory is referenced in exactly one manifest
#   - every scripts/guardrails/G*.sh file is referenced in exactly one manifest
#   - no manifest entry refers to a non-existent artifact
#   - no artifact appears in two manifests
#
# Exit codes:
#   0 — clean
#   1 — drift detected (orphan, duplicate, or dangling reference)
#   2 — infra problem (missing jq, missing manifest dir, etc.)
#
# Usage: bash scripts/validate-packages.sh

set -uo pipefail
PIPELINE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MANIFEST_DIR="$PIPELINE_ROOT/.claude/package-manifests"

if ! command -v jq >/dev/null 2>&1; then
  echo "INFRA: jq is required (install via package manager)" >&2
  exit 2
fi

if [ ! -d "$MANIFEST_DIR" ]; then
  echo "INFRA: manifest dir missing at $MANIFEST_DIR" >&2
  exit 2
fi

shopt -s nullglob
MANIFESTS=("$MANIFEST_DIR"/*.json)
if [ ${#MANIFESTS[@]} -eq 0 ]; then
  echo "INFRA: no *.json manifests found in $MANIFEST_DIR" >&2
  exit 2
fi

# Build flat "manifest:artifact" lists with associative tracking for dupe detection.
declare -A AGENT_OWNER SKILL_OWNER GUARDRAIL_OWNER
DUPES=""
DANGLING=""

for m in "${MANIFESTS[@]}"; do
  pkg=$(basename "$m" .json)

  # Validate JSON shape first.
  if ! jq -e '.name, .version, .agents, .skills, .guardrails' "$m" >/dev/null 2>&1; then
    echo "FAIL: $m missing required fields (name/version/agents/skills/guardrails)"
    exit 1
  fi

  while IFS= read -r a; do
    [ -z "$a" ] && continue
    if [ ! -f "$PIPELINE_ROOT/.claude/agents/$a.md" ]; then
      DANGLING+="  manifest=$pkg agent=$a (not on filesystem)"$'\n'
    fi
    if [ -n "${AGENT_OWNER[$a]+x}" ]; then
      DUPES+="  agent=$a in both $pkg and ${AGENT_OWNER[$a]}"$'\n'
    else
      AGENT_OWNER[$a]=$pkg
    fi
  done < <(jq -r '.agents[]' "$m")

  while IFS= read -r s; do
    [ -z "$s" ] && continue
    if [ ! -d "$PIPELINE_ROOT/.claude/skills/$s" ]; then
      DANGLING+="  manifest=$pkg skill=$s (not on filesystem)"$'\n'
    fi
    if [ -n "${SKILL_OWNER[$s]+x}" ]; then
      DUPES+="  skill=$s in both $pkg and ${SKILL_OWNER[$s]}"$'\n'
    else
      SKILL_OWNER[$s]=$pkg
    fi
  done < <(jq -r '.skills[]' "$m")

  while IFS= read -r g; do
    [ -z "$g" ] && continue
    if [ ! -f "$PIPELINE_ROOT/scripts/guardrails/$g.sh" ]; then
      DANGLING+="  manifest=$pkg guardrail=$g (not on filesystem)"$'\n'
    fi
    if [ -n "${GUARDRAIL_OWNER[$g]+x}" ]; then
      DUPES+="  guardrail=$g in both $pkg and ${GUARDRAIL_OWNER[$g]}"$'\n'
    else
      GUARDRAIL_OWNER[$g]=$pkg
    fi
  done < <(jq -r '.guardrails[]' "$m")
done

# Orphan check: is every filesystem artifact referenced by some manifest?
ORPHANS=""
for f in "$PIPELINE_ROOT"/.claude/agents/*.md; do
  [ -f "$f" ] || continue
  name=$(basename "$f" .md)
  if [ -z "${AGENT_OWNER[$name]+x}" ]; then
    ORPHANS+="  agent=$name (on fs, in no manifest)"$'\n'
  fi
done

for d in "$PIPELINE_ROOT"/.claude/skills/*/; do
  [ -d "$d" ] || continue
  name=$(basename "$d")
  if [ -z "${SKILL_OWNER[$name]+x}" ]; then
    ORPHANS+="  skill=$name (on fs, in no manifest)"$'\n'
  fi
done

for f in "$PIPELINE_ROOT"/scripts/guardrails/G*.sh; do
  [ -f "$f" ] || continue
  name=$(basename "$f" .sh)
  if [ -z "${GUARDRAIL_OWNER[$name]+x}" ]; then
    ORPHANS+="  guardrail=$name (on fs, in no manifest)"$'\n'
  fi
done

# Results
FAIL=0

if [ -n "$DUPES" ]; then
  echo "FAIL: duplicate ownership (an artifact in 2+ manifests):"
  printf '%s' "$DUPES"
  FAIL=1
fi

if [ -n "$DANGLING" ]; then
  echo "FAIL: dangling references (manifest points at missing file):"
  printf '%s' "$DANGLING"
  FAIL=1
fi

if [ -n "$ORPHANS" ]; then
  echo "FAIL: orphans (on filesystem but in no manifest):"
  printf '%s' "$ORPHANS"
  FAIL=1
fi

if [ "$FAIL" -ne 0 ]; then
  echo ""
  echo "Fix: update .claude/package-manifests/*.json so every on-disk artifact is in exactly one manifest."
  exit 1
fi

# Pretty report on success
AGENT_COUNT=${#AGENT_OWNER[@]}
SKILL_COUNT=${#SKILL_OWNER[@]}
GR_COUNT=${#GUARDRAIL_OWNER[@]}
FS_AGENTS=$(ls "$PIPELINE_ROOT"/.claude/agents/*.md 2>/dev/null | wc -l)
FS_SKILLS=$(ls -d "$PIPELINE_ROOT"/.claude/skills/*/ 2>/dev/null | wc -l)
FS_GUARDRAILS=$(ls "$PIPELINE_ROOT"/scripts/guardrails/G*.sh 2>/dev/null | wc -l)

echo "PASS: manifests consistent with filesystem"
echo "  agents:     $AGENT_COUNT manifested / $FS_AGENTS on fs"
echo "  skills:     $SKILL_COUNT manifested / $FS_SKILLS on fs"
echo "  guardrails: $GR_COUNT manifested / $FS_GUARDRAILS on fs"
echo ""
echo "Package breakdown:"
for m in "${MANIFESTS[@]}"; do
  pkg=$(basename "$m" .json)
  a=$(jq -r '.agents | length' "$m")
  s=$(jq -r '.skills | length' "$m")
  g=$(jq -r '.guardrails | length' "$m")
  printf "  %-16s  %2d agents   %2d skills   %2d guardrails\n" "$pkg" "$a" "$s" "$g"
done
exit 0
