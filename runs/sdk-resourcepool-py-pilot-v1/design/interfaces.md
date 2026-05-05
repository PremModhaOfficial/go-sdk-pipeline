<!-- Generated: 2026-04-27T00:01:01Z | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 | Author: interface (D1) -->

# Interfaces — Protocols, Generics, mypy `--strict` plan

Companion to `design/api-design.md`. Spells out the typing contract that every public symbol obeys. Backs `python-class-design` skill conventions.

---

## 1. Goal — `mypy --strict` clean on the package

Per TPRD §4 Compat Matrix: `mypy --strict` MUST pass on the package. Practical implications:

- No `Any` in any public signature (only allowed in private helpers if escape-hatch genuinely needed; document with `# type: ignore[no-any-return]` + reason).
- Every callable has a typed signature.
- Every `TypeVar` is bound or constrained where appropriate (here: bare `T = TypeVar("T")` since the pool is fully covariant in resource type and the resource itself has no constraint).
- `__slots__` on dataclasses is compatible with mypy because dataclass field types are derived from class annotations (which mypy reads), not from `__slots__` itself.

---

## 2. The single `TypeVar`

```python
from typing import TypeVar

T = TypeVar("T")
```

- **Bound**: none. Pool is generic in any caller-supplied resource type. Constraining (e.g. `T = TypeVar("T", bound=Closeable)`) would force users to inherit from a sentinel base — ergonomics loss without semantic gain. Hooks already validate behavior at runtime.
- **Variance**: invariant by default in `Generic[T]`. Pool[Connection] is NOT Pool[Resource] even if Connection : Resource — correct, because `release(resource: T)` is contravariant in T. Don't override.
- Same `T` is re-imported at every module boundary (`_config.py`, `_pool.py`, `_acquired.py`); declaring the TypeVar once in `_config.py` and re-importing is a Python idiom (`from ._config import T` — mypy accepts).

---

## 3. Hook Protocols

The hooks accept either sync or async callables. Two strategies considered:

**Strategy A — Type-alias union** (chosen):

```python
# _config.py
from collections.abc import Awaitable, Callable

OnCreateHook = Callable[[], "T | Awaitable[T]"]
OnResetHook = Callable[["T"], "None | Awaitable[None]"]
OnDestroyHook = Callable[["T"], "None | Awaitable[None]"]
```

- Pro: simple, discoverable, no `Protocol` boilerplate, mypy accepts.
- Pro: matches Python typing-shed convention for "hook may be sync-or-async."
- Con: caller error of mistakenly returning the wrong type is detected at runtime by `inspect.iscoroutinefunction` + duck-typing on the result, not at type-check time. Acceptable: the asymmetry is structural to Python's await/non-await split.

**Strategy B — Two `Protocol`s per hook + Union**:

```python
class SyncOnCreate(Protocol[T]):
    def __call__(self) -> T: ...
class AsyncOnCreate(Protocol[T]):
    def __call__(self) -> Awaitable[T]: ...
OnCreateHook = SyncOnCreate[T] | AsyncOnCreate[T]
```

- Pro: more precise — mypy can distinguish overloads.
- Con: 4× more lines in `_config.py` for marginal gain; protocol-with-typevar is a known mypy footgun (variance issues on Protocol generics).

**Decision**: Strategy A. Structural simplicity wins; runtime detection via `inspect.iscoroutinefunction` is cached at `__init__` time so the dispatch overhead is one bool check per hook call.

---

## 4. Hook detection — `inspect.iscoroutinefunction` cached

```python
# _pool.py — inside Pool.__init__
import inspect

self._on_create_is_async = inspect.iscoroutinefunction(config.on_create)
self._on_reset_is_async = (
    config.on_reset is not None
    and inspect.iscoroutinefunction(config.on_reset)
)
self._on_destroy_is_async = (
    config.on_destroy is not None
    and inspect.iscoroutinefunction(config.on_destroy)
)
```

Then in hot paths:

```python
async def _create_resource_via_hook(self) -> T:
    """Calls on_create; awaits result if async. Wraps user exceptions in
    ResourceCreationError. [traces-to: TPRD-§7-ResourceCreationError]"""
    try:
        if self._on_create_is_async:
            return await self._config.on_create()  # type: ignore[no-any-return,misc]
        return self._config.on_create()  # type: ignore[no-any-return,return-value]
    except Exception as user_exc:
        raise ResourceCreationError(
            f"on_create failed in pool '{self._config.name}'"
        ) from user_exc
```

**mypy interaction**: the Union return type of the hook means mypy sees both branches as `T | Awaitable[T]`. The `type: ignore` annotations are local to two lines and are documented as the structural-typing escape hatch. Acceptable per `mypy --strict`'s allowed-with-comment exemption.

**Alternative considered**: `typing.cast` instead of `type: ignore`. Equivalent runtime behavior; cast is slightly more honest ("I assert this type"); `type: ignore` is shorter. Picking `type: ignore` because the comment forces a reason and is greppable for audit.

---

## 5. Public signature contract — every method's mypy view

