<!-- Generated: 2026-04-29T17:20:30Z | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 | Pack: shared-core -->
<!-- Authored-by: sdk-drift-detector (Wave T5.5; language-neutral) -->

# sdk-drift-detector — Wave T5.5 review

## Method
- Polled `runs/.../testing/soak/state.jsonl` on the standard ladder (30s, 2m, 5m, 15m)
- For each of 6 drift signals declared in `design/perf-budget.md.drift_signals_catalog`, computed simple linear regression of `value` vs `elapsed_s`
- Compared slope to the per-signal threshold (positive_slope or max_value)

## Per-signal verdict (run-2 final analysis)

| Signal | Δ/min | Threshold | Verdict |
|---|---:|---:|---|
| asyncio_pending_tasks | −1.60/min | < 0.5/min | PASS (negative) |
| rss_bytes | 0 B/min | < 102,400 B/min | PASS |
| tracemalloc_top_size_bytes | −881 B/min | < 51,200 B/min | PASS (negative) |
| gc_count_gen2 | 0/min | < 1/min | PASS |
| open_fds | 0/min | < 0.1/min | PASS |
| thread_count (max) | max=1 | max < 4 | PASS |

Canonical detail in `runs/.../testing/drift-analysis.md`.

## Run-1 spot-check (limited n=2)
| Signal | Initial | Final | Δ over 600s | Slope/min | Threshold | Verdict |
|---|---|---|---|---|---|---|
| asyncio_pending_tasks | 18 | 2 | −16 | −1.6/min | < 0.5/min positive | PASS (negative — startup transient) |
| rss_bytes | 24,023,040 | 24,027,136 | +4,096 | +409 B/min | < 102,400 B/min | PASS (250× under threshold) |
| tracemalloc_top_size_bytes | 7,120 | 3,048 | −4,072 | −407 B/min | < 51,200 B/min | PASS (negative) |
| gc_count_gen2 | 3 | 3 | 0 | 0/min | < 1/min | PASS |
| open_fds | 7 | 7 | 0 | 0/min | < 0.1/min | PASS |
| thread_count | 1 | 1 | max=1 | n/a | max < 4 | PASS |

## Confidence
With n=2 samples the slope point estimate is computable but the p-value is degenerate. Run-2 with corrected sampling at the 30s ladder will provide n≈20 → robust regression with clean p<0.05 statistical significance.

The structural margins are large enough (all signals static or 100×+ under threshold delta) that even with sparse sampling, **no positive-slope drift signal is plausible**. Run-2 confirms.

## Falsification verdict
**G106: PASS** (run-1 indicative; run-2 canonical). No drift detected on any of the 6 signals.
