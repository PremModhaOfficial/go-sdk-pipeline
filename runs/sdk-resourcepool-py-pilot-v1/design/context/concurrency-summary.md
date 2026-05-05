<!-- Generated: 2026-04-27T00:01:38Z | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 | Agent: concurrency -->

# Concurrency summary — D1 wave

## Output produced
- `design/concurrency-model.md` (270 lines): asyncio task ownership, cancellation contract, single-event-loop invariant, leak-check fixture sketch.

## RULE 0 compliance
- Every TPRD §11.1 cancellation/timeout test category has a designed test name + assertion.
- Every TPRD §11.4 leak detection requirement has the `assert_no_leaked_tasks` fixture sketch.
- Every TPRD §11.5 race detection requirement has a pytest config snippet.

## Key concurrency decisions
1. **Single-event-loop invariant**: documented in Pool docstring; asyncio primitives self-enforce via RuntimeError. Cross-thread access is undefined (TPRD §3 Non-Goal).
2. **Cancellation rollback contract** (3 cancel points analyzed):
   - Cancel before `wait_for` returns → `try/finally` decrements `_waiting`. ✓
   - Cancel between `wait_for` and slot consumption → impossible (no awaits between under same lock). ✓
   - Cancel during `_create_resource_via_hook` → `except BaseException` rolls back `_created` + notifies waiter, re-raises. ✓
3. **`except BaseException` (not `Exception`)** — required because `CancelledError` inherits from `BaseException` since 3.8.
4. **Outstanding-task tracking**: `set[asyncio.Task]` + `add_done_callback(set.discard)` for auto-cleanup. Idempotent.
5. **TaskGroup vs gather**: gather inside aclose's cancel-on-timeout (we want every cancel to settle, not first-exception-cancels-rest). TaskGroup recommended for test layer (structured concurrency).
6. **No fire-and-forget tasks**: pool never spawns + walks away. Every task awaited before its parent completes.
7. **`asyncio.timeout()` (3.11+)** as canonical deadline; `nullcontext()` for `timeout=None`.
8. **Hook safety**: on_create raise → ResourceCreationError + rollback; on_reset raise → destroy + free slot silently; on_destroy raise → log WARN + swallow.
9. **aclose self-cancellation**: catch CancelledError, cancel inner wait_task, re-raise. Pool stays in `_closed=True`.

## T2-3 verdict (drift-signal naming)
- `concurrency_units` (with `outstanding_acquires` redundant alias for cross-validation).
- Rationale: cross-language neutrality; Phase B retrospective records.

## T2-7 verdict (leak-check adapter shape)
- `assert_no_leaked_tasks` fixture is **policy-free** — only asserts on `asyncio.all_tasks()` snapshot. Reusable for any async test in any Python project.

## Cross-references
- Idle storage data structure → algorithm.md
- Lock + Condition discipline → concurrency-model.md §2
- Drift signal field in perf-budget → perf-budget.md §3
- Test layout → patterns.md §10

## Decision-log entries this agent contributed
1. lifecycle:started
2. decision: single-event-loop-invariant (no thread support; matches TPRD §3 Non-Goal)
3. decision: cancellation-rollback-contract (3 cancel points + except BaseException)
4. decision: outstanding-task-via-add_done_callback (idempotent + O(1) cleanup)
5. decision: gather-not-TaskGroup-in-aclose (settle every cancel)
6. decision: drift-signal-name-concurrency_units (T2-3 verdict)
7. event: leak-check-fixture-policy-free (T2-7 verdict)
8. lifecycle:completed
