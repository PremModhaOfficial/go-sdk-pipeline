<!-- Generated: 2026-04-29T13:43:30Z | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 -->

# Design-Lead Context Summary

For consumption by `sdk-impl-lead` (Phase 2). ≤200 lines per CLAUDE.md rule 2.

## What landed in design

The design package authoritatively specifies **9 public symbols**, the
**perf contract** for each, the **algorithm** + **concurrency model** + **error
taxonomy** + **package layout** they require. Mode A — greenfield Python —
so impl creates everything from scratch under
`/home/meet-dadhania/Documents/motadata-ai-pipeline/motadata-sdk/`
(currently empty modulo `TPRD.md`).

## Public surface (`api.py.stub`)

```
Pool[T]                    # class — async pool; async-ctx-mgr
PoolConfig[T]              # frozen+slotted dataclass
PoolStats                  # frozen+slotted dataclass
AcquiredResource[T]        # async ctx mgr returned by Pool.acquire()
PoolError                  # base exception
  PoolClosedError
  PoolEmptyError
  ConfigError
  ResourceCreationError    # lifted from TPRD §7 inline-note
```

## Algorithm summary (`algorithm-design.md`)

- State: `_max_size`, `_idle: deque`, `_in_use`, `_created`, `_closed`,
  `_closing`, `_lock` (asyncio.Lock — base of Condition `_slot_available`),
  `_async_on_create` (cached at init).
- **Fast path** — `acquire_resource`: idle deque non-empty → popleft,
  `_in_use += 1`, return. O(1).
- **Capacity-create path**: `_in_use += 1; _created += 1` BEFORE awaiting
  `on_create`. On hook failure roll back both counters.
- **Wait path**: `asyncio.wait_for(_slot_available.wait(), remaining)`.
  Cancellation propagates cleanly because `_in_use` was NOT incremented
  before the wait.
- LIFO via `collections.deque` (cache locality > FIFO fairness).

## Concurrency invariants

- One asyncio event loop per Pool instance. Cross-loop = undefined.
- `asyncio.Lock` held during `on_create` await (intentional, matches Go).
- Cancellation correctness proven: cancelled `acquire_resource` mid-wait
  leaves `_in_use` unchanged ⇒ `pool.stats().waiting == 0` invariant holds.
- `try_acquire` is sync, relies on GIL bytecode atomicity; raises
  `ConfigError` if `on_create` is async.
- No background tasks spawned by pool itself in v1.

## Error model

- All 5 PoolError subclasses are sentinels (no extra fields).
- `ResourceCreationError` uses `raise ... from e` (PEP 3134) — `__cause__`
  preserves user's exception.
- `asyncio.CancelledError` is RE-RAISED (never wrapped, never swallowed).
- Per `python-asyncio-leak-prevention` Rule 1.

## Perf contract (the linchpin per CLAUDE.md rule 32)

8 symbols budgeted in `perf-budget.md`. Hot paths: acquire (50 µs p50),
acquire_resource (40 µs), try_acquire (5 µs), release (30 µs),
AcquiredResource.__aenter__ (8 µs). All oracle-anchored to Go pool with
**10× margin** (TPRD §10). Heap budget per symbol stated in `heap_bytes_per_call`
(per `scripts/perf/perf-config.yaml` § python). Drift signals: 6 declared,
indexed in `drift_signals_catalog`.

Hot-path declarations (G109): `_acquire_idle_slot`, `_release_slot`,
`_create_resource_via_hook`. Profile-auditor at M3.5 will compare py-spy
top-10 against these.

## Layout

```
src/motadata_py_sdk/resourcepool/{__init__,_config,_stats,_errors,_acquired,_pool}.py
src/motadata_py_sdk/py.typed
tests/{unit,integration,bench,leak}/...
pyproject.toml + hatchling backend + Apache-2.0 license
```

## Open items handed to impl-lead

1. **DD-005** — append docstring note to `Pool.acquire`: "If `on_create`
   performs I/O, prefer warming the pool at startup."
2. **CV-001** — import `Callable` from `collections.abc`, not `typing`.
3. **PK-001** — use PEP 639 SPDX `license = "Apache-2.0"` form in
   pyproject.toml.
4. **PK-002** — add `[tool.uv]` block if uv is the chosen resolver.
5. **G200-py + G32-py** re-fire at impl-exit (M9). Both need a populated
   `pyproject.toml` to validate; design declared the content authoritatively
   in `package-layout.md`. Impl must produce the file matching that decl.

## What impl-lead must NOT change without design re-approval

- The 9-symbol `__all__` list (semver freeze for v1.0.0).
- The 8-symbol perf-budget targets (would invalidate downstream gates).
- The frozen+slotted dataclass shape of PoolConfig/PoolStats.
- The async-vs-sync method split (`acquire`, `acquire_resource`, `release`,
  `aclose` async; `try_acquire`, `stats` sync).
- The error class hierarchy (5 classes; sentinel-style; PEP 3134 chaining
  for ResourceCreationError).

Any change to those requires a design revision and a new H5.

## Pilot-meta hooks (for Phase 4 retrospective per TPRD Appendix C)

- **D2 evaluation**: sdk-design-devil quality_score on Python = 87 vs Go
  baseline ~85; within ±3pp ⇒ Lenient holds for this agent.
- **D6 evaluation**: shared-core devils with python/conventions.yaml
  produced clean Python findings (no Go-flavored noise). D6=Split working.
- **T2-3 (drift naming)**: chose `asyncio_pending_tasks` over
  `outstanding_tasks` (collision) and `concurrency_units` (open).
- **T2-7 (adapter scripts)**: deferred — leak-check + py-spy adapters
  surface at M3.5 / M9 / T6.

## State

- decision-log.jsonl: 18 entries total, max 9 per agent (under rule 11 cap).
- All design context files written under `runs/.../design/`.
- Run-manifest will mark `phases.design.status = "completed"` post-H5.
