<!-- Generated: 2026-04-27 | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 | Wave: M7 | Reviewer: sdk-api-ergonomics-devil (READ-ONLY) -->

# API Ergonomics — Findings

First-time-integrator review of the public surface. Looking for: boilerplate-heavy callsites, surprising defaults, missing runnable examples.

## Verdict: ACCEPT (2 advisory notes; 0 BLOCKER)

---

## AE-001 — Advisory: two acquire methods (carries DD-002 from design phase)

**Where**: `Pool.acquire(*, timeout=None)` (sync, returns ctx mgr) vs. `Pool.acquire_resource(*, timeout=None)` (async, returns T).

**Observation**: A first-time integrator may write `await pool.acquire(...)` by accident, expecting a coroutine. mypy --strict catches it (AcquiredResource is not Awaitable), but the runtime error message is somewhat opaque (`TypeError: object AcquiredResource can't be used in 'await' expression`).

**Mitigation present**:
- mypy --strict catches the type error.
- `Pool.acquire` docstring opens with: "acquire returns an async context manager yielding a pooled T."
- `docs/USAGE.md` table contrasts the two methods.
- A runnable docstring example on `Pool` shows `async with pool.acquire(timeout=1.0) as item:`.

**Verdict**: ACCEPT (Q6 was an explicit design decision to avoid dual-mode magic; mypy + docs are the safety net).

**Optional follow-up**: consider raising a more helpful error from `AcquiredResource.__await__` (which doesn't exist today) — explicitly defining `__await__` to raise a `TypeError("did you mean: async with pool.acquire(...): ...?")` would catch the runtime case before it hits asyncio. Out of v1.0.0 scope.

---

## AE-002 — Advisory: `release` is async but most callers want sync semantics

**Where**: `Pool.release(resource: T) -> None` is `async def`.

**Observation**: A caller doing `await pool.release(r)` is mostly waiting on counter mutations (microsecond-fast) plus optional `on_reset` (caller-controlled). The await keyword adds noise on the call site.

**Defense**:
- TPRD §15 Q4 explicitly chose async because `on_reset` may be async.
- The default code path (acquire+release via `async with pool.acquire():`) handles the await automatically.
- Manual-release callers use `try/finally: await pool.release(r)` — standard async cleanup pattern.

**Verdict**: ACCEPT. Q4 was a deliberate user-decided trade-off.

---

## AE-003 — Runnable example coverage

PASS. Every public symbol (9 names) has a runnable docstring example:

| Symbol | Example shown |
|---|---|
| `PoolConfig` | construction with `make_thing` factory |
| `Pool` | full async-with-acquire cycle |
| `PoolStats` | invariant assertion |
| `AcquiredResource` | embedded in Pool's example |
| `PoolError` | `isinstance(e, PoolError)` |
| `PoolClosedError` | construction + `isinstance` check |
| `PoolEmptyError` | try/except fallback pattern |
| `ConfigError` | construction example |
| `ResourceCreationError` | `__cause__` chaining |

`docs/USAGE.md` carries multi-line examples for the common patterns (async-with, raw, handoff across tasks, hooks).

---

## AE-004 — Default values are documented

PASS:

- `timeout=None` -> wait forever (documented in 3 places: docstring `Args:`, `docs/USAGE.md`, `concurrency-model.md`).
- `name="resourcepool"` -> default pool label (TPRD §6).
- `on_reset=None` -> skip reset hook (TPRD §5.1).
- `on_destroy=None` -> skip destroy hook (TPRD §5.1).

No surprising defaults.

---

## AE-005 — Imports are clean

PASS. `from motadata_py_sdk.resourcepool import Pool, PoolConfig` is the canonical 80% case. Power users add `AcquiredResource`, `PoolError`, `ResourceCreationError`. Nothing is buried under `motadata_py_sdk.resourcepool._pool` for normal use.

---

## Verdict summary

ACCEPT. Two advisory notes (DD-002 carried, async-release noise) — both already debated + chosen at design time. Recommend H7 APPROVE.
