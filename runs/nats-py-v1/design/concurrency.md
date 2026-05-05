# Concurrency Design (D1) — `nats-py-v1`

**Authored**: 2026-05-02 by `sdk-design-lead` (acting in `concurrency-designer` role).
**Skills consulted**: `python-asyncio-patterns`, `asyncio-cancellation-patterns`.

## Cross-cutting concurrency invariants

| ID | Invariant | Enforcement |
|---|---|---|
| C-1 | Every public-API I/O method is `async def`. No sync wrappers. | mypy `strict`; G122 |
| C-2 | First parameter (after `self`) of every I/O method that takes a deadline is `*, timeout: float \| None = None` (Python equivalent of Go's `ctx context.Context` first-param). Internally wraps with `asyncio.timeout(timeout)`. | API design at impl time; bench p99 enforces |
| C-3 | No `init()` functions, no global mutable state. All singletons (tracer, meter, registry) gated through `functools.cache(...)` initialization. | G122 + manual code review |
| C-4 | All asyncio.Tasks created with `name=` for debuggability. | ruff rule `ASYNC` family |
| C-5 | Long-running background tasks ALWAYS captured in `self._tasks: set[asyncio.Task]` with `done_callback(self._tasks.discard)` — no fire-and-forget tasks. | leak harness in `tests/leak/` |
| C-6 | All Locks are `asyncio.Lock`, NEVER `threading.Lock`. We are single-threaded asyncio. | mypy + ruff |
| C-7 | Cancellation propagates: `asyncio.CancelledError` is RE-RAISED after cleanup, never swallowed. (Per `asyncio-cancellation-patterns` skill.) | code review |
| C-8 | `close()` / `aclose()` is idempotent on every closeable. Second call returns None. | unit test per closeable |
| C-9 | No `loop.run_*` or `asyncio.run` inside library code. Library is invoked from caller's existing event loop. | code review |
| C-10 | Per `nats-python-client-patterns` skill: `nc` (NATS connection) is caller-owned. SDK never opens or closes it (TPRD §2 invariant 1). | impl design + integration test |

## Per-module concurrency design

### codec (no async)

- All `pack_*` / `unpack_*` are synchronous functions. No event loop touch.
- Pure-CPU work; should NOT yield. Caller MUST NOT call them on a hot async loop with multi-MB payloads (that would block the loop). Doc-warn in module docstring; offer no asyncio offload (caller can `loop.run_in_executor` if needed).

### events.utils (no async)

- All sentinel + classifier code synchronous.

### events.core (no async)

- ContextVar set/get are synchronous.
- `extract_headers` / `inject_context` are synchronous (they read contextvars, no I/O).

### events.corenats

- `Publisher`:
  - `_closed: bool` + `_closed_lock: asyncio.Lock` (RW pattern via single Lock; no `asyncio.RWLock` in stdlib — all reads acquire the same Lock briefly. Acceptable given fast critical section.)
  - `_middleware: tuple[PublishMiddleware, ...]` — immutable tuple, swapped atomically under `_mw_lock` on `use_middleware`. Reads snapshot the tuple ref under lock, then unlock and use the snapshot.
  - `publish` / `request` workflow: `async with self._closed_lock: closed = self._closed; mw = self._middleware` → release → run.
  - `close()`: `async with self._closed_lock: if self._closed: return; self._closed = True` → `await self._nc.flush(timeout)`.
- `BatchPublisher`:
  - `_buffer: list[tuple[str, NatsMsg]]` + `_buffer_lock: asyncio.Lock` (single mutex; high-frequency add → contention risk; benchmarked at perf-budget §C row 4).
  - `_auto_flush_task: asyncio.Task | None` — created on `__init__` only if `flush_interval > 0`. Cancelled in `close()`.
  - **Concurrent flush**: `asyncio.gather(*[self._publish_one(s, m) for s, m in batch])` bounded by `asyncio.Semaphore(max_flush_workers)`. Mirrors Go's "buffered work channel + N workers" but with asyncio idioms.
  - **Cancellation**: `close()` cancels auto-flush task, then awaits it with `try: await ... except asyncio.CancelledError: pass`. Final `flush()` runs after.
- `Subscriber`:
  - `_subs: dict[id(nats_sub), _Subscription]` + `_subs_lock: asyncio.Lock`.
  - Per-subscription cancel: `_cancel_token: asyncio.Event` per sub; checked at top of NATS callback. Set in `unsubscribe(sub)` + `close()`.
  - **Callback re-entrancy**: nats-py invokes callbacks via `asyncio.create_task(cb(msg))` — they run concurrently. No global lock taken in the callback path; per-sub state is read-only after registration.
  - `close()`: write-lock held for entire close (mirrors Go); cancels every cancel-token; `await sub.drain()` per sub; collects errors; logs WARN with `error_count`; returns None.
  - **`on_error` hook (DD-1 fix, D3 iter 1)**: optional async callback registered at construction or via `set_error_handler(cb)`. When `close()` catches a per-sub drain error, BEFORE the WARN log it calls `await self._on_error(exc)` if set. Hook fires on the close coroutine (the same task that's holding the write-lock — no extra task spawn). The hook MUST NOT raise; if it does, the exception is caught with a single `log.exception("subscriber on_error hook raised", exc_info=hook_exc)` and processing continues to the next sub. This avoids close-time recursion and preserves close's invariant of returning None unconditionally. Default `on_error=None` preserves Go-equivalent silent behavior.

### events.jetstream

- `JsPublisher`:
  - Same `_closed_lock` + `_middleware` pattern as corenats.Publisher.
  - `publish_async`: spawns `asyncio.create_task(self._publish_async_impl(...), name=f"jspub_async_{subj}_{seq}")`. **Known issue MIRRORED**: no concurrency cap — caller can flood. Document in docstring.
- `Consumer`:
  - `_running: bool` + `_running_lock: asyncio.Lock` for start/stop race-safety (Go has a bug here per §7.3 — Python FIXES per scope.md).
  - `start()` holds `_running_lock` for full lifecycle until `stop()` flips it. Internal: `_consume_task: asyncio.Task` running the dispatch loop; `_consume_task.cancel()` on stop.
  - **Per-msg dispatch**: `nats-py` invokes callbacks concurrently per delivered msg, bounded by server-side `MaxAckPending=1000`. Handler is invoked via `await handler(ctx, msg)` directly — no extra task spawn (we are already in nats-py's spawned task).
  - `delete()`: `await self.stop()` + `await js.delete_consumer(stream, name)`.
  - **`on_error` hook (DD-1 fix, D3 iter 1)**: optional async callback registered at construction or via `set_error_handler(cb)`. Fires on the dispatch coroutine (the nats-py-spawned per-msg callback task) on three error paths: (a) ctx-cancellation nak failure, (b) handler-raise nak failure, (c) ack failure on success path. In each case, `await self._on_error(exc)` runs BEFORE the WARN log; then dispatch returns to nats-py per the existing flow (no propagation up the call stack). Hook MUST NOT raise — if it does, `log.exception("consumer on_error hook raised", exc_info=hook_exc)` swallows the secondary failure (avoids dispatch recursion) and the original WARN still fires. Default `on_error=None` preserves Go-equivalent silent behavior.
- `Requester`:
  - `_pending: dict[str, asyncio.Future[Response]]` + `_pending_lock: asyncio.Lock`.
  - `_seq: itertools.count()` for monotonic per-instance counter.
  - `_consume_task: asyncio.Task` running dispatch; cancelled on close.
  - `_closed_lock: asyncio.Lock`.
  - **request() flow**: lock-acquire-once → check closed → register future → release. Then publish. Then `await asyncio.wait_for(future, timeout=request_timeout)`. On timeout: `del pending[request_id]` under lock (idempotent), raise `ErrRequestTimeout`.
  - **dispatch flow**: receive reply msg → parse `X-Reply-To` (which is OUR sub) — actually NO; reply subject IS the consumer's filter. Parse the reply-id token from msg.subject; lookup `pending[request_id]`; `future.set_result(Response(...))`. If not in map: WARN log "requester: no pending request for reply" — this happens on late replies after timeout cleanup.
  - `close()` does NOT delete consumer (mirror Go).

### events.stores

- `KVStore` / `ObjectStore` are thin wrappers; they HOLD the underlying `nats.js.kv.KeyValue` / `ObjectStore` reference. No additional locks needed — the underlying lib is async-safe.
- **Watch iterator**: `async def watch(...)` returns an `AsyncIterator[KeyValueEntry]` that wraps the underlying watcher's `async for entry in raw_watcher`. Cancellation: caller cancels the consuming `async for` → asyncio propagates → underlying watcher's `__aexit__` cleans up (per `nats-py` contract).
- `TenantKVStore` / `TenantObjectStore`: stateless wrappers; no locks; the prefix is bound at construction.

### events.middleware

- `Stack` / `chain`:
  - `Stack._publish: list[PublishMiddleware]` + `_subscribe: list[SubscribeMiddleware]`. NOT thread-safe; caller is expected to register all middlewares at startup before calling `wrap_*`. If runtime add is needed (e.g., dynamic CB toggle), wrap with `asyncio.Lock` — not done by default.
  - `chain(*ms)` is a pure function; produces an immutable closure chain.
- `CircuitBreaker`:
  - `_state: State` + `_failures: int` + `_successes: int` + `_last_failure_time: float` (monotonic seconds).
  - `_lock: asyncio.Lock` for ALL state mutations + transitions (ensures `on_state_change` fires once per real transition).
  - `allow()` reads `_state` under `_lock`; if OPEN and `monotonic() - _last_failure_time > timeout` → transition to HALF_OPEN, allow this call. Otherwise raise/return per state.
  - `MultiCircuitBreaker._cbs: dict[str, CircuitBreaker]` + `_dict_lock: asyncio.Lock`. Lazy create: lock-check-create-release pattern (NOT double-checked locking; just hold the lock for the whole get-or-create. Contention is fine for typical N≤100 unique subjects.)
- `RetryMiddleware`:
  - Stateless. The retry loop is per-call (lives entirely on the caller's task).
  - **Backoff sleep**: `await asyncio.sleep(backoff)`. Cancellation during sleep → `CancelledError` propagates; we DO NOT catch it (per C-7).
  - Per §9.3 spec: if ctx fires DURING wait, return `last_err` not ctx.err. Implementation: wrap with `asyncio.timeout(remaining_ctx_budget)`; on `TimeoutError` → return `last_err`. Test checks 118-120 verify.
- `TokenBucketLimiter`:
  - `_milli_tokens: int` + `_last_update_ns: int` + `_lock: asyncio.Lock`.
  - Go uses lock-free atomic CAS; Python doesn't have native atomics. We use `asyncio.Lock` for the small critical section. Benchmarked at perf-budget §F row 8 (1.5µs p50 includes lock acquire).
  - `wait_n` spin: `while not await allow_n(n): wait_time = max(deficit/rate, 0.001); await asyncio.sleep(wait_time)`. Cancel-aware.
- `SlidingWindowLimiter`:
  - `_requests: collections.deque[int]` + `_lock: asyncio.Lock`.
  - Allow: lock; prune leading via `while _requests and _requests[0] <= now - window: _requests.popleft()`; if `len >= limit`: return False; else append now → return True.
- `OTELMetricsMiddleware`:
  - Cached counter + histogram handles via `functools.cache` per (name, namespace).
  - OTel SDK is thread-/asyncio-safe internally; no extra locks.
- `LoggingMiddleware`:
  - Stateless wrapping (binds logger ref). stdlib logging is thread-safe; OTel bridge passes context.Background() per Go behavior.
- `TracingMiddleware`:
  - Cached tracer via `functools.cache` per package name.
  - `start_as_current_span` uses contextvars internally (OTel SDK); no extra locking.

### otel

- `Init` family is one-shot at startup. NOT idempotent — calling twice is undefined per OTel SDK contract; document.
- `ShutdownCollector` collects `Awaitable[None]` shutdown handles; runs them in declared order with `asyncio.timeout(timeout)` total budget.
- `Registry` uses `dict` keyed by `(name, kind)`; protected by an internal `asyncio.Lock` for first-init; subsequent reads are unlocked (dict reads are atomic under GIL).

### config

- `Settings` (pydantic-settings) is constructed once at startup; Pydantic v2 freezes it. No concurrency concerns at runtime.
- `load(dir, env)` is sync (file I/O via `pyyaml`); wrap `loop.run_in_executor` if calling from async context with large YAMLs (typical configs are <100KB; not a practical concern).

## asyncio task accounting (for leak harness)

Background tasks the library may create:

| Owner | Task name pattern | Created at | Cancelled at |
|---|---|---|---|
| `BatchPublisher` (auto-flush=True) | `bp_autoflush_<id>` | `__init__` | `close()` |
| `JsPublisher.publish_async` | `jspub_async_<subj>_<seq>` | per call | tracked via Future; runs to completion |
| `Consumer.start` | `consumer_dispatch_<name>` | `start()` | `stop()` |
| `Requester.create` | `requester_dispatch_<instance_id>` | `create()` | `close()` |
| `TokenBucketLimiter.wait_n` | (caller-task; no spawn) | n/a | n/a |

`Subscriber` does NOT spawn tasks of its own — `nats-py` does. Subscriber leak detection focuses on whether `nats-py`'s task count drops on `close()`.

Test harness in `tests/leak/test_<owner>_leak.py` asserts `len(asyncio.all_tasks())` returns to baseline after `close()`. Per CLAUDE.md rule 14: `goleak.VerifyTestMain`-equivalent enforced via `pytest-asyncio` `--asyncio-mode=auto` + a custom autouse fixture that snapshots task count pre/post.

## Cancellation semantics (per `asyncio-cancellation-patterns`)

Three cancellation paradigms used:

1. **Bound by caller's `asyncio.timeout(t)`**: Publisher.publish, Publisher.request, Requester.request, JsPublisher.publish. The library does NOT introduce its own timeout unless explicitly per-method (e.g., JS publish defaults to 10s if caller has no deadline; mirrors Go).
2. **Cooperative cancellation via per-sub Event**: Subscriber subscriptions, Requester pending futures. Cancel-then-drain is the close pattern.
3. **Task-level cancellation**: BatchPublisher auto-flush, Consumer dispatch loop, Requester dispatch loop. `task.cancel()` then `await task` with `except CancelledError: pass`.

**Asymmetry to mirror from Go (per §9.3)**: in `RetryMiddleware`, ctx-cancellation during the BACKOFF sleep returns `last_err`, NOT the cancellation error. This is verified by check 120.

## Re-entrancy + thread-safety claims (for docstrings)

| Class | Re-entrant? | Multi-task concurrent? |
|---|---|---|
| Publisher | yes | yes — all methods after `__init__` |
| BatchPublisher | yes | yes — `add` is concurrent-safe |
| Subscriber | yes | yes — `subscribe` from multiple tasks OK |
| JsPublisher | yes | yes |
| Consumer | NO `start` re-entry | one `start` at a time per Consumer instance |
| Requester | yes | yes — `request` from N concurrent tasks |
| KVStore / ObjectStore | yes | yes — delegated to nats-py |
| All middlewares | yes | yes — wrappers are pure-functional once constructed |
| Tracer / Meter / Registry handles | yes | yes — OTel SDK guarantees |

## What we DO NOT use (and why)

- `asyncio.Queue` for BatchPublisher buffer — list+lock is faster for the throughput we target (125k ops/s); Queue's overhead is ~30% on micro-bench.
- `asyncio.PriorityQueue` anywhere — no priority ordering need.
- `concurrent.futures.ThreadPoolExecutor` — purely asyncio; no thread offload (caller can do it for codec).
- `multiprocessing` — no process boundaries; library is in-proc.
- `threading.Lock` / `threading.Event` — incompatible with asyncio.
- `aiomonitor` / `asyncio-debug-mode` in production — leak harness uses these in tests only.

## Open question (not blocking H5)

- Q-conc-1: `BatchPublisher.flush` concurrent path — bounded by `asyncio.Semaphore(N)` vs `asyncio.gather(*[bounded_pub(...)])` with internal semaphore. Both produce same observed concurrency. Pick one in impl; bench either is identical at perf-budget §C row 6. Defer to impl-lead.
