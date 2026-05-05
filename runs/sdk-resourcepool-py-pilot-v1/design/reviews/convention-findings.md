<!-- Generated: 2026-04-27T00:02:04Z | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 | Reviewer: sdk-convention-devil (READ-ONLY) | Note: agent not in active-packages.json; orchestrator brief requested explicit convention review — providing as design-lead surrogate review -->

# Convention Findings — `motadata_py_sdk.resourcepool`

Verifies Python conventions per TPRD §16 + Python adapter manifest's marker-syntax declaration + PEP 8 compliance.

## Verdict: ACCEPT

All conventions honored. Zero deviations. Marker comment syntax correct (`#`).

---

## CF-001 — Naming conventions per TPRD §16 / PEP 8

| Category | Rule | Examples in design | Verdict |
|---|---|---|---|
| Module names | snake_case, leading underscore for private | `_config.py`, `_pool.py`, `_stats.py`, `_acquired.py`, `_errors.py` | ✓ |
| Class names | PascalCase | `Pool`, `PoolConfig`, `PoolStats`, `AcquiredResource`, `PoolError`, `PoolClosedError`, `PoolEmptyError`, `ConfigError`, `ResourceCreationError` | ✓ |
| Method names | snake_case | `acquire`, `acquire_resource`, `try_acquire`, `release`, `aclose`, `stats` | ✓ |
| Private internals | _snake_case | `_acquire_with_timeout`, `_create_resource_via_hook`, `_release_slot`, `_lock`, `_idle`, `_outstanding`, `_created`, `_in_use`, `_waiting`, `_closed`, `_close_event`, `_on_create_is_async`, `_on_reset_is_async`, `_on_destroy_is_async`, `_config` | ✓ |
| Type variables | single uppercase | `T = TypeVar("T")` | ✓ |
| Constants | UPPER_SNAKE_CASE | (none in this pool — no module-level constants) | ✓ N/A |
| Type aliases | PascalCase | `OnCreateHook`, `OnResetHook`, `OnDestroyHook` | ✓ |

PASS.

---

## CF-002 — Type hints on every public signature (TPRD §16)

Verified against api-design.md §1–§6 + interfaces.md §5:

- All 10 Pool methods have typed signatures (params + return).
- PoolConfig synthesized __init__ has typed params.
- PoolStats synthesized __init__ has typed params.
- AcquiredResource methods have typed signatures.
- All 5 exception classes inherit Exception's untyped __init__ (Python convention for sentinel exceptions; PEP 8 + standard idiom).

PASS.

---

## CF-003 — frozen+slots on Config + Stats (TPRD §16)

Verified:
- `PoolConfig` uses `@dataclass(frozen=True, slots=True)` per api-design.md §2.
- `PoolStats` uses `@dataclass(frozen=True, slots=True)` per api-design.md §4.

PASS.

---

## CF-004 — Sentinel error class hierarchy from `PoolError` (TPRD §16)

Verified per api-design.md §6:
- `PoolError(Exception)` is the base.
- `PoolClosedError(PoolError)`, `PoolEmptyError(PoolError)`, `ConfigError(PoolError)`, `ResourceCreationError(PoolError)` all inherit from `PoolError`.
- All 5 inherit (transitively) from `Exception` not `BaseException` — caller's `except Exception:` will catch them. Standard library convention.

PASS.

---

## CF-005 — Marker comment syntax (`#` per python.json `marker_comment_syntax.line`)

Verified across all design files:
- All `[traces-to: TPRD-§<n>-<symbol>]` markers in api-design.md / interfaces.md / algorithm.md are written as `# [traces-to: ...]` (line-comment form).
- All `[constraint: ...]` markers in algorithm.md are written as `# [constraint: ...]`.
- All `[perf-exception: ...]` documentation in perf-exceptions.md uses `# [perf-exception: ...]`.

No Go-style `// [...]` markers anywhere. ✓ PASS.

---

## CF-006 — Docstring conventions (PEP 257)

Verified across api-design.md:
- Every public class has a docstring.
- Every public method has a docstring.
- Docstring first word = symbol name (per CLAUDE.md "Quality Standards" rule 6).
  - `Pool` docstring starts "Pool is..." ✓
  - `PoolConfig` docstring starts "PoolConfig is..." ✓
  - `acquire` docstring starts "acquire returns..." ✓
  - `acquire_resource` docstring starts "acquire_resource returns..." ✓
  - `try_acquire` docstring starts "try_acquire returns..." ✓
  - `release` docstring starts "release returns..." ✓
  - `aclose` docstring starts "aclose drains..." ✓
  - `stats` docstring starts "stats returns..." ✓
  - `__aenter__` docstring starts "__aenter__ supports..." ✓
  - `__aexit__` docstring starts "__aexit__ delegates..." ✓
  - All 5 exception classes start with "<ExceptionName> is..." ✓

PASS.

---

## CF-007 — `Example_*`-style runnable docstring examples (CLAUDE.md rule 14)

Verified that every public symbol has at least one `>>> ` doctest-style example in api-design.md:
- `PoolConfig` — example block §2 ✓
- `Pool` — example block §3.1 ✓
- `acquire` — example block §3.2 ✓
- `acquire_resource` — example block §3.3 ✓
- `try_acquire` — example block §3.4 ✓
- `release` — example block §3.5 ✓
- `aclose` — example block §3.6 ✓
- `stats` — example block §3.7 ✓
- `PoolStats` — example block §4 ✓
- `AcquiredResource` — N/A (not user-constructed; acquire's example covers it)
- `PoolError` — example block §6 ✓
- `PoolEmptyError` — example block §6 ✓
- `ResourceCreationError` — example block §6 ✓

PASS.

---

## CF-008 — No init() functions, no global mutable state (CLAUDE.md rule 6)

- No module-level `init()` functions in any of the 5 internal modules. ✓
- No module-level mutable state (constants OK; no module-level lists/dicts/sets). ✓
- No class-level mutable defaults (PoolConfig is frozen+slotted; mutable defaults would be a TypeError). ✓

PASS.

---

## CF-009 — `context.Context` first param? — N/A for Python

Python doesn't have `context.Context`. Equivalent is `asyncio.timeout()` carried via `timeout=` kwarg. Honored across `acquire`, `acquire_resource`, `aclose`. PASS.

---

## CF-010 — Compile-time interface assertions? — N/A for Python

Python's structural duck-typing replaces Go's explicit interface assertions. mypy strict + the type-alias hooks provide equivalent type-check-time enforcement. PASS.

---

## Final verdict: ACCEPT

All Python conventions per TPRD §16, PEP 8, PEP 257, and the python adapter manifest are honored. No deviations to file. No fixes required.