| Method | Signature (post-mypy) |
|---|---|
| `PoolConfig[T].__init__` (synthesized) | `(*, max_size: int, on_create: OnCreateHook[T], on_reset: OnResetHook[T] \| None = None, on_destroy: OnDestroyHook[T] \| None = None, name: str = 'resourcepool') -> None` |
| `Pool[T].__init__` | `(self, config: PoolConfig[T]) -> None` |
| `Pool[T].acquire` | `(self, *, timeout: float \| None = None) -> AcquiredResource[T]` |
| `Pool[T].acquire_resource` | `async (self, *, timeout: float \| None = None) -> T` |
| `Pool[T].try_acquire` | `(self) -> T` |
| `Pool[T].release` | `async (self, resource: T) -> None` |
| `Pool[T].aclose` | `async (self, *, timeout: float \| None = None) -> None` |
| `Pool[T].stats` | `(self) -> PoolStats` |
| `Pool[T].__aenter__` | `async (self) -> Pool[T]` |
| `Pool[T].__aexit__` | `async (self, exc_type: type[BaseException] \| None, exc: BaseException \| None, tb: TracebackType \| None) -> None` |
| `AcquiredResource[T].__aenter__` | `async (self) -> T` |
| `AcquiredResource[T].__aexit__` | `async (self, exc_type, exc, tb) -> None` (untyped exit-args mypy-accepted) |
| `PoolStats.__init__` (synthesized) | `(*, created: int, in_use: int, idle: int, waiting: int, closed: bool) -> None` |
| Five exception classes | `(self, *args: object) -> None` (inherit `Exception.__init__`) |

---

## 6. Generic propagation — verifying caller usability

A caller writes:

```python
async def make_client() -> HttpClient: ...
config = PoolConfig[HttpClient](max_size=10, on_create=make_client)
pool: Pool[HttpClient] = Pool(config)
async with pool.acquire(timeout=5.0) as client:
    reveal_type(client)  # mypy: HttpClient
```

The flow:
1. `PoolConfig[HttpClient]` binds T=HttpClient at construction.
2. `Pool(config)` — mypy infers `Pool[HttpClient]` from `config: PoolConfig[HttpClient]`.
3. `pool.acquire(...)` returns `AcquiredResource[HttpClient]`.
4. `async with ... as client` — `__aenter__` returns `T` = `HttpClient`. ✓

This is the load-bearing usability proof. Tested under `mypy --strict` in `tests/unit/test_typing.py` (impl phase).

---

## 7. Forward-reference handling

- `_config.py` defines `T` and the three hook type aliases.
- `_pool.py` imports `T` from `_config.py` (NOT redefining; same identity).
- `AcquiredResource` is referenced in `_pool.py` `acquire`'s return type; resolved by:
  - In `_pool.py`: `from ._acquired import AcquiredResource` (no circular import — `_acquired` only imports `Pool` under `if TYPE_CHECKING:`).
- `Pool` is referenced in `_acquired.py` for the back-reference; guarded by `TYPE_CHECKING` to break the cycle:
  ```python
  from typing import TYPE_CHECKING
  if TYPE_CHECKING:
      from ._pool import Pool
  ```
  And `_acquired.py`'s `__init__` annotates `pool: "Pool[T]"` as a forward-string reference.

mypy `--strict` resolves all forward refs at type-check time without runtime cost.

---

## 8. Why no `Protocol[T]` for Pool itself

We do NOT define `class IPool(Protocol[T])` or `class IAcquiredResource(Protocol[T])`. Reasons:

1. **No second implementation planned.** The pilot ships exactly one Pool. A Protocol exists to allow polymorphism at type-check time when there are >1 implementers.
2. **`__slots__` + Protocol = footgun.** Protocols are structural; `__slots__` restricts instance attributes; the combination produces confusing mypy errors when a caller tries to substitute a non-slotted impl.
3. **Future-proofing penalty isn't worth it.** If a future TPRD adds (e.g.) `DistributedPool[T]`, a `Protocol[T]` can be extracted at that point with zero impact on the existing API (the concrete Pool will already match the structural Protocol).

If a caller wants a typing seam (e.g. for Mock injection in tests), they can `cast(Pool[T], mock_pool)` — Python's structural duck-typing handles it without a Protocol declaration.

---

## 9. mypy config snippet (for impl phase to land in `pyproject.toml`)

```toml
[tool.mypy]
strict = true
python_version = "3.11"
warn_unused_ignores = true       # surfaces stale `type: ignore` markers
disallow_untyped_decorators = true
follow_imports = "silent"         # avoid noise on 3rd-party
plugins = []                       # no plugins needed (no pydantic, no SQLAlchemy)

[[tool.mypy.overrides]]
module = "motadata_py_sdk.resourcepool._pool"
# Permit the two `type: ignore` lines in _create_resource_via_hook for the
# sync-or-async hook union escape hatch. Documented in interfaces.md §4.
warn_unused_ignores = true
```

This is the testable surface for the `vet` toolchain step (`mypy --strict .`).

---

## 10. Deliverable summary

- All public signatures are concrete (no `Any`).
- Hook callables: `OnCreateHook[T]`, `OnResetHook[T]`, `OnDestroyHook[T]` as `Callable` type aliases over `Union[T, Awaitable[T]]`.
- Hook sync/async detected once at `__init__` via `inspect.iscoroutinefunction`; cached as bool flags on `Pool`.
- `T = TypeVar("T")` declared once in `_config.py`, re-imported by `_pool.py` and `_acquired.py`.
- No public `Protocol`s — single implementation; structural ducks suffice.
- Forward references handled via `TYPE_CHECKING` guard in `_acquired.py`.
- Two documented `type: ignore` lines in `_create_resource_via_hook`; rationale logged here.
- mypy `--strict` will pass on the package.
