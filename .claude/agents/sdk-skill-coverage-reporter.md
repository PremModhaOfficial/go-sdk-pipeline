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

## Devil-verdict stability (compensating baseline for retired golden-corpus)

After (3), for each invoked skill compute:
- `devil_fix_rate` = (NEEDS-FIX findings whose `fix_agent` cites a symbol in a region the skill prescribes) / (total exported symbols the skill's rules apply to). Read findings from `runs/<run-id>/{design,impl,testing}/reviews/*.findings.json`.
- `devil_block_rate` = same numerator, BLOCKER-severity only / total.

Append one line per invoked skill to `baselines/devil-verdict-history.jsonl`:
```json
{"run_id":"<uuid>","timestamp":"<ISO>","skill":"<name>","skill_version":"<X.Y.Z>","devil_fix_rate":0.12,"devil_block_rate":0.02,"symbols_scoped":<N>,"pipeline_version":"<ver>"}
```

If the skill was NOT auto-patched this run, this is a pure trend signal (baseline-manager raises). If the skill WAS auto-patched (check `evolution/knowledge-base/prompt-evolution-log.jsonl` for a matching entry this run), flag `regression_candidate: true` on the line so `learning-engine` can surface the jump in `learning-notifications.md` before user H10 review.

Also backfill `skills_invoked` on this run's `baselines/output-shape-history.jsonl` entry (metrics-collector leaves it `[]` if it ran first).

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
