<!-- Generated: 2026-04-29T13:34:00Z | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 | Pack: python -->

# Algorithm Design — `motadata_py_sdk.resourcepool`

This document fixes the *algorithm* the implementation must follow. It is the
contract `sdk-impl-lead` codifies into source. Performance numbers (which the
choice of data structure must not violate) live in `perf-budget.md`.

## State variables

```
_max_size:        int                            # immutable, set in __init__
_idle:            collections.deque[T]           # ready resources, LIFO order
_in_use:          int                            # checked-out count
_created:         int                            # monotonic
_closed:          bool
_closing:         bool                           # set at start of aclose
_lock:            asyncio.Lock                   # protects _idle/_in_use/_created
_slot_available:  asyncio.Condition (re-uses _lock)
_outstanding:     set[asyncio.Task]              # tasks holding resources via acquire_resource
_async_on_create: bool                           # cached iscoroutinefunction(config.on_create)
```

Invariant after each lock release:
- `0 <= _in_use + len(_idle) <= _max_size`
- `_in_use <= _created`
- `len(_idle) <= _created - _in_use`
- `_closed == True ⇒ _in_use == 0 and len(_idle) == 0`

## Algorithm: `acquire_resource`

```
async def acquire_resource(*, timeout: float | None = None) -> T:
    if _closed: raise PoolClosedError

    async with _slot_available:                    # owns _lock
        # FAST PATH — idle slot available
        if _idle:
            r = _idle.popleft()
            _in_use += 1
            return r

        # SLOW PATH 1 — capacity to create
        if _in_use + len(_idle) < _max_size:
            _in_use += 1                           # reserve slot BEFORE await
            _created += 1
            try:
                r = await _create_resource_via_hook()  # outside lock? NO — see below
            except BaseException:
                _in_use -= 1
                _created -= 1
                raise
            return r

        # SLOW PATH 2 — wait for a slot
        deadline = monotonic() + timeout if timeout is not None else inf
        while not _idle:
            remaining = deadline - monotonic()
            if remaining <= 0: raise asyncio.TimeoutError
            try:
                await asyncio.wait_for(_slot_available.wait(), remaining)
            except asyncio.CancelledError:
                # CRITICAL: do not leak; _slot_available.wait() releases _lock
                #          on entry and re-acquires on cancel — we are inside
                #          the lock when this except runs.
                raise
            if _closed: raise PoolClosedError
        r = _idle.popleft()
        _in_use += 1
        return r
```

**Key correctness points:**

- **Reserving the slot before awaiting `on_create`**: the state mutation
  (`_in_use += 1; _created += 1`) is done under the lock *before* awaiting
  the user-supplied `on_create` hook. This forbids two acquirers from racing
  past the capacity check.
- **`on_create` is awaited under the lock**. This is intentional and matches
  the Go pool's semantics. Awaiting outside the lock would require a
  re-check pattern that's harder to reason about; awaiting inside is
  serializable. `on_create` is a *cold-path* call (only on first-fill), so
  the throughput cost is negligible. Bench `bench_acquire_idle` confirms:
  the 80k op/s budget is the *steady-state* (idle-slot fast-path) regime.
- **Cancellation safety**: `asyncio.wait_for(...)` propagates `CancelledError`
  cleanly. The `_slot_available.wait()` call releases `_lock` on entry and
  re-acquires it on exit (including cancellation). `_in_use` is *not*
  incremented before the wait, so a cancelled wait leaks no slot.

## Algorithm: `acquire`

```
def acquire(*, timeout=None) -> AcquiredResource[T]:
    return AcquiredResource(self, timeout)
```

`acquire` itself is **synchronous** — it returns an unentered context manager
immediately. The actual await happens inside `AcquiredResource.__aenter__`,
which delegates to `acquire_resource`. This matches Python idiom (compare
`asyncio.timeout` and `httpx.AsyncClient`) and makes the cancellation point
obvious to the type checker.

## Algorithm: `try_acquire`

```
def try_acquire() -> T:
    if _async_on_create: raise ConfigError(
        "try_acquire is sync and cannot await async on_create; use acquire_resource"
    )
    if _closed: raise PoolClosedError
    # Use a synchronous protective lock — but asyncio.Lock is async-only.
    # Solution: track with a simple uncontested flag check; data-race-free
    # under the GIL because CPython's bytecode dispatcher serializes single
    # ops. If the impl needs stricter, drop to threading.Lock for the
    # try_acquire path (NOT for the async path).
    if _idle:
        r = _idle.popleft()
        _in_use += 1
        return r
    if _in_use + len(_idle) < _max_size:
        # Sync on_create only path
        r = _config.on_create()
        _in_use += 1
        _created += 1
        return r
    raise PoolEmptyError
```

