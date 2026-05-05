<!-- Generated: 2026-04-27T00:01:37Z | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 | Agent: algorithm -->

# Algorithm summary — D1 wave

## Output produced
- `design/algorithm.md` (336 lines): data structures + O(1) amortized proof + pseudocode for hot paths.

## RULE 0 compliance
- Every TPRD §10 perf row has named bench file + complexity declaration.
- All hot-path internals (`_acquire_with_timeout`, `release`, `_create_resource_via_hook`, `try_acquire`, `aclose`) have explicit pseudocode.
- Big-O accounting per operation step.

## Key algorithmic decisions
1. **Idle storage**: `collections.deque[T]` (LIFO via `pop()` + `append()`). Rejected `asyncio.Queue` (extra allocation per parked waiter, tighter cancel-rollback control needed). Rejected `list` (push/pop_left is O(n)).
2. **Wait wakeup**: `asyncio.Condition(self._lock)` with `wait_for(predicate)` + `notify(n=1)` per release. Rejected Event-per-slot (memory cost + bookkeeping). Rejected Semaphore (decoupled from resource identity).
3. **LIFO vs FIFO**: LIFO chosen — matches Python deque default; tighter cache reuse on warm resources; TPRD Appendix B explicitly allows.
4. **Outstanding tracker**: `set[asyncio.Task]` with `add_done_callback(self._outstanding.discard)` for auto-cleanup.
5. **try_acquire**: sync, NO lock — relies on single-event-loop GIL guarantee + no-await invariant.
6. **aclose**: O(n) drain; cancels outstanding on timeout via `gather(*self._outstanding, return_exceptions=True)`.
7. **Big-O proof**: O(1) amortized for steady-state acquire + release; O(n) for aclose. Scaling sweep at N ∈ {10, 100, 1k, 10k} validates (G107).

## Hot-path declaration (G109)
- `_acquire_with_timeout` inner block: idle-slot pop + counter mutations
- `release` inner block: deque.append + notify + counter mutations
- `_create_resource_via_hook`: cold path; <5% steady-state CPU samples expected

## Cross-references
- Async coordination (Lock + Condition discipline) → concurrency-model.md
- Hook detection idiom → patterns.md §4
- Per-symbol perf budgets → perf-budget.md §1

## Decision-log entries this agent contributed
1. lifecycle:started
2. decision: deque-not-asyncio-Queue (zero-alloc steady state; cancel-control)
3. decision: condition-not-event-per-slot (single critical section; lower memory)
4. decision: LIFO-via-pop (Python idiom; warm-cache reuse)
5. decision: try_acquire-no-lock (single-loop GIL guarantee)
6. event: O(1)-amortized-proven-via-step-by-step-accounting
7. lifecycle:completed
