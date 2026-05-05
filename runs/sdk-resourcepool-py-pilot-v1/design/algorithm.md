<!-- Generated: 2026-04-27T00:01:02Z | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 | Author: algorithm (D1) -->

# Algorithm — Data Structures + O(1) Amortized Proof

Companion to `design/api-design.md` and `design/concurrency-model.md`. Justifies the data-structure choices and provides the amortized-complexity proof that backs `perf-budget.md`'s `complexity_big_o = "O(1) amortized"` declaration (G107).

---

## 1. Decision matrix — idle slot storage

The pool stores up-to-`max_size` idle resources. Choices:

| Option | Push | Pop | LIFO/FIFO | Allocation per op | Notes |
|---|---|---|---|---|---|
| `asyncio.Queue[T]` (bounded) | `await q.put(x)` — O(1) | `await q.get()` — O(1) | FIFO by default | one Future per parked waiter; `asyncio.Queue` internally allocates a `_putters` deque + a `_getters` deque + an `_unfinished_tasks` int | both sides await; integrates with Queue's own wait queue |
| `collections.deque[T]` + `asyncio.Condition` | `d.append(x)` — O(1) | `d.pop()` — O(1) | LIFO via `pop()` (right end) OR FIFO via `popleft()` | zero allocation on push/pop (deque reuses block-list nodes); Condition allocates one Future per waiter on `await cond.wait()` | manual wait orchestration but tighter control over wakeup ordering |
| `list[T]` + `asyncio.Condition` | `lst.append(x)` — O(1) amortized | `lst.pop()` — O(1) | LIFO via `pop(-1)`; FIFO via `pop(0)` is O(n) | amortized-zero on append; pop(0) is O(n) so this is LIFO-only | OK if we commit to LIFO; inferior to deque for re-insertion symmetry |

**Decision**: `collections.deque[T]` + `asyncio.Condition`.

**Rationale**:
1. Both `append` (push idle) and `pop` (acquire idle) are exact O(1) — deque uses a doubly-linked list of fixed-size blocks; no amortization needed.
2. Zero allocation on hot path (push/pop) once the deque has reached steady-state block count. `asyncio.Queue` internally allocates more (its own deques + bookkeeping).
3. `asyncio.Condition` lets us combine slot-availability signaling with the same lock that protects the counter mutations (single critical section per acquire/release; no double-locking).
4. LIFO via `pop()` (right end) matches the "hot-cache" intuition — the most recently released resource is the one most likely to still have warm caller-side state (e.g. an HTTP keep-alive connection that just returned). The Go reference impl uses a channel which is FIFO; we can match Go (FIFO via `popleft`) or pick LIFO. **Choice: LIFO** because (a) Python's `deque.pop()` is the default, (b) for in-process pools without per-resource freshness concerns LIFO is empirically slightly faster (tighter reuse window), (c) TPRD Appendix B explicitly says "LIFO via deque if oracle perf demands" — perf-architect's oracle calibration confirms this.

**Anti-pattern rejected**: `asyncio.Queue` would force every acquire/release to traverse the Queue's `_get` / `_put` machinery which performs additional Future creation per parked waiter. We need finer control over the wakeup-on-cancel rollback (see concurrency-model.md), which is awkward to graft onto `asyncio.Queue`.

---

## 2. Wait wakeup primitive — Condition vs Event-per-slot

When a task calls `acquire(timeout=N)` and the pool is at capacity with no idle slot, it must park and wake when ANOTHER task releases. Choices:

| Option | Wakeup semantic | Cancel-safe |
|---|---|---|
| `asyncio.Condition(self._lock)` + `await cond.wait()` then `cond.notify(n=1)` on release | wake one waiter per release | yes — `wait()` re-acquires lock on cancel-cleanup |
| `asyncio.Event` per slot (`max_size` events) | binary; toggled per slot | yes but bookkeeping is verbose |
| `asyncio.Semaphore(initial=max_size)` | acquire / release counts directly | no clean way to tie semaphore to per-slot resource identity |

**Decision**: `asyncio.Condition(self._lock)` — single condition variable, single lock.

