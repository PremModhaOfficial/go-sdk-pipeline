---
name: python-asyncio-patterns
description: >
  Use this when writing async I/O methods, fan-out work, background workers, or
  bridging blocking code into a Python SDK client. Covers asyncio.TaskGroup
  structured concurrency, strong-ref task storage to prevent mid-flight GC,
  gather vs wait selection, asyncio.to_thread / run_in_executor for sync
  bridging, and Task.cancel() semantics.
  Triggers: asyncio, create_task, ensure_future, TaskGroup, gather, wait, run_in_executor, fire-and-forget, async, await.
---

# python-asyncio-patterns (v1.0.0)

## Rationale

Every Python SDK client that performs I/O is async-first. Asyncio rewards two disciplines and silently punishes their absence: (1) **task ownership** — `asyncio.create_task` returns a task whose only strong reference may be the caller's local variable; if dropped, the GC can collect the task mid-flight and the coroutine vanishes without raising. (2) **structured concurrency** — when a parent op fans out N children, the parent must own their cancellation. `asyncio.TaskGroup` (3.11+) makes both mechanical: tasks are owned by the group, exceptions in any child cancel siblings, the `async with` block does not exit until every child has terminated. The SDK pipeline treats unowned `create_task` calls and bare fire-and-forget patterns as BLOCKER findings.

## Activation signals

- Designing any client method that fans out work across multiple awaits
- Adding a background worker, ticker, or pub/sub listener to a client
- Bridging sync code (CPU-bound, blocking I/O lib) into an async client
- Reviewer cites "task GC", "fire-and-forget", "swallowed exception", or "blocking call in coroutine"
- Replacing legacy `asyncio.ensure_future` / `asyncio.wait_for` with 3.11+ idioms

## `create_task` vs `ensure_future` — choose `create_task`

`asyncio.create_task(coro)` is the modern, type-correct entry point for scheduling a coroutine on the running loop. `asyncio.ensure_future(obj)` accepts coroutines, futures, or awaitables — use it ONLY when interoperating with non-coroutine futures (rare in SDK code). Default to `create_task`.

## Task storage — the GC trap

A bare `asyncio.create_task(...)` whose return value is discarded is reachable from the loop's weak set only. The CPython runtime's weak references mean the garbage collector can finalize a running task; the coroutine raises `CancelledError` into the void and the SDK silently does nothing. **Always store the task in a strong reference; remove on completion.**

```python
# sdk/client.py
from __future__ import annotations
import asyncio
import logging
from typing import Any

log = logging.getLogger(__name__)


class Client:
    def __init__(self) -> None:
        self._tasks: set[asyncio.Task[Any]] = set()

    def fire_and_forget(self, coro: Any) -> asyncio.Task[Any]:
        """Spawn a background task with strong-ref storage and exception logging."""
        task = asyncio.create_task(coro)
        self._tasks.add(task)
        task.add_done_callback(self._on_task_done)
        return task

    def _on_task_done(self, task: asyncio.Task[Any]) -> None:
        self._tasks.discard(task)
        if task.cancelled():
            return
        if exc := task.exception():
            log.exception("background task failed", exc_info=exc)
```

`add_done_callback` runs synchronously on the loop thread when the task finishes; use it both to drop the strong ref AND to surface exceptions that no one awaited.

## Structured concurrency with `asyncio.TaskGroup` (3.11+) — preferred

For any fan-out where the parent should fail-fast on the first child error and cancel siblings, use `TaskGroup`. The `async with` block:
- Owns child task lifetime (cancellation cascade is automatic)
- Re-raises child exceptions as an `ExceptionGroup` (PEP 654)
- Does NOT exit until every child task has terminated — no leaked coroutines

```python
async def fetch_all(client: Client, keys: list[str]) -> list[bytes]:
    results: list[bytes] = [b""] * len(keys)

    async def fetch_one(idx: int, key: str) -> None:
        results[idx] = await client.get(key)

    async with asyncio.TaskGroup() as tg:
        for idx, key in enumerate(keys):
            tg.create_task(fetch_one(idx, key))
    # On exit: every task done. If any raised, ExceptionGroup propagates.
    return results
```

