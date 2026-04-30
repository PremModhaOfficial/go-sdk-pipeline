# TPRD — `motadata_py_sdk.resourcepool` · Python Adapter Pilot v1

**Module**: `motadata_py_sdk/resourcepool/` (new package, target Python SDK)
**Owner**: Platform SDK
**Status**: Draft v0.1 — first Python adapter pilot for v0.5.0 Phase B
**Date**: 2026-04-29
**Request Mode**: **A — New package** (target SDK does not yet exist; the pilot creates it).
**Scope**: Port the well-defined Go primitive `motadatagosdk/core/pool/resourcepool/Pool[T]` (a generic in-memory resource pool with cancellation, timeouts, and graceful shutdown) to idiomatic async Python. The port is the empirical test of D2 + D6 from `docs/LANGUAGE-AGNOSTIC-DECISIONS.md`.

---

## §Target-Language

`python` — exercises Python adapter manifest at `.claude/package-manifests/python.json` (v0.5.0 Phase A scaffold).

## §Target-Tier

`T1` — full perf-confidence regime per pipeline rule 32. Pool's hot path (Get/Put under contention) is a meaningful candidate for alloc budget + scaling sweep + soak (drift detection over heap_bytes + outstanding-task count).

## §Required-Packages

`["shared-core@>=1.0.0", "python@>=1.0.0"]` — defaults are correct; declared explicitly for documentation.

---

## 1. Purpose

Port the Go `Pool[T]` primitive to async Python. The pilot has two intertwined goals:

**Primary (delivery)**: ship `motadata_py_sdk.resourcepool.Pool` — a typed async resource pool with the same semantic contract as its Go counterpart (bounded capacity, async acquire with timeout, blocking-or-cancel behavior, graceful shutdown with outstanding-resource tracking, optional create/reset/destroy hooks with panic recovery).

**Secondary (pipeline test)**: exercise the agent fleet on Python source for the first time. Specifically test:

- **D2** (cross-language fairness for shared-core debt-bearers): does `sdk-design-devil`'s `quality_score` on this Python run materially differ from the Go-pool baseline? If divergence ≥3pp on any debt-bearer agent, that agent flips to per-language partition (Progressive fallback). If indistinguishable, Lenient stays.
- **D6** (Split shape — rule shared, examples per-lang): which shared-core agent prompts genuinely need a `python/conventions.yaml` companion vs. which work as-is? Author the conventions file lazily, only for agents that visibly fail.
- **T2-3** (drift signals): the pool's outstanding-task tracker is the Python analog of Go's `sync.WaitGroup`-tracked goroutines. Forces the rename decision: `goroutines` → `concurrency_units`?
- **T2-7** (adapter script policy): the leak-check adapter must verify "all acquired items released before pool closure." Python equivalent of `goleak.VerifyTestMain`. Forces decision on `seam:leak-check` adapter shape.

## 2. Goals

- Async-native API: `async with pool.acquire(timeout=N) as r:` is the canonical use; manual `acquire()` / `release()` is a power-user fallback.
- Type-safe via `Generic[T]` + strict mypy compatibility (`mypy --strict` passes on the package).
- `asyncio.timeout()` (Python 3.11+) as the canonical deadline carrier; no integer-seconds-since-epoch globals.
- Cancellation correctness: a coroutine canceled while waiting on a pool slot must propagate `CancelledError` cleanly, never leak the slot, and must NOT be silently swallowed.
- Lifecycle hooks (`on_create`, `on_reset`, `on_destroy`) callable as either sync functions or coroutines; pool detects + awaits as needed. Panic-recovery semantic preserved (a hook raising must not corrupt pool state; the offending resource is destroyed; the pool stays usable).
- Graceful shutdown via `aclose()` (canonical Python async-close). Optional `timeout` arg for bounded shutdown; outstanding acquires must complete or be cancelled at deadline.
- Observability hooks: `pool.stats()` returns a frozen `PoolStats` dataclass at any time; intended caller wiring into OTel is out of pilot scope (deferred to a follow-up TPRD with the Python OTel adapter).
- Test coverage ≥90% mirroring the Go module's 35-test surface area (state transitions, contention, panic recovery, race conditions equivalent for asyncio).
- Bench at N ∈ {10, 100, 1k, 10k} concurrent acquirers; oracle-calibrate against the Go reference numbers (within an order of magnitude on throughput; complexity must be O(1) amortized for acquire/release per the Go declaration).

