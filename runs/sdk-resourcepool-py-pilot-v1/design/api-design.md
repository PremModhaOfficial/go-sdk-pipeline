<!-- Generated: 2026-04-27T00:01:00Z | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 | Author: designer (D1) -->

# API Design — `motadata_py_sdk.resourcepool`

Idiomatic async-Python design for the `Pool[T]` primitive ported from `motadatagosdk/core/pool/resourcepool`. Honors TPRD §15 Q1–Q6 verbatim. Backed by `design/interfaces.md` (Protocols), `design/algorithm.md` (data structures), `design/concurrency-model.md` (cancellation semantics), `design/patterns.md` (Pythonic idioms), and `design/perf-budget.md` (NFR targets).

---

## 1. Public surface — module-level

`motadata_py_sdk.resourcepool/__init__.py` re-exports exactly nine names:

```python
from ._config import PoolConfig
from ._pool import Pool
from ._stats import PoolStats
from ._acquired import AcquiredResource
from ._errors import (
    PoolError,
    PoolClosedError,
    PoolEmptyError,
    ConfigError,
    ResourceCreationError,
)

__all__ = [
    "PoolConfig",
    "Pool",
    "PoolStats",
    "AcquiredResource",
    "PoolError",
    "PoolClosedError",
    "PoolEmptyError",
    "ConfigError",
    "ResourceCreationError",
]
```

Internals (`_config`, `_pool`, `_stats`, `_acquired`, `_errors`) are private — leading underscore signals "do not import from outside the package." Convention-devil enforces.

---

## 2. `PoolConfig[T]` — frozen + slotted, generic

```python
# _config.py
# [traces-to: TPRD-§5.1-PoolConfig]

from collections.abc import Awaitable, Callable
from dataclasses import dataclass, field
from typing import Generic, TypeVar

T = TypeVar("T")

# Hook callable type aliases. Either sync or async is acceptable;
# Pool detects via inspect.iscoroutinefunction at __init__ time.
OnCreateHook = Callable[[], "T | Awaitable[T]"]
OnResetHook = Callable[["T"], "None | Awaitable[None]"]
OnDestroyHook = Callable[["T"], "None | Awaitable[None]"]


@dataclass(frozen=True, slots=True)
class PoolConfig(Generic[T]):
    """PoolConfig is an immutable configuration record for a Pool[T].

    All fields are bound at construction. Mutation post-construction raises
    `dataclasses.FrozenInstanceError`. The hook callables are stored by
    reference; replacing them on a live Pool requires constructing a new Pool.

    Args:
        max_size: Maximum number of resources the pool may create. Must be > 0.
        on_create: Required factory invoked when the pool needs a new resource.
            Either a sync callable returning T or an async callable returning T.
        on_reset: Optional callable invoked on `release()` before the resource
            re-enters the idle slot list. Either sync or async. If raising, the
            resource is destroyed and a fresh one is created on next acquire.
        on_destroy: Optional callable invoked when the pool drops a resource
            (close, reset failure, on_create failure-after-reservation). Either
            sync or async. Best-effort: a raise is caught and logged at WARN.
        name: Human-readable pool name for logs / future metrics. Default
            "resourcepool". Empty string is coerced to default at __init__.

    Example:
        >>> from motadata_py_sdk.resourcepool import PoolConfig
        >>> async def make_thing() -> dict[str, int]:
        ...     return {"counter": 0}
        >>> config = PoolConfig[dict[str, int]](
        ...     max_size=4,
        ...     on_create=make_thing,
        ...     name="thing-pool",
        ... )
        >>> config.max_size
        4
        >>> config.name
        'thing-pool'

    [traces-to: TPRD-§5.1-PoolConfig]
    """

    max_size: int
    on_create: OnCreateHook[T]
    on_reset: OnResetHook[T] | None = None
    on_destroy: OnDestroyHook[T] | None = None
    name: str = "resourcepool"
```

**Notes**:
- `slots=True` removes the per-instance `__dict__` overhead (perf-architect confirms benefit on PoolConfig; keep).
- `frozen=True` makes the dataclass hashable for caching keys; matches Python idiom for immutable config.
- Generic `Generic[T]` carries `T` through to `Pool[T]` constructor for mypy `--strict` correctness.
- The `Awaitable[T]` union typing covers both `async def make_thing() -> T` and `def make_thing() -> Awaitable[T]` shapes.

