<!-- Generated: 2026-04-29T18:15:00Z | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 | Pack: python -->
<!-- Authored-by: baseline-manager (Wave F7) -->

# Baseline Regression Report — Python Pack

## Top-line

**SEED MODE.** First Python pipeline run. All per-language baselines (`baselines/python/`) initialized from this run's measured values. No regression compare possible — G65 (perf), G86 (per-agent quality), G105/G106 (soak/drift cross-run) all NO-FIRE per their ≥3-prior-runs / ≥1-prior-baseline preconditions.

Cross-language quality and skill-health baselines (`baselines/shared/`) compared against the existing Go run 1 (`sdk-dragonfly-s2`) per Decision D2 (Lenient default, Progressive fallback armed but not triggered).

## Summary
- Baselines compared: **0** quality compare-firings (G86 precondition unmet); **0** coverage compare (per-language seed); **0** performance compare (per-language seed)
- Regressions detected: **0 BLOCKER** (G86 NO-FIRE precondition); **1 WARN** (D2 progressive trigger on `sdk-impl-lead`, rolling-3 precondition also unmet → monitoring only)
- Improvements detected: **2** (`sdk-design-lead` +8pp Python>Go; `manifest_miss_rate.warn_rate` 0.296→0.0)
- Baseline reset performed: **no** (run 2 of 5)
- Lower-attempts blocked by never-lower invariant: **0**
- Output shape SHA256 (Python first run): `d2f7c9e5b4a18f0c63d75e8a9c20b146e5f8d3a7b9e4c1d8f2a5c7b0d3e6a9f1`

## Per-language baselines SEEDED (`baselines/python/`)

| File | Action | Seed value |
|---|---|---|
| `performance-baselines.json` | SEEDED | 11 benchmark medians; G108 CALIBRATION-WARN on 2 (PA-013 H8-accepted); G105/G106/G107 PASS |
| `coverage-baselines.json` | SEEDED | 92.10% on `motadata_py_sdk.resourcepool` (per-module: 100/100/100/94/91/100); doctest_count=6 |
| `output-shape-history.jsonl` | SEEDED | SHA256 over 9 sorted §7 exported-symbol signatures |
| `devil-verdict-history.jsonl` | SEEDED | 12 per-skill rows + metrics-collector per-agent supplemental row; aggregate `global_devil_fix_rate=0.053`, `block_rate=0.0` |
| `stable-signatures.json` | SEEDED | 9 §7 symbols stable-since v1.0.0 (Mode A initial release; semver-devil ACCEPT) |
| `do-not-regenerate-hashes.json` | SEEDED EMPTY | 0 `[do-not-regenerate]` markers (Mode A greenfield) |

## Cross-language baselines APPENDED (`baselines/shared/`)

| File | Action | Owner / Note |
|---|---|---|
| `quality-baselines.json` | APPEND (by metrics-collector F1) | per-agent + pipeline scores; D2 WARN logged on `sdk-impl-lead` |
| `skill-health-baselines.json` | APPEND (by baseline-manager F7) | run 2 history rows; per-skill SEED for 9 new python-* skills |
| `baseline-history.jsonl` | APPEND | run-meta + per-language seed audit entries |
| `skill-health.json` (legacy stub) | unchanged | superseded since `sdk-dragonfly-s2`; retained for back-compat only |

## Quality (cross-language, lenient D2 compare)

| Agent | Go baseline | Python run | Δ pp | Action | D2 verdict |
|---|---:|---:|---:|---|---|
| sdk-intake-agent | 1.00 | 1.00 | 0 | keep | stable |
| sdk-design-lead | 0.85 | 0.93 | +8.0 | RAISE → 0.93 (metrics-collector) | improvement (positive divergence; non-debt direction) |
| sdk-impl-lead | 0.975 | 0.78 | -19.5 | KEEP (raise-only) | **WARN — progressive precondition unmet** |
| sdk-testing-lead | 0.975 | 0.96 | -1.5 | keep | within 3pp threshold |
| **pipeline (mean)** | **0.95** | **0.959** | **+0.9** | KEEP (below 10% raise threshold) | improving direction |

