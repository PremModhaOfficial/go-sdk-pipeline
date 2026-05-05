<!-- Generated: 2026-04-27T00:01:03Z | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 | Author: concurrency (D1) -->

# Concurrency Model — asyncio task ownership, cancellation correctness, single-loop assumption

Companion to `design/algorithm.md`. Spells out the cancellation-safety contract, the outstanding-task tracking strategy, and the single-event-loop invariant. Backs the §11.4 leak-detection test category and the §11.1 cancellation-correctness unit tests.

---

## 1. Single-event-loop invariant

**Pool is bound to one asyncio event loop — the loop that runs `__init__`.** All subsequent acquire / release / aclose calls MUST execute on that loop.

**Justification**:
- `asyncio.Lock`, `asyncio.Condition`, `asyncio.Event` are loop-bound (they store a reference to the loop they were created on; using them from a different loop raises `RuntimeError`).
- `asyncio.Task` is loop-bound (created via `loop.create_task` or `asyncio.create_task` which uses the running loop).
- The `try_acquire` sync path relies on the GIL serializing bytecode between coroutine resumptions on the same loop. Cross-thread access has no such serialization guarantee.

**Enforcement**: documented in Pool's docstring. Tested by a unit test that constructs a Pool, runs it under one loop, then creates a second `asyncio.new_event_loop()` and asserts that calling `acquire()` on the second loop raises `RuntimeError` (asyncio's built-in error from the loop-bound primitives — we do NOT need to add explicit checks).

**Out of scope** (TPRD §3 Non-Goals): thread pool support, multi-loop pool, distributed pool. If a caller wants thread-safe access, they wrap calls with `asyncio.run_coroutine_threadsafe(pool.acquire_resource(), pool_loop)` themselves.

---

## 2. Lock + Condition discipline

The pool owns exactly two synchronization primitives (plus an Event for close completion):

