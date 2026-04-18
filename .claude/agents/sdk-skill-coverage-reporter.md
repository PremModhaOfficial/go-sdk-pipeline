---
name: sdk-skill-coverage-reporter
description: Phase 4. Reports which skills were actually invoked by agents this run, vs. which were expected (based on TPRD tech signals). Unused-but-relevant = triggers gap.
model: sonnet
tools: Read, Glob, Grep, Write
---

# sdk-skill-coverage-reporter

## Input
- `runs/<run-id>/decision-log.jsonl`
- `runs/<run-id>/tprd.md` (for expected skills via §Skills-Manifest + tech signals)
- `runs/<run-id>/intake/skills-manifest-check.md` (declared-required set)

## Procedure

1. Extract "skill invocations" from decision log — entries where agent cites a skill name in `decision.rationale` or `communication.tags`
2. Cross-reference with TPRD tech signals → expected skill set
3. Find:
   - Invoked skills (used this run)
   - Expected-but-unused (signal matched, skill exists, yet no agent cited it) — TRIGGERS-GAP
   - Invoked-but-unexpected (used but signal didn't match) — either good lateral transfer OR over-invocation

## Output
`runs/<run-id>/feedback/skill-coverage.md`:
```md
# Skill Coverage Report

## Expected (from TPRD signals)
- sdk-cache-client-patterns
- circuit-breaker-policy
- network-error-classification
- sdk-config-struct-pattern
- otel-instrumentation
- testcontainers-setup

## Invoked
- sdk-config-struct-pattern ✓
- otel-instrumentation ✓
- testcontainers-setup ✓
- sdk-cache-client-patterns ✓
- go-concurrency-patterns (unexpected — OK, agents generalized)

## Expected-but-unused
- **circuit-breaker-policy** — TRIGGERS-GAP: skill exists (v1.0.0) but no agent invoked it despite TPRD §9 Resilience requesting CB thresholds. Investigate: skill description keywords too narrow?
- **network-error-classification** — TRIGGERS-GAP: skill exists (v1.0.0) but impl uses generic fmt.Errorf wrapping without classification. Investigate.

## Recommendations for improvement-planner
- Enhance `circuit-breaker-policy` description to include tech-signal keywords ("retry", "resilience", "retries")
- Add trigger to `network-error-classification` description referencing "error handling" domain
```

Feeds `improvement-planner`.
