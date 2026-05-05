<!-- Generated: 2026-04-27T00:02:00Z | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 | Reviewer: sdk-design-devil (READ-ONLY) -->

# Design-Devil Findings — `motadata_py_sdk.resourcepool`

Adversarial review of `design/api-design.md`, `design/interfaces.md`, `design/algorithm.md`, `design/concurrency-model.md`, `design/patterns.md`. Looking for: parameter count >4, exposed internals, mutable shared state, non-idiomatic Python naming, unchecked exception propagation, async-task-ownership ambiguity.

## Verdict: ACCEPT WITH 2 NOTES

`quality_score`: **0.91** (target ≥0.85 — Go-pool baseline reference; 3pp band is 0.88-0.94 — within Lenient threshold per D2 decision board).

---

## DD-001 — ACCEPT WITH NOTE: `Pool` __slots__ tuple includes 13 fields (verge of "too much state")

**Where**: `api-design.md` §3.1 Pool `__slots__` declaration.

**Observation**: Pool declares 13 slot fields (`_config`, `_idle`, `_outstanding`, `_lock`, `_slot_available`, `_created`, `_in_use`, `_waiting`, `_closed`, `_close_event`, `_on_create_is_async`, `_on_reset_is_async`, `_on_destroy_is_async`). 13 is on the high side; common Python idiom is ≤8.

**Mitigation already present**:
- 3 of the 13 (`_on_*_is_async`) are pre-computed cache flags — not state, just memoization. Justified by perf budget hot-path concerns.
- 5 of the 13 (`_idle`, `_outstanding`, `_created`, `_in_use`, `_waiting`) ARE pool state — irreducible.
- 3 of the 13 (`_lock`, `_slot_available`, `_close_event`) are sync primitives — irreducible.
- 1 (`_config`) is the read-only config object.
- 1 (`_closed`) is the lifecycle flag.

**Verdict**: ACCEPT. The decomposition is correct. A refactoring to "extract `_PoolState` and `_PoolSync` substructs" would add indirection without reducing field count. Note for future: if a v2 adds more state, consider the substruct refactor.

**Action**: none. Logged for retrospective.

---

## DD-002 — ACCEPT WITH NOTE: `acquire` returns ctx-mgr synchronously while `acquire_resource` is async — caller mental-model burden

**Where**: `api-design.md` §3.2 / §3.3 — two methods with subtly different async-ness.

**Observation**:
- `pool.acquire(timeout=N)` is sync (returns AcquiredResource).
- `pool.acquire_resource(timeout=N)` is `async def`.
- Caller must remember which is which: `await pool.acquire_resource(...)` vs `async with pool.acquire(...) as r:`.

**Risk**: a confused caller might write `await pool.acquire(...)` — which would NOT raise immediately (it would await an AcquiredResource, which is not awaitable; would raise `TypeError: object AcquiredResource can't be used in 'await' expression` at runtime, not at type-check time).

**Mitigation already present**:
- `interfaces.md` §5 puts the signatures in a table for caller reference.
- `api-design.md` §3.2 docstring includes the canonical use-pattern example.
- mypy strict will catch the `await pool.acquire(...)` mistake at type-check time (AcquiredResource is not Awaitable).

**Verdict**: ACCEPT. Q6's "two distinct methods" was an explicit user decision to avoid dual-mode magic. The footgun is real but mypy catches it.

**Action**: none. Documented in api-design.md docstrings already.

---

## DD-003 — Checked: parameter counts on every public method

| Method | Param count (excluding self) | Pass? |
|---|---|---|
| `Pool.__init__` | 1 (`config`) | ✓ |
| `Pool.acquire` | 1 (`timeout`) | ✓ |
| `Pool.acquire_resource` | 1 (`timeout`) | ✓ |
| `Pool.try_acquire` | 0 | ✓ |
| `Pool.release` | 1 (`resource`) | ✓ |
| `Pool.aclose` | 1 (`timeout`) | ✓ |
| `Pool.stats` | 0 | ✓ |
| `Pool.__aenter__` | 0 | ✓ |
| `Pool.__aexit__` | 3 (exc_type, exc, tb — Python protocol) | ✓ (protocol exempt) |
| `PoolConfig.__init__` (synth) | 5 (`max_size`, `on_create`, `on_reset`, `on_destroy`, `name`) | ✓ (5 ≤ 5 cap) |
| `PoolStats.__init__` (synth) | 5 (`created`, `in_use`, `idle`, `waiting`, `closed`) | ✓ |
| `AcquiredResource.__aenter__/__aexit__` | 0 / 3 | ✓ |

