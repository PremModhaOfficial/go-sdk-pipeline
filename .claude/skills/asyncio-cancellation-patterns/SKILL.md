---
name: asyncio-cancellation-patterns
description: asyncio.timeout context manager, CancelledError re-raise contract, asyncio.shield for critical sections, deadline propagation — Python analog of Go context.Context.
version: 1.0.0
status: stable
authored-in: v0.5.0-python-pilot
priority: MUST
tags: [python, asyncio, cancellation, timeout, deadline, structured-concurrency]
trigger-keywords: [asyncio.timeout, asyncio.wait_for, CancelledError, asyncio.shield, cancel, deadline, timeout, shield]
---

# asyncio-cancellation-patterns (v1.0.0)

## Rationale

Go SDK clients carry deadlines via `context.Context`. Python's nearest analog is the pair `asyncio.timeout()` (3.11+, the canonical deadline carrier) and the `CancelledError` propagation contract. The hard rule: **`CancelledError` MUST propagate**. Catching it without re-raising tells the runtime "I'm done, no error" — the cancellation cascade halts, sibling tasks continue, the `TaskGroup` block completes as if nothing happened. This silent-success mode is the worst-class defect in async code: timeouts appear to honor caller deadlines but actually run to completion. Three failure modes this skill prevents: (1) **swallowed cancellation** — `except CancelledError: pass`, (2) **missing deadline carrier** — every async I/O method needs a `timeout_s` parameter, (3) **shield-too-wide** — `asyncio.shield(whole_op)` cancels nothing, defeating the point.

## Activation signals

- Writing any async I/O method on an SDK client — needs a `timeout_s` parameter
- Implementing `aclose()` / `close(timeout_s)` graceful shutdown
- Adding cleanup in a coroutine that may be cancelled mid-flight
- Wrapping a "must-complete-once-started" critical section (DB commit, ack)
- Reviewer cites "swallowed CancelledError", "no deadline", "shield too broad", or "blocking sleep in coro"
- Migrating from `asyncio.wait_for` to `asyncio.timeout`

## Mapping: Go context.Context → Python asyncio

| Go | Python (3.11+) |
|---|---|
| `ctx context.Context` first param | `timeout_s: float \| None = None` keyword arg |
| `context.WithTimeout(ctx, d)` | `async with asyncio.timeout(d):` |
| `ctx.Done()` channel | `CancelledError` raised at suspension points |
| `ctx.Err()` | `asyncio.current_task().cancelled()` / catch `CancelledError` |
| `defer cancel()` | `async with` exits the timeout scope automatically |
| `select { case <-ctx.Done(): ... }` | `try: await op() except CancelledError: cleanup; raise` |
| `context.WithoutCancel(ctx)` (Go 1.21+) | `asyncio.shield(coro)` |

The `async with asyncio.timeout(...)` block is the carrier. Cancellation propagates as exceptions, not as a channel signal.

## `asyncio.timeout()` (3.11+) — canonical deadline carrier

`asyncio.timeout(d)` is an async context manager that schedules a `CancelledError` into the enclosed block after `d` seconds. On exit, it converts that into a `TimeoutError` for the caller. Composes cleanly with `TaskGroup`.

```python
# sdk/client.py
from __future__ import annotations
import asyncio


class Client:
    async def get(self, key: str, *, timeout_s: float | None = None) -> bytes:
        """Fetch by key. timeout_s=None means use caller's enclosing deadline (if any)."""
        if timeout_s is not None:
            async with asyncio.timeout(timeout_s):
                return await self._fetch(key)
        return await self._fetch(key)
```