---

## 3. `Pool[T]` — main class

`Pool` is intentionally **not** a frozen dataclass: it owns mutable runtime state (slot list, outstanding-task set, lock, condition, stats counters, closed flag). It declares `__slots__` for memory locality (decision Q5: yes on Pool itself).

### 3.1 Constructor

```python
# _pool.py
# [traces-to: TPRD-§5.1-Pool]

import asyncio
import inspect
from collections import deque
from typing import Generic, TypeVar

from ._acquired import AcquiredResource
from ._config import PoolConfig
from ._errors import (
    ConfigError,
    PoolClosedError,
    PoolEmptyError,
    ResourceCreationError,
)
from ._stats import PoolStats

T = TypeVar("T")


class Pool(Generic[T]):
    """Pool is a bounded async resource pool over a caller-supplied factory.

    Resources are created lazily up to `config.max_size`, handed out via
    `acquire()` (async context manager), `acquire_resource()` (raw), or
    `try_acquire()` (sync, non-blocking). Returned via `release()` or
    auto-released by `acquire()`'s `__aexit__`.

    Lifecycle:
        - Construction: `Pool(config)` validates and pins the configuration.
        - Steady state: acquire / release; size bounded by `max_size`.
        - Shutdown: `await pool.aclose()` drains and destroys all resources.
          Idempotent. After aclose, all acquire variants raise PoolClosedError.

    Concurrency model: single asyncio event loop only. The pool is NOT
    thread-safe — calling acquire/release from multiple threads will corrupt
    state. (This matches Python's GIL+asyncio convention.)

    Cancellation: a coroutine cancelled while awaiting a slot has its slot
    reservation rolled back before CancelledError re-raises; never leaks.

    Args:
        config: A `PoolConfig[T]` instance. Validated immediately; invalid
            input raises ConfigError.

    Raises:
        ConfigError: max_size <= 0, on_create is None, or try_acquire would be
            unusable due to async on_create (deferred to first try_acquire call).

    Example:
        >>> import asyncio
        >>> from motadata_py_sdk.resourcepool import Pool, PoolConfig
        >>> async def demo() -> None:
        ...     async def make() -> int:
        ...         return 42
        ...     async with Pool(PoolConfig[int](max_size=2, on_create=make)) as pool:
        ...         async with pool.acquire(timeout=1.0) as item:
        ...             assert item == 42
        ...         assert pool.stats().idle == 1
        >>> asyncio.run(demo())

    [traces-to: TPRD-§5.1-Pool]
    """

    __slots__ = (
        "_config",
        "_idle",            # deque[T] — LIFO idle slot list (push/pop right)
        "_outstanding",     # set[asyncio.Task[Any]] — tasks holding a resource
        "_lock",            # asyncio.Lock — protects slot/counter mutations
        "_slot_available",  # asyncio.Condition — signaled on release
        "_created",         # int — total resources ever created
        "_in_use",          # int — currently checked out
        "_waiting",         # int — tasks parked in acquire()
        "_closed",          # bool
        "_close_event",     # asyncio.Event — signaled when aclose completes
        "_on_create_is_async",  # bool — cached at __init__
        "_on_reset_is_async",   # bool
        "_on_destroy_is_async", # bool
    )

    def __init__(self, config: PoolConfig[T]) -> None:
        # Validation per §6 Config Validation.
        if config.max_size <= 0:
            raise ConfigError("max_size must be > 0")
        if config.on_create is None:  # type: ignore[unreachable]
            raise ConfigError("on_create is required")

        self._config = config
        self._idle = deque()
        self._outstanding = set()
        self._lock = asyncio.Lock()
        self._slot_available = asyncio.Condition(self._lock)
        self._created = 0
        self._in_use = 0
        self._waiting = 0
        self._closed = False
        self._close_event = asyncio.Event()
        self._on_create_is_async = inspect.iscoroutinefunction(config.on_create)
        self._on_reset_is_async = (
            config.on_reset is not None
            and inspect.iscoroutinefunction(config.on_reset)
        )
        self._on_destroy_is_async = (
            config.on_destroy is not None
            and inspect.iscoroutinefunction(config.on_destroy)
        )
```

### 3.2 `acquire` — returns an async context manager