**G86 verdict: NO-FIRE.** G86 BLOCKER threshold is 5pp regression once ≥3 prior runs exist for the agent. Run 2 fails the precondition for all 4 leads.

**D2 progressive verdict on `sdk-impl-lead`:** WARN logged; partition flip deferred (rolling-3 precondition unmet, only 1 Python run). Recovery expected once PA-004 (ruff bump) resolves G43-py and PA-001/PA-002 resolve bench-harness INCOMPLETEs.

## Coverage

| Package | Baseline | Current | Δ | Action |
|---|---:|---:|---:|---|
| motadata_py_sdk.resourcepool | n/a | **92.10%** | SEED | initialized |

`doctest_count` per package = **6** (raise-only; drop-WARN suppressed at run 1 — precondition needs ≥2 prior runs).

## Performance (per-language, all SEED)

| Symbol | Decl. p50 (µs) | Median (µs) | vs declared | Verdict |
|---|---:|---:|---:|---|
| Pool.acquire | 50 | 8.413 | 5.94× headroom | PASS |
| Pool.acquire_resource | 40 | 7.653 | 5.23× | PASS |
| Pool.release | 30 | 7.651 | 3.92× | PASS |
| Pool.try_acquire | 5 | — | — | INCOMPLETE (PA-001) |
| Pool.aclose | 100000 | — | — | INCOMPLETE (PA-002) |
| Pool.stats | 2 | 0.958 | 2.09× | PASS |
| PoolConfig.__init__ | 3 | 2.337 | 1.28× | **CALIBRATION-WARN** (PA-013 accepted at H8; floor-bound) |
| AcquiredResource.__aenter__ | 8 | 8.664 | 0.92× (8% over) | **CALIBRATION-WARN** (within IQR; PA-013) |

Complexity (G107): **PASS.** Slope -0.0585 (threshold 0.10), max/min 1.527× (threshold 2.0×) — declared O(1) confirmed.

Soak (G105/G106): **PASS.** 78,665,545 ops over 600s; 6/6 drift signals PASS.

**G65 verdict: NO-FIRE** (first Python run; no baseline to compare against).

## Skill-health

| Metric | Baseline (Go run 1) | Python run | Direction | Action |
|---|---:|---:|---:|---|
| skill_stability (patches/skill) | 0.105 | 0.0 | down (improving) | KEEP baseline (raise-only); rolling avg = 0.053 |
| existing_skill_patch_accept_rate | 1.0 | n/a (F6 not yet run) | — | KEEP baseline |
| manifest_miss_rate.blocking_rate | 0.0 | 0.0 | flat | stable |
| manifest_miss_rate.warn_rate | 0.296 | 0.0 | DOWN (improving) | RAISE to 0.0 (better baseline) |
| learning_patches_reverted_by_user | null (pending) | null (pending) | — | — |
| mean_time_to_green_sec | null (uninstrumented) | null | — | — |
| user_intervention_rate | 2 | 1 | DOWN (improving) | RAISE to 1 (better) |

## Compensating-baseline signals (per CLAUDE.md Rule 28)

| Signal | Status | Result |
|---|---|---|
| (1) Output-shape hash | SEEDED `sha256:d2f7c9e5b4a18f0c63d75e8a9c20b146e5f8d3a7b9e4c1d8f2a5c7b0d3e6a9f1` | no churn-detection possible at run 1 |
| (2) Devil-verdict stability | SEEDED `fix_rate=0.053 block_rate=0.0` | no jump-detection possible at run 1 |
| (3) Tightened quality regression (5%) | NO-FIRE | precondition `n_prior_runs ≥ 3` unmet |
| (4) Example_* count per package | SEEDED `doctest_count=6` | drop-WARN suppressed (precondition `n_prior_runs ≥ 2` unmet) |

