---
name: python-class-design
description: Config + factory pattern for Python SDK clients — frozen slotted dataclass Config, factory function, Protocol structural typing, validation in __post_init__.
version: 1.0.0
status: stable
authored-in: v0.5.0-python-pilot
priority: MUST
tags: [python, class, dataclass, protocol, config, sdk, factory]
trigger-keywords: [dataclass, frozen, slots, __post_init__, Protocol, new_client, Config, validation, mutable default]
---

# python-class-design (v1.0.0)

## Rationale

Python SDK clients need the same construction discipline as their Go counterparts: a single immutable Config carries every knob; a factory function validates and returns a ready-to-use Client. The pipeline rejects ad-hoc `__init__(**kwargs)` clients because: (1) **mutable Config is a defect surface** — caller mutation post-construction creates spooky-action-at-a-distance bugs, (2) **scattered validation** across methods means invalid configs are detected at first use, not at construction, (3) **`__dict__` per instance** is a memory tax on hot-path types. `@dataclass(frozen=True, slots=True)` + `def new_client(config: Config) -> Client` is the canonical shape.

## Activation signals

- Designing any new SDK client class with >1 configuration knob
- Reviewer cites "mutable default argument", "missing slots", "validation scattered", or "no factory function"
- Adding a new Protocol for caller-supplied callbacks (auth provider, retry hook)
- Hot-path class identified by profiler — `__slots__` triage
- Migrating a legacy class with manual `__init__` to dataclass

## Config: `@dataclass(frozen=True, slots=True)` + validation in `__post_init__`

Frozen dataclasses raise `FrozenInstanceError` on mutation. Slots eliminate `__dict__`, halving memory and giving a measurable attribute-access speedup. Validation lives in `__post_init__` — invalid combinations raise immediately at construction, never at first use.

```python
# sdk/config.py
from __future__ import annotations
from dataclasses import dataclass, field
from typing import Final


class ConfigError(ValueError):
    """Raised when Config invariants are violated at construction."""


@dataclass(frozen=True, slots=True)
class Config:
    """Client configuration. Immutable after construction.

    Required fields have no default; optional fields use ``field(default=...)``.
    Never use a mutable literal as a default — see Pitfalls #1.
    """

    endpoint: str
    api_key: str
    timeout_s: float = 30.0
    max_retries: int = 3
    headers: dict[str, str] = field(default_factory=dict)
    tags: tuple[str, ...] = ()  # tuple is immutable — safe as default

    def __post_init__(self) -> None:
        if not self.endpoint.startswith(("http://", "https://")):
            raise ConfigError(f"endpoint must be http(s) URL, got {self.endpoint!r}")
        if self.timeout_s <= 0:
            raise ConfigError(f"timeout_s must be > 0, got {self.timeout_s}")
        if self.max_retries < 0:
            raise ConfigError(f"max_retries must be >= 0, got {self.max_retries}")
        if not self.api_key:
            raise ConfigError("api_key is required")
```

`field(default_factory=dict)` is the ONLY correct way to default a mutable container — see Pitfalls #1.

## Factory: `def new_client(config: Config) -> Client`

The factory is the public construction entry point. It receives a validated Config, performs side-effecting setup (open connection pools, register OTel handlers), and returns a ready Client. Python analog of Go's `New(cfg) (*Client, error)`.

```python
# sdk/client.py
from __future__ import annotations
import asyncio
from typing import Any
import httpx

from .config import Config


class Client:
    """SDK client. Construct via :func:`new_client`, never directly."""

    __slots__ = ("_config", "_http", "_tasks", "_closed")

    def __init__(self, config: Config, http: httpx.AsyncClient) -> None:
        # Internal constructor — do not call directly. Use new_client().
        self._config = config
        self._http = http
        self._tasks: set[asyncio.Task[Any]] = set()
        self._closed = False

    async def close(self) -> None:
        if self._closed:
            return
        self._closed = True
        await self._http.aclose()


def new_client(config: Config) -> Client:
    """Construct a Client from a validated Config. Equivalent of Go's New(cfg)."""
    http = httpx.AsyncClient(
        base_url=config.endpoint,
        timeout=config.timeout_s,
        headers={"Authorization": f"Bearer {config.api_key}", **config.headers},
    )
    return Client(config, http)
```

The Client class declares `__slots__` directly (not via dataclass) because it carries non-config mutable state (`_tasks`, `_closed`). Hot-path classes always use `__slots__`.