```python
def acquire(self, *, timeout: float | None = None) -> "AcquiredResource[T]":
    """acquire returns an async context manager yielding a pooled T.

    `acquire` itself is a regular `def` (returns the helper synchronously);
    the async work happens in `AcquiredResource.__aenter__`.

    Args:
        timeout: Maximum seconds to wait for a slot. None = wait forever.

    Returns:
        AcquiredResource[T] — async context manager. On `__aenter__`, yields
        the resource; on `__aexit__`, calls `pool.release(resource)`.

    Raises (on `async with` body):
        asyncio.TimeoutError: timeout elapsed before a slot freed.
        asyncio.CancelledError: awaiting task was cancelled (slot rolled back).
        PoolClosedError: pool is closed.
        ResourceCreationError: on_create raised; user's exception is `__cause__`.

    Example:
        >>> async with pool.acquire(timeout=5.0) as resource:
        ...     await use(resource)

    [traces-to: TPRD-§5.2-acquire]
    """
    return AcquiredResource(self, timeout=timeout)
```

**Why `acquire` is sync `def`** even though Q1 says "keyword-only timeout": the keyword-only requirement is for the `timeout` parameter (no positional). The method itself constructs and returns an `AcquiredResource` — no I/O — so sync is correct. The `await` happens inside `async with`'s `__aenter__`. This matches `aiofiles.open` and `aiohttp.ClientSession.get` idiom.

### 3.3 `acquire_resource` — raw async (power-user)

```python
async def acquire_resource(self, *, timeout: float | None = None) -> T:
    """acquire_resource returns a raw T without the context-manager wrapper.

    Caller MUST call `await pool.release(resource)` later. Failing to release
    leaks the slot until pool closure. Recommended only when the resource's
    lifetime spans multiple coroutines (e.g. handed off across a TaskGroup).

    Args:
        timeout: Maximum seconds to wait. None = wait forever.

    Returns:
        T — the acquired resource.

    Raises: same as `acquire().__aenter__`.

    Example:
        >>> resource = await pool.acquire_resource(timeout=5.0)
        >>> try:
        ...     await use(resource)
        ... finally:
        ...     await pool.release(resource)

    [traces-to: TPRD-§5.2-acquire_resource]
    """
    return await self._acquire_with_timeout(timeout)
```

`_acquire_with_timeout(timeout)` is the shared engine — see algorithm.md §3.

### 3.4 `try_acquire` — sync, non-blocking

```python
def try_acquire(self) -> T:
    """try_acquire returns an idle resource immediately without blocking.

    Returns:
        T — the acquired resource. Caller MUST `await pool.release(resource)`.

    Raises:
        PoolClosedError: pool is closed.
        PoolEmptyError: no idle slot AND pool at capacity (or on_create is
            async — sync `try_acquire` cannot await it).
        ConfigError: on_create is async; cannot be called from sync context.
            Raised on first try_acquire call (deferred from __init__ for
            symmetry with the async-call paths that DO await on_create).
        ResourceCreationError: sync on_create raised.

    Behavior:
        1. If closed → PoolClosedError.
        2. If on_create is async → ConfigError (per §15 Q2 decision).
        3. If idle slot exists → pop it (LIFO), update counters, return.
        4. Else if created < max_size → call sync on_create, increment, return.
        5. Else → PoolEmptyError.

    No await means no event-loop yield; the scheduler does not get a chance
    to run releasers between steps. Safe to call from sync code, including
    from `__init__` of caller objects where `await` is impossible.

    Example:
        >>> try:
        ...     resource = pool.try_acquire()
        ... except PoolEmptyError:
        ...     # fall back to async path
        ...     resource = await pool.acquire_resource(timeout=1.0)

    [traces-to: TPRD-§5.2-try_acquire]
    """
```

### 3.5 `release` — async

```python
async def release(self, resource: T) -> None:
    """release returns a manually-acquired resource to the pool.

    Behavior (in order):
        1. If pool closed → invoke on_destroy(resource); return PoolClosedError.
        2. If on_reset is configured → invoke (await if async). On raise:
           invoke on_destroy(resource); decrement created; signal slot. Caller
           sees nothing (release does not propagate on_reset errors — the slot
           has been freed; the bad resource is gone; next acquire creates fresh).
        3. Push resource onto idle deque (LIFO). Decrement in_use. Notify a
           waiter via _slot_available.notify().

    Args:
        resource: The T previously acquired via acquire_resource / try_acquire
            / acquire (in raw form). Identity is NOT verified — releasing a
            non-pool resource is undefined behavior (mirrors Go's pool).

    Raises:
        PoolClosedError: pool was closed before this release. Resource is
            still on_destroy'd best-effort.

    Example:
        >>> resource = await pool.acquire_resource()
        >>> try:
        ...     ...
        ... finally:
        ...     await pool.release(resource)

    [traces-to: TPRD-§5.2-release]
    """
```

