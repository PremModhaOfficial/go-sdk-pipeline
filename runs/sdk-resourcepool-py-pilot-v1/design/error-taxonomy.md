<!-- Generated: 2026-04-29T13:35:00Z | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 | Pack: python -->

# Error Taxonomy — `motadata_py_sdk.resourcepool`

Authored per `python-exception-patterns` skill. Catalog all exception types
the package raises and the contract caller-side `except` handlers should
target.

## Inheritance tree

```
Exception (Python builtin)
└── PoolError                    (package base)
    ├── PoolClosedError
    ├── PoolEmptyError
    ├── ConfigError
    └── ResourceCreationError    (PEP 3134 — wraps user hook exception)

asyncio.TimeoutError             (re-raised on bounded-wait expiry)
asyncio.CancelledError           (re-raised on task cancellation)

RuntimeError                     (raised on programming errors:
                                  double-release, AcquiredResource re-entry)
```

`PoolError` and descendants are **sentinel-style** — they carry no extra
fields beyond Exception's `args`. Callers test via `isinstance(e, PoolClosedError)`,
not via attribute inspection.

## When does each fire?

| Exception | Raised by | Condition | Caller action |
|---|---|---|---|
| `ConfigError` | `Pool.__init__` | `max_size <= 0` or `on_create is None` | Fix config; not retryable. |
| `ConfigError` | `Pool.try_acquire` | `on_create` is async | Use `acquire_resource` instead; not retryable. |
| `PoolClosedError` | `Pool.acquire`, `acquire_resource`, `try_acquire`, `release` | `aclose` already called | Stop using this pool; not retryable. |
| `PoolEmptyError` | `Pool.try_acquire` only | No idle slot AND `_in_use == _max_size` | Caller may retry / fall back to `acquire_resource(timeout=N)`. |
| `ResourceCreationError` | `Pool.acquire`, `acquire_resource` | User's `on_create` hook raised | Slot is freed; subsequent `acquire` will retry creation. `__cause__` is the user's original exception. Caller may retry. |
| `asyncio.TimeoutError` | `Pool.acquire`, `acquire_resource` | `timeout` elapsed | Caller may retry with longer timeout, or back off. |
| `asyncio.CancelledError` | `Pool.acquire`, `acquire_resource`, `release`, `aclose` | The awaiting task was cancelled | RE-RAISE (per `python-asyncio-leak-prevention` Rule 1). Never swallow. |
| `RuntimeError` | `AcquiredResource.__aenter__` | Re-entered after `__aexit__` | Bug; fix caller code. |
| `RuntimeError` | `Pool.release` | Same resource released twice | Bug; fix caller code. |

## Sentinel-style rationale

Per `python-exception-patterns` skill Rule 3 (Sentinel exceptions):
> "Prefer sentinel exception classes over message-string-matching."

Callers should write:
```python
try:
    async with pool.acquire(timeout=5) as r:
        ...
except PoolClosedError:
    return None        # service shutting down
except asyncio.TimeoutError:
    return await fallback()
except ResourceCreationError as e:
    log.warning("transient create failure: %s", e.__cause__)
    raise
```

Not:
```python
except PoolError as e:
    if "closed" in str(e):       # ANTI-PATTERN
        ...
```

## `ResourceCreationError` and PEP 3134 chaining

When the pool catches a user-hook exception, it MUST raise via:

```python
try:
    r = await config.on_create()
except BaseException as e:
    raise ResourceCreationError("on_create raised") from e
```

The `from e` uses PEP 3134 implicit chaining, setting `__cause__` so the
caller can drill into the original exception. We catch `BaseException`
(not `Exception`) for `KeyboardInterrupt` correctness in REPL contexts —
`asyncio.CancelledError` is re-raised separately so it does not get wrapped.

```python
try:
    r = await config.on_create()
except asyncio.CancelledError:
    raise                         # never wrap
except BaseException as e:
    raise ResourceCreationError("on_create raised") from e
```

## What we do NOT define

- **No `BackpressureError`** — pool is not a flow-control primitive
  (TPRD §3 Non-Goal).
- **No `RateLimitedError`** — separate concern (TPRD §3 Non-Goal).
- **No `CircuitOpenError`** — separate concern (TPRD §3 Non-Goal).
- **No subclass of `OSError`** — pool does not own file/socket lifecycle;
  caller's `on_create` does.
- **No custom `BaseException` subclass** — only `Exception` subclasses, so
  blanket `except Exception` in user code catches us correctly.

## TPRD §5.4 reconciliation

TPRD §5.4 enumerates 4 exception classes; this design adds a 5th:
`ResourceCreationError`. TPRD §7 also references "ResourceCreationError"
inline, so it's already understood — we lift it from inline note to first-class
exported symbol. `__all__` includes it; this is recorded as the only
TPRD-vs-design delta.

This delta is **not** a breaking change against TPRD intent (the section
already names the symbol); semver-devil ACCEPT 1.0.0 holds.
