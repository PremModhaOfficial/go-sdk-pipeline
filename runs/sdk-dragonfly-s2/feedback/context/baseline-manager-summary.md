<!-- Generated: 2026-04-18T15:30:00Z | Run: sdk-dragonfly-s2 -->
# baseline-manager — Wave F8 Context Summary

For downstream (H10 merge verdict and future runs). Self-contained.

## Status

Wave F8 COMPLETE. First-run baselines established across 4 dimensions: quality, coverage, performance (verified intact, set by T5), and skill-health. Zero regressions possible (no priors). Zero baselines lowered. No baseline reset triggered (due after run #5).

## Inputs consumed

- `runs/sdk-dragonfly-s2/feedback/metrics.json` — pipeline_quality 0.95, per-agent scores, coverage 90.4%
- `baselines/performance-baselines.json` — verified intact (testing-lead T5 owned this file; wrote dragonfly entry at 14:20:00Z with H8 waiver)
- `runs/sdk-dragonfly-s2/feedback/skill-drift.md` (F4a: 0 MAJOR / 1 MODERATE / 3 MINOR / 14 NONE)
- `runs/sdk-dragonfly-s2/feedback/skill-coverage.md` (F4b: 3 TRIGGERS-GAP, 2 manifest-gap)
- `runs/sdk-dragonfly-s2/feedback/context/learning-engine-summary.md` (F7: 2 patch-level skill bumps applied)

## Outputs

| File | Action | Size/Entries |
|---|---|---|
| `baselines/quality-baselines.json` | CREATED (overwrite of empty stub) | pipeline + 4 agents + raise policy |
| `baselines/coverage-baselines.json` | CREATED (overwrite of empty stub) | 1 package (dragonfly @ 90.4%) |
| `baselines/skill-health-baselines.json` | CREATED (new) | 6 metrics + drift/coverage scoreboards + 2 per-skill entries |
| `baselines/skill-health.json` | UPDATED to deprecation-stub pointer | (points to -baselines.json) |
| `baselines/performance-baselines.json` | VERIFIED (not modified) | 5 benchmarks, H8 waiver confirmed |
| `baselines/baseline-history.jsonl` | CREATED | 19 initial entries (1 per baseline target touched) |
| `baselines/regression-report-sdk-dragonfly-s2.md` | CREATED | first-run summary (≤300 lines) |

## Key findings

1. **Pipeline quality 0.95** locked as baseline (mean of 4 primary agents). Weakest: sdk-design-lead 0.85 (G32/G33 tool-unavail + 1 rework iter).
2. **Coverage 90.4%** locked for `core/l2cache/dragonfly` — meets 90% floor.
3. **Performance baseline already present and correct** — testing-lead T5 wrote it earlier this run. H8 waiver annotation ("WAIVED-H8 ... 32 becomes baseline; future regressions gate against 32+5% = 34") is explicit and correct. No correction required.
4. **Skill-health** is first-baselined with 6 metrics; 2 deferred (golden_regression_rate, mean_time_to_green_sec) pending corpus-seeding and wall-clock instrumentation respectively.

## Policy summary (preserved for downstream agents)

- Raise quality baseline only on >10% improvement; coverage on >5%; performance on >10% shared / >5% hot (lower ns_per_op).
- Never lower any baseline without explicit learning-engine signoff.
- Reset all baselines at run #5 per `settings.json baseline_reset_every_n_runs: 5`.
- H8 waiver on dragonfly BenchmarkGet allocs is permanent until TPRD §10 is rewritten by a human.

## Anomalies flagged

None from this wave. All flagged anomalies (A1-A5) originated upstream in metrics.json and remain valid.

## Decision log entries

seq 155-160 (6 entries total; within 10-entry cap per baseline-manager and 15-entry global per-agent cap).

## Handoff

Next: Wave F9 (phase-retrospector already completed; baselines are final artifact of feedback phase).
H10 merge verdict can now proceed with full baseline context.

## Artifacts

- `/home/prem-modha/projects/nextgen/motadata-sdk-pipeline/baselines/quality-baselines.json`
- `/home/prem-modha/projects/nextgen/motadata-sdk-pipeline/baselines/coverage-baselines.json`
- `/home/prem-modha/projects/nextgen/motadata-sdk-pipeline/baselines/skill-health-baselines.json`
- `/home/prem-modha/projects/nextgen/motadata-sdk-pipeline/baselines/skill-health.json`
- `/home/prem-modha/projects/nextgen/motadata-sdk-pipeline/baselines/baseline-history.jsonl`
- `/home/prem-modha/projects/nextgen/motadata-sdk-pipeline/baselines/regression-report-sdk-dragonfly-s2.md`
- `/home/prem-modha/projects/nextgen/motadata-sdk-pipeline/runs/sdk-dragonfly-s2/feedback/context/baseline-manager-summary.md`
