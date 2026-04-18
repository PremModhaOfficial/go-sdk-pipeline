<!-- Generated: 2026-04-18T15:30:00Z | Run: sdk-dragonfly-s2 -->
# Baseline Regression Report — sdk-dragonfly-s2

## Executive Summary

**First-run baseline establishment.** No prior baselines existed for any dimension at the start of this run. All four baseline files are now populated from sdk-dragonfly-s2 data. Zero regressions are possible this run (nothing to compare against); zero baselines were lowered. Baseline reset (every-5-runs) is **not due** — this is run 1.

| Dimension | Status | Baseline file |
|---|---|---|
| Performance (bench) | CREATED (by testing-lead T5 prior to this wave; verified intact) | `baselines/performance-baselines.json` |
| Coverage | CREATED (first-run) | `baselines/coverage-baselines.json` |
| Quality | CREATED (first-run) | `baselines/quality-baselines.json` |
| Skill-health | CREATED (first-run) | `baselines/skill-health-baselines.json` |

## Summary Counts

- Baselines compared: 0 (first run — no priors)
- Regressions detected: 0
- Improvements detected: 0
- Baseline reset performed: no (due after run #5; settings.json `baseline_reset_every_n_runs: 5`)
- Anomalies in performance baseline: none — H8 waiver annotation present and explicit (see below)

## Performance Baseline Verification (owned by testing-lead T5, verified here)

The dragonfly entry was written by sdk-testing-lead at wave T5 (`2026-04-18T14:20:00Z`) and was NOT modified by this wave. Verification checks:

| Check | Result |
|---|---|
| `packages["core/l2cache/dragonfly"]` present | PASS |
| `git_sha` recorded | PASS (`b83c23e`) |
| All 5 benchmarks present (Get/Set/HExpire/EvalSha/Pipeline_100) | PASS |
| `allocs_per_op` for BenchmarkGet = 32 | PASS |
| H8 waiver explicitly annotated on `tprd_s10_constraint_table.allocs_per_get_le_3` | PASS — text reads "WAIVED-H8 (user accept-with-waiver 2026-04-18: declare target <=35 allocs/GET to match go-redis v9.18 floor; 32 becomes baseline; future regressions gate against 32+5% = 34.)" |
| Regression policy (hot/shared + thresholds) recorded | PASS |
| `missing_benchmarks` section (BenchmarkHSet, A/B harness) documented | PASS |

No corrections required. Baseline stays at recorded values; future runs of this package compare against this record.

## Quality Baselines Set

| Agent | Baseline | Runs tracked | Trend | Notes |
|---|---:|---:|---|---|
| **pipeline (rollup)** | 0.95 | 1 | insufficient-data | Mean of 4 primary agents, equal-weighted |
| sdk-intake-agent | 1.00 | 1 | insufficient-data | Perfect score: all G20-G24 PASS/WARN-non-blocking, 0 rework, 0 escalations |
| sdk-design-lead | 0.85 | 1 | insufficient-data | Lowest of 4; G32/G33 tool-unavail → 0.67 guardrail, 1 rework iter → 0.5 rework |
| sdk-impl-lead | 0.975 | 1 | insufficient-data | 13/13 guardrails PASS; dep-escalation resolved via Option A |
| sdk-testing-lead | 0.975 | 1 | insufficient-data | 10/10 executed guardrails PASS; T10 mutation SKIP (tool-unavail) |

## Coverage Baselines Set

| Package | Baseline (branch cov %) | Runs tracked | Notes |
|---|---:|---:|---|
| core/l2cache/dragonfly | 90.4 | 1 | Meets 90% floor (CLAUDE.md Rule #14). 71 unit pass, 1 skip, 0 fail. |

Regression threshold: >5% drop flags. Raise threshold: >5% improvement.

## Skill-Health Baselines Set (SDK-mode Delta 2)

| Metric | Baseline | Target | Status |
|---|---:|---|---|
| skill_stability (patches/skill) | 0.105 | <0.3 (10-run avg) | PASS single-run |
| existing_skill_patch_accept_rate | 1.0 | ≥0.8 | PASS with caveat (corpus empty) |
| manifest_miss_rate (blocking) | 0.0 | 0.0 | PASS |
| manifest_miss_rate (WARN-only) | 0.296 | tracking only | 8 proposals filed to docs/PROPOSED-SKILLS.md |
| golden_regression_rate | null | 1.0 (5-run) | DEFERRED — corpus empty |
| mean_time_to_green_sec | null | trending down | not instrumented |
| user_intervention_rate | 2 overrides | trending down | mode-override + dep-bump Option A |

Skill-drift scoreboard at baseline (from F4a): 0 MAJOR / 1 MODERATE / 3 MINOR / 14 NONE.
Skill-coverage scoreboard at baseline (from F4b): 19 declared-present / 8 WARN-absent / 3 TRIGGERS-GAP / 2 manifest-gap.

## Performance Baselines (reference — set by testing-lead T5, verified by this wave)

| Benchmark | ns/op | B/op | allocs/op | Class | Regression gate |
|---|---:|---:|---:|---|---|
| BenchmarkGet | 26,600 | 1,257 | 32 | hot | +5% (ns: 27,930) / allocs H8-waived to 34 |
| BenchmarkSet | 26,670 | 1,426 | 37 | hot | +5% (ns: 28,003) |
| BenchmarkHExpire | 25,050 | 1,815 | 47 | hot | +5% (ns: 26,302) |
| BenchmarkEvalSha | 136,100 | 178,583 | 729 | shared | +10% (ns: 149,710) |
| BenchmarkPipeline_100 | 955,900 | 50,514 | 1,917 | shared | +10% (ns: 1,051,490) |

Missing benchmarks acknowledged: BenchmarkHSet (TPRD §11.3 gap), A/B harness vs raw go-redis (TPRD §10 overhead-constraint measurement). Both filed as Phase-4 backlog per testing-lead T5.

## Baseline Changes Applied

| Type | Target | Previous | New | Reason |
|---|---|---|---|---|
| quality | pipeline | null | 0.95 | initial |
| quality | sdk-intake-agent | null | 1.00 | initial |
| quality | sdk-design-lead | null | 0.85 | initial |
| quality | sdk-impl-lead | null | 0.975 | initial |
| quality | sdk-testing-lead | null | 0.975 | initial |
| coverage | core/l2cache/dragonfly | null | 90.4 | initial |
| performance | dragonfly (5 benchmarks) | null | see table | initial (set by T5) |
| skill-health | skill_stability | null | 0.105 | initial |
| skill-health | patch_accept_rate | null | 1.0 | initial |
| skill-health | manifest_miss_rate (blocking) | null | 0.0 | initial |
| skill-health | drift MAJOR/MODERATE/MINOR/NONE | null | 0/1/3/14 | initial |
| skill-health | coverage TRIGGERS-GAP / manifest-gap | null | 3 / 2 | initial |

## Trend Analysis

Not applicable — single data point per dimension. Trend computation requires ≥3 runs (per SDK-MODE Delta 2, rolling windows: 10-run for skill_stability, 5-run for golden_regression_rate, and general 3-point minimum for quality trends).

## Flags and Open Items

1. **Golden-corpus empty** — `existing_skill_patch_accept_rate` is nominally 1.0 but corpus-gate was bypassed per learning-engine deferral (decision-log seq 151). Human seeding of `golden-corpus/dragonfly-v1/` from commit `a4d5d7f` is a precondition for meaningful future accept-rate tracking.

2. **Tool-availability gaps** drove design-lead quality down (0.85). Two guardrails (G32 govulncheck, G33 osv-scanner) and T10 mutation testing were tool-unavailable. Backlog items A1, A4 filed by metrics-collector; recommend pipeline preflight tooling check (Phase 0 addition).

3. **H8 waiver is a policy decision, not a baseline weakness** — allocs_per_op=32 is a legitimate go-redis v9.18 floor. Future runs gate against 34 (32+5%). TPRD §10 declared ≤3 allocs/GET; anomaly A3 recommends TPRD authors validate client floors before declaring allocs gates.

4. **Missing benchmark**: TPRD §11.3 BenchmarkHSet not emitted. Minor gap (anomaly A5); HExpire covers adjacent alloc profile. Rolled to next slice.

5. **Skill-library follow-ups** deferred but tracked: SKD-005 go-error-handling-patterns body-split (minor bump pending corpus), 8 WARN-absent skills filed to docs/PROPOSED-SKILLS.md.

## Reset Schedule

Per `settings.json` `baseline_reset_every_n_runs: 5`:
- Run #1 (sdk-dragonfly-s2, this run): baselines established
- Run #2-4: raise-only updates per policy
- Run #5: first scheduled reset — all baselines re-set to run-5 values to prevent normalization drift

## Artifacts Written by This Wave

- `baselines/quality-baselines.json` (created, first-run)
- `baselines/coverage-baselines.json` (created, first-run)
- `baselines/skill-health-baselines.json` (created, first-run, SDK-MODE Delta 2)
- `baselines/skill-health.json` (deprecated-stub pointer written; authoritative data in the -baselines.json variant)
- `baselines/baseline-history.jsonl` (created, 19 initial entries)
- `baselines/regression-report-sdk-dragonfly-s2.md` (this file)
- `runs/sdk-dragonfly-s2/feedback/context/baseline-manager-summary.md` (context summary for downstream)

**Verified intact (NOT modified by this wave):** `baselines/performance-baselines.json` — dragonfly entry owned by testing-lead T5, H8 waiver annotation confirmed present.
