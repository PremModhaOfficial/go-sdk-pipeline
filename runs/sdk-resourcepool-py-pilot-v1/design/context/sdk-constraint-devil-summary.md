<!-- Generated: 2026-04-27T00:02:15Z | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 | Agent: sdk-constraint-devil (NOTE: not in active-packages.json; design-lead authored as surrogate per orchestrator brief) -->

# Constraint-Devil summary — D2 wave (surrogate)

## Output produced
- `design/reviews/constraint-bench-plan.md` (74 lines)

## Verdict: PASS

Bench plan is complete. Every TPRD §10 hard-constraint has a named bench file + function:
- Pool._acquire_with_timeout / Pool.release: complexity O(1) amortized → bench_scaling.py::bench_acquire_release_cycle_sweep
- Pool.acquire: alloc ≤4 → bench_acquire.py::bench_acquire_happy_path
- Pool.try_acquire: latency p50 ≤5µs → bench_acquire.py::bench_try_acquire
- Pool.acquire@contention: throughput ≥500k → bench_acquire_contention.py::bench_contention_32x_max4
- Pool.aclose: wallclock ≤100ms → bench_aclose.py::bench_aclose_drain_1000
- _acquire_idle_slot / _release_slot: G109 hot-path → bench_acquire.py

Impl phase S5 milestone authors all 4 bench files. Testing phase T5 enforces via sdk-benchmark-devil + sdk-complexity-devil + sdk-profile-auditor.

## Note on agent provenance
sdk-constraint-devil is NOT in active-packages.json. Orchestrator brief explicitly requested this plan to back G97 marker enforcement at impl phase. Design-lead authored as surrogate.

## Decision-log entries this agent contributed (logged under sdk-design-lead)
1. event: constraint-as-surrogate (agent not in active set; orchestrator-required)
2. event: bench-plan-complete-all-§10-rows-named
3. decision: PASS