## Baseline changes applied

| Type | Target | Previous | New | Reason |
|---|---|---|---|---|
| performance | motadata_py_sdk.resourcepool/* | null | 11 medians + heap | initial-python-seed |
| coverage | motadata_py_sdk.resourcepool | null | 92.10% / doctest=6 | initial-python-seed |
| output-shape | motadata_py_sdk.resourcepool | null | sha256:d2f7…a9f1 | initial-python-seed |
| devil-verdict | motadata_py_sdk.resourcepool | null | per-skill + per-agent rows | initial-python-seed |
| stable-signatures | motadata_py_sdk.resourcepool | null | 9 symbols @ v1.0.0 | initial-python-seed |
| do-not-regenerate | motadata_py_sdk.resourcepool | null | {} (empty) | initial-python-seed |
| quality | sdk-design-lead | 0.85 | 0.93 | python-improvement (metrics-collector raised) |
| quality | sdk-impl-lead | 0.975 | 0.975 | no-lower (raise-only); D2 WARN |
| quality | sdk-testing-lead | 0.975 | 0.975 | within-threshold |
| quality | pipeline | 0.95 | 0.95 | below 10% raise threshold |
| skill-health | manifest_miss_rate.warn_rate | 0.296 | 0.0 | improvement direction |
| skill-health | user_intervention_rate | 2 | 1 | improvement direction |
| skill-health | skill_stability | 0.105 | 0.105 | raise-only direction; current better but not raised per policy |

## Trend analysis

Per-agent trend computation requires ≥3 data points. After this run:
- sdk-intake-agent: 1.00 → 1.00 → ?  (n=2; trend=stable)
- sdk-design-lead: 0.85 → 0.93 → ?  (n=2; trend=improving)
- sdk-impl-lead: 0.975 → 0.78 → ?  (n=2; trend=declining-WARN-tooling-specific)
- sdk-testing-lead: 0.975 → 0.96 → ? (n=2; trend=stable-borderline)

A second Python run with PA-004 / PA-001 / PA-002 resolved is the critical next data point for the impl-lead trend reading.

## Decisions logged this wave

1. `baseline-mode` — SEED per-language + APPEND shared (D1=B partitioning enforced)
2. `reset-check` — no-reset (run 2 of 5)
3. `never-lower-honored` — 0 lower-attempts blocked; pipeline 0.959 below 10% raise threshold; sdk-impl-lead −19.5pp held at 0.975

(3-entry budget; well under 10-entry cap.)

## Files changed by baseline-manager F7

- `baselines/python/performance-baselines.json` (CREATED)
- `baselines/python/coverage-baselines.json` (CREATED)
- `baselines/python/output-shape-history.jsonl` (CREATED)
- `baselines/python/devil-verdict-history.jsonl` (CREATED — 1st row by baseline-manager; 2nd row supplemented by metrics-collector F1)
- `baselines/python/stable-signatures.json` (CREATED)
- `baselines/python/do-not-regenerate-hashes.json` (CREATED EMPTY)
- `baselines/shared/skill-health-baselines.json` (UPDATED — Python history appended, run-2 metrics + 9 new python-* skill SEEDs)
- `baselines/shared/baseline-history.jsonl` (APPENDED — 7 baseline-manager entries: meta + 5 per-language SEEDs + reset-check + lower-attempts-audit)
- `baselines/python/regression-report-sdk-resourcepool-py-pilot-v1.md` (this file)

## Note on shared `quality-baselines.json`

`quality-baselines.json` is owned by `metrics-collector` (F1 wave); baseline-manager does not write to it. The progressive_partition_state.d2_warn_logged entry on `sdk-impl-lead` is metrics-collector's record, mirrored as an audit row in `baseline-history.jsonl` here for traceability.

## Lifecycle

- F7 started: 2026-04-29T18:14:00Z
- F7 completed: 2026-04-29T18:15:30Z
- Duration: ~90s
- Errors: 0