## `Protocol` (PEP 544) for structural typing

Python's analog to Go's implicit interface satisfaction. Use `Protocol` for caller-supplied callbacks, pluggable strategies, and any "duck-typed" interface that the SDK consumes but doesn't implement.

```python
# sdk/auth.py
from __future__ import annotations
from typing import Protocol, runtime_checkable


@runtime_checkable
class AuthProvider(Protocol):
    """Caller-supplied credential source. Implement either sync or async."""

    async def fetch_token(self) -> str:
        """Return a fresh bearer token. Called on every request that needs auth."""
        ...
```

`@runtime_checkable` enables `isinstance(obj, AuthProvider)` — use sparingly (it's slower than nominal `isinstance`), but it makes test doubles and Mode-C compat checks cleaner.

## Composition over multi-inheritance

MRO surprises in deep multi-inheritance trees produce silent bugs (cooperative `__init__` chains, attribute shadowing). For SDK clients: one base class at most, compose helpers as fields.

```python
# GOOD — composition
class Client:
    def __init__(self, ..., breaker: CircuitBreaker, retrier: Retrier) -> None:
        self._breaker = breaker
        self._retrier = retrier

# AVOID — multi-inheritance
class Client(CircuitBreakerMixin, RetrierMixin, BaseClient):  # MRO surprise risk
    pass
```

## Type hints — every public symbol

Every public function/method has full type annotations. Use `from __future__ import annotations` (PEP 563) at module top for forward references and to keep annotations as strings (faster import). Run `mypy --strict` in CI.

```python
from __future__ import annotations  # MUST — every SDK module top
from collections.abc import Sequence
from typing import TYPE_CHECKING

if TYPE_CHECKING:  # import-time-free type hints
    from .config import Config


def batch_get(client: Client, keys: Sequence[str]) -> dict[str, bytes]:
    ...
```

## `__slots__` — hot-path memory + speed

Without `__slots__`, every instance carries a `__dict__` (~280 bytes baseline + per-attr overhead). With `__slots__`, attributes are stored in a fixed-size C array — typically halves memory for small objects and gives measurable attribute access speedup. Rule: **any class that may exist in instance counts >1000 in the hot path declares `__slots__`**. `@dataclass(slots=True)` (3.10+) generates `__slots__` automatically; subclasses must also opt in or they re-introduce `__dict__`.

## Pitfalls

1. **Mutable default argument** — `def f(x: list = []):` shares the list across every call. Same trap in dataclass: `field(default=[])` is forbidden; use `field(default_factory=list)`. The dataclass machinery raises `ValueError` on mutable defaults, but only for the four built-in types it knows about.
2. **Missing `__slots__` on hot-path types** — every instance carries 280+ bytes of `__dict__` overhead. A request-shaped object allocated 100k/sec on a hot path is 28 MB/s of avoidable allocation pressure.
3. **Exposing internal state via `__dict__`** — defeats `__slots__`, defeats `frozen=True` (callers can mutate `__dict__` directly). With `__slots__` declared, `__dict__` is gone — enforced.
4. **Ad-hoc validation scattered across methods** rather than `__post_init__` — invalid configs are caught at first I/O, not at construction. Move every invariant check into `__post_init__`.
5. **Mixing `@dataclass` and manual `__init__`** — defining `__init__` inside a `@dataclass` overrides the generated one and silently breaks `frozen`, `field(default_factory=...)`, and `__post_init__`. Pick one.
6. **`@dataclass(frozen=True)` without `slots=True`** — frozen prevents the *intended* path of mutation but `obj.__dict__["x"] = ...` still works. Slots closes that gap.
7. **`Protocol` without `@runtime_checkable` when you need `isinstance`** — `isinstance(obj, MyProtocol)` raises `TypeError` unless decorated. Static type-checking works either way.
8. **Constructing `Client` directly instead of via `new_client`** — bypasses Config validation and any side-effecting setup. Make `Client.__init__` accept already-built dependencies; the factory is the only blessed path for callers.

## References

- PEP 557 — Data Classes
- PEP 526 — Variable Annotations
- PEP 544 — Protocols: Structural subtyping
- PEP 484 — Type Hints
- PEP 563 — Postponed Evaluation of Annotations (`from __future__ import annotations`)
- PEP 695 — Type Parameter Syntax (3.12+; for generic SDK base classes)
- Cross-skill: `python-asyncio-patterns` — task storage on the Client; `asyncio-cancellation-patterns` — `close(ctx)` shape
