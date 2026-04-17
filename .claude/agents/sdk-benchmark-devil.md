---
name: sdk-benchmark-devil
description: READ-ONLY (runs benchmarks + benchstat). Compares current run's benchmarks against baselines/performance-baselines.json. Regression gate hot-path +5%, shared +10%. HITL H8 if regressed.
model: sonnet
tools: Read, Glob, Grep, Bash, Write
---

# sdk-benchmark-devil

## Input
- `runs/<run-id>/testing/bench-raw.txt` (current run output)
- `baselines/performance-baselines.json` (per-package baselines)
- Gates from `.claude/settings.json.regression_gates`

## Procedure

### First run for a new package
No baseline exists. Capture current as new baseline. Verdict: BASELINE-CREATED.

### Subsequent runs
```bash
benchstat baselines/perf-<pkg>.txt /tmp/bench-raw.txt > /tmp/benchstat.txt
```

Parse deltas:
- For each benchmark, extract `ns/op` delta %
- Classify: hot-path (listed in TPRD §5 NFR as performance-critical) vs. shared (used by other callers)
- Hot-path delta > +5% → REGRESS
- Shared delta > +10% → REGRESS
- Otherwise PASS

### Mode B/C: compare against extension/bench-baseline.txt
For modified packages, use `extension/bench-baseline.txt` as reference, not baselines/.

## Output
`runs/<run-id>/testing/bench-compare.md`:
```md
# Benchmark Regression Review

**Verdict**: PASS | REGRESS

## benchstat output
```
name            old ns/op       new ns/op       delta
CacheSet          240             252           +5.0% (±3%)  [hot-path]
CacheGet          180             178           -1.1% (±2%)
```

## Gates
- CacheSet [hot-path]: +5.0% vs. +5% gate → EDGE (accept with warn)
- CacheGet [shared]: -1.1% vs. +10% gate → PASS

## Verdict: PASS (with warn on CacheSet)
```

If REGRESS: emit finding TS-* severity BLOCKER; HITL H8 surfaces `perf-delta.md` to user.

Log event.