### 3.6 `aclose` — graceful shutdown

```python
async def aclose(self, *, timeout: float | None = None) -> None:
    """aclose drains the pool and destroys all resources.

    Idempotent: second call is a no-op (returns immediately).

    Behavior:
        1. Set `_closed = True`. Subsequent acquire variants raise
           PoolClosedError immediately.
        2. Cancel all parked waiters (CancelledError raised in their await).
        3. If timeout is None: wait indefinitely for all outstanding resources
           to be released. If timeout > 0: wait up to timeout, then cancel
           outstanding tasks.
        4. Drain idle deque: invoke on_destroy on each.
        5. Drain any post-cancel returned resources: invoke on_destroy.
        6. Set _close_event.

    Args:
        timeout: Maximum seconds to wait for outstanding to drain. None = wait
            forever (matches Python's `BaseEventLoop.shutdown_asyncgens`).

    Returns:
        None. Note: per Q4 release is async, so aclose is also async.

    Example:
        >>> await pool.aclose(timeout=10.0)

    [traces-to: TPRD-§5.2-aclose]
    """
```

### 3.7 `stats` — sync snapshot

```python
def stats(self) -> PoolStats:
    """stats returns a frozen snapshot of pool state.

    Sync because no I/O. Reads counters under the lock-free path; the only
    race is a missed/extra increment, which `PoolStats` documents as
    "snapshot, may be stale by one operation."

    Returns:
        PoolStats — frozen + slotted dataclass.

    Example:
        >>> snapshot = pool.stats()
        >>> snapshot.idle, snapshot.in_use, snapshot.waiting
        (1, 3, 0)

    [traces-to: TPRD-§5.2-stats]
    """
    return PoolStats(
        created=self._created,
        in_use=self._in_use,
        idle=len(self._idle),
        waiting=self._waiting,
        closed=self._closed,
    )
```

### 3.8 `__aenter__` / `__aexit__` — Pool as async context manager

```python
async def __aenter__(self) -> "Pool[T]":
    """__aenter__ supports `async with Pool(config) as pool:`. Returns self.

    No setup required (constructor did everything); enables `async with`
    syntax for guaranteed `aclose` on exit.

    [traces-to: TPRD-§5.1-Pool]
    """
    return self

async def __aexit__(self, exc_type, exc, tb) -> None:
    """__aexit__ delegates to aclose() with no timeout (wait indefinitely).

    Caller wanting bounded shutdown should call pool.aclose(timeout=N)
    explicitly instead of relying on __aexit__.

    [traces-to: TPRD-§5.1-Pool]
    """
    await self.aclose()
```

---

## 4. `PoolStats` — frozen + slotted snapshot

```python
# _stats.py
# [traces-to: TPRD-§5.3-PoolStats]

from dataclasses import dataclass


@dataclass(frozen=True, slots=True)
class PoolStats:
    """PoolStats is a frozen snapshot of Pool[T] state.

    Snapshot semantics: counters are read sequentially, not atomically. A
    snapshot may be stale by one acquire/release relative to the live pool.
    Adequate for debug/observability use; not a replacement for live counters
    in tight feedback loops.

    Attributes:
        created: Total resources ever created (lifetime counter, monotonic).
        in_use: Resources currently checked out (acquire'd, not yet released).
        idle: Resources sitting in the idle deque, ready for next acquire.
        waiting: Tasks parked in acquire(), awaiting a free slot.
        closed: True if aclose() has been called and completed.

    Invariants (eventually consistent):
        in_use + idle <= created
        in_use + idle <= max_size  (after pool fully warmed)

    Example:
        >>> snapshot = pool.stats()
        >>> assert snapshot.in_use + snapshot.idle <= snapshot.created

    [traces-to: TPRD-§5.3-PoolStats]
    """

    created: int
    in_use: int
    idle: int
    waiting: int
    closed: bool
```

