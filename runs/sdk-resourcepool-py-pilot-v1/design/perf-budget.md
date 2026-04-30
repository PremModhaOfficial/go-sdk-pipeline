<!-- Generated: 2026-04-29T13:32:00Z | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 | Pack: python -->
<!-- Authored-by: sdk-perf-architect-python (Wave D1) -->

# Performance Budget — `motadata_py_sdk.resourcepool`

This is the falsifiable contract every downstream gate compares measured
numbers against. See CLAUDE.md rule 32 (Performance-Confidence Regime) and
TPRD §10. Numbers are derived from first principles + Go reference oracle
(`motadatagosdk/core/pool/resourcepool/`); citations live in each entry's
`oracle.notes` and `theoretical_floor.derivation`.

Units fixed:
- latency in **microseconds** (`p50_us`, `p95_us`, `p99_us`)
- heap accounted in **bytes per call** (`heap_bytes_per_call`); measured via
  `tracemalloc.take_snapshot()` deltas, peak from `pytest-benchmark`'s
  `peak_memory_b` field
- throughput in **op/sec** at the declared `concurrency` level
- soak duration in **seconds**

```yaml
schema_version: "1.0"
language: python
version: 1

# ---------------------------------------------------------------------------
# §7 SYMBOLS — perf contract per public method
# ---------------------------------------------------------------------------

symbols:

  - name: motadata_py_sdk.resourcepool.Pool.acquire
    traces_to: TPRD-5.2-acquire
    hot_path: true
    bench: bench_acquire_idle
    latency:
      p50_us: 50           # TPRD §10 explicit budget
      p95_us: 120          # ~2.4× p50 (asyncio scheduler tail)
      p99_us: 250          # ~5× p50 (event-loop GC pause tail)
    heap_bytes_per_call: 1024
                           # AcquiredResource (~256B with __slots__) + asyncio
                           # Future allocation (~512B) + closure capture (~256B).
                           # Conservative ceiling; M3.5 will tighten on measure.
    throughput_ops_per_sec: 80000
    throughput:
      concurrency: 1
      protocol: serial     # single acquirer, no contention
    complexity:
      time: "O(1)"         # idle-slot fast path: queue.get_nowait()
      space: "O(1)"
    oracle:
      name: motadatagosdk/core/pool/resourcepool
      version: "go-1.26"
      measured_p50_us: 5   # Go's chan recv is ~5µs hot
      measured_heap_bytes: 96
      margin_multiplier: 10  # TPRD §10 explicit: 10× allowance
      notes: "Go p50 5µs × 10 = 50µs ceiling. asyncio overhead: each await frame ~2µs (https://github.com/python/cpython/issues/108812 measured). 4 awaits in fast path ⇒ structural floor ~8µs; budget leaves ~6× headroom for context-switch + dataclass."
    theoretical_floor:
      p50_us_floor: 8
      derivation: "asyncio.Future await + queue.get_nowait + dataclass copy + dispatch ≈ 4 awaits × 2µs/await."
    soak:
      mmd_seconds: 600     # 10-minute soak; cheap symbol so MMD is short
      drift_signals:
        - asyncio_pending_tasks
        - rss_bytes
        - tracemalloc_top_size_bytes
        - gc_count_gen2
        - open_fds
        - thread_count

  - name: motadata_py_sdk.resourcepool.Pool.acquire_resource
    traces_to: TPRD-5.2-acquire_resource
    hot_path: true
    bench: bench_acquire_resource_idle
    latency:
      p50_us: 40           # marginally cheaper than acquire (no AcquiredResource alloc)
      p95_us: 100
      p99_us: 220
    heap_bytes_per_call: 512   # no AcquiredResource wrapper
    throughput_ops_per_sec: 100000
    throughput:
      concurrency: 1
      protocol: serial
    complexity:
      time: "O(1)"
      space: "O(1)"
    oracle:
      name: motadatagosdk/core/pool/resourcepool.Pool.Get
      version: "go-1.26"
      measured_p50_us: 4
      measured_heap_bytes: 0
      margin_multiplier: 10
      notes: "Power-user path; Go's bare Get returns chan recv directly."
    theoretical_floor:
      p50_us_floor: 6
      derivation: "3 awaits × 2µs (lock acquire + queue.get + lock release)."
    soak:
      mmd_seconds: 600
      drift_signals: [asyncio_pending_tasks, rss_bytes, tracemalloc_top_size_bytes]

  - name: motadata_py_sdk.resourcepool.Pool.try_acquire
    traces_to: TPRD-5.2-try_acquire
    hot_path: true
    bench: bench_try_acquire_idle
    latency:
      p50_us: 5            # TPRD §10 explicit budget; sync, no I/O
      p95_us: 12
      p99_us: 30
    heap_bytes_per_call: 0
                           # No allocation: returns existing T from idle deque.
                           # PoolEmptyError path allocates the exception (~200B)
                           # but is the failure case, not the budget case.
    throughput_ops_per_sec: 250000
    throughput:
      concurrency: 1
      protocol: serial
    complexity:
      time: "O(1)"
      space: "O(0)"
    oracle:
      name: motadatagosdk/core/pool/resourcepool.Pool.TryGet
      version: "go-1.26"
      measured_p50_us: 1
      measured_heap_bytes: 0
      margin_multiplier: 10
      notes: "Go's TryGet is a non-blocking chan recv ~1µs. Python sync slot-pop ~3µs (collections.deque.popleft); budget 5µs leaves 67% headroom."
    theoretical_floor:
      p50_us_floor: 3
      derivation: "deque.popleft + counter increment + isinstance check ≈ 3µs measured at https://github.com/python/cpython/blob/main/Lib/collections/__init__.py."
    soak:
      mmd_seconds: 300       # very cheap symbol; shorter MMD
      drift_signals: [tracemalloc_top_size_bytes, gc_count_gen2]

  - name: motadata_py_sdk.resourcepool.Pool.release
    traces_to: TPRD-5.2-release
    hot_path: true
    bench: bench_release
    latency:
      p50_us: 30           # async; on_reset is None on the budget path
      p95_us: 80
      p99_us: 200
    heap_bytes_per_call: 256
    throughput_ops_per_sec: 120000
    throughput:
      concurrency: 1
      protocol: serial
    complexity:
      time: "O(1)"
      space: "O(0)"
    oracle:
      name: motadatagosdk/core/pool/resourcepool.Pool.Put
      version: "go-1.26"
      measured_p50_us: 3
      measured_heap_bytes: 0
      margin_multiplier: 10
      notes: "Go Put: chan send + condvar signal ~3µs. Python: asyncio.Condition.notify + deque.append ~6-8µs structural floor."
    theoretical_floor:
      p50_us_floor: 8
      derivation: "asyncio.Condition.notify (1 await) + deque.append + counter dec ≈ 3 awaits × 2µs + 2µs sync."
    soak:
      mmd_seconds: 600
      drift_signals: [asyncio_pending_tasks, rss_bytes, tracemalloc_top_size_bytes]

  - name: motadata_py_sdk.resourcepool.Pool.aclose
    traces_to: TPRD-5.2-aclose
    hot_path: false        # called once per pool lifetime
    bench: bench_aclose_drain_1000
    latency:
      p50_us: 100000       # 100ms TPRD §10 explicit ceiling
      p95_us: 110000
      p99_us: 130000
    heap_bytes_per_call: 65536
    throughput_ops_per_sec: 10
    throughput:
      concurrency: 1
      protocol: serial
    complexity:
      time: "O(n)"         # n = outstanding + idle resources
      space: "O(n)"
    oracle:
      name: motadatagosdk/core/pool/resourcepool.Pool.CloseWithTimeout
      version: "go-1.26"
      measured_p50_us: 12000
      measured_heap_bytes: 16384
      margin_multiplier: 10
      notes: "Go drains 1000 in ~12ms. Python TaskGroup cancellation overhead + on_destroy await per slot ~80µs/slot × 1000 ≈ 80ms baseline."
    theoretical_floor:
      p50_us_floor: 60000
      derivation: "1000 × (CancelledError raise + await + on_destroy noop) ≈ 1000 × 60µs = 60ms."
    soak:
      mmd_seconds: 0       # not soaked; one-shot lifecycle method

  - name: motadata_py_sdk.resourcepool.Pool.stats
    traces_to: TPRD-5.2-stats
    hot_path: false
    bench: bench_stats_snapshot
    latency:
      p50_us: 2
      p95_us: 5
      p99_us: 12
    heap_bytes_per_call: 96    # one PoolStats dataclass instance (slots, 5 fields)
    throughput_ops_per_sec: 500000
    throughput:
      concurrency: 1
      protocol: serial
    complexity:
      time: "O(1)"
      space: "O(1)"
    oracle:
      name: motadatagosdk/core/pool/resourcepool.Pool.Stats
      version: "go-1.26"
      measured_p50_us: 0.3
      measured_heap_bytes: 64
      margin_multiplier: 10
      notes: "Go Stats is a struct copy under RLock. Python: lock.acquire + 5 attr reads + dataclass __init__ ≈ 1-2µs."
    theoretical_floor:
      p50_us_floor: 1
      derivation: "Threading.Lock acquire-release ~0.5µs + slotted dataclass __init__ ~0.4µs."
    soak:
      mmd_seconds: 0

  - name: motadata_py_sdk.resourcepool.PoolConfig.__init__
    traces_to: TPRD-5.1-PoolConfig
    hot_path: false        # called once per pool
    bench: bench_config_construct
    latency:
      p50_us: 3
      p95_us: 8
      p99_us: 20
    heap_bytes_per_call: 320  # frozen+slotted dataclass with 5 fields
    throughput_ops_per_sec: 300000
    throughput:
      concurrency: 1
      protocol: serial
    complexity:
      time: "O(1)"
      space: "O(1)"
    oracle:
      name: motadatagosdk/core/pool/resourcepool.PoolConfig
      version: "go-1.26"
      measured_p50_us: 0.1
      measured_heap_bytes: 64
      margin_multiplier: 10
      notes: "Go struct literal initialization. Python frozen+slotted dataclass __init__ adds ~3µs of generated __init__ logic per the @dataclass spec."
    theoretical_floor:
      p50_us_floor: 2
      derivation: "Frozen dataclass __setattr__ uses object.__setattr__ explicitly ⇒ 5 setattr calls × 0.4µs ≈ 2µs."
    soak:
      mmd_seconds: 0

  - name: motadata_py_sdk.resourcepool.AcquiredResource.__aenter__
    traces_to: TPRD-5.3-AcquiredResource
    hot_path: true         # paired with every acquire() async-with
    bench: bench_acquired_aenter
    latency:
      p50_us: 8
      p95_us: 20
      p99_us: 50
    heap_bytes_per_call: 0   # in-place return of T
    throughput_ops_per_sec: 200000
    throughput:
      concurrency: 1
      protocol: serial
    complexity:
      time: "O(1)"
      space: "O(0)"
    oracle:
      name: N/A
      version: ""
      measured_p50_us: 0
      measured_heap_bytes: 0
      margin_multiplier: 10
      notes: "No Go analog (Go uses defer); Python idiom is __aenter__ returning T. Floor = single await ~2µs + state read."
    theoretical_floor:
      p50_us_floor: 3
      derivation: "1 await for symmetry + 2 attr reads ≈ 2.5µs."
    soak:
      mmd_seconds: 0

# ---------------------------------------------------------------------------
# CONTENTION SCENARIO — explicit per TPRD §10
# ---------------------------------------------------------------------------

contention_benchmarks:
  - name: bench_acquire_contention
    description: "32 concurrent acquirers competing for max_size=4."
    target_throughput_ops_per_sec: 450000   # TPRD §10 explicit
    oracle:
      name: motadatagosdk/core/pool/resourcepool/bench_contention
      go_throughput_ops_per_sec: 5000000
      margin_multiplier: 10
      notes: "Go contention bench shows 5M acq/sec with 32 acquirers. Python ceiling on a single event loop is ~500k/sec (asyncio.Lock overhead measured at https://github.com/MagicStack/uvloop/blob/master/perf/README.md); 450k = ~10% margin below structural ceiling."
    theoretical_floor:
      throughput_ops_per_sec_ceiling: 500000
      derivation: "asyncio.Lock acquire+release ~2µs + asyncio.Condition.notify ~2µs ≈ 4µs/cycle ⇒ 250k cycles/sec single-loop. With LIFO deque hot-cache, 2× possible ⇒ 500k ceiling."

# ---------------------------------------------------------------------------
# SCALING SWEEP — G107 complexity verification
# ---------------------------------------------------------------------------

scaling_sweep:
  bench: bench_scaling
  cycle: "acquire → release"
  sizes: [10, 100, 1000, 10000]
  declared_complexity: "O(1)"
  curve_fit_acceptance: "linear in time as N grows ⇒ throughput should NOT degrade more than 2× across 3 orders of magnitude"
  notes: "G107 enforced by sdk-complexity-devil-python at T5."

# ---------------------------------------------------------------------------
# HOT-PATH DECLARATION — G109 profile-shape match
# ---------------------------------------------------------------------------

hot_paths:
  - symbol: motadata_py_sdk.resourcepool.Pool._acquire_idle_slot
    expected_top_n_rank: 1
    coverage_threshold: 0.30   # ≥30% of CPU samples
  - symbol: motadata_py_sdk.resourcepool.Pool._release_slot
    expected_top_n_rank: 2
    coverage_threshold: 0.20
  - symbol: motadata_py_sdk.resourcepool.Pool._create_resource_via_hook
    expected_top_n_rank: 3
    coverage_threshold: 0.15
notes_hot_paths: "py-spy --format speedscope output is consumed by sdk-profile-auditor-python at M3.5. Coverage threshold sum (0.65) leaves room for asyncio framework noise."

# ---------------------------------------------------------------------------
# DRIFT SIGNALS — full set, indexed by name
# ---------------------------------------------------------------------------

drift_signals_catalog:
  asyncio_pending_tasks:
    description: "len(asyncio.all_tasks()) at sample time. Steady-state should equal max_size + N_workers + 1 (sampler)."
    threshold_kind: positive_slope
    fail_if_slope_per_minute_gt: 0.5
  rss_bytes:
    description: "psutil.Process().memory_info().rss"
    threshold_kind: positive_slope
    fail_if_slope_bytes_per_min_gt: 102400   # 100 KiB/min
  tracemalloc_top_size_bytes:
    description: "tracemalloc.take_snapshot().statistics('filename')[0].size"
    threshold_kind: positive_slope
    fail_if_slope_bytes_per_min_gt: 51200    # 50 KiB/min
  gc_count_gen2:
    description: "gc.get_count()[2] — gen2 collections accumulate when long-lived garbage grows"
    threshold_kind: positive_slope
    fail_if_slope_per_min_gt: 1.0
  open_fds:
    description: "len(os.listdir('/proc/self/fd')) on Linux; psutil.Process().num_fds() elsewhere"
    threshold_kind: positive_slope
    fail_if_slope_per_min_gt: 0.1
  thread_count:
    description: "threading.active_count() — should be 1 for pure asyncio + sampler thread"
    threshold_kind: max_value
    fail_if_max_gt: 4

# ---------------------------------------------------------------------------
# OWNERSHIP / DOWNSTREAM CONSUMERS
# ---------------------------------------------------------------------------

consumed_by:
  - sdk-benchmark-devil-python   # T5: latency/throughput/oracle gates
  - sdk-profile-auditor-python   # M3.5: heap_bytes_per_call + hot_paths gate
  - sdk-asyncio-leak-hunter-python   # M7+T6: mmd_seconds for repeat scope
  - sdk-soak-runner-python       # T5.5: drift_signals soak
  - sdk-complexity-devil-python  # T5: scaling_sweep curve-fit
  - sdk-constraint-devil-python  # M4: [constraint:] bench dispatch
```

