<!-- Generated: 2026-04-29T17:11:00Z | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 | Pack: python -->
<!-- Authored-by: sdk-asyncio-leak-hunter-python (Wave T6) -->

# Wave T6 — Asyncio leak hunt

## Verdict: PASS — 0 leaks

## Command
`.venv/bin/pytest tests/leak/ -v --count=5`

## Results
- 15 / 15 PASS in 0.53 s (3 tests × 5 repetitions)
- 0 BLOCKER, 0 leak signal triggered
- Used `asyncio_task_tracker` fixture from `tests/conftest.py` (snapshots `asyncio.all_tasks()` pre/post; asserts no orphan tasks)

| Test | Repetitions | PASS rate |
|---|---:|---:|
| `test_aclose_idempotent_no_leak` | 5 | 5/5 |
| `test_acquire_release_cycle_no_leak` | 5 | 5/5 |
| `test_cancellation_no_leak` | 5 | 5/5 |

## What this falsifies
- Tasks spawned by `aclose()` retry path don't survive past their parent
- 50× acquire/release cycle leaves `len(asyncio.all_tasks())` exactly equal to baseline
- Cancelled `acquire_resource(timeout=10.0)` does not orphan the awaiter, the slot, or the queue waiter

## Soak-time leak coverage
The 600-s soak (T5.5) exercises continuous acquire/release at 16 workers / max_size=4. If a task-leak leaks per cycle, the `asyncio_pending_tasks` drift signal fires positive slope (G106). T5.5 is the long-tail leak gate.

## Inherited warnings
One `DeprecationWarning: There is no current event loop` from `tests/conftest.py:36`'s legacy event-loop bridge. Pre-existing; documented in Phase 2 review-fix-log as INFO-deferred. Not a leak. Filed separately as PA-007 for Phase 4 ("modernize conftest.py event-loop fixture to async-aware idiom").

## Gate verdict
**Leak gate: PASS — 0 leaks. 15/15 PASS rate at --count=5.**