---

## 5. `AcquiredResource` — async context manager

```python
# _acquired.py
# [traces-to: TPRD-§5.3-AcquiredResource]

from typing import TYPE_CHECKING, Generic, TypeVar

if TYPE_CHECKING:
    from ._pool import Pool

T = TypeVar("T")


class AcquiredResource(Generic[T]):
    """AcquiredResource is the async context manager returned by `pool.acquire()`.

    Not user-constructed. Holds a back-reference to the pool, the timeout, and
    (post-`__aenter__`) the acquired resource. On `__aexit__`, calls
    `pool.release(resource)` regardless of whether the body raised.

    Cancellation:
        - If `__aenter__` itself is cancelled mid-acquire, the slot reservation
          is rolled back inside Pool's _acquire_with_timeout; CancelledError
          re-raises. `__aexit__` is never called (the body never started).
        - If the body raises (including CancelledError), `__aexit__` releases
          and lets the exception propagate. release() is awaited fully.

    [traces-to: TPRD-§5.3-AcquiredResource]
    """

    __slots__ = ("_pool", "_timeout", "_resource")

    def __init__(self, pool: "Pool[T]", *, timeout: float | None) -> None:
        self._pool = pool
        self._timeout = timeout
        self._resource: T | None = None

    async def __aenter__(self) -> T:
        """__aenter__ acquires from the pool and stores the resource locally.

        Raises:
            asyncio.TimeoutError, asyncio.CancelledError, PoolClosedError,
            ResourceCreationError — propagated from Pool._acquire_with_timeout.
        """
        self._resource = await self._pool._acquire_with_timeout(self._timeout)
        return self._resource

    async def __aexit__(self, exc_type, exc, tb) -> None:
        """__aexit__ releases the resource back to the pool. Awaits release.

        Body exception (if any) propagates after release completes. release()
        errors are NOT swallowed: if release raises (e.g. pool closed mid-body),
        the release error is what surfaces — matches Python's `__exit__`
        convention that explicit close errors take precedence.
        """
        if self._resource is not None:
            try:
                await self._pool.release(self._resource)
            finally:
                self._resource = None
```

---

## 6. Errors — `_errors.py`

```python
# _errors.py
# [traces-to: TPRD-§5.4-PoolError]


class PoolError(Exception):
    """PoolError is the base sentinel for all resourcepool errors.

    Catch-all for callers that want to handle "pool problem" generically:

        >>> try:
        ...     await pool.acquire_resource()
        ... except PoolError as e:
        ...     log.error("pool issue: %s", e)

    Subclasses:
        PoolClosedError — operation on a closed pool.
        PoolEmptyError — try_acquire with no idle slot and no capacity left.
        ConfigError — invalid PoolConfig at __init__ or sync/async mismatch.
        ResourceCreationError — on_create hook raised; user error in __cause__.

    [traces-to: TPRD-§5.4-PoolError]
    """


class PoolClosedError(PoolError):
    """PoolClosedError is raised on any operation against a closed pool.

    [traces-to: TPRD-§5.4-PoolClosedError]
    """


class PoolEmptyError(PoolError):
    """PoolEmptyError is raised by try_acquire when no slot is immediately available.

    Distinguishes "currently exhausted" from "permanently broken." Caller may
    retry via the async path:

        >>> try:
        ...     resource = pool.try_acquire()
        ... except PoolEmptyError:
        ...     resource = await pool.acquire_resource(timeout=1.0)

    [traces-to: TPRD-§5.4-PoolEmptyError]
    """


class ConfigError(PoolError):
    """ConfigError is raised on invalid PoolConfig or sync/async hook mismatch.

    Specific cases:
        - max_size <= 0
        - on_create is None
        - try_acquire called with async on_create (cannot await from sync)

    [traces-to: TPRD-§5.4-ConfigError]
    """


class ResourceCreationError(PoolError):
    """ResourceCreationError wraps a user exception raised by on_create.

    The original user exception is preserved on `__cause__` (raised via
    `raise ResourceCreationError(...) from user_exc`).

        >>> try:
        ...     await pool.acquire_resource()
        ... except ResourceCreationError as e:
        ...     log.error("factory failed: %s", e.__cause__)

    [traces-to: TPRD-§7-ResourceCreationError]
    """
```

