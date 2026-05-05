<!-- Generated: 2026-04-27 | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 | Wave: M3 mid-impl checkpoint -->

# H7b Mid-Impl Checkpoint — Cancellation Contract

Per impl-lead Wave M9 brief — informational checkpoint at end of S3 (cancellation correctness done).

## Status: PROCEED (no surprise; cancellation contract matches design)

The cancellation contract from `concurrency-model.md §3` was implemented faithfully:

1. **Cancel mid-`wait_for`** — `try/finally` decrements `_waiting`. Verified by `test_cancel_while_waiting_does_not_leak_waiting_counter`.
2. **Cancel mid-`on_create`** — `except BaseException` rolls back `_created` AND `notify(n=1)` to wake another waiter. Verified by `test_cancel_during_on_create_rolls_back_created_counter`.
3. **Cancel a parked waiter that never holds a resource** — task NOT in `_outstanding` set. Verified by `test_cancel_does_not_leak_outstanding_set`.
4. **`PoolError` doesn't catch `CancelledError`** — confirmed by `test_pool_error_does_not_inherit_base_exception_so_cancel_unswallowed`.

All 4 cancellation tests PASS. State invariants (`_waiting`, `_created`, `_in_use`) all roll back correctly.

No ESCALATION needed. Proceeding to S4 (`aclose`).
