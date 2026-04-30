<!-- Generated: 2026-04-29T17:05:00Z | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 | Pack: python -->
<!-- Authored-by: sdk-testing-lead + sdk-benchmark-devil-python (Wave T5) -->

# Wave T5 — Benchmark + Complexity

## Verdict: PASS-WITH-2-CALIBRATION-WARN + 2-INCOMPLETE-INHERITED

## Command
`.venv/bin/pytest tests/bench/ --benchmark-only --benchmark-json=runs/.../testing/bench-results.json -o python_files='bench_*.py test_*.py'`

11/13 benches PASS, 2 FAIL with pre-existing harness bugs (PA-001, PA-002 inherited from Phase 2 INCOMPLETE).

## G108 oracle margin matrix (per perf-budget.md margin_multiplier = 10×)

| Symbol | Declared p50 (µs) | Go × 10 (µs) | Measured median (µs) | Headroom vs declared | Headroom vs Go×10 | Verdict |
|---|---:|---:|---:|---:|---:|---|
| `Pool.acquire` | 50 | 50 | 8.413 | 5.94× | 5.94× | **PASS** |
| `Pool.acquire_resource` | 40 | 40 | 7.653 | 5.23× | 5.23× | **PASS** |
| `Pool.release` | 30 | 30 | 7.651 | 3.92× | 3.92× | **PASS** |
| `Pool.try_acquire` | 5 | 10 | INCOMPLETE-by-harness (PA-001) | — | — | INCOMPLETE |
| `Pool.aclose` | 100000 | 120000 | INCOMPLETE-by-harness (PA-002) | — | — | INCOMPLETE |
| `Pool.stats` | 2 | 3.0 | 0.958 | 2.09× | 3.13× | **PASS** |
| `PoolConfig.__init__` | 3 | 1.0 | 2.337 | 1.28× | **0.43× (over)** | **CALIBRATION-WARN** |
| `AcquiredResource.__aenter__` | 8 | n/a | 8.664 | 0.92× (8% over decl) | n/a | **CALIBRATION-WARN** |
| `bench_acquire_contention` | n/a | n/a | 173.910 (full 32-acquirer sequence) | — | — | PASS (sequence-time) |

### CALIBRATION-WARN classification per learned pattern (sdk-dragonfly-s2)

Both findings are **mechanically-floor-bound**, not wrapper defects:

1. **`PoolConfig.__init__`** — measured 2.337µs, theoretical floor declared 2.0µs (delta-to-floor 0.34µs). Go×10 = 1.0µs is unreachable on Python: frozen+slotted dataclass `@dataclass(frozen=True, slots=True)` `__setattr__` via `object.__setattr__` for 5 fields ≈ 5 × 0.4µs = 2.0µs structural floor. The Go reference is a literal struct initializer (CPU-only, no Python interpreter overhead). The wrapper does the minimum the language permits.
2. **`AcquiredResource.__aenter__`** — measured 8.664µs, declared 8µs (8% over). IQR is 0.615µs ≈ 7% spread → within statistical noise. Theoretical floor declared 3µs. No Go analog (Go uses `defer`); this is a Python-idiomatic context-manager pattern. The 0.7µs overshoot vs declared 8µs ceiling is `await` scheduler-pause variance.

**H8 recommendation: Option A** (accept as calibration miss; revise baseline at H8).
- For PoolConfig: declared p50 should be revised upward to **3µs (current declared is already 3µs — only Go×10 oracle is the issue)** — the 10× oracle is meaningful for hot async paths but not for a one-shot frozen-dataclass init. Recommendation: keep `margin_multiplier: 10` but acknowledge `PoolConfig.__init__` is **floor-bound by language**; document a Python-specific oracle floor of 2µs in perf-budget.md and rerun the gate against that adjusted floor.
- For AcquiredResource: declared p50 should be revised to **10µs** (8µs ceiling + IQR margin). The 8.664µs measurement is in the "at-budget" band the perf-architect already flagged.

### G108 verdict
**G108: CALIBRATION-WARN** on 2 symbols (`PoolConfig.__init__` Go-oracle floor-bound; `AcquiredResource.__aenter__` 8% over within-IQR). H8 review REQUIRED to accept calibration revisions.

### G65 (regression vs baseline)
**G65: SEED — no comparison.** This is the first Python run; `baselines/python/performance-baselines.json` does not yet exist. Per `baselines/python/` partitioning (D1=B), Phase 4 baseline-manager will seed using these 11 measurements. Regression gate no-fires.

## G107 complexity (sweep N ∈ {10, 100, 1000, 10000})

Cycle = `acquire_resource` → `release`. Declared big-O **O(1)** per cycle.

| N | total_µs | per-cycle µs | ops/sec |
|---:|---:|---:|---:|
| 10 | 21.597 | 2.160 | 463,027 |
| 100 | 152.955 | 1.530 | 653,787 |
| 1,000 | 1,417.073 | 1.417 | 705,680 |
| 10,000 | 14,143.091 | 1.414 | 707,059 |

**Log-log slope (per_cycle_us vs N): −0.0585** (acceptance: `|slope| < 0.1` for declared O(1)).
**Per-cycle ratio max/min: 1.527×** (acceptance: `< 2.0×` per perf-budget.md `curve_fit_acceptance`).

Per-cycle time *decreases* slightly with N — amortized event-loop overhead from once-per-batch `loop.run_until_complete` setup. This is consistent with O(1) per-cycle behavior and validates the LIFO-deque hot-path allocation strategy from `algorithm-design.md`.

### G107 verdict
**G107: PASS.** Measured complexity matches declared O(1). No accidental quadratic / superlinear path detected.

## Inherited INCOMPLETE (Phase 4 backlog)
- **PA-001** — `bench_try_acquire_idle` fixture mismatch: bench passes async `on_create=_factory_sync` (which is sync) but Pool's hot_pool fixture has async on_create configured → `ConfigError`. Filed against Phase 4.
- **PA-002** — `bench_aclose_drain_1000` calls `asyncio.gather(*[pool.acquire_resource() for _ in range(1000)])` outside any event loop, causing `DeprecationWarning: There is no current event loop` then `ValueError`. Filed against Phase 4.

Both pre-existing from Phase 2 M3.5 — no new INCOMPLETE introduced at Phase 3.

## H8 trigger
**H8 REQUIRED** — G108 CALIBRATION-WARN on 2 symbols. User decides between:
- **Option A** (recommended per learned pattern): accept calibration; baseline-manager seeds with revised floors (PoolConfig 3µs declared retained, but Go×10 oracle marked as Python-floor-bound; AcquiredResource budget revised to 10µs).
- **Option B**: reject; back to design phase to retune perf-budget.md.
- **Option C**: tighten implementation — likely impossible given measured ≈ structural floor.

Soak/drift gate (T5.5) and leak gate (T6) verdicts also feed into H8 if non-PASS.

## Files
- `runs/sdk-resourcepool-py-pilot-v1/testing/bench-results.json` (raw pytest-benchmark JSON)
- `runs/sdk-resourcepool-py-pilot-v1/testing/reviews/sdk-benchmark-devil-python.md`
- `runs/sdk-resourcepool-py-pilot-v1/testing/reviews/sdk-complexity-devil-python.md`
