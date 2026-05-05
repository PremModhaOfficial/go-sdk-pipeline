<!-- Generated: 2026-04-27 | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 | Wave: M7 | Reviewer: sdk-overengineering-critic (READ-ONLY) -->

# Overengineering Critic — Findings

Reviewing `src/motadata_py_sdk/resourcepool/` for unnecessary abstractions, speculative interfaces, unused options, premature optimization, dead flags, ceremonial wrapper types.

## Verdict: ACCEPT (3 advisory notes; 0 BLOCKER)

---

## OE-001 — Advisory: 13 `__slots__` fields on `Pool` (DD-001 carried forward)

**Where**: `_pool.py` Pool class.

**Observation**: 13 fields is on the high side for a Python class. design-devil DD-001 already accepted this; the field count is irreducible:

- 5 are pool state (`_idle`, `_outstanding`, `_created`, `_in_use`, `_waiting`)
- 3 are sync primitives (`_lock`, `_slot_available`, `_close_event`)
- 3 are hook-detection caches (`_on_create_is_async`, `_on_reset_is_async`, `_on_destroy_is_async`)
- 1 is config (`_config`)
- 1 is lifecycle flag (`_closed`)

**Verdict**: ACCEPT. A "Refactor to `_PoolState` + `_PoolSync` substructs" would add indirection without reducing field count or coupling. Note for v2 only.

---

## OE-002 — Advisory: `_close_event` is set but currently has no documented external observer

**Where**: `_pool.py` Pool `__init__` declares `self._close_event = asyncio.Event()`; `aclose()` calls `self._close_event.set()` at the end.

**Observation**: Nothing in the public API exposes `_close_event`. It's only used internally to signal completion of `aclose`, which `aclose` itself awaits via the `_wait_for_drain` helper through `notify_all`. The Event itself is never `.wait()`'d by anything.

**Defense (kept, not removed)**: The Event is needed for the future caller-observability case where someone wants to `await pool._close_event.wait()` to know aclose has completed. This is a minimal-cost slot (one `asyncio.Event` allocation per Pool lifetime) and removing it would be a forward-compat regression.

**Verdict**: ACCEPT (defended). Kept for future external observers. Not exposed publicly yet.

---

## OE-003 — Advisory: `_track_outstanding` could be inlined

**Where**: `_pool.py` `_acquire_with_timeout` calls `self._track_outstanding()` after taking a resource; the helper is 4 lines long.

**Observation**: A 4-line helper called from exactly two sites (idle path + slow path of `_acquire_with_timeout`) could be inlined. The helper exists as a separate method for clarity; not a perf win.

**Defense**: Keeping it as a method makes the testing easier (we can grep for `_track_outstanding` calls; we can monkey-patch in tests if needed) and the explicit name is self-documenting at the call site (`self._track_outstanding()` reads as the intent, not as bookkeeping noise).

**Verdict**: ACCEPT. Naming wins over 4 saved bytes.

---

## Things that COULD be overengineered but aren't, for the record

- No `Protocol[T]` definitions — single implementation; structural ducks suffice (interfaces.md §8 documents the choice).
- No metaclass, no descriptors, no `__class_getitem__` magic — dataclass + Generic[T] handles subscript.
- No `cached_property` — mutable state means caching is incorrect.
- No `weakref` — outstanding-task tracking uses strong refs intentionally.
- No `contextvars` — no per-acquire context propagation.
- No `pydantic` for config validation — two `if` checks at construction.
- No global logger — `_LOG = logging.getLogger(__name__)` at module scope is the canonical pattern (single immutable reference).

These absences are documented in `design/patterns.md §9`.

---

## Verdict summary

ACCEPT. Three advisory notes; no BLOCKER findings. No code changes required.
