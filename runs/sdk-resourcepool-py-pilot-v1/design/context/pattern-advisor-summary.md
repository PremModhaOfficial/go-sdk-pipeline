<!-- Generated: 2026-04-27T00:01:39Z | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 | Agent: pattern-advisor -->

# Pattern-advisor summary — D1 wave

## Output produced
- `design/patterns.md` (230 lines): Python idioms applied + naming conventions + marker syntax + pyproject.toml shape + test layout.

## RULE 0 compliance
- Every TPRD §16 naming convention rule explicitly addressed.
- Every TPRD §12 file in package layout has a stated test file.
- pyproject.toml fully specified (zero direct deps; dev tools in optional-dependencies.dev).

## Key idiom decisions
1. **`__slots__` matrix**: PoolConfig (frozen+slots), PoolStats (frozen+slots), Pool (explicit __slots__ tuple), AcquiredResource (explicit __slots__). NOT on exception classes.
2. **`@dataclass(frozen=True, slots=True)`** for value types (PoolConfig, PoolStats); explicit __slots__ for behavior types (Pool, AcquiredResource).
3. **Sentinel exception hierarchy** from `PoolError`; `raise ... from user_exc` for chained traces (preserves __cause__).
4. **Sync/async hook detection** via `inspect.iscoroutinefunction` cached at `__init__` as bool slots.
5. **Two `__aenter__/__aexit__` surfaces**: Pool (whole-lifetime) + AcquiredResource (per-borrow). Canonical Python nesting pattern.
6. **Naming**: snake_case modules + methods, PascalCase classes, _private leading underscore, T single-uppercase TypeVar, PascalCase type aliases.
7. **Marker syntax**: `# [traces-to: ...]` per python.json `marker_comment_syntax.line = "#"`.
8. **Logging**: stdlib `logging.getLogger(__name__).warning(...)` with `%` formatting (lazy expansion); lazy-imported in hook-error path.
9. **Deliberately NOT used**: cached_property, weakref, contextvars, __class_getitem__ magic, metaclass, descriptors, pydantic.

## pyproject.toml shape
- `dependencies = []` (zero direct deps per TPRD §4)
- `[project.optional-dependencies] dev = [pytest, pytest-asyncio, pytest-benchmark, pytest-cov, pytest-randomly, ruff, mypy, pip-audit, safety]`
- pytest asyncio_mode = "strict"
- mypy strict = true, python_version = "3.11"
- ruff selects E, F, W, I, N, UP, B, ASYNC, RUF

## Test file layout (mirrors TPRD §12)
- 8 unit + 2 integration + 4 bench + 1 leak = 15 test files
- Every TPRD §11.x category has ≥1 file (zero tech debt)

## Convention-devil pre-check (pre-D2)
All Python conventions per TPRD §16 satisfied:
- snake_case methods ✓
- PascalCase classes ✓
- _private underscore ✓
- type hints on every public signature ✓
- frozen+slots on Config + Stats ✓
- sentinel error class hierarchy ✓
- # marker syntax ✓

## Cross-references
- API surface → api-design.md
- Typing rationale → interfaces.md
- Algorithm choices → algorithm.md
- Concurrency primitives → concurrency-model.md
- Perf budgets → perf-budget.md

## Decision-log entries this agent contributed
1. lifecycle:started
2. decision: dataclass-frozen-slots-for-value-types (vs pydantic; vs attrs)
3. decision: explicit-__slots__-for-behavior-types
4. decision: no-public-protocols (defer to interfaces.md §8 rationale)
5. decision: stdlib-logging-with-%-formatting (deferred eval; standard idiom)
6. decision: deliberately-no-cached_property-weakref-etc (avoid overengineering-critic findings)
7. event: convention-devil-pre-check-passed
8. lifecycle:completed
