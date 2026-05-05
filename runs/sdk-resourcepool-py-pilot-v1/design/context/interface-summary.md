<!-- Generated: 2026-04-27T00:01:36Z | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 | Agent: interface -->

# Interface summary — D1 wave

## Output produced
- `design/interfaces.md` (212 lines): typing contract for `mypy --strict` clean compilation.

## RULE 0 compliance
- Every public method in the API has a typed signature in §5 (no `Any` in public surface).
- mypy strict config snippet provided; testable via `vet` toolchain step.
- Two documented `type: ignore` comments in `_create_resource_via_hook` for sync/async hook union escape hatch — explicit + greppable + audited.

## Key typing decisions
1. Single `T = TypeVar("T")` declared once in `_config.py`, re-imported by `_pool.py` and `_acquired.py` (NOT re-declared — same identity).
2. Hook protocols: type-alias union `Callable[[], "T | Awaitable[T]"]` (Strategy A) instead of two-Protocol-per-hook (Strategy B). Simpler; protocol-with-typevar is a known mypy footgun.
3. No `Protocol[T]` for Pool itself — single implementation; structural ducks suffice. Future `DistributedPool[T]` can extract a Protocol post-hoc with zero impact.
4. Forward refs handled via `TYPE_CHECKING` guard in `_acquired.py` (breaks the Pool↔AcquiredResource import cycle).
5. `inspect.iscoroutinefunction` cached as bool slot at `__init__` (vs called per hook invocation).

## Generic propagation proof
Caller writes `PoolConfig[HttpClient](...)` → mypy infers `Pool[HttpClient]` → `pool.acquire(...)` returns `AcquiredResource[HttpClient]` → `async with ... as client` → `client: HttpClient`. Tested in `tests/unit/test_typing.py` (impl phase).

## Cross-references
- Public method signatures table → interfaces.md §5
- Caller usability proof → interfaces.md §6
- Forward-reference pattern → interfaces.md §7
- mypy config snippet → interfaces.md §9

## Decision-log entries this agent contributed
1. lifecycle:started
2. decision: hook-typing-strategy-A (type-alias union, not two protocols)
3. decision: no-public-protocols (single impl; structural ducks)
4. decision: type-ignore-vs-cast (type:ignore — comment forces reason; greppable for audit)
5. lifecycle:completed
