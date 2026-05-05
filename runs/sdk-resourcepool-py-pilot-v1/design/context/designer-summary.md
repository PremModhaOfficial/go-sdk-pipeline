<!-- Generated: 2026-04-27T00:01:35Z | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 | Agent: designer -->

# Designer summary — D1 wave

## Output produced
- `design/api-design.md` (584 lines): full Pythonic API surface for `motadata_py_sdk.resourcepool`. Honors TPRD §15 Q1–Q6 verbatim. Covers PoolConfig, Pool (10 methods), AcquiredResource, PoolStats, all 5 exception classes (PoolError + 4 descendants).

## RULE 0 compliance
- Every TPRD §5 / §7 named symbol has a final signature + docstring + traces-to marker.
- Zero TODO/FIXME/TBD/placeholder.
- §3 Non-Goals reaffirmed in §9 (not tech debt — written contracts).

## Key design decisions
1. Pool exposes both `acquire` (returns AcquiredResource ctx mgr) and `acquire_resource` (raw async, returns T) per Q6.
2. `try_acquire` is sync `def`; raises `ConfigError` if `on_create` is async per Q2.
3. Pool itself is async ctx mgr — `__aenter__` returns self; `__aexit__` calls aclose() per Q3.
4. `release` is async per Q4 (must await async on_reset).
5. PoolConfig + PoolStats use `@dataclass(frozen=True, slots=True)` per Q5.
6. `keyword-only` `timeout` enforced by `*, timeout: float | None = None` signature per Q1.
7. `ResourceCreationError` raised via `raise ... from user_exc` to preserve user's exception in `__cause__`.
8. `AcquiredResource.__aexit__` awaits release fully; release errors take precedence over body errors.

## Cross-references
- Hook protocols + Generic[T] + mypy strict plan → interfaces.md
- Idle storage choice (deque + Condition) → algorithm.md
- Cancellation rollback semantics → concurrency-model.md
- __slots__ matrix + sentinel hierarchy → patterns.md
- Perf budgets per symbol → perf-budget.md

## Decision-log entries this agent contributed
1. lifecycle:started (D1-spawn)
2. decision: api-surface-finalized (Q1-Q6 verbatim honored)
3. decision: error-hierarchy (5 sentinel classes from PoolError; chained traces via `from`)
4. decision: ctx-mgr-vs-raw-split (Q6 — two distinct methods, no dual-mode)
5. event: traces-to-markers-on-all-9-symbols
6. lifecycle:completed