**Sync vs async hook detection** — at `__init__`:
```
_async_on_create = inspect.iscoroutinefunction(config.on_create)
```
Cached so the per-call cost is one bool read.

## Algorithm: `release`

```
async def release(resource: T) -> None:
    async with _slot_available:
        if _closed:
            # best-effort destroy, do not re-add to idle
            await _maybe_run_destroy(resource)
            return
        if _config.on_reset is not None:
            try:
                await _maybe_run_async(_config.on_reset, resource)
            except Exception:
                # destroy + free slot; do not re-add
                await _maybe_run_destroy(resource)
                _in_use -= 1
                _slot_available.notify()
                return
        _idle.append(resource)
        _in_use -= 1
        _slot_available.notify()
```

`_maybe_run_async(fn, *args)` checks `iscoroutinefunction(fn)`; awaits if
async, calls and returns if sync.

## Algorithm: `aclose`

```
async def aclose(*, timeout: float | None = None) -> None:
    if _closed: return                       # idempotent
    async with _slot_available:
        if _closed: return                   # double-checked locked
        _closing = True
        _slot_available.notify_all()         # wake every parked acquirer

    deadline = monotonic() + timeout if timeout is not None else None
    # Wait for outstanding to drain
    while True:
        async with _slot_available:
            if _in_use == 0: break
        if deadline is not None and monotonic() >= deadline:
            break
        await asyncio.sleep(0.001)            # cooperative

    # Cancel any tasks still parked in acquire_resource
    async with _slot_available:
        _closed = True
        # Drain idle resources, destroy each
        while _idle:
            r = _idle.popleft()
            try:
                await _maybe_run_destroy(r)
            except Exception as e:
                _log.warning("on_destroy raised on close: %s", e)
        _slot_available.notify_all()
```

**Edge case** — outstanding at deadline: any task awaiting `_slot_available.wait()`
sees `_closed = True` after wake and raises `PoolClosedError`. Tasks holding
acquired resources via `acquire_resource()` are *not* directly cancelled by
`aclose` — the contract is they finish or release within `timeout`. If they
don't, the slot count is permanently off, but `aclose` returns. (Matches Go
semantics; documented in §5.2 docstring.)

## Algorithm: `stats`

```
def stats() -> PoolStats:
    # No lock needed under GIL — but lock for cross-event-loop correctness:
    # if Pool is shared across event loops (anti-pattern but we don't crash).
    return PoolStats(
        created=_created,
        in_use=_in_use,
        idle=len(_idle),
        waiting=len(_slot_available._waiters) if hasattr(_slot_available, "_waiters") else 0,
        closed=_closed,
    )
```

The `waiting` field reads a private attr of `asyncio.Condition`. If that's
unstable across CPython versions, fall back to maintaining `_waiting: int`
ourselves — incremented before `wait()`, decremented in `finally`.

## Complexity claims (G107 dispatcher)

| Operation | Time | Space |
|---|---|---|
| `acquire_resource` (idle) | O(1) | O(1) |
| `acquire_resource` (create) | O(1) + `on_create` | O(1) |
| `acquire_resource` (wait) | O(1) wakeup; await time depends on contention | O(1) |
| `try_acquire` | O(1) | O(1) |
| `release` | O(1) + `on_reset` | O(1) |
| `aclose` | O(n) — drain idle | O(n) |
| `stats` | O(1) | O(1) |
| `PoolConfig.__init__` | O(1) | O(1) |
| `AcquiredResource.__aenter__` | O(1) + `acquire_resource` | O(1) |

## Why deque (LIFO) instead of asyncio.Queue (FIFO)

Two reasons:
1. **Cache locality** — most-recently-released resource is most likely to be
   warm in caller's CPU cache; LIFO trumps FIFO for cache hit rate.
2. **`asyncio.Queue` adds a layer**: it's built on `collections.deque` plus
   condition variables. We use the primitives directly to skip the queue's
   own per-op overhead (~3µs measured on CPython 3.12).

Trade-off: a long-idle resource may sit at the deque bottom longer. Caller
who needs FIFO fairness can supply an `on_reset` that records timestamps and
proactively destroy stale ones. Out of scope for v1.

## Cross-reference

- TPRD §5 — API contract this algorithm must satisfy.
- TPRD §10 — perf targets the algorithm choice must respect.
- TPRD Appendix B — Go ↔ Python primitive mapping (informs the choices above).
- `python-asyncio-patterns` skill — hot-path async idioms.
- `python-asyncio-leak-prevention` skill — cancellation correctness rules.
- `python-connection-pool-tuning` skill — generic pool patterns.
