<!-- Generated: 2026-04-28 | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 | Author: sdk-testing-lead (acting sdk-soak-runner) | Wave: T3 -->

# Soak verdict (Wave T3 — sdk-soak-runner / G105)

## Setup

- Workload: 32 acquirers continuously cycling against `max_size=4` `Pool[int]`
- Per perf-budget.md §3 `soak_targets`: MMD = 600 s, poll interval = 30 s, samples_required = 20
- Harness: `runs/<id>/testing/soak/soak_runner.py` v2 (thread-poller — v1 had asyncio loop starvation)
- Launched via `Bash run_in_background` to outlive any single tool-call window
- Drift signals captured per perf-budget.md §3: `ops_completed`, `concurrency_units`, `outstanding_acquires`, `heap_bytes` (tracemalloc), `gc_count_gen0/1/2`

## Result (G105 — MMD)

| Field | Value |
|---|---|
| MMD declared | 600 s |
| Actual duration (final sample) | **600.38 s** (final sentinel: 611.21 s after 10s grace + cleanup) |
| Samples collected | 20 (perf-budget.md required ≥ 20 — gate satisfied) |
| Total ops_completed | **40,256,000** acquire+release cycles |
| Throughput average | ~67k cycles/sec (32 workers × ~2.1k each, roughly) |
| Sentinel `event: soak_complete` written | YES |
| Pool `closed: false` during run / `aclose` clean at end | YES (no errors during aclose; tracemalloc.peak = 101,673 bytes) |

**G105 verdict: PASS** — `actual_duration_s (600.38) ≥ mmd_seconds (600)` AND samples (20) ≥ required (20).

## Per-sample table (excerpt of full state.jsonl)

| ix | elapsed_s | ops_completed | concurrency_units | outstanding | heap_bytes | gc0 | gc1 | gc2 |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 30.01 | 2,080,000 | 0 | 0 | 66,805 | 637 | 10 | 2 |
| 5 | 150.10 | 10,016,000 | 0 | 0 | 67,297 | 638 | 10 | 2 |
| 10 | 300.21 | 19,680,000 | 0 | 0 | 67,960 | 644 | 10 | 2 |
| 15 | 450.30 | 29,632,000 | 0 | 0 | 68,663 | 650 | 10 | 2 |
| 20 | 600.38 | 39,456,000 | 0 | 0 | 69,598 | 658 | 10 | 2 |

Full data: `runs/<id>/testing/soak/state.jsonl` (22 lines: 1 sentinel + 20 samples + 1 complete record).

## Soak verdict

**PASS** — soak ran to MMD (600.38 s ≥ 600 s declared); 20 samples collected; pool closed cleanly; no worker exceptions; all observability counters non-NaN. See `drift-verdict.md` for the per-signal trend analysis (drift verdict).