| Primitive | Type | Purpose |
|---|---|---|
| `self._lock` | `asyncio.Lock` | Protects `_idle`, `_outstanding`, `_created`, `_in_use`, `_waiting`, `_closed` mutations. Held briefly (no awaits inside critical sections except the Condition's `wait()`). |
| `self._slot_available` | `asyncio.Condition(self._lock)` | Built atop `_lock` — same lock identity. Used for "wait until a slot frees / capacity opens / pool closes" parking. |
| `self._close_event` | `asyncio.Event` | Set once at the very end of `aclose`. Lets observers `await pool._close_event.wait()` for shutdown completion. |

**No nested locking**: every critical section acquires only `self._lock` (or implicitly via the Condition). No lock-order graph; deadlock impossible by construction.

**No await-while-locked except Condition.wait()**: the only sanctioned await inside `async with self._lock:` is `await self._slot_available.wait_for(predicate)` — which Python documents as "atomically releases the lock, parks, re-acquires on wakeup." Any other await (e.g. user hooks) MUST happen with the lock dropped — see `_acquire_with_timeout` pseudocode in algorithm.md §3.

**Critical-section size**: bounded by O(1) operations (counter mutations, deque push/pop, set add/discard). No user code, no I/O. Lock contention is therefore minimal even at high parallelism.

---

## 3. Cancellation correctness — the rollback contract

**Contract**: a coroutine that is cancelled while awaiting a slot in `acquire()` MUST NOT leak any pool state. Specifically:

1. If cancelled BEFORE `wait_for(predicate)` completes: `_waiting` was incremented; the `try/finally` decrements it. No other state changed. ✓
2. If cancelled AFTER `wait_for` returns but BEFORE the slot is consumed (between `wait_for` and the `_idle.pop()` / `_created += 1` step): IMPOSSIBLE — these two steps are within the same `async with self._lock:` block with no awaits between them. asyncio's preemption model only switches at await points. ✓
3. If cancelled AFTER `_created += 1` but BEFORE `_create_resource_via_hook` completes: the `except BaseException:` handler in `_acquire_with_timeout` rolls back `_created -= 1` AND notifies one waiter, then re-raises CancelledError. ✓

```python
# From algorithm.md §3 — annotated for cancellation correctness
async def _acquire_with_timeout(self, timeout):
    if self._closed:
        raise PoolClosedError(...)
    async with asyncio.timeout(timeout) if timeout is not None else nullcontext():
        async with self._lock:
            self._waiting += 1
            try:
                # Cancel point #1: cancellation here unwinds finally → _waiting--
                await self._slot_available.wait_for(...)
                if self._closed:
                    raise PoolClosedError(...)
                # No await between here and the function-end of this block;
                # cancellation cannot interleave.
                if self._idle:
                    resource = self._idle.pop()
                    self._in_use += 1
                    return resource
                self._created += 1
            finally:
                self._waiting -= 1
        # Lock dropped. Cancel point #2: cancellation here triggers the
        # except BaseException handler below.
        try:
            resource = await self._create_resource_via_hook()
        except BaseException:
            async with self._lock:
                self._created -= 1
                self._slot_available.notify(n=1)
            raise
        async with self._lock:
            self._in_use += 1
        return resource
```

**Why `except BaseException` and not `except Exception`?** `asyncio.CancelledError` inherits from `BaseException` (not `Exception`) since Python 3.8. We MUST catch it to roll back, then re-raise. The `raise` (bare) preserves the exception chain — caller sees the original CancelledError.

**Why notify on rollback?** Rolling back `_created -= 1` re-opens a creation slot. A parked waiter checking the predicate `_created < max_size` may now succeed. Without `notify(n=1)`, that waiter could remain parked indefinitely.

**Test backing**:
- `tests/unit/test_cancellation.py::test_cancel_mid_acquire_no_slot_leak` — spawns an acquire, cancels its task, asserts `pool.stats().waiting == 0` and `pool.stats().in_use` unchanged.
- `tests/unit/test_cancellation.py::test_cancel_during_on_create_rolls_back` — spawns an acquire whose on_create hangs, cancels mid-create, asserts `pool.stats().created == 0`.

---

## 4. Outstanding-task tracking (T2-3 forcing function)

For `aclose`'s timeout-then-cancel path, we need to know which tasks currently hold a resource so we can cancel them. Strategy:

```python
# In _acquire_with_timeout, AFTER the resource is in hand, BEFORE returning:
current_task = asyncio.current_task()
if current_task is not None:  # always non-None when called from a coroutine
    self._outstanding.add(current_task)
    current_task.add_done_callback(self._outstanding.discard)
```

**Why `set[asyncio.Task]` and not `list`?**:
- `set.add` / `set.discard` are O(1).
- Insertion order doesn't matter.
- Duplicate inserts are no-ops (defensive).

**Why `add_done_callback(set.discard)` and not manual cleanup in `release`?**:
- A task may finish (success or exception) WITHOUT calling release if it never started the body — e.g. `acquire().__aenter__` succeeded but the user's `async with` body raised before the resource was used. The done-callback fires regardless.
- Idempotent: discarding a non-member from a set is a no-op.

**TPRD Appendix C Q3 — drift signal naming**: this set-of-outstanding-tasks is the Python analog of Go's `sync.WaitGroup`-tracked goroutines. The Python soak harness (Phase 3 T5.5) tracks `len(self._outstanding)` over time as a drift signal. **Decision**: rename "goroutines" → `concurrency_units` in `perf-budget.md` `drift_signals` field, per the language-agnostic decision board (cross-language neutrality). perf-architect records rationale; testing-lead's soak harness consumes the same name.

---

## 5. TaskGroup vs gather — when each is right

The pool itself does NOT spawn long-running tasks (it parks coroutines, not tasks). But aclose and the test/integration layer do.

| Use case | Pick | Why |
|---|---|---|
| `aclose` waiting for outstanding to drain | `await self._wait_for_drain()` (a single coroutine that awaits the Condition) | We don't spawn a task; we just await the condition. No TaskGroup needed. |
| `aclose` cancel-then-gather of outstanding on timeout | `asyncio.gather(*self._outstanding, return_exceptions=True)` | gather is the right primitive when you have a fixed list of awaitables and want to wait for all to settle (success or exception). TaskGroup would re-raise the first exception, which we don't want here — we want every cancel to propagate. |
| Test layer spawning N concurrent acquirers | `asyncio.TaskGroup` (3.11+) | Structured concurrency: if any acquirer raises, the TaskGroup cancels the rest. Cleaner than gather. |
| `_wait_for_drain` itself | Single coroutine, no TaskGroup | One await point; nothing to spawn. |

**No fire-and-forget tasks**: the pool never does `asyncio.create_task(self._destroy_resource_via_hook(resource))` and walks away. Every task spawned (only inside aclose's gather path) is awaited before aclose returns.

---

## 6. Timeout handling — `asyncio.timeout()` as the canonical deadline

Per TPRD §2: `asyncio.timeout()` (3.11+) is the canonical deadline carrier. Implementation pattern:

```python
from contextlib import nullcontext

async def _acquire_with_timeout(self, timeout):
    ...
    async with asyncio.timeout(timeout) if timeout is not None else nullcontext():
        # parkable region
        ...
```

**Behavior**:
- `timeout=None` → `nullcontext()` → no deadline; wait forever.
- `timeout=5.0` → `asyncio.timeout(5.0)` → at deadline, the protected region's awaits get a `CancelledError` injected; `asyncio.timeout` then converts that to `TimeoutError` at exit.
- The injected `CancelledError` triggers OUR cancellation rollback (the `except BaseException` in `_acquire_with_timeout`); we re-raise; `asyncio.timeout` catches it and converts to `TimeoutError`. ✓

**Edge case**: `timeout=0.0` is permitted; effectively a non-blocking probe. For non-blocking, prefer `try_acquire()` (sync, no event-loop yield).

**Edge case**: Python 3.11's `asyncio.timeout()` raises `TimeoutError` (the builtin), not `asyncio.TimeoutError` (which became an alias in 3.11). TPRD §5.2 docstring says `asyncio.TimeoutError`; same class, no behavior diff.

---

## 7. Hook safety — exceptions and the event loop

User hooks (`on_create`, `on_reset`, `on_destroy`) execute IN THE POOL'S EVENT LOOP. Implications:

1. **Sync hook that takes a long time** blocks the event loop. Documented in TPRD §14 risks. Mitigation: doc strongly recommends async hooks for I/O. We do NOT magic-wrap sync hooks with `asyncio.to_thread` (TPRD §3 Non-Goal — explicit: "no sync-callable hook coercion via asyncio.to_thread() magic").
2. **Hook raising** is caught:
   - `on_create` raise → wrapped as `ResourceCreationError(__cause__=user_exc)`; rolled back per §3 above.
   - `on_reset` raise → resource destroyed via on_destroy; slot freed; release returns normally (silently drops the bad resource); next acquire creates fresh. Matches Go pool semantics.
   - `on_destroy` raise → caught + logged at WARN; never propagated (best-effort destroy).
3. **Hook is itself awaited from inside acquire/release**, so user code participates in cancellation:
   - If a caller's `acquire(timeout=N)` deadline expires while their `on_create` is running, the `asyncio.timeout` will inject CancelledError into the on_create coroutine. User code sees CancelledError; we treat that the same as `BaseException` and roll back the reservation. User's on_create should be cancellation-safe (clean up partial state) — documented in API design.

---

## 8. `aclose` cancellation safety

```python
async def aclose(self, *, timeout=None):
    async with self._lock:
        if self._closed:
            return
        self._closed = True
        self._slot_available.notify_all()  # wake everyone — they'll re-check and raise PoolClosedError

    if self._in_use > 0:
        wait_task = asyncio.create_task(self._wait_for_drain())
        try:
            if timeout is not None:
                await asyncio.wait_for(wait_task, timeout=timeout)
            else:
                await wait_task
        except asyncio.TimeoutError:
            # Cancel outstanding holders.
            for task in list(self._outstanding):
                task.cancel()
            await asyncio.gather(*self._outstanding, return_exceptions=True)
        # NOTE: If aclose ITSELF is cancelled, the wait_task should be cancelled
        # too. asyncio.wait_for handles this correctly (it cancels the inner task
        # on outer cancellation). Bare wait_task case (timeout=None) needs explicit
        # cleanup:
        # ... see implementation: catch CancelledError, cancel wait_task, re-raise
    ...
```

**Cancellation of aclose itself**: if a caller does `await asyncio.wait_for(pool.aclose(), timeout=5)` and the outer wait_for times out, aclose receives a CancelledError. We:
1. Cancel the inner `wait_task` (so we don't leak it).
2. Re-raise CancelledError (caller wanted to abort).
3. Pool stays in `_closed=True` state; subsequent acquire raises PoolClosedError; subsequent aclose returns immediately (idempotent).

This is implemented via a `try/except asyncio.CancelledError:` around the wait section; impl phase will write the explicit code; design phase commits to this behavior.

---

## 9. The leak-check fixture (T2-7 adapter shape)

TPRD §11.4 requires an asyncio analog of `goleak.VerifyTestMain`. Design sketch:

```python
# tests/conftest.py — reusable across unit/integration/leak suites
import asyncio
import pytest
import pytest_asyncio


@pytest_asyncio.fixture
async def assert_no_leaked_tasks():
    """Snapshot asyncio.all_tasks() before/after each test.

    Yields control to the test, then asserts no NEW tasks remain
    (excluding the test's own task, which is always in all_tasks()).
    """
    before = {t for t in asyncio.all_tasks() if not t.done()}
    yield
    # Allow one event-loop tick for done callbacks to drain.
    await asyncio.sleep(0)
    after = {t for t in asyncio.all_tasks() if not t.done()}
    leaked = after - before
    # Filter out the current test task (always in `after`).
    current = asyncio.current_task()
    leaked.discard(current)
    if leaked:
        pytest.fail(
            f"Leaked {len(leaked)} task(s): "
            + "\n".join(f"  - {t}" for t in leaked)
        )
```

**Adapter shape (T2-7 verdict)**: this fixture is **policy-free** — it only asserts a measurable property of `asyncio.all_tasks()`. No knowledge of the pool's internals. Reusable for any async test in any Python project. Backs G63 equivalent until a Python-aware G63.sh ships.

The test files in `tests/leak/` use this fixture; e.g. `test_pool_no_leaked_tasks.py` runs each Pool method through happy + cancel + timeout + close paths under the fixture, asserting no task leak.

---

## 10. Race detection (§11.5)

Python's GIL means we don't have data-races in the C-level memory-ordering sense. But we have **logical races** — interleaved coroutine schedulings that expose ordering bugs (slot leak under cancellation, hook ordering anomalies). Mitigation:

- `pytest-asyncio` `asyncio_mode = strict` — requires every async test to be explicitly marked; surfaces unintended sync calls.
- `--count=10` flake detection — runs each test 10 times; surfaces tests that occasionally fail due to scheduling-dependent bugs.
- `pytest-randomly` (optional add to dev deps) — randomizes test order; surfaces order-dependent state pollution.

These are wired in `tests/pyproject.toml` `[tool.pytest.ini_options]` — impl phase responsibility.

---

## 11. Summary

| Concurrency concern | Resolution |
|---|---|
| Multi-loop access | Forbidden by docstring; asyncio primitives self-enforce via RuntimeError. |
| Cancellation mid-wait | `try/finally` decrements `_waiting`; lock auto-released. |
| Cancellation mid-create | `except BaseException` handler rolls back `_created` and notifies a waiter. |
| Outstanding-task tracking | `set[asyncio.Task]` with `add_done_callback(set.discard)` for auto-cleanup. |
| aclose cancel-on-timeout | `asyncio.wait_for(wait_task)` + cancel each outstanding + gather. |
| aclose itself cancelled | catch CancelledError, cancel inner wait_task, re-raise. Pool stays closed. |
| Hook raising | Per-hook policy: on_create wraps + rolls back; on_reset destroys; on_destroy logs WARN. |
| Sync hook blocking | Documented as user responsibility; not magic-wrapped. |
| Timeout primitive | `asyncio.timeout()` (3.11+); `nullcontext()` for `timeout=None`. |
| Race detection | `pytest-asyncio strict` + `--count=10` + (optional) `pytest-randomly`. |
| Leak detection | `assert_no_leaked_tasks` fixture; policy-free; reusable. |
| Drift signal name | `concurrency_units` (T2-3 verdict, recorded in perf-budget.md). |
