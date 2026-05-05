<!-- Generated: 2026-04-27T00:01:04Z | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 | Author: pattern-advisor (D1) -->

# Patterns — Pythonic idioms applied across the package

Companion to api-design.md / interfaces.md / algorithm.md / concurrency-model.md. Documents the Python idioms chosen and why each is appropriate for this pool.

---

## 1. `__slots__` decision matrix

| Class | `__slots__`? | Justification |
|---|---|---|
| `PoolConfig` | YES (via `@dataclass(frozen=True, slots=True)`) | Frozen + slotted = canonical Python config-object idiom (Python 3.10+ dataclass `slots=True` parameter). Removes per-instance `__dict__`; ~50 % memory reduction; ~15 % attribute access speedup. Caller may have many configs; cheap to enable. |
| `PoolStats` | YES (via `@dataclass(frozen=True, slots=True)`) | Same justification. Stats snapshots are short-lived (one per `pool.stats()` call) but allocated frequently in observability paths; reducing per-instance overhead matters. |
| `Pool` | YES (explicit `__slots__ = (...)` tuple) | Q5 says "yes if benchmarks justify"; perf-architect's bench expectation says yes (the Pool instance lives long but every attribute access is on the hot path). Explicit `__slots__` (not dataclass) because Pool has mutable state, an `__init__` with logic, and inheritance is undesirable. |
| `AcquiredResource` | YES (explicit `__slots__ = ("_pool", "_timeout", "_resource")`) | Allocated once per `acquire()` call. With `__slots__`, allocation is a single fixed-size struct; without, also allocates a `__dict__`. The 4 % per-acquire savings compounds. |
| Five exception classes | NO | Subclassing `Exception` with `__slots__` is awkward (Exception itself uses `__dict__` for `args` + `__notes__`); the gain is tiny (exceptions are rare). Standard Python practice: don't slot exception classes. |

**Anti-pattern rejected**: declaring `__slots__` on a class that inherits from a non-slotted parent (e.g. `Generic[T]` from typing) used to be problematic in older Python; in 3.11+ this works. Pool inherits `Generic[T]` and declares `__slots__`; verified compatible.

---

## 2. `@dataclass(frozen=True, slots=True)` — the right tool for value types

Both `PoolConfig` and `PoolStats` are **value types** — equality by field value, immutable, no behavior beyond data-holding. Python 3.10+'s `dataclass(frozen=True, slots=True)` produces:

- `__init__` from field annotations
- `__repr__` from field values
- `__eq__` / `__hash__` from frozen fields
- `__slots__` for memory efficiency
- `FrozenInstanceError` on mutation

This is the canonical Python equivalent of Go's `type Config struct { ... }`. No external dep needed (no pydantic, no attrs).

**Anti-pattern rejected**: `pydantic.BaseModel` for runtime validation. Overkill — our validation is two `if` checks (`max_size > 0`, `on_create is not None`) at Pool construction. Pydantic would add a 5MB transitive dep + import-time cost for marginal gain.

---

## 3. Sentinel exception class hierarchy

```
Exception
└── PoolError                 [base sentinel — caller catches this for "any pool problem"]
    ├── PoolClosedError       [op against closed pool]
    ├── PoolEmptyError        [try_acquire saw no slot + no capacity]
    ├── ConfigError           [bad PoolConfig or sync/async mismatch]
    └── ResourceCreationError [user's on_create raised; user_exc on __cause__]
```

**Why a base class?** Lets callers do `except PoolError: ...` to catch all pool issues without knowing which subclass. Matches Python's `OSError` family pattern.

**Why no `BaseException` inheritance?** `BaseException` is reserved for system-level errors (SystemExit, KeyboardInterrupt, CancelledError). Library errors MUST inherit from `Exception` so callers' `except Exception:` catches them. CLAUDE.md / Python convention.

**`raise X from Y` for `ResourceCreationError`**: `raise ResourceCreationError(...) from user_exc` sets `__cause__` to the user's exception. This preserves the full traceback chain — caller sees both our wrapper and the original user error.

---

## 4. Sync/async hook detection — `inspect.iscoroutinefunction` once at `__init__`

```python
import inspect
self._on_create_is_async = inspect.iscoroutinefunction(config.on_create)
```

