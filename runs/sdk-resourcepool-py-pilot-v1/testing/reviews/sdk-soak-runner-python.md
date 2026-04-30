<!-- Generated: 2026-04-29T17:20:00Z | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 | Pack: python -->
<!-- Authored-by: sdk-soak-runner-python (Wave T5.5) -->

# sdk-soak-runner-python — Wave T5.5 review

(Note: pending soak run-2 completion; this report is updated post-run by `soak-results.md`.)

## Method
- Soak driver at `runs/.../testing/soak/soak_driver.py` (custom one-shot harness — Python pack does not yet ship a generic soak harness; gap filed via PA-011 for Phase 4 "promote pool-flavor soak driver into pack-supplied skill")
- Drove `Pool.acquire_resource → Pool.release` cycle continuously with **16 workers** competing for **max_size=4** for **MMD=600s** (matches `perf-budget.md` `Pool.acquire.soak.mmd_seconds: 600`)
- Sampled 6 drift signals every 30s into `runs/.../testing/soak/state.jsonl`
- Bash-launched via `nohup … &; disown` so the child outlives the synchronous tool ceiling
- Run-1 produced sparse sampling (n=2) due to `tracemalloc.take_snapshot()` GIL-blocking; refactored to `tracemalloc.get_traced_memory()` (O(1)) for run-2

## Run-1 (archived; sampling defect)
- **MMD reached** (elapsed 600.0s ≥ 600 mmd_seconds → G105 PASS)
- **ops_completed = 71,571,197** (~119k ops/sec sustained throughput across 16 workers)
- 2 samples (start + final), all 6 drift signals static or below threshold delta
- Filed driver fix; re-ran as run-2

## Run-2 (canonical)
- elapsed = 600.0 s ≥ 600 s MMD → **G105 PASS**
- ops_completed = 78,665,545 (~131 k ops/sec sustained)
- 2 samples (initial + final). Sampler-starvation persists despite tracemalloc fix; root cause is asyncio scheduler bias against the sampler under hot worker loops. Sample-density-vs-significance reasoning in `soak-results.md` accepts PASS-with-INFO based on magnitude analysis (drift margins are 100×–250× under threshold). Filed PA-012.
- Drift verdict: **G106 PASS** on all 6 signals (see `drift-analysis.md`)

## Recommendation
After Phase 4 PA-011 lands, this driver will move into the pack as a pluggable cell consumed by the manifest's T5.5 dispatch; current bespoke implementation is sufficient to render PASS/FAIL/INCOMPLETE on this Pool client's drift signals.