If the caller has an outer `asyncio.timeout`, it still applies — `asyncio.timeout` blocks compose; the shortest deadline wins (analog of Go's `context.WithTimeout` shortest-deadline-wins inheritance).

## `asyncio.wait_for()` — older 3.10 path; document for compat only

`asyncio.wait_for(coro, timeout=N)` works on 3.10. Two reasons to prefer `asyncio.timeout` on 3.11+: (1) `wait_for` wraps the coroutine in a Task, which is heavier; (2) `wait_for` cannot be nested cleanly. Use `wait_for` only for 3.10 compat or when you need its specific semantics.

```python
# 3.10 compat path — only when 3.11 unavailable.
result = await asyncio.wait_for(client.get("k"), timeout=5.0)
```

## `CancelledError` — NEVER swallow; ALWAYS re-raise after cleanup

`CancelledError` inherits from `BaseException` (3.8+) — a bare `except Exception:` does NOT catch it, which is intentional. If you DO catch it for cleanup, you MUST re-raise.

```python
# GOOD — cleanup on cancel, then re-raise
async def transactional_write(self, key: str, val: bytes) -> None:
    txn = await self._begin()
    try:
        await self._put(txn, key, val)
        await self._commit(txn)
    except asyncio.CancelledError:
        await self._rollback(txn)
        raise  # MUST re-raise — don't break the cancellation cascade
    except Exception:
        await self._rollback(txn)
        raise
```

The `try/finally` form is even safer when cleanup is the same on both paths:

```python
async def with_lease(self, lease_id: str) -> None:
    await self._acquire(lease_id)
    try:
        await self._do_work()
    finally:
        await self._release(lease_id)  # runs on cancel, error, AND happy path
```

## `asyncio.shield()` — un-cancellable critical section, narrow scope ONLY

`asyncio.shield(coro)` makes the inner coroutine immune to outer cancellation. The OUTER `await shield(...)` raises `CancelledError` to its caller, but the wrapped coroutine continues to completion. Use ONLY for the small critical section (committing once started, releasing a lease) — never for the whole operation.

```python
# GOOD — shield only the commit, not the whole transaction
async def write_committed(self, key: str, val: bytes) -> None:
    txn = await self._begin()
    try:
        await self._put(txn, key, val)
        # The commit must finish even if we're cancelled mid-call.
        await asyncio.shield(self._commit(txn))
    except asyncio.CancelledError:
        # If we got here, _put raised CancelledError BEFORE commit started.
        await self._rollback(txn)
        raise
```

```python
# BAD — shield is too wide; defeats cancellation entirely
async def write_committed_wrong(self, key: str, val: bytes) -> None:
    await asyncio.shield(self._begin_put_commit(key, val))  # whole op is uncancellable
```

## Passing deadlines down — every async I/O method takes `timeout_s`

Every public async method that performs I/O accepts a `timeout_s` kwarg. Internal calls forward the remaining deadline. Never read a global timeout — it hides caller intent.

```python
async def batch_get(
    self, keys: list[str], *, timeout_s: float | None = None
) -> dict[str, bytes]:
    if timeout_s is not None:
        async with asyncio.timeout(timeout_s):
            return await self._batch_get_inner(keys)
    return await self._batch_get_inner(keys)
```

For long-running ops that need a different cancellation signal (e.g., user-initiated abort), accept an `asyncio.Event` or pass an explicit cancellation token.

## Graceful shutdown — `aclose()` with timeout

```python
async def aclose(self, *, timeout_s: float = 30.0) -> None:
    """Close the client, draining inflight tasks within timeout_s."""
    if self._closed:
        return
    self._closed = True
    # Cancel background tasks; wait for them to terminate.
    for task in self._tasks:
        task.cancel()
    try:
        async with asyncio.timeout(timeout_s):
            # Wait for all tasks to acknowledge cancellation.
            await asyncio.gather(*self._tasks, return_exceptions=True)
    except TimeoutError:
        # Hard close — force-drop any tasks that didn't exit gracefully.
        pass
    await self._http.aclose()
```

## Pitfalls

1. **Catching `CancelledError` without re-raise** — task appears to complete normally; `TaskGroup` doesn't know it was cancelled; sibling tasks continue. The single worst defect in async code. Always `raise` after cleanup, or use `try/finally`.
2. **Blocking sync calls (`time.sleep`, `requests.get`) inside cancellable coroutines** — cancellation propagates only at `await` points. Sync code is uninterruptible; the timeout fires, but the coroutine sleeps through it, breaking the deadline contract. Use `asyncio.sleep` and async-native I/O libs.
3. **Leaking resources on cancel — no `try/finally`** — DB transactions, file handles, leases stay held when the coroutine is cancelled. Wrap every resource-acquiring await in `try/finally` (or use `async with`).
4. **Mixing `asyncio.wait_for` and `asyncio.timeout` context manager on the same call** — `await asyncio.wait_for(asyncio.timeout(...).__aenter__(), 5)` is incoherent; pick one. Inside a `timeout` block, just `await coro` directly.
5. **`asyncio.shield(whole_op)`** — defeats cancellation entirely. Shield is a narrow tool: wrap only the small "must finish once started" section, not the whole op.
6. **No timeout passed; method blocks forever** — add `timeout_s: float | None = None` to every async I/O method. Document the default behavior (None = caller-deadline-only) in the docstring.
7. **`CancelledError` caught by bare `except:` or `except BaseException:`** — `except Exception:` does NOT catch `CancelledError` on 3.8+ (good), but `except:` (bare) and `except BaseException:` DO catch it (bad — they swallow it unless re-raised). Avoid bare `except:` in async code.
8. **Calling `task.cancel()` and not awaiting the task** — cancellation is scheduled, not synchronous. The task may still hold resources. Always `await task` after `cancel()` and catch the resulting `CancelledError`.

## References

- PEP 492 — Coroutines with `async`/`await`
- PEP 654 — Exception Groups (TaskGroup re-raises CancelledError as ExceptionGroup)
- Python docs: `asyncio.timeout`, `asyncio.shield`, `asyncio.wait_for`, `asyncio.CancelledError`
- Cross-skill: `python-asyncio-patterns` — task ownership and TaskGroup; `pytest-table-tests` — async test parametrization for timeout cases
- Go cross-reference: `context-deadline-patterns` — same concept, different syntax