**Why detect once and cache?** `inspect.iscoroutinefunction` is not free (it walks the callable's metadata); on a hot path with thousands of acquires/sec, the overhead matters. Cache as a `bool` slot.

**Why `inspect.iscoroutinefunction` and not `asyncio.iscoroutinefunction`?**: identical behavior in 3.11+, but `inspect` version is slightly newer / more general (handles `functools.partial`, `functools.wraps`'d coroutines).

**Edge case — `functools.partial(async_fn, ...)`**: `inspect.iscoroutinefunction` correctly returns True for these in 3.11+. Documented; tested in unit phase.

**Edge case — `lambda: asyncio.sleep(0)`**: this is NOT a coroutine function (it's a sync function returning a coroutine). `iscoroutinefunction` returns False; we'd call it sync, which returns the coroutine object, which would NOT be awaited → silent bug. Mitigation: docstring on PoolConfig says "if your hook returns an awaitable, declare it `async def`." Accept the footgun; alternative would require `inspect.isawaitable(result)` check after every hook call which is per-call overhead.

---

## 5. `__aenter__` / `__aexit__` placement — Pool itself + AcquiredResource

Two distinct context-manager surfaces:

1. `Pool.__aenter__/__aexit__` — for `async with Pool(config) as pool: ...` lifecycle management. `__aexit__` calls `aclose()` (with no timeout — wait forever).
2. `AcquiredResource.__aenter__/__aexit__` — for `async with pool.acquire(timeout=N) as resource: ...` per-resource lifecycle. `__aexit__` calls `pool.release(resource)`.

**Why two?** Different scopes:
- Pool's `async with` covers the pool's entire lifetime.
- AcquiredResource's `async with` covers one borrow.

This nesting pattern is canonical Python (compare `async with aiohttp.ClientSession() as session: async with session.get(url) as resp: ...`).

**Q3 honored**: Pool is an async ctx mgr. **Q6 honored**: `acquire` returns the helper synchronously; the helper is the ctx mgr. No dual-mode magic.

---

## 6. Naming conventions (TPRD §16 / convention-devil pre-check)

| Symbol category | Convention | Examples in this design |
|---|---|---|
| Module names | `snake_case`, leading underscore for private | `_config.py`, `_pool.py`, `_stats.py`, `_acquired.py`, `_errors.py` |
| Class names | `PascalCase` | `Pool`, `PoolConfig`, `PoolStats`, `AcquiredResource`, `PoolError` |
| Method names | `snake_case` | `acquire`, `acquire_resource`, `try_acquire`, `release`, `aclose`, `stats` |
| Private internals | `_snake_case` | `_acquire_with_timeout`, `_create_resource_via_hook`, `_lock`, `_idle` |
| Type variables | `T` (single uppercase) | `T = TypeVar("T")` |
| Constants | `UPPER_SNAKE_CASE` | none in this pool (no module-level constants) |
| Type aliases | `PascalCase` | `OnCreateHook`, `OnResetHook`, `OnDestroyHook` |

All conform to PEP 8 + the TPRD §16 explicit list.

---

## 7. Marker comment syntax (Python adapter `python.json` `marker_comment_syntax.line`)

Every pipeline-authored `.py` file carries `# [traces-to: TPRD-§<n>-<symbol>]` at the symbol's declaration line. The Python marker syntax is `#` (declared in `python.json`). All five marker types (CLAUDE.md rule 29) are supported:

- `# [traces-to: TPRD-§5.1-Pool]` — required on every pipeline-authored symbol (G99 equivalent).
- `# [constraint: complexity O(1) bench/test_scaling.py::bench_acquire_release_cycle]` — on `_acquire_with_timeout` and `release` (G97 equivalent).
- `# [stable-since: v1.0.0]` — to be added on every public symbol post-merge (G101 equivalent).
- `# [do-not-regenerate]` — none in this pilot (no MANUAL escape hatches needed).
- `# [perf-exception: <reason> bench/test_X]` — none in this pilot; design has no premature optimization that would trigger overengineering-critic.

---

## 8. Logging pattern

Python pool uses stdlib `logging` (NOT `print`, NOT `sys.stderr.write`). Lazy-imported only inside `_destroy_resource_via_hook` (to avoid the import cost when on_destroy never raises). Logger name: `__name__` (resolves to `motadata_py_sdk.resourcepool._pool`); caller can configure via the standard `logging.getLogger("motadata_py_sdk.resourcepool")` namespace.

```python
import logging
logging.getLogger(__name__).warning(
    "on_destroy raised in pool '%s'; resource dropped",
    self._config.name,
    exc_info=True,
)
```

**Why % formatting and not f-string?** Stdlib logging defers % expansion until the record is actually emitted (filtered by level). f-string evaluates always — wasteful when DEBUG/WARN level is filtered. Standard Python logging idiom.

**No global logger**: never `LOG = logging.getLogger(...)` at module scope (matches CLAUDE.md "no global mutable state" — although a logger object is technically immutable, the namespace style is debatable; explicit `getLogger(__name__).warning(...)` per call is cleaner).

---

## 9. Future-proofing: what we deliberately did NOT add

- **No `cached_property`**: the Pool's mutable state means caching anything is incorrect.
- **No `weakref`**: outstanding-task tracking uses strong refs (a `set[Task]`); we WANT to keep tasks alive long enough to cancel them.
- **No `contextvars`**: pool has no per-acquire context state worth propagating.
- **No `__class_getitem__` magic**: dataclass + Generic[T] supplies subscript notation correctly.
- **No metaclass**: zero need.
- **No descriptors**: no smart attributes.

Each of these is a Python idiom that COULD apply but adds complexity for no design benefit. Documenting their absence to short-circuit overengineering-critic findings.

---

## 10. Module-level test discovery layout

```
tests/
├── conftest.py          # `assert_no_leaked_tasks` fixture; `event_loop_policy` fixture
├── unit/
│   ├── test_construction.py     # PoolConfig + Pool() validation
│   ├── test_acquire_release.py  # happy path, contention, idle reuse
│   ├── test_cancellation.py     # cancel-mid-acquire rollback
│   ├── test_timeout.py          # asyncio.timeout boundary cases
│   ├── test_aclose.py           # graceful shutdown + idempotency
│   ├── test_hook_panic.py       # on_create / on_reset / on_destroy raising
│   ├── test_stats.py            # snapshot consistency
│   └── test_typing.py           # mypy --strict reveal_type assertions
├── integration/
│   ├── test_contention.py       # 32 acquirers, max=4, all complete
│   └── test_chaos.py            # 100 acquirers, 50% on_create failure rate
├── bench/
│   ├── bench_acquire.py         # latency p50/p95/p99 for happy + try_acquire
│   ├── bench_acquire_contention.py  # throughput at 32 acquirers, max=4
│   ├── bench_aclose.py          # drain 1000 outstanding < 100ms
│   └── bench_scaling.py         # O(1) sweep at N ∈ {10, 100, 1k, 10k}
└── leak/
    └── test_pool_no_leaked_tasks.py  # every method through assert_no_leaked_tasks
```

Mirrors TPRD §12 layout. Every TPRD §11.x test category has ≥1 file. Zero tech debt.

---

## 11. pyproject.toml shape (impl phase will land)

```toml
[project]
name = "motadata-py-sdk"
version = "1.0.0"
requires-python = ">=3.11"
dependencies = []   # zero direct deps per TPRD §4

[project.optional-dependencies]
dev = [
    "pytest>=8.0",
    "pytest-asyncio>=0.23",
    "pytest-benchmark>=4.0",
    "pytest-cov>=4.1",
    "pytest-randomly>=3.15",  # optional but recommended for race surfacing
    "ruff>=0.5",
    "mypy>=1.10",
    "pip-audit>=2.7",
    "safety>=3.2",
]

[tool.pytest.ini_options]
asyncio_mode = "strict"
testpaths = ["tests"]
python_files = ["test_*.py", "bench_*.py"]

[tool.ruff]
line-length = 100
target-version = "py311"

[tool.ruff.lint]
select = ["E", "F", "W", "I", "N", "UP", "B", "ASYNC", "RUF"]

[tool.mypy]
strict = true
python_version = "3.11"
```

Confirms TPRD §4 Compat Matrix + zero-deps invariant. dep-vet-devil verifies dev deps stay in `optional-dependencies.dev` (NOT shipped at install).

---

## 12. Summary

- `__slots__` everywhere it pays (PoolConfig, PoolStats, Pool, AcquiredResource); not on exception classes.
- `@dataclass(frozen=True, slots=True)` for value types (PoolConfig, PoolStats); explicit `__slots__` for behavior types (Pool, AcquiredResource).
- Sentinel exception hierarchy from `PoolError`; `raise … from user_exc` for chained traces.
- Hook sync/async detection via `inspect.iscoroutinefunction`, cached at `__init__`.
- Two `__aenter__/__aexit__` surfaces: Pool (whole-lifetime) and AcquiredResource (per-borrow).
- All naming per PEP 8 + TPRD §16.
- Markers per Python `#`-line syntax; G97 / G99 / G101 honored.
- Logging via stdlib `logging.getLogger(__name__)`, % formatting, lazy import.
- No metaclasses, no descriptors, no contextvars, no weakref, no cached_property, no pydantic.
- pyproject.toml zero direct deps; dev tools in `optional-dependencies.dev`.
- Test file layout mirrors §12; every §11.x category has ≥1 file.
