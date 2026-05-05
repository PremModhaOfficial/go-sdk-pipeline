<!-- Generated: 2026-04-27 | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 | Wave: M7 | Reviewer: code-reviewer (READ-ONLY) -->

# Code Reviewer — Findings

Adversarial code review of `src/motadata_py_sdk/resourcepool/` (Python flavor: PEP 8, type hints, asyncio patterns, error handling, naming, package structure, security, test quality).

## Verdict: ACCEPT (5 advisory notes; 0 BLOCKER)

---

## CR-001 — PEP 8 + naming

PASS. All conventions per `convention-findings.md` from design phase. Verified post-impl:

- Modules: `snake_case` with leading underscore for private (`_config.py`, `_pool.py`, `_stats.py`, `_acquired.py`, `_errors.py`).
- Classes: `PascalCase` (`Pool`, `PoolConfig`, `PoolStats`, `AcquiredResource`, 5 errors).
- Methods: `snake_case` (`acquire`, `release`, `aclose`, etc.).
- Private internals: `_snake_case` (`_acquire_with_timeout`, `_create_resource_via_hook`, etc.).
- Type aliases: `PascalCase` (`OnCreateHook`, `OnResetHook`, `OnDestroyHook`).
- Constants: none at module scope (PASS — no global mutable state per CLAUDE.md rule 6).

---

## CR-002 — Type hints (mypy --strict clean)

PASS. `mypy --strict` reports zero errors across 26 source + test files. Verified:

- Every public method has a typed signature (no `Any` in public API).
- The two documented `type: ignore` lines in `_create_resource_via_hook` are justified per `interfaces.md §4` (sync/async hook union escape hatch).
- Generic[T] propagates correctly through `PoolConfig[T]` -> `Pool[T]` -> `AcquiredResource[T]` -> body type.

---

## CR-003 — asyncio patterns

PASS. Confirmed:

- Single-event-loop invariant documented + tested implicitly (asyncio primitives self-enforce).
- `asyncio.timeout()` used as the canonical deadline (3.11+).
- Cancellation rollback via `except BaseException` in `_acquire_with_timeout` per `concurrency-model.md §3`.
- `asyncio.Condition(self._lock)` paired with `wait_for(predicate)` + `notify(n=1)` — canonical pattern.
- `asyncio.gather(*..., return_exceptions=True)` for the cancel-then-collect path in aclose timeout.
- No fire-and-forget `asyncio.create_task` without storing reference.
- `add_done_callback(set.discard)` for outstanding-task auto-cleanup.

---

## CR-004 — Error handling

PASS. Confirmed:

- `PoolError` inherits `Exception` (NOT `BaseException`) so `except Exception:` catches it.
- `ResourceCreationError` chained via `raise ... from user_exc` (preserves `__cause__`).
- `on_destroy` raises caught + logged at WARN; never propagated (best-effort).
- `on_reset` raises -> destroy + drop silently; release returns clean.
- Cancellation (BaseException) propagated transparently; never swallowed.

### CR-004a — Advisory: `release` swallows `on_reset` exceptions silently

**Where**: `_pool.py` `release()` — when `on_reset` raises, the resource is destroyed and `release` returns silently (no exception to caller).

**Observation**: From a strict "tell don't ignore" perspective, the silent swallow is unusual. But it matches the Go pool's documented "best effort" semantic AND the design (api-design.md §3.5).

**Decision**: Accept as designed. Add a logger.debug in a future iteration if hook-debugging surface is needed. Not a v1.0.0 change.

---

## CR-005 — Package structure

PASS. The 5-file package matches the design layout exactly. `__init__.py` exports exactly the 9 documented public names (verified by `test_all_nine_names_are_exported`). Internals use leading-underscore convention.

---

## CR-006 — Security (carries SD-001 from design phase)

PASS. The "Security Model" docstring section was added to `Pool` per SD-001 recommendation. Hook trust boundary is documented in:

- `Pool` docstring `Security model:` paragraph.
- `_pool.py` module docstring `Security model:` paragraph (multi-paragraph treatment).
- `docs/USAGE.md` "Security model" section.

No new security findings.

---

## CR-007 — Test quality

PASS with one observation:

- 60 unit + 4 integration + 5 leak + 12 bench-smoke = 81 tests.
- Coverage 92.33% (gate ≥ 90%).
- Every TPRD §11.1 category covered by ≥1 test.
- Tests are real (no `pytest.skip`, no `assert True`, no empty bodies).

### CR-007a — Advisory: `test_lambda_returning_coroutine_is_treated_as_sync_documented_footgun`

**Where**: `tests/unit/test_hook_panic.py`.

**Observation**: This test documents a real footgun (lambda returning a coroutine is detected as sync). The behavior is by design (documented in `patterns.md §4`); the test confirms the documented behavior is actually emitted.

**Decision**: Keep. It's a contract test for the documented quirk; future refactors that "fix" iscoroutinefunction detection would surface here.

---

## Verdict summary

ACCEPT. All quality gates green; 5 advisory notes; 0 BLOCKER. Recommend H7 APPROVE.