## `gather` vs `wait` — when to use which

| API | Behavior | Use when |
|---|---|---|
| `asyncio.gather(*coros)` | Awaits all; raises first exception immediately, cancels siblings | Caller wants "all-or-nothing" with auto-cancellation |
| `asyncio.gather(*coros, return_exceptions=True)` | Awaits all; returns exceptions inline as values | Caller wants every result regardless of failures |
| `asyncio.wait(tasks, return_when=FIRST_COMPLETED)` | Returns `(done, pending)` sets; does NOT cancel pending | Caller needs control over which/when |
| `asyncio.TaskGroup` (3.11+) | Structured; auto-cancels on first failure | Default for fan-out; supersedes `gather` |

Prefer `TaskGroup` over `gather` in new SDK code. Use `gather(..., return_exceptions=True)` only when partial-failure visibility is the explicit contract.

## Mixing sync + async — `loop.run_in_executor`

CPU-bound or blocking-I/O calls (e.g., `requests`, `time.sleep`, hashing a 100MB blob) MUST NOT run inline in a coroutine — they freeze the event loop. Offload to a thread pool via `asyncio.to_thread` (3.9+) or, for explicit pool control, `loop.run_in_executor`.

```python
import asyncio
import hashlib

async def hash_blob(data: bytes) -> str:
    # to_thread runs on the default ThreadPoolExecutor; ctx-aware via cancellation.
    return await asyncio.to_thread(lambda: hashlib.sha256(data).hexdigest())
```

For CPU-bound work that benefits from true parallelism, use `concurrent.futures.ProcessPoolExecutor` and pass it explicitly to `run_in_executor`.

## `Task.cancel()` semantics — schedules, not synchronous

`task.cancel()` schedules a `CancelledError` into the task's coroutine at the next suspension point. It does NOT synchronously stop the task. To wait for cancellation to finish:

```python
task.cancel()
try:
    await task
except asyncio.CancelledError:
    pass  # expected; cancellation completed
```

If the coroutine catches `CancelledError` without re-raising, cancellation is silently swallowed — see `asyncio-cancellation-patterns` for the re-raise contract.

## Pitfalls

1. **Bare `asyncio.create_task` with no storage** — task can be GC'd mid-flight; coroutine vanishes silently. Always store in `self._tasks` and add a done callback.
2. **Swallowed exceptions in fire-and-forget tasks** — a task that raises and is never awaited prints a noisy `Task exception was never retrieved` warning at GC time, often long after the failure window. Always attach `add_done_callback` that logs exceptions.
3. **Calling `asyncio.run()` from inside a running loop** — raises `RuntimeError: asyncio.run() cannot be called from a running event loop`. Inside an async context, `await` the coroutine directly or use `loop.create_task`.
4. **Blocking sync I/O in a coroutine** — `requests.get`, `time.sleep`, `subprocess.run` freeze the loop for every other task. Use `asyncio.to_thread` or an async-native library (`httpx.AsyncClient`, `asyncio.sleep`).
5. **`asyncio.gather` without `return_exceptions=True`** when the caller wanted to inspect partial results — the first failure cancels siblings; subsequent results are lost.
6. **`asyncio.wait` confused with `asyncio.wait_for`** — `wait` waits for tasks with no timeout default; `wait_for(coro, timeout=N)` adds a timeout. Different APIs, similar names.
7. **Mixing `asyncio.ensure_future` and `create_task` in the same module** — pick one. `create_task` is the 3.7+ idiom for scheduling coroutines.

## References

- PEP 3156 — Asynchronous IO Support Rebooted
- PEP 492 — Coroutines with `async`/`await`
- PEP 654 — Exception Groups (foundation for TaskGroup)
- Python 3.11 docs: `asyncio.TaskGroup`, `asyncio.timeout`
- Cross-skill: `asyncio-cancellation-patterns` — cancellation discipline; `python-class-design` — `__slots__`-aware client class shape