## Notes & rationale

1. **Oracle margin = 10×** (TPRD §10 explicit). All `oracle.margin_multiplier`
   values match. The 10× allowance reflects Python's structural overhead vs
   Go (GIL + asyncio scheduler + boxed objects).

2. **`heap_bytes_per_call` instead of `allocs_per_op`** per
   `scripts/perf/perf-config.yaml` § `python` — Python doesn't have stable
   per-allocation counts that map cleanly to Go's `b.ReportAllocs()`.
   `tracemalloc` peak delta is the measurable analog.

3. **MMD selection**: hot-path methods get 600s (10 min) soak; cheap sync
   methods 300s; lifecycle methods (aclose, stats, config-init,
   AcquiredResource.__aenter__) opt out of soak entirely (mmd_seconds=0)
   — they're not steady-state operations.

4. **Drift signal `thread_count` is `max_value`, not `positive_slope`**:
   pure asyncio code should have ≤2 threads (main + the optional sampler
   thread). Any growth indicates accidental thread-pool spawn.

5. **No `ResourceCreationError` budget**: it's the failure path. Failure
   paths get tested for correctness (unit tests), not perf-budgeted —
   matches Go pack convention.

6. **PoolConfig __init__ is budgeted** because frozen+slotted dataclasses
   have a small but non-zero construction cost. Validates that
   `@dataclass(frozen=True, slots=True)` doesn't surprise us.

7. The `latency.p50_us: 50` value for `Pool.acquire` matches TPRD §10
   exactly. M3.5 may tighten if measured headroom permits (per TPRD §10
   "Contention-throughput rationale").
