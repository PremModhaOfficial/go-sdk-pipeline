<!-- Generated: 2026-04-29T13:34:30Z | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 | Pack: python -->

# Concurrency Model — `motadata_py_sdk.resourcepool`

## Runtime assumptions

- **Single asyncio event loop**. The pool is bound to the event loop
  running when it was constructed. Cross-loop usage (constructing on
  loop A, calling acquire from loop B) is **undefined behavior** — we do
  not crash, but we do not synchronize.
- **GIL provides bytecode-level atomicity** but not multi-step atomicity.
  `_in_use += 1` is bytecode-atomic, but the *check + mutate* sequence
  (`if _idle: r = _idle.popleft(); _in_use += 1`) is NOT — hence the lock.
- **Trio / anyio not supported**. TPRD §3 explicitly excludes.

## Primitives in use

| Primitive | Role | Notes |
|---|---|---|
| `asyncio.Lock` | Implicit base of `_slot_available: Condition`. Mutual exclusion on state mutations. | `Condition` re-uses the same lock. |
| `asyncio.Condition` | Wait/notify on slot availability. | `wait()` releases lock on entry, re-acquires on exit. |
| `asyncio.wait_for(coro, timeout)` | Bounds the wait on `Condition.wait()`. | Cancellation propagates `TimeoutError` cleanly. |
| `asyncio.CancelledError` | Re-raised after cleanup. | Per `python-asyncio-leak-prevention` Rule 1. |
| `inspect.iscoroutinefunction` | One-shot at `__init__` to cache `_async_on_create`. | Per-call would be too expensive. |

## Why `asyncio.Lock` not `threading.Lock`

The pool is asyncio-native. Using `threading.Lock` from a coroutine would
block the event loop. `asyncio.Lock` is *cooperative* — `await lock.acquire()`
yields to the loop if contended.

`try_acquire` (sync) does NOT take `asyncio.Lock` — it relies on GIL
atomicity for the `if _idle: ...` fast path. If that becomes a flake source
in tests, drop in a `threading.Lock` for the sync path only (held for at most
~1µs, so loop-blocking is bounded).

## Cancellation correctness — the only bug we MUST avoid

Per TPRD §11.1 and §14:
> "A coroutine cancelled mid-acquire propagates CancelledError; the pool
>  slot is NOT leaked. Verify via pool.stats().waiting == 0 post-cancel."

The proof obligation:

```
T1: await pool.acquire_resource(timeout=10.0)   # parks in _slot_available.wait()
T2: T1.cancel()
# After T1 raises CancelledError, pool.stats().waiting must equal 0.
```

The mechanism: `asyncio.Condition.wait()`'s implementation
(`Lib/asyncio/locks.py` Condition.wait) handles cancellation by waking the
waiter, re-acquiring the lock, then re-raising. Our `acquire_resource` body
is structured so the only state mutation that follows the wait is
`_in_use += 1` — which we MUST NOT execute on cancellation. The `while not
_idle:` predicate handles this: if cancellation happens mid-wait, the
exception unwinds *without* hitting `_in_use += 1`. Slot accounting stays
consistent.

Test: `tests/unit/test_cancellation.py::test_cancel_mid_wait_no_leak`.

## TaskGroup vs raw create_task

**Per `python-asyncio-leak-prevention` Rule 2**: `asyncio.create_task` is
forbidden in library code unless the task is held by a strong reference and
its lifecycle is bounded.

Pool internals do not spawn background tasks at all in v1. The only
"outstanding" tasks are those holding acquired resources via
`acquire_resource()` — those are caller-owned. We do NOT track them in a
`set[Task]` because callers may not be tasks (could be the main coroutine).

If a future v1.x adds a background reaper (idle-resource TTL), it will use
`asyncio.TaskGroup` per `python-asyncio-patterns` Rule 4.

## GIL implications

| Concern | Verdict |
|---|---|
| Multi-thread access to `Pool` | **Not supported**. Pool is asyncio-only. If multi-thread is needed, caller wraps with `loop.run_coroutine_threadsafe(pool.acquire_resource(), loop)`. |
| Multi-process access | **Not supported** (TPRD §3). |
| GIL contention from `_create_resource_via_hook` running synchronously | If `on_create` is CPU-bound and slow, it blocks the event loop. Caller responsibility — documented in §5.1 docstring. |

## Drift signal naming — TPRD §15 Q7 resolution

TPRD asked: should the soak observer track `outstanding_tasks` or
`concurrency_units`? **Resolution by this design**: use `asyncio_pending_tasks`
(see `perf-budget.md` `drift_signals_catalog`). Rationale:

- `outstanding_tasks` collides with the pool's own "outstanding-resource
  tracker" concept (set of acquired-but-not-released resources). Naming the
  drift signal the same thing is confusing.
- `concurrency_units` is what `docs/LANGUAGE-AGNOSTIC-DECISIONS.md` T2-3
  proposes as the cross-language rename, but that decision is still open.
- `asyncio_pending_tasks` is **language-explicit** (the `asyncio_` prefix),
  **measurable** (`len(asyncio.all_tasks())`), and **unambiguous**.

This is the empirical answer to TPRD Q7 — feed it into Phase 4
`python-pilot-retrospective.md` per Appendix C.

## Test surface

| Test | Verifies |
|---|---|
| `tests/unit/test_cancellation.py::test_cancel_mid_wait_no_leak` | Cancellation path leaks no slot. |
| `tests/unit/test_cancellation.py::test_cancel_mid_create` | `on_create` cancellation rolls back `_in_use` and `_created`. |
| `tests/integration/test_contention.py::test_32_acquirers_max4` | Throughput target met without deadlock. |
| `tests/leak/test_no_leaked_tasks.py::test_aclose_idempotent_no_leak` | Second `aclose` does not spawn tasks; `asyncio.all_tasks()` snapshot stable. |
| Soak `T5.5` driven by `sdk-soak-runner-python` | Drift signals stay within slope thresholds for `mmd_seconds`. |