---

## 7. Mapping of TPRD §5 symbols → final signatures

| TPRD symbol | Final signature | Where defined |
|---|---|---|
| `PoolConfig` | `@dataclass(frozen=True, slots=True) class PoolConfig(Generic[T])` | `_config.py` |
| `Pool` | `class Pool(Generic[T])` with `__slots__` | `_pool.py` |
| `Pool.__init__(self, config: PoolConfig[T]) -> None` | sync; raises ConfigError | `_pool.py` |
| `Pool.acquire(self, *, timeout=None) -> AcquiredResource[T]` | sync; returns ctx mgr | `_pool.py` |
| `Pool.acquire_resource(self, *, timeout=None) -> T` | async | `_pool.py` |
| `Pool.try_acquire(self) -> T` | sync; raises PoolEmptyError / ConfigError | `_pool.py` |
| `Pool.release(self, resource: T) -> None` | async | `_pool.py` |
| `Pool.aclose(self, *, timeout=None) -> None` | async; idempotent | `_pool.py` |
| `Pool.stats(self) -> PoolStats` | sync | `_pool.py` |
| `Pool.__aenter__` / `__aexit__` | async; aenter returns self; aexit calls aclose() | `_pool.py` |
| `PoolStats` | `@dataclass(frozen=True, slots=True)` | `_stats.py` |
| `AcquiredResource` | `class AcquiredResource(Generic[T])` with `__slots__`; aenter / aexit | `_acquired.py` |
| `PoolError` | `class PoolError(Exception)` | `_errors.py` |
| `PoolClosedError` | `class PoolClosedError(PoolError)` | `_errors.py` |
| `PoolEmptyError` | `class PoolEmptyError(PoolError)` | `_errors.py` |
| `ConfigError` | `class ConfigError(PoolError)` | `_errors.py` |
| `ResourceCreationError` | `class ResourceCreationError(PoolError)` (raised via `raise … from user_exc`) | `_errors.py` |

All nine TPRD §5 + §7 named symbols accounted for. Zero deferred. Zero "TBD".

---

## 8. §15 Q1–Q6 / Q7 honored

| Q | TPRD decision | This design |
|---|---|---|
| Q1 | keyword-only `timeout` | `acquire(*, timeout=None)`, `acquire_resource(*, timeout=None)`, `aclose(*, timeout=None)` ✓ |
| Q2 | `try_acquire` is sync `def` | Yes; raises `ConfigError` if on_create is async ✓ |
| Q3 | `Pool` is async ctx mgr | `__aenter__` returns self; `__aexit__` calls aclose() ✓ |
| Q4 | `release` is `async def` | Yes; needed to `await` async on_reset ✓ |
| Q5 | `__slots__` everywhere it helps | PoolConfig + PoolStats frozen+slots; Pool + AcquiredResource declare `__slots__` ✓ |
| Q6 | NO dual-mode `acquire`; two distinct methods | `acquire` returns ctx mgr; `acquire_resource` returns T ✓ |
| Q7 | drift signal name — pilot-driven | Deferred to `perf-budget.md` (perf-architect picks `concurrency_units` per language-agnostic decision board); doc rationale there |

---

## 9. §3 Non-Goals reaffirmed (NOT tech debt — written contracts)

This design intentionally does NOT include: distributed/multi-process pool, thread pool, OTel wiring, dynamic resize, TTL/expiry, load-shedding, circuit-breaker integration, rate limiting, Python 3.10 backport, sync `Pool` variant, sync-callable hook coercion via `to_thread`, streaming acquire, integration with the Go SDK. All thirteen are TPRD §3 Non-Goals.

---

## 10. Cross-references

- Hook protocols and Generic[T] strategy → `design/interfaces.md`.
- Idle slot data structure choice (deque vs Queue), wait wakeup primitive (Condition vs Event-per-slot), outstanding-task tracking → `design/algorithm.md`.
- Cancellation rollback semantics, TaskGroup vs gather, single-event-loop assumption → `design/concurrency-model.md`.
- `__slots__` decision matrix, sentinel exception hierarchy, sync/async hook detection via `inspect.iscoroutinefunction`, `__aenter__` placement on Pool → `design/patterns.md`.
- All §10 perf budgets, oracle calibration against Go reference, drift-signal naming rationale → `design/perf-budget.md`.