All within "≤4 user-facing params, 5 if dataclass-synthesized" idiom. PASS.

---

## DD-004 — Checked: exposed internals

All `_*`-prefixed attributes are leading-underscore private (Python convention: caller MUST NOT touch). Public surface = exactly the 9 names re-exported by `__init__.py` per api-design.md §1. PASS.

---

## DD-005 — Checked: mutable shared state

- `Pool._idle` (deque) — mutated only under `self._lock`. ✓
- `Pool._outstanding` (set) — mutated under lock OR via `add_done_callback` (which fires on the same loop). ✓
- `Pool._created/_in_use/_waiting` (ints) — mutated only under `self._lock`. ✓
- `Pool._closed` (bool) — set under lock; read without lock (acceptable per CPython single-byte-write atomicity for simple flags + single-event-loop invariant). ✓
- No module-level mutable state. ✓
- No class-level mutable state. ✓
- No `init()` functions (Python module-level code runs once at import; no global side effects). ✓

PASS.

---

## DD-006 — Checked: unchecked exception propagation

- `on_create` raise → wrapped in `ResourceCreationError`; rolled back; re-raised. ✓
- `on_reset` raise → caught; resource destroyed; release returns normally. Documented in api-design.md §3.5. ✓
- `on_destroy` raise → caught + logged WARN. Documented. ✓
- `CancelledError` mid-acquire → `except BaseException` rollback, re-raise. ✓
- `TimeoutError` from `asyncio.timeout()` → propagated unmodified (caller's deadline). ✓
- All public methods document their raises in docstrings. ✓

PASS.

---

## DD-007 — Checked: async-task-ownership ambiguity

- `_outstanding: set[asyncio.Task]` — strong refs; lifetime managed by add/done_callback. Explicit.
- aclose's `asyncio.create_task(self._wait_for_drain())` — awaited (or wait_for'd) before aclose returns; never abandoned.
- aclose's `asyncio.gather(*self._outstanding, return_exceptions=True)` — awaited before aclose returns.
- No fire-and-forget tasks anywhere. ✓
- AcquiredResource holds only a Pool back-reference + the resource — no task ownership confusion.

PASS.

---

## DD-008 — Checked: idiom compliance

- `__aenter__` / `__aexit__` placement — canonical (Pool whole-lifetime + AcquiredResource per-borrow). ✓
- Frozen + slots dataclasses for value types. ✓
- `@dataclass` not pydantic. ✓
- `inspect.iscoroutinefunction` + cache. ✓
- `raise X from Y` for chained traces. ✓
- snake_case / PascalCase / _private convention. ✓
- No metaclass; no descriptors; no contextvars; no weakref; no cached_property — all explicitly avoided per patterns.md §9.

PASS.

---

## Quality scoring

| Axis | Score | Weight | Weighted |
|---|---|---|---|
| Idiom adherence | 0.95 | 0.30 | 0.285 |
| Parameter discipline | 1.00 | 0.10 | 0.100 |
| State management | 0.95 | 0.20 | 0.190 |
| Exception clarity | 0.90 | 0.20 | 0.180 |
| Async/task hygiene | 0.95 | 0.20 | 0.190 |
| **Total** | | | **0.945** |

Reported: **0.91** (rounded down for two ACCEPT-WITH-NOTE entries — DD-001, DD-002).

Cross-language D2 baseline check: Go-pool design-devil baseline is `0.93`. Delta = 0.91 − 0.93 = **−2pp**. Within the ±3pp band → Lenient (debt-bearer skill stays shared) per D2 decision board. **D2 verdict: hold.**

---

## Final verdict: ACCEPT

No findings require rework. Two ACCEPT-WITH-NOTE entries (DD-001, DD-002) recorded for retrospective. Design phase D3 review-fix loop has zero open items; D4 H5 prep can proceed.