**Rationale**:
1. The wait predicate is "either an idle slot exists OR I can create a new one OR pool is closed." Condition's `wait_for(predicate)` matches this directly.
2. `cond.notify(n=1)` on release wakes exactly one waiter — fair-ish (deque order, FIFO among waiters) and avoids the thundering-herd problem of `notify_all`.
3. Cancellation safety: `await cond.wait()` is documented to re-acquire the lock on `CancelledError` propagation. Our cleanup (decrement `_waiting`, possibly roll back a creation slot) runs in a `try/finally` under the lock and is correct.
4. Semaphore was rejected because we need to know "did I get a slot via reuse OR via create-new?" — semaphore decoupled from the resource identity gives us no signal.
5. Event-per-slot was rejected for memory + bookkeeping cost (max_size events created up-front).

---

## 3. The `_acquire_with_timeout` engine — pseudocode

```python
async def _acquire_with_timeout(self, timeout: float | None) -> T:
    """The shared engine for acquire and acquire_resource. Hot path.

    [traces-to: TPRD-§5.2-acquire]
    [constraint: complexity O(1) amortized acquire bench/test_scaling.py::bench_acquire_release_cycle]
    """
    if self._closed:
        raise PoolClosedError(...)

    # Use asyncio.timeout for the deadline (3.11+ canonical).
    async with asyncio.timeout(timeout) if timeout is not None else nullcontext():
        async with self._lock:
            self._waiting += 1
            try:
                # Wait until there is an idle slot, OR we can create, OR pool closed.
                await self._slot_available.wait_for(
                    lambda: bool(self._idle)
                    or self._created < self._config.max_size
                    or self._closed
                )
                if self._closed:
                    raise PoolClosedError(...)

                # Fast path: idle slot available.
                if self._idle:
                    resource = self._idle.pop()  # LIFO; O(1)
                    self._in_use += 1
                    return resource

                # Slow path: capacity available, must create.
                # Reserve the slot under the lock, then drop the lock for
                # the (possibly long-running) on_create call.
                self._created += 1
            finally:
                self._waiting -= 1

        # Lock dropped. Run on_create outside the lock so we don't block
        # other releasers / acquirers while user code runs.
        try:
            resource = await self._create_resource_via_hook()
        except BaseException:
            # Roll back the reservation on ANY exception (CancelledError too).
            async with self._lock:
                self._created -= 1
                self._slot_available.notify(n=1)  # wake another waiter
            raise

        async with self._lock:
            self._in_use += 1
        return resource
```