## 3. Non-Goals

- **No** distributed pool / multi-process pool — single asyncio event loop.
- **No** thread pool — this is for asyncio coroutines, not `concurrent.futures`. Sync callers wrap with `asyncio.run()` themselves.
- **No** OTel wiring in this pilot — deferred to a follow-up TPRD once `python-otel-hook-integration` skill exists.
- **No** dynamic resizing post-construction (`MaxSize` is set at config time; matches Go's pool).
- **No** automatic resource expiry / TTL — caller drives lifecycle via hooks.
- **No** load-shedding / queue-depth backpressure — `acquire()` either blocks within timeout or raises.
- **No** circuit-breaker integration — separate concern.
- **No** rate limiting — separate concern.
- **No** Python 3.10 backport — pilot targets 3.11+ for `asyncio.timeout()` + `TaskGroup` + exception groups.
- **No** sync `Pool` variant — async-only.
- **No** sync-callable hook coercion via `asyncio.to_thread()` magic — caller-declared hook is awaited if it's a coroutine, called directly if it's a plain function. No automatic offloading.
- **No** streaming acquire (yielding multiple resources from one acquire). Single-shot only.
- **No** integration with the Go target SDK — this is a new Python package, intentionally independent.

## 4. Compat Matrix

| Target | Version |
|---|---|
| Python | 3.11+ (pinned; `asyncio.timeout()` + `TaskGroup` are 3.11) |
| `mypy` | latest (strict mode) |
| `pytest` | 8.x |
| `pytest-asyncio` | 0.23.x |
| `pytest-benchmark` | 4.x |
| `ruff` | latest |
| `pip-audit` / `safety` | latest |
| OS | Linux primary; macOS dev-target |
| Async runtime | stdlib `asyncio` only (no anyio / trio for v1; could split into adapter later) |
| External deps for the package | **zero** — stdlib only |

## 5. API Surface

### 5.1 Construction

```python
from dataclasses import dataclass
from typing import Awaitable, Callable, Generic, TypeVar

T = TypeVar("T")

@dataclass(frozen=True, slots=True)
class PoolConfig(Generic[T]):
    """Immutable pool configuration. Pass to Pool() or Pool.from_config().

    [traces-to: TPRD-§5.1-PoolConfig]
    """
    max_size: int
    on_create: Callable[[], T | Awaitable[T]]
    on_reset:   Callable[[T], None | Awaitable[None]] | None = None
    on_destroy: Callable[[T], None | Awaitable[None]] | None = None
    name: str = "resourcepool"

class Pool(Generic[T]):
    """Bounded async resource pool. Resources are lazily created up to max_size,
    handed out via acquire(), and released back via release() or async-with.

    Use:
        config = PoolConfig(max_size=10, on_create=make_thing, on_destroy=teardown_thing)
        pool = Pool(config)
        async with pool.acquire(timeout=5.0) as resource:
            await use(resource)
        # auto-released

    Or manually:
        resource = await pool.acquire_resource(timeout=5.0)
        try:
            await use(resource)
        finally:
            await pool.release(resource)

    Cancellation: a coroutine cancelled mid-acquire propagates CancelledError;
    the pool slot is NOT leaked.

    Shutdown: await pool.aclose() to drain. After aclose, all acquire() calls
    raise PoolClosedError.

    [traces-to: TPRD-§5.1-Pool]
    """

    def __init__(self, config: PoolConfig[T]) -> None: ...
```

### 5.2 Methods

```python
class Pool(Generic[T]):
    # ... (continuing class body)

    async def acquire(
        self,
        *,
        timeout: float | None = None,
    ) -> "AcquiredResource[T]":
        """Returns an async context manager yielding a pooled T.

        Use:
            async with pool.acquire(timeout=5.0) as r:
                ...

        Raises:
            asyncio.TimeoutError if timeout exceeds before a slot frees.
            asyncio.CancelledError if the awaiting task is cancelled.
            PoolClosedError if pool.aclose() has been called.

        [traces-to: TPRD-§5.2-acquire]
        """

    async def acquire_resource(self, *, timeout: float | None = None) -> T:
        """Power-user: acquire without context-manager wrapping.

        Caller must release via pool.release(t). Failing to release leaks the
        slot until pool closure. Recommended only when the caller cannot use
        async-with (e.g. resource lifetime spans multiple coroutines).

        [traces-to: TPRD-§5.2-acquire_resource]
        """

    def try_acquire(self) -> T:
        """Non-blocking acquire. Returns immediately or raises PoolEmptyError.

        Synchronous because no I/O. Subject to: pool open, slot free, on_create
        synchronous. If on_create is async, try_acquire raises ConfigError.

        [traces-to: TPRD-§5.2-try_acquire]
        """

    async def release(self, resource: T) -> None:
        """Returns a manually-acquired resource to the pool.

        on_reset (if configured) is awaited before the resource becomes
        available again. on_reset raising → resource is destroyed via
        on_destroy, slot is freed. Subsequent acquire() creates a fresh one.

        [traces-to: TPRD-§5.2-release]
        """

    async def aclose(self, *, timeout: float | None = None) -> None:
        """Graceful shutdown.

        Behavior:
        1. Pool transitions to closing — new acquire() raises PoolClosedError.
        2. Awaits up to `timeout` for all outstanding acquired resources to
           be released.
        3. On timeout: outstanding-acquire tasks are cancelled (CancelledError
           raised in their await sites); any returned-after-cancel resources
           are still on_destroy'd.
        4. All idle resources are on_destroy'd.

        Idempotent — second call is a no-op.

        [traces-to: TPRD-§5.2-aclose]
        """

    def stats(self) -> "PoolStats":
        """Snapshot of current pool state (immutable). No allocations on hot
        path beyond the dataclass instance.

        [traces-to: TPRD-§5.2-stats]
        """

    def __aenter__(self) -> "Pool[T]": ...    # equivalent to constructed pool
    async def __aexit__(self, *exc) -> None: ... # equivalent to aclose
```

### 5.3 Auxiliary types

```python
@dataclass(frozen=True, slots=True)
class PoolStats:
    """Frozen snapshot of pool state.

    [traces-to: TPRD-§5.3-PoolStats]
    """
    created: int        # total resources ever created
    in_use: int         # currently checked out
    idle: int           # in pool, ready for acquire
    waiting: int        # tasks parked in acquire(), waiting for a slot
    closed: bool


class AcquiredResource(Generic[T]):
    """Async context manager returned by pool.acquire(). NOT user-constructed.

    [traces-to: TPRD-§5.3-AcquiredResource]
    """
    async def __aenter__(self) -> T: ...
    async def __aexit__(self, *exc) -> None: ...   # calls pool.release()
```

### 5.4 Errors

All sentinel exceptions inherit from `PoolError`. None of these are caught and re-raised internally — caller asserts via `isinstance(e, PoolClosedError)` etc.

```python
class PoolError(Exception):
    """Base for all resourcepool errors. [traces-to: TPRD-§5.4-PoolError]"""

class PoolClosedError(PoolError):
    """Raised on acquire after aclose. [traces-to: TPRD-§5.4-PoolClosedError]"""

class PoolEmptyError(PoolError):
    """Raised by try_acquire when pool has no slot available right now.
    [traces-to: TPRD-§5.4-PoolEmptyError]"""

class ConfigError(PoolError):
    """Raised at Pool() construction on invalid config (max_size <= 0,
    on_create None, sync try_acquire with async on_create, etc.).
    [traces-to: TPRD-§5.4-ConfigError]"""
```

`asyncio.TimeoutError` and `asyncio.CancelledError` are re-raised on bounded-wait cancellation — these are not pool-specific.

## 6. Config Validation

Performed in `Pool.__init__`:

- `max_size <= 0` → `ConfigError("max_size must be > 0")`
- `on_create is None` → `ConfigError("on_create is required")`
- `name` non-string or empty → coerce to default; do not error.

No reconfiguration after construction (matches Go's `PoolConfig`).

## 7. Error Model — Errors / Exceptions

See §5.4. Additionally:

- A hook (`on_create`, `on_reset`, `on_destroy`) raising propagates the user's exception only via the LIFECYCLE PATH — `acquire()` raises the user-thrown exception wrapped in a `ResourceCreationError(PoolError)` if `on_create` failed, leaving the slot free for the next acquirer. `on_reset` failure → that resource is destroyed; next acquire creates a fresh one. `on_destroy` failure → logged at WARN, slot still freed (matches Go pool's "best effort destroy").
- Cancellation correctness: any `CancelledError` caught for cleanup MUST be re-raised after `await self._restore_slot()`. Testable via `pytest-asyncio` cancel-mid-acquire.

## 8. Observability

Out of scope for this pilot. `pool.stats()` is the only observability surface. Caller-side OTel wiring belongs in a follow-up TPRD that establishes `python-otel-hook-integration` skill.

## 9. Security

- No secrets/credentials are pool-handled — caller's responsibility per `on_create`.
- No deserialization of untrusted input (resources are caller-typed `T`).
- `safety check` + `pip-audit` clean (zero direct deps).

## 10. NFR — Performance Targets

| Symbol | Metric | Budget | Bench |
|---|---|---|---|
| `Pool.acquire` happy path (slot idle) | latency p50 | ≤ 50 µs | `bench_acquire_test.py` |
| `Pool.acquire` happy path | allocs/op | ≤ 4 (one PoolStats? no — none on hot path; one Task? framework-level; aim: ≤ 4 user-level Python objects per acquire) | `bench_acquire_test.py` |
| `Pool.try_acquire` | latency p50 | ≤ 5 µs | `bench_acquire_test.py` |
| `Pool.acquire` under contention (32 acquirers, max_size=4) | throughput (acquires/sec) | ≥ 450k (within 10× of Go reference; oracle field carries the Go number) | `bench_acquire_contention.py` |
| `Pool.aclose` | wallclock to drain 1000 outstanding resources | ≤ 100 ms | `bench_aclose.py` |
| Scaling sweep `acquire/release` cycle | complexity | O(1) amortized | `bench_scaling_test.py` (G107) |

**Oracle**: per-bench Go-reference numbers from `motadatagosdk/core/pool/resourcepool/bench_*_test.go` are recorded in `runs/<run-id>/design/perf-budget.md` `oracle.reference_impl_p50` field. Margin: `≤ 10× Go's number` — Python is allowed to be slower (1ms acquire is fine if Go is 50µs) but not by more than an order of magnitude. This margin informs T2-1 (cross-language oracle calibration) — calibrate during this run.

**Contention-throughput rationale**: `≥ 450k acq/sec` is derived from a back-of-envelope theoretical ceiling for `asyncio.Lock` + `asyncio.Condition` on a single event loop (~500k acq/sec). The 450k target leaves ~10% margin below the structural ceiling; if M3.5 profile-auditor measures materially higher headroom, the budget can tighten at H7 design sign-off.

**Big-O declaration** (G107): `acquire/release` is O(1) amortized. `aclose` is O(n) in outstanding resources. Declared in `perf-budget.md`; `sdk-complexity-devil` runs scaling sweep at N ∈ {10, 100, 1k, 10k} acquirers.

**Hot-path declaration** (G109): `_acquire_idle_slot`, `_release_slot`, `_create_resource_via_hook` are the three top-level CPU consumers expected in pprof-equivalent profile. py-spy will be the profiler (decision: T2-7 — adapter script for Python profiler must emit normalized JSON).

## 11. Test Strategy

### 11.1 Unit (`tests/unit/`)
`pytest-asyncio`, no external services. ≥90% line + branch coverage.

Required tables:
- **Construction**: invalid max_size, missing on_create, sync vs async hooks.
- **Happy path**: acquire → release → re-acquire returns same resource (with on_reset called once).
- **Contention**: 32 acquirers competing for max_size=4 — all must succeed in bounded time.
- **Cancellation**: a task cancelled mid-acquire must NOT leak the slot. Verify via `pool.stats().waiting == 0` post-cancel.
- **Timeout**: `acquire(timeout=0.01)` against an exhausted pool raises `TimeoutError` cleanly.
- **Shutdown**: `aclose()` with outstanding acquires waits up to `timeout`, then cancels.
- **Hook panics**: `on_create` raising → next acquire creates fresh; pool state intact.
- **Idempotent close**: second `aclose()` is a no-op.

### 11.2 Integration (`tests/integration/`)
Cross-feature scenarios. `pytest-asyncio` with multiple acquirers spawned via `asyncio.TaskGroup`.

Sample scenario: 100 acquirers, max_size=10, 50% of `on_create` calls raise `ResourceCreationError` randomly, asserts:
- All eventual acquirers either succeed or see `ResourceCreationError`.
- No slot leaks (post-test `pool.stats().created` matches expected).
- No hung tasks (test passes within wallclock cap).

### 11.3 Bench (`tests/bench/`)
`pytest-benchmark`. See §10. Each bench writes its result to a JSON the pipeline parses for regression.

### 11.4 Leak detection
Asyncio analog of `goleak`. Custom fixture `assert_no_leaked_tasks` that snapshots `asyncio.all_tasks()` before/after each test, raises if any non-current-task remains. Backs G63 equivalent (T2-7 adapter shape).

### 11.5 Race
Python's GIL makes traditional race detection less applicable, but contention bugs (slot leaks under cancellation, hook ordering) still happen. Tests must run with `pytest-asyncio` `asyncio_mode = strict` and `--count=10` for flake detection.

## 12. Package Layout

```
motadata_py_sdk/
├── pyproject.toml
├── README.md
├── src/motadata_py_sdk/resourcepool/
│   ├── __init__.py            # public exports
│   ├── _config.py             # PoolConfig dataclass
│   ├── _pool.py               # Pool main class
│   ├── _stats.py              # PoolStats
│   ├── _errors.py             # PoolError + descendants
│   └── _acquired.py           # AcquiredResource context manager
├── tests/
│   ├── unit/test_construction.py
│   ├── unit/test_acquire_release.py
│   ├── unit/test_cancellation.py
│   ├── unit/test_timeout.py
│   ├── unit/test_aclose.py
│   ├── unit/test_hook_panic.py
│   ├── integration/test_contention.py
│   ├── integration/test_chaos.py
│   ├── bench/bench_acquire.py
│   ├── bench/bench_acquire_contention.py
│   ├── bench/bench_aclose.py
│   ├── bench/bench_scaling.py
│   └── leak/test_no_leaked_tasks.py
└── docs/
    ├── USAGE.md
    └── DESIGN.md
```

All `.py` files carry `# [traces-to: TPRD-<section>]` markers per pipeline rule 29 (Python comment syntax = `#`, declared in `python.json` `marker_comment_syntax`).

## 13. Milestones

| Slice | Scope | Priority |
|---|---|---|
| S1 | `_config.py` + `_errors.py` + `_stats.py` + tests | Pilot |
| S2 | `_pool.py` core: `__init__`, `acquire`, `release`, `try_acquire` (idle slot fast-path) | Pilot |
| S3 | Cancellation correctness + timeout + hook awaiting | Pilot |
| S4 | `aclose` graceful shutdown + idempotency | Pilot |
| S5 | All bench files + scaling-sweep bench | Pilot |
| S6 | Hook panic recovery + edge cases (sync hook + async hook detection) | Pilot |

## 14. Risks

| Risk | Mitigation |
|---|---|
| Cancellation mid-acquire leaks the slot | Cancel-test in unit tier asserts `pool.stats().waiting == 0` post-cancel. Coverage gate. |
| `try_acquire` with async `on_create` is a footgun — silent slow path | `ConfigError` raised at first `try_acquire` call; doc'd in §5.2. |
| Sync `on_destroy` blocks the event loop | Doc strongly recommends async hooks for I/O destruction; sync hooks for in-memory teardown only. Linter test detects sync-hook + I/O-imports combination as WARN. |
| Bench numbers diverge wildly from Go (oracle margin breach) | Margin set to 10× — generous on purpose since GIL + asyncio overhead is structural. The actual quality of the port is judged by *consistency across runs* (drift baseline), not absolute parity. |
| `asyncio.timeout()` re-raises `TimeoutError` differently from `asyncio.wait_for` (3.11 vs 3.10) | Pinned 3.11+ in `pyproject.toml`; CI matrix runs 3.11, 3.12, 3.13. |
| Python `dataclass(frozen=True)` doesn't actually prevent mutation of nested mutable fields (e.g. callbacks in PoolConfig) | Dataclass freezing is sufficient because callbacks are referenced, not mutated — reset/destroy hooks are intentionally caller-replaceable across pool instances, but a single Pool's config is captured at __init__ and never reread. |
| pytest-asyncio strict mode breaks teardown of cancelled tasks | All async fixtures use explicit cleanup via `try/finally` or `pytest_asyncio.fixture(loop_scope="function")`. |

## 15. Open Questions

- **Q1**: Should `acquire()` accept a positional `timeout` arg or only keyword? → **Decided: keyword-only** (`*, timeout: float | None = None`). Forces explicit-named call sites; matches `asyncio.wait_for` signature philosophy.
- **Q2**: Should `try_acquire` be `def` (sync) or `async def`? → **Decided: sync**. No I/O, no await needed. Mismatched async `on_create` raises `ConfigError`.
- **Q3**: Should `Pool` itself be an async-context-manager (so `async with Pool(config) as pool: ...` works)? → **Decided: yes**. `__aenter__` returns self; `__aexit__` calls `aclose`. Matches Python idiom.
- **Q4**: Should `release` be sync (to avoid an await on the hot path)? → **Decided: async**. `on_reset` may be async; if we made `release` sync, async hooks couldn't fire. Trade hot-path overhead for hook flexibility.
- **Q5**: Should pool size be enforceable via `__slots__` for memory locality? → **Decided: yes** on `PoolConfig` (frozen + slots). Pool itself uses `__slots__` if benchmarks justify (likely yes).
- **Q6**: Should we expose `pool.acquire()` as both context manager AND awaitable (so `r = await pool.acquire()` returns T directly, while `async with pool.acquire() as r:` yields T)? → **Decided: NO**. Two separate methods (`acquire` returns context manager, `acquire_resource` returns T directly) — the dual-mode trick is too cute; explicit is better.
- **Q7**: Drift signal naming — should the soak observer track `outstanding_tasks` or `concurrency_units`? → **PILOT-DRIVEN — surfaces T2-3.** Author the soak harness using whichever name the first design-devil pass produces. Capture the friction in a Phase B retrospective.

## 16. Breaking-Change Risk

**Mode A — new package**. `motadata_py_sdk` does not yet exist; this pilot creates it. No semver risk against prior shipping API. Initial version `1.0.0` (with `experimental = false`) — the port is the reference implementation; subsequent users adopting it can rely on stable API.

`sdk-semver-devil` verdict: **ACCEPT 1.0.0** (Mode A, new package).
`sdk-breaking-change-devil`: **N/A** (no prior API).
`sdk-convention-devil`: confirm Python conventions — `snake_case` methods, `PascalCase` classes, `_private` underscore prefix on internals, type hints on every public signature, frozen+slotted dataclasses for config/stats.

---

## §Skills-Manifest

Required skills (tested via I2 — WARN on miss, file to `docs/PROPOSED-SKILLS.md`):

| Skill | Min version | Why required | Source pack |
|---|---|---|---|
| `python-asyncio-patterns` | 1.0.0 | §5 async API, §11.4 task lifecycle, §11.1 cancellation correctness | python (v0.5.0 Phase B) |
| `python-sdk-config-pattern` | 1.0.0 | §5.1 PoolConfig — frozen+slotted dataclass, immutable post-construction | python (v0.5.0 Phase B) |
| `python-exception-patterns` | 1.0.0 | §5.4 PoolError hierarchy + sentinel-style exception classes | python (v0.5.0 Phase B) |
| `python-pytest-patterns` | 1.0.0 | §11.1 parametrized table-driven unit tests | python (v0.5.0 Phase B) |
| `python-asyncio-leak-prevention` | 1.0.0 | §5.2 timeout + cancellation propagation, §11.4 leaked-task fixture | python (v0.5.0 Phase B) |
| `python-mypy-strict-typing` | 1.0.0 | §2 mypy --strict pass; §5 Generic[T] typing | python (v0.5.0 Phase B) |
| `tdd-patterns` | 1.0.0 | red→green→refactor per slice; shared-core (debt-bearer — first Python exercise) | shared-core |
| `idempotent-retry-safety` | 1.0.0 | §3 non-goal confirmation that pool is NOT a retry primitive; shared-core (debt-bearer) | shared-core |
| `network-error-classification` | 1.0.0 | §11.1 cancellation + timeout error taxonomy; shared-core (debt-bearer) | shared-core |
| `spec-driven-development` | 1.0.0 | this TPRD itself is the contract | shared-core |
| `decision-logging` | 1.0.0 | every agent appends to `decision-log.jsonl` | shared-core |
| `guardrail-validation` | 1.0.0 | G05 + G20–G24 + the language-neutral subset | shared-core |
| `review-fix-protocol` | 1.0.0 | review→fix iteration loop | shared-core |
| `lifecycle-events` | 1.0.0 | every agent emits lifecycle entries | shared-core |
| `feedback-analysis` | 1.0.0 | Phase 4 reads decision-log + drift baselines | shared-core |
| `sdk-marker-protocol` | 1.0.0 | `[traces-to:]` markers on every pipeline-authored symbol — first Python exercise | shared-core |
| `sdk-semver-governance` | 1.0.0 | §16 semver Mode A initial version | shared-core |
| `api-ergonomics-audit` | 1.0.0 | §5.2 acquire vs acquire_resource trade-off; Q3 / Q6 ergonomics decisions | shared-core |
| `conflict-resolution` | 1.0.0 | escalation protocol per CLAUDE.md rule 8 | shared-core |
| `environment-prerequisites-check` | 1.0.0 | confirm Python 3.11+, pytest-asyncio installed | shared-core |
| `mcp-knowledge-graph` | 1.0.0 | Phase 4 cross-run learning (degrades to JSONL on MCP miss per rule 31) | shared-core |
| `context-summary-writing` | 1.0.0 | per-agent context summaries ≤200 lines (rule 2) | shared-core |

> **Notes**:
> - The six `python-*` skills shipped in v0.5.0 Phase B; intake's I2 wave resolves them as PRESENT.
> - Three shared-core debt-bearer skills (`tdd-patterns`, `idempotent-retry-safety`, `network-error-classification`) are deliberately NOT replaced with Python siblings yet. They're the empirical D2/D6 test — does the Go-flavored body produce useful guidance on Python code?
> - `mcp-knowledge-graph` is WARN-degrades-cleanly per pipeline rule 31; safe to declare even on a Python pilot where MCPs may not be wired up.

## §Guardrails-Manifest

| Guardrail | Phase | Enforcement | Purpose | Source pack |
|---|---|---|---|---|
| G01 | all | BLOCKER | decision-log valid JSONL | shared-core |
| G02 | all | BLOCKER | decision-log entry-limit per agent ≤15 | shared-core |
| G03 | all | BLOCKER | run-manifest schema validity | shared-core |
| G04 | all | WARN | MCP health (graceful degrade) | shared-core |
| G05 | intake | BLOCKER | active-packages.json valid + python.json resolves cleanly | shared-core |
| G06 | meta | BLOCKER | pipeline_version drift check (settings.json single source) | shared-core |
| G07 | impl | BLOCKER | target-dir discipline (writes only to motadata_py_sdk/ + runs/) | shared-core |
| G20 | intake | BLOCKER | TPRD topic-area completeness (16 sections + 2 manifests) | shared-core |
| G21 | intake | BLOCKER | §Non-Goals populated (this TPRD has 13) | shared-core |
| G22 | intake | INFO | clarifications ≤3 | shared-core |
| G23 | intake | WARN | §Skills-Manifest validation | shared-core |
| G24 | intake | BLOCKER | §Guardrails-Manifest validation | shared-core |
| G69 | impl | BLOCKER | credential hygiene — N/A but enforced (no creds in any artifact) | shared-core |
| G80 | feedback | BLOCKER | evolution-report written | shared-core |
| G85 | feedback | BLOCKER | learning-notifications.md written when any patch applied | shared-core |
| G86 | feedback | BLOCKER | quality regression ≥5% (when ≥3 prior runs exist) — first Python run, gate no-ops | shared-core |
| G90 | meta | BLOCKER | skill-index ↔ filesystem strict equality | shared-core |
| G93 | meta | BLOCKER | settings.json schema valid | shared-core |
| G116 | meta | BLOCKER | retired-concept catalog (DEPRECATED.md) | shared-core |

> **Notes**:
> - Go-package guardrails (the Go thirty-through-sixty-five and ninety-five-through-one-ten ranges) are NOT in this manifest. Some have natural Python analogs (the coverage ≥90% and leak-clean checks) but those have not yet been authored as Python-aware scripts. Pilot proceeds without them; T2-7 (adapter script policy) will codify whether they're authored as `.sh` wrappers calling `pytest-cov` / asyncio leak harness, or whether they're folded into the Python toolchain block.
> - The bench-regression check (sixty-five) is replaced for this run by `sdk-benchmark-devil`'s direct comparison against `baselines/python/performance-baselines.json` (which materializes on first run; first-run baseline → seed, no regression possible). Future Python runs gate against the seeded baseline.
> - **Deferred guardrails** — three rule-28 compensating-baseline gates (the eighty-one / eighty-three / eighty-four trio: baselines-updated check, skill evolution-log audit, per-run safety caps respected) are declared as `aspirational_guardrails` in `shared-core.json` but their `.sh` scripts are not yet authored. They are intentionally OMITTED from this pilot's manifest — for a first-Python run with empty baselines, they would no-op anyway. A follow-up PR will author the three scripts; once landed, this manifest can be amended.

### Exit codes

- 0: all phases PASS, branch ready for review at H10
- 1: HITL gate declined
- 2: guardrail BLOCKER unresolved after review-fix
- 5: target dir invalid
- 6: §Guardrails-Manifest validation FAIL (missing script)
- 7: package resolution FAIL (G05)

---

## Appendix A — Usage Sketch

```python
import asyncio
from motadata_py_sdk.resourcepool import Pool, PoolConfig


class HttpClient:
    """Caller-defined resource. Pool is generic over T."""

    async def open(self) -> None: ...
    async def close(self) -> None: ...
    async def request(self, url: str) -> str: ...


async def main() -> None:
    async def make_client() -> HttpClient:
        c = HttpClient()
        await c.open()
        return c

    async def teardown_client(c: HttpClient) -> None:
        await c.close()

    config = PoolConfig[HttpClient](
        max_size=10,
        on_create=make_client,
        on_destroy=teardown_client,
        name="httpclient-pool",
    )

    async with Pool(config) as pool:
        # Bounded acquire; auto-release on exit; auto-shutdown on context exit.
        async with pool.acquire(timeout=5.0) as client:
            response = await client.request("https://example.com")
            print(response)

        print(pool.stats())


asyncio.run(main())
```

## Appendix B — Cross-Language Mapping

For Phase B retrospective + T2-3 / T2-7 decision input. Maps Go `motadatagosdk/core/pool/resourcepool/` concepts to their Python equivalents.

| Go primitive | Python equivalent | Notes |
|---|---|---|
| `Pool[T any] struct` | `class Pool(Generic[T])` | Generic typing; mypy strict |
| `chan T` (resources) | `asyncio.Queue[T]` | Bounded; LIFO via deque if oracle perf demands |
| `chan struct{}` (returned signal) | `asyncio.Event` per slot OR `asyncio.Condition` | Simpler: condition variable on shared state |
| `sync.RWMutex` (creation guard) | `asyncio.Lock` | RWMutex's reader concurrency irrelevant under GIL |
| `atomic.Int32` (created count) | int + Lock OR `itertools.count()` (single-thread) | GIL makes atomic int counters trivial |
| `sync.WaitGroup` (outstanding tracker) | `set[asyncio.Task]` + `add_done_callback(set.discard)` | T2-3 forcing function — rename "goroutines" → "concurrency_units" |
| `goroutine` (CloseWithTimeout's drain) | `asyncio.create_task` with task-set storage | The fire-and-forget anti-pattern must be avoided |
| `select { case ... }` 8-way | `asyncio.wait(tasks, return_when=FIRST_COMPLETED)` OR `asyncio.TaskGroup` | TaskGroup is cleaner for structured concurrency |
| `context.Context` cancellation | `asyncio.timeout()` context manager + `CancelledError` propagation | Canonical 3.11+ pattern |
| `defer x.Close()` | `async with` + `__aexit__` | Native idiom |
| `panic` / `recover` in hooks | `try: await hook() except Exception:` | Python's exception model is simpler |
| `goleak.VerifyTestMain` | custom fixture asserting `asyncio.all_tasks()` snapshot | T2-7 forcing function |
| `b.ReportAllocs()` | `pytest-benchmark` JSON output + `tracemalloc` snapshot | Allocation accounting differs structurally; pilot will reveal whether `allocs/op` is even a meaningful metric in Python |

## Appendix C — Retrospective Hooks

The following questions MUST be answered in `runs/<run-id>/feedback/python-pilot-retrospective.md` at end-of-run, regardless of pass/fail:

1. **D2 verdict**: did `sdk-design-devil`'s `quality_score` on this run differ ≥3pp from Go-pool baseline? (See `baselines/shared/quality-baselines.json` Go entry for `sdk-design-devil`.) If yes → flip that agent to per-language partition. If no → Lenient holds.
2. **D6 verdict**: which shared-core agents produced demonstrably useful reviews on Python code without Go-flavored noise? Which ones produced confusing or wrong findings? Author `python/conventions.yaml` entries for the latter.
3. **T2-3 verdict**: what did the soak harness call the outstanding-task counter? Is `concurrency_units` the right rename, or did `outstanding_tasks` / `pending_acquires` come up more naturally?
4. **T2-7 verdict**: how were the leak-check + bench-output adapter scripts shaped? Are they policy-free (just emit normalized JSON)?
5. **Generalization-debt update**: which entries in `shared-core.json` `generalization_debt` array should be removed (Split rewrite landed) vs kept vs added (new debt surfaced by Python use)?

These answers feed `improvement-planner` at end-of-Phase-4 and may produce a v0.5.x patch PR.
