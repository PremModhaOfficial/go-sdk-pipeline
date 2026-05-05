<!-- Generated: 2026-04-27T00:02:05Z | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 | Reviewer: sdk-constraint-devil (READ-ONLY) | Note: agent not in active-packages.json; orchestrator brief requested explicit constraint plan — providing as design-lead surrogate review -->

# Constraint Bench Plan — `motadata_py_sdk.resourcepool`

Per CLAUDE.md rule 29 (Code Provenance Markers): `[constraint: ... bench/BenchmarkX]` triggers automatic bench proof (G97 equivalent). At design phase, no impl exists yet; this file lists the named benches that WILL prove each declared constraint at impl + testing phases.

## Verdict: PASS — bench plan complete; every TPRD §10 hard-constraint has a named bench

---

## Declared constraints (will be marked at impl phase)

| Symbol | Marker (impl phase will add) | Bench file | Bench function | Proves |
|---|---|---|---|---|
| `Pool._acquire_with_timeout` | `# [constraint: complexity O(1) amortized acquire bench/test_scaling.py::bench_acquire_release_cycle_sweep]` | tests/bench/bench_scaling.py | bench_acquire_release_cycle_sweep | O(1) amortized scaling at N ∈ {10, 100, 1k, 10k} |
| `Pool.release` | `# [constraint: complexity O(1) amortized release bench/test_scaling.py::bench_acquire_release_cycle_sweep]` | tests/bench/bench_scaling.py | bench_acquire_release_cycle_sweep | same sweep covers release |
| `Pool.acquire` | `# [constraint: alloc ≤4 per acquire bench/test_acquire.py::bench_acquire_happy_path]` | tests/bench/bench_acquire.py | bench_acquire_happy_path | allocs/op ≤ 4 per TPRD §10 |
| `Pool.try_acquire` | `# [constraint: latency p50 ≤5µs bench/test_acquire.py::bench_try_acquire]` | tests/bench/bench_acquire.py | bench_try_acquire | p50 ≤ 5µs |
| `Pool.acquire@contention` | `# [constraint: throughput ≥500k acq/s bench/test_acquire_contention.py::bench_contention_32x_max4]` | tests/bench/bench_acquire_contention.py | bench_contention_32x_max4 | ≥ 500k/s |
| `Pool.aclose` | `# [constraint: wallclock ≤100ms drain 1000 bench/test_aclose.py::bench_aclose_drain_1000]` | tests/bench/bench_aclose.py | bench_aclose_drain_1000 | ≤ 100ms |
| `_acquire_idle_slot` (G109 hot-path) | `# [hot-path bench/test_acquire.py::bench_acquire_happy_path]` | tests/bench/bench_acquire.py | bench_acquire_happy_path | ≥50% of acquire CPU samples |
| `_release_slot` (G109 hot-path) | `# [hot-path bench/test_acquire.py::bench_release]` | tests/bench/bench_acquire.py | bench_release | ≥30% of release CPU samples |

---

## Bench file existence requirement (impl phase S5 milestone)

Every named bench file above MUST exist at the end of S5. testing-lead's T5 wave runs them; sdk-benchmark-devil parses output JSON; sdk-complexity-devil runs the scaling sweep; sdk-profile-auditor runs py-spy on the hot-path benches.

Action items for impl phase:
- `tests/bench/bench_acquire.py` — 4 bench functions: bench_acquire_happy_path, bench_acquire_resource_happy_path, bench_try_acquire, bench_release, bench_stats
- `tests/bench/bench_acquire_contention.py` — 1 bench function: bench_contention_32x_max4
- `tests/bench/bench_aclose.py` — 1 bench function: bench_aclose_drain_1000
- `tests/bench/bench_scaling.py` — 1 bench function: bench_acquire_release_cycle_sweep (with sub-benches per N)

All bench functions use `pytest-benchmark` + `tracemalloc` for allocation accounting. Output → `bench.json` (consumed by sdk-benchmark-devil + sdk-complexity-devil + sdk-drift-detector).

---

## G97 enforcement at impl phase

When impl-lead lands the marked symbols (e.g. `# [constraint: latency p50 ≤5µs ...]`), guardrail-validator's G97 (or its python-aware sibling, materializing per python.json `notes.marker_protocol_note`) MUST verify:
1. The named bench file exists.
2. The named bench function exists in that file.
3. The bench, when run, produces output that satisfies the constraint.

Orphan markers (constraint declared but no bench) = BLOCKER per CLAUDE.md rule 29.

---

## Final verdict: PASS

Bench plan is complete. Every TPRD §10 hard-constraint has a named bench file + function. Every G109 hot-path declaration has a backing bench. impl phase S5 milestone is bench-authoring; testing phase T5 enforces.

No design rework required.