**Big-O accounting** (G107 evidence):
- `if self._closed`: O(1).
- `_lock` acquire/release: O(1) — asyncio.Lock is a FIFO of futures; one append + one pop per acquire/release pair.
- `wait_for(predicate)`: O(1) in the wait-once case (predicate evaluated once + suspend); O(1) per wakeup × 1 wakeup per release = O(1) amortized.
- `_idle.pop()`: O(1) exact.
- `_create_resource_via_hook`: O(C) where C is user's on_create cost. NOT counted in pool's complexity (it's an external dependency, declared separately).
- Counter mutations: O(1).
- `notify(n=1)`: O(1).

**Total**: O(1) amortized for the steady-state acquire path; O(1) + on_create-cost for the create-new path. The amortization argument is needed only for the `notify(n=1)` step (some releases may notify a waiter that subsequently finds the pool empty due to a race and re-suspends) — but this re-suspension is bounded by the number of concurrent waiters, not by N (pool size), so amortized O(1) holds.

---

## 4. The `release` engine — pseudocode

```python
async def release(self, resource: T) -> None:
    """Returns a resource to the pool. Hot path.

    [traces-to: TPRD-§5.2-release]
    [constraint: complexity O(1) amortized release bench/test_scaling.py::bench_acquire_release_cycle]
    """
    if self._closed:
        await self._destroy_resource_via_hook(resource)
        # Decrement counters under lock.
        async with self._lock:
            self._in_use -= 1
            self._created -= 1
        raise PoolClosedError(...)

    # Try on_reset (if any). Reset failure → destroy + don't re-pool.
    if self._config.on_reset is not None:
        try:
            await self._reset_resource_via_hook(resource)
        except Exception:
            await self._destroy_resource_via_hook(resource)
            async with self._lock:
                self._in_use -= 1
                self._created -= 1
                self._slot_available.notify(n=1)
            return  # silently drop the bad resource; next acquire creates fresh

    async with self._lock:
        self._idle.append(resource)  # O(1) push to right end (LIFO with pop())
        self._in_use -= 1
        self._slot_available.notify(n=1)  # wake one waiter
```

**Big-O**: O(1) per release. `notify(n=1)` is O(1). Hook calls are external cost.

---

## 5. The `_create_resource_via_hook` and helpers

```python
async def _create_resource_via_hook(self) -> T:
    """[traces-to: TPRD-§7-ResourceCreationError]
    [constraint: hot-path G109 _create_resource_via_hook]"""
    try:
        if self._on_create_is_async:
            return await self._config.on_create()
        return self._config.on_create()
    except Exception as user_exc:
        raise ResourceCreationError(
            f"on_create failed in pool '{self._config.name}'"
        ) from user_exc

async def _reset_resource_via_hook(self, resource: T) -> None:
    if self._on_reset_is_async:
        await self._config.on_reset(resource)
    else:
        self._config.on_reset(resource)

async def _destroy_resource_via_hook(self, resource: T) -> None:
    """Best-effort destroy. on_destroy raising → log WARN + swallow.
    Matches Go pool's safeDestroy semantics."""
    if self._config.on_destroy is None:
        return
    try:
        if self._on_destroy_is_async:
            await self._config.on_destroy(resource)
        else:
            self._config.on_destroy(resource)
    except Exception:
        # Log at WARN; do not propagate. Pool stays usable.
        # logging import lazy — design defers to logging-pattern in patterns.md
        import logging
        logging.getLogger(__name__).warning(
            "on_destroy raised in pool '%s'; resource dropped",
            self._config.name,
            exc_info=True,
        )
```

---

## 6. The `try_acquire` engine — sync, no await

```python
def try_acquire(self) -> T:
    """[traces-to: TPRD-§5.2-try_acquire]
    [constraint: latency p50 ≤ 5µs bench/test_acquire.py::bench_try_acquire]"""
    if self._closed:
        raise PoolClosedError(...)
    if self._on_create_is_async:
        raise ConfigError(
            "try_acquire cannot be called when on_create is async; "
            "use await pool.acquire_resource() instead"
        )

    # No await possible — must NOT touch self._lock (which is async).
    # Solution: try_acquire reads/mutates the deque directly under the
    # GIL guarantee. The GIL serializes bytecode atomically across coroutines
    # *on the same event loop*; combined with the no-await invariant, this
    # is safe. Cross-thread access is undefined (matches single-event-loop
    # contract from concurrency-model.md).
    if self._idle:
        resource = self._idle.pop()
        self._in_use += 1
        return resource

    if self._created < self._config.max_size:
        # Sync on_create call.
        try:
            resource = self._config.on_create()  # type: ignore[misc]
        except Exception as user_exc:
            raise ResourceCreationError(
                f"on_create failed in pool '{self._config.name}'"
            ) from user_exc
        self._created += 1
        self._in_use += 1
        return resource

    raise PoolEmptyError(
        f"pool '{self._config.name}' has no idle slot and is at capacity"
    )
```

**Concurrency note**: `try_acquire` does not take `self._lock` because (a) async Lock cannot be acquired from sync code, (b) under the single-event-loop contract, sync code runs to completion between awaits — no other coroutine on the same loop can interleave. This is the canonical Python idiom for sync inspection of asyncio-protected state. Documented in `concurrency-model.md`.

**Risk**: a release happening on a different event loop or thread could race `try_acquire`'s `_idle.pop()`. Mitigated by: (a) TPRD §3 Non-Goals — "no thread pool", (b) docstring on Pool says "single asyncio event loop only".

---

## 7. The `aclose` engine — graceful drain

```python
async def aclose(self, *, timeout: float | None = None) -> None:
    """Graceful shutdown. O(n) in outstanding + idle resources.

    [traces-to: TPRD-§5.2-aclose]
    [constraint: complexity O(n) aclose bench/test_aclose.py::bench_aclose_drain_1000]"""
    async with self._lock:
        if self._closed:
            return  # idempotent
        self._closed = True
        self._slot_available.notify_all()  # wake all parked waiters; they'll see _closed and raise

    # Wait for outstanding to drain or timeout.
    if self._in_use > 0:
        wait_task = asyncio.create_task(self._wait_for_drain())
        try:
            if timeout is not None:
                await asyncio.wait_for(wait_task, timeout=timeout)
            else:
                await wait_task
        except asyncio.TimeoutError:
            # Cancel outstanding tasks — they'll raise CancelledError in their
            # await sites; whoever was holding the resource is responsible for
            # cleanup. Pool no longer tracks them.
            for task in list(self._outstanding):
                task.cancel()
            # Best-effort wait for cancellations to propagate.
            await asyncio.gather(*self._outstanding, return_exceptions=True)

    # Drain idle slots.
    async with self._lock:
        idle_snapshot = list(self._idle)
        self._idle.clear()

    for resource in idle_snapshot:
        await self._destroy_resource_via_hook(resource)
        async with self._lock:
            self._created -= 1

    self._close_event.set()

async def _wait_for_drain(self) -> None:
    """Helper: wait until _in_use drops to 0."""
    async with self._lock:
        while self._in_use > 0:
            await self._slot_available.wait()
```

**Big-O**: O(n) where n = outstanding + idle resources at shutdown. Each drain step is one hook call. The `notify_all` at the top is O(W) where W = waiting tasks; bounded by the number of acquirers ever parked.

**Outstanding-task tracking**: a task that holds a resource is added to `self._outstanding` on acquire and removed on release. This lets `aclose` cancel them on timeout. See `concurrency-model.md` §4 for the `add_done_callback(set.discard)` pattern.

---

## 8. Hot-path identification (G109 declaration)

Per TPRD §10 / `python.json` `marker_protocol_note`, three internal functions are declared as the top-3 CPU consumers:

| Hot-path symbol | Why hot |
|---|---|
| `_acquire_idle_slot` (the inner block of `_acquire_with_timeout` that pops the deque + increments counters) | called on every acquire, idle path = ~95% of acquires under steady state |
| `_release_slot` (`release`'s deque.append + notify) | called on every release |
| `_create_resource_via_hook` (the hook dispatch) | called once per resource lifetime, but on the cold path |

Note: `_acquire_idle_slot` and `_release_slot` are NOT separate methods — they're the inner blocks of `_acquire_with_timeout` and `release`. The G109 profile-shape check at M3.5 will see them as part of those parent function's CPU samples in py-spy. perf-architect logs the pprof-equivalent expectation in `perf-budget.md`.

---

## 9. Big-O / complexity declarations (G107 evidence)

| Operation | Declared complexity | Bench file proving it |
|---|---|---|
| `Pool.acquire` (idle-slot path) | O(1) amortized | `tests/bench/bench_scaling.py::bench_acquire_release_cycle` |
| `Pool.try_acquire` | O(1) | `tests/bench/bench_acquire.py::bench_try_acquire` |
| `Pool.release` | O(1) amortized | `tests/bench/bench_scaling.py::bench_acquire_release_cycle` |
| `Pool.aclose` | O(n) in outstanding + idle | `tests/bench/bench_aclose.py::bench_aclose_drain_1000` |
| `Pool.stats` | O(1) | implicit; just reads ints |

**Scaling sweep** (`bench_scaling.py`) runs at N ∈ {10, 100, 1k, 10k} concurrent acquirers, fits a curve, reports the leading exponent. G107 fails if the fit deviates >20% from O(1).

---

## 10. Summary

- Idle storage: `collections.deque[T]` (LIFO via `pop()` + `append()`).
- Wait wakeup: `asyncio.Condition(self._lock)` with `wait_for(predicate)` + `notify(n=1)` per release.
- Outstanding tracker: `set[asyncio.Task]` with `add_done_callback(self._outstanding.discard)` on acquire (see concurrency-model.md §4).
- All acquire/release operations are O(1) amortized; aclose is O(n) in resources held; sweep test at N ∈ {10, 100, 1k, 10k} proves it.
- `try_acquire` is sync and bypasses the async Lock under the single-event-loop GIL guarantee.
- All hook calls are dispatched through cached sync/async bool flags; one `inspect.iscoroutinefunction` call per hook at `__init__` time.
