---
name: network-error-classification
description: >
  Use this when an SDK client returns errors from a wire call and callers need
  to know whether to retry, fail-fast, or re-auth — building the sentinel
  taxonomy (retriable / fatal / auth-failure), the mapErr precedence ladder,
  and wrapping with %w (Go) or `raise … from` (Python). Cross-language.
  Triggers: errors.Is, errors.As, fmt.Errorf %w, sentinel, ErrTimeout, ErrAuth, ErrUnavailable, net.Error, tls.CertificateVerificationError, mapErr, raise from, PoolError, PoolTimeout, asyncio.TimeoutError.
---

# network-error-classification (v1.1.0)

> **Cross-language status**: this skill targets BOTH Go and Python clients.
> Go examples in the original body (sections "GOOD examples" 1–3, "BAD
> examples" 1–3) are **Go-specific** — they use `errors.New`, `fmt.Errorf %w`,
> `errors.Is/As`, `net.Error`, `tls.CertificateVerificationError`. The
> Python equivalents live in the new "GOOD examples — Python" section below;
> the conceptual rules (sentinel taxonomy, precedence, classification table)
> are language-neutral.

## Rationale

Every SDK client returns errors from a wire call. Callers need to know, from
the error alone, whether to: **retry** (transient), **fail-fast** (fatal /
programmer error), or **re-auth** (credentials no longer valid). Without a
taxonomy, callers string-match on `err.Error()` — fragile, breaks on dependency
upgrades.

The SDK commits to a **sentinel-based** model at minimum three classes:

1. **Retriable / transient** — `ErrTimeout`, `ErrUnavailable`, `ErrPoolExhausted`, `ErrPoolClosed`. Safe to retry with backoff (subject to idempotency).
2. **Fatal / permanent** — `ErrInvalidConfig`, `ErrWrongType`, `ErrSyntax`, `ErrOutOfRange`, `ErrNotConnected`. Retrying is useless; the caller or the data is wrong.
3. **Auth-failure** — `ErrAuth`, `ErrNoPerm`, `ErrTLS`. Retrying won't help; the caller must rotate credentials / fix cert chain.

Classification happens at the adapter boundary via a `mapErr(err) error`
helper. It wraps every return value through `fmt.Errorf("%w: %v", sentinel,
err)` so `errors.Is(err, ErrTimeout)` works AND the original message survives
for logs.

CLAUDE.md rule 6 demands this: sentinel errors, wrapping via `%w`,
`errors.Is` matchable. The target SDK's `dragonfly` package freezes a 17-set
of sentinels in TPRD §7 — adding/removing is a semver-major break.

## Activation signals

- New client returns errors from a remote server
- TPRD §Skills-Manifest lists `network-error-classification`
- Design review flags "string-match on err" or "no retry hint"
- `sdk-convention-devil` requires sentinel taxonomy
- Reviewer asks "how does the caller know to retry?"

## GOOD examples

### 1. Sentinel catalog — `errors.New` at package scope

From `core/l2cache/dragonfly/errors.go`:

```go
var (
    // Retriable
    ErrTimeout       = errors.New("dragonfly: timeout")
    ErrUnavailable   = errors.New("dragonfly: unavailable")
    ErrPoolExhausted = errors.New("dragonfly: pool exhausted")
    ErrPoolClosed    = errors.New("dragonfly: pool closed")

    // Fatal
    ErrInvalidConfig = errors.New("dragonfly: invalid config")
    ErrNotConnected  = errors.New("dragonfly: not connected")
    ErrWrongType     = errors.New("dragonfly: wrong type")
    ErrSyntax        = errors.New("dragonfly: syntax error")
    ErrOutOfRange    = errors.New("dragonfly: value out of range")
    ErrCanceled      = errors.New("dragonfly: canceled")
    ErrNil           = errors.New("dragonfly: key not found")

    // Auth-failure
    ErrAuth   = errors.New("dragonfly: auth failed")
    ErrNoPerm = errors.New("dragonfly: no perm")
    ErrTLS    = errors.New("dragonfly: tls failure")
)
```

### 2. Central `mapErr` with precedence and `errors.As` for typed errors

From `core/l2cache/dragonfly/errors.go` — precedence-sensitive, typed checks
before string scans:

```go
func mapErr(err error) error {
    if err == nil { return nil }

    // 1. Passthrough if caller already wrapped with our sentinel.
    if errors.Is(err, ErrNil) || errors.Is(err, ErrTimeout) /* ... */ {
        return err
    }

    // 2. Stdlib sentinels.
    switch {
    case errors.Is(err, context.Canceled):
        return fmt.Errorf("%w: %v", ErrCanceled, err)
    case errors.Is(err, context.DeadlineExceeded):
        return fmt.Errorf("%w: %v", ErrTimeout, err)
    }

    // 3. net.Error.Timeout() — typed via errors.As.
    var ne net.Error
    if errors.As(err, &ne) && ne.Timeout() {
        return fmt.Errorf("%w: %v", ErrTimeout, err)
    }

    // 4. TLS identity — typed errors.As, NOT string match.
    var certErr *tls.CertificateVerificationError
    if errors.As(err, &certErr) {
        return fmt.Errorf("%w: %v", ErrTLS, err)
    }
    var x509Err x509.UnknownAuthorityError
    if errors.As(err, &x509Err) {
        return fmt.Errorf("%w: %v", ErrTLS, err)
    }

    // 5. Last-resort string prefix scan on server-returned wire errors.
    msg := err.Error()
    switch {
    case strings.HasPrefix(msg, "WRONGPASS"), strings.HasPrefix(msg, "NOAUTH"):
        return fmt.Errorf("%w: %v", ErrAuth, err)
    case strings.HasPrefix(msg, "NOPERM"):
        return fmt.Errorf("%w: %v", ErrNoPerm, err)
    case strings.HasPrefix(msg, "WRONGTYPE"):
        return fmt.Errorf("%w: %v", ErrWrongType, err)
    }

    // 6. Fallback.
    return fmt.Errorf("%w: %v", ErrUnavailable, err)
}
```

### 3. Caller-side dispatch via `errors.Is`

```go
func fetch(ctx context.Context, cache *dragonfly.Cache, key string) ([]byte, error) {
    val, err := cache.Get(ctx, key)
    switch {
    case err == nil:
        return val, nil
    case errors.Is(err, dragonfly.ErrNil):
        return nil, nil // miss
    case errors.Is(err, dragonfly.ErrTimeout),
         errors.Is(err, dragonfly.ErrUnavailable),
         errors.Is(err, dragonfly.ErrPoolExhausted):
        return retryWithBackoff(ctx, cache, key) // retriable
    case errors.Is(err, dragonfly.ErrAuth),
         errors.Is(err, dragonfly.ErrTLS):
        return nil, fmt.Errorf("credentials: %w", err) // re-auth, don't retry
    default:
        return nil, err // fatal; caller decides
    }
}
```

## GOOD examples — Python (added v1.1.0)

Python has no `errors.Is`/`%w`. The equivalent identity is **exception class
hierarchy + `raise … from <user_exc>`**: `isinstance(e, PoolTimeout)` is the
analog of `errors.Is(err, ErrTimeout)`; `raise PoolTimeout(...) from
asyncio_te` chains the underlying cause via `__cause__` (preserved across
formatters and tracebacks).

### P1. Sentinel hierarchy — `class` at module scope

From `motadatapysdk/resourcepool/errors.py` (sdk-resourcepool-py-pilot-v1):

```python
class PoolError(Exception):
    """Root sentinel for all resourcepool errors. Callers may except this
    to catch every pool-originated failure regardless of class."""

# Retriable (transient)
class PoolTimeout(PoolError):
    """Acquire deadline exceeded; safe to retry with backoff."""

class PoolExhausted(PoolError):
    """Pool at capacity AND queue at limit; safe to retry with backoff."""

# Fatal (caller / config bug)
class PoolClosed(PoolError):
    """close() already called; retrying is useless — pool is permanent-dead."""

class PoolConfigError(PoolError, ValueError):
    """min_size > max_size, negative timeout, etc. — caller must fix config."""
```

Inheriting from `PoolError` lets callers catch the whole family with one
`except PoolError`. Inheriting `PoolConfigError` from `ValueError` follows
the Python convention that "bad argument" errors share the stdlib
hierarchy (analogous to Go embedding sentinels in a struct error).

### P2. Mapping foreign exceptions — `raise … from <user_exc>` (the `%w` analog)

Wherever the pool catches an `asyncio.TimeoutError` or any third-party
async-cancel exception and translates it to a sentinel, the original MUST
be chained via `from`. This preserves `__cause__` so loggers, sentry, and
`traceback.format_exception` see the full chain — exactly what `%w` gives
Go:

```python
import asyncio

async def acquire(self, timeout: float) -> Resource:
    try:
        return await asyncio.wait_for(self._waiters.get(), timeout=timeout)
    except asyncio.TimeoutError as te:
        # GOOD: classify into sentinel + chain the cause
        raise PoolTimeout(
            f"acquire deadline exceeded after {timeout:.3f}s"
        ) from te
    except asyncio.CancelledError:
        # CancelledError MUST propagate untranslated. Wrapping it breaks
        # cooperative cancellation (the event loop will not see it).
        raise
```

Three rules:

1. **`from <orig>`** is mandatory on every translation. `raise PoolTimeout(...)`
   without `from` orphans the cause; `raise PoolTimeout(...) from None`
   is allowed only when the original is genuinely irrelevant (rare).
2. **Never wrap `asyncio.CancelledError`** — re-raise as-is. Python 3.8+
   treats it as a `BaseException`, not `Exception`, precisely so naive
   `except Exception` doesn't swallow cancellation. Wrapping it into a
   sentinel breaks cooperative shutdown.
3. **Never use a bare `except:`** in classification code. `except Exception`
   is the maximum width; `except <SpecificType>` is preferred.

### P3. Caller-side dispatch via `isinstance` (the `errors.Is` analog)

```python
async def fetch(pool: ResourcePool, key: str) -> bytes | None:
    try:
        async with pool.acquire(timeout=5.0) as conn:
            return await conn.get(key)
    except PoolTimeout:
        # transient — retry with backoff
        return await retry_with_backoff(pool, key)
    except PoolExhausted:
        # transient — retry with backoff
        return await retry_with_backoff(pool, key)
    except PoolClosed:
        # fatal — pool is dead, propagate
        raise
    except PoolConfigError:
        # fatal — caller bug
        raise
```

Or grouped via parent class:

```python
try:
    ...
except (PoolTimeout, PoolExhausted) as e:
    # any retriable family member
    return await retry_with_backoff(...)
except PoolError as e:
    # any non-retriable pool error
    log.error("pool failure", exc_info=e)
    raise
```

### P4. Closes a generalization-debt entry

This section was added per `shared-core.json` `generalization_debt` entry
flagging this skill as Go-only. The Python `PoolError` hierarchy +
`raise … from` chaining is the documented Python equivalent of every Go
construct in §1–§3 above. The `mapErr` precedence ladder (§2) translates
to a chain of `try / except` blocks in the same precedence order
(self-sentinel passthrough → stdlib mapping → typed exception isinstance →
last-resort string/code scan); see `motadatapysdk/resourcepool/errors.py`
for the live reference.

## BAD examples

### 1. `%v` instead of `%w` — breaks `errors.Is`

```go
// BAD: caller's errors.Is(err, ErrTimeout) will be false.
return fmt.Errorf("%s: %v", ErrTimeout, err) // %w required
```

### 2. Ad-hoc error types per call site

```go
// BAD: every adapter defines its own error type; callers can't compose.
type GetError struct{ Cause error }
type SetError struct{ Cause error }
// ... no shared taxonomy; retry logic can't generalise.
```

### 3. String matching the message

```go
// BAD: fragile on go-redis minor upgrade; misses wrapped errors.
if strings.Contains(err.Error(), "connection refused") {
    // retry
}
```

Fix: wrap into `ErrUnavailable` in `mapErr`, then caller uses `errors.Is`.

## BAD examples — Python (added v1.1.0)

### P-BAD-1. Translation without `from` — orphans the cause

```python
# BAD: __cause__ is None; the original asyncio.TimeoutError is lost.
try:
    await asyncio.wait_for(fut, timeout=t)
except asyncio.TimeoutError:
    raise PoolTimeout("acquire deadline exceeded")  # missing `from te`
```

Fix: always `raise PoolTimeout(...) from te`.

### P-BAD-2. Catching and wrapping `asyncio.CancelledError`

```python
# BAD: cancellation is swallowed; downstream tasks won't see the cancel.
try:
    await coro
except asyncio.CancelledError as ce:
    raise PoolError("operation cancelled") from ce  # WRONG
```

Fix: do not catch `CancelledError` at the classification boundary. Let it
propagate. (Catch only at the trust boundary that owns lifecycle.)

### P-BAD-3. String-matching `str(exc)` instead of class hierarchy

```python
# BAD: brittle; breaks on asyncio version bumps that reword the message.
except asyncio.TimeoutError as e:
    if "timeout" in str(e).lower():
        raise PoolTimeout(...) from e
```

Fix: catch the exception type directly. The class IS the classification.

## Decision criteria

| Category | Default sentinel | Retry? |
|---|---|---|
| `context.DeadlineExceeded` | `ErrTimeout` | Yes, fresh context |
| `context.Canceled` | `ErrCanceled` | No — caller asked to stop |
| `net.Error` with `Timeout() == true` | `ErrTimeout` | Yes |
| `tls.CertificateVerificationError` | `ErrTLS` | No — rotate creds / fix chain |
| `x509.UnknownAuthorityError` | `ErrTLS` | No |
| Server "WRONGPASS" / "NOAUTH" | `ErrAuth` | No — reauth |
| Server "NOPERM" | `ErrNoPerm` | No — fix ACL |
| Server "WRONGTYPE" | `ErrWrongType` | No — fix caller |
| Pool timeout | `ErrPoolExhausted` | Yes — backoff |
| Closed pool | `ErrPoolClosed` | No — client closed |
| Unclassified wire error | `ErrUnavailable` | Yes, with caution |
| Config validation | `ErrInvalidConfig` | No |
| **Python: `asyncio.TimeoutError`** | `PoolTimeout` (chain via `from`) | Yes — caller's deadline; allow retry with fresh budget |
| **Python: `asyncio.CancelledError`** | DO NOT translate — re-raise | No — cooperative cancellation; never wrap |
| **Python: pool full + queue full** | `PoolExhausted` | Yes — backoff |
| **Python: pool already closed** | `PoolClosed` | No — terminal state |
| **Python: bad config (e.g. min>max)** | `PoolConfigError` (also `ValueError`) | No — caller bug |

Precedence rules:

1. **Check sentinel identity before message string.** `errors.Is` on our own sentinels short-circuits double-wrapping.
2. **Use `errors.As` for typed stdlib errors** (`net.Error`, `*tls.CertificateVerificationError`, `x509.UnknownAuthorityError`). Never rely on `strings.Contains("tls:")` alone.
3. **String scan is LAST.** Server wire-protocol strings ("WRONGPASS") only checked after typed checks fail.
4. **Sentinel set is semver-public.** Adding is minor; removing or renaming is major. Document the set in the package godoc.

### Python-specific precedence addenda (added v1.1.0)

5. **Class-hierarchy check before string check.** `isinstance(e, PoolTimeout)`
   is the canonical Python equivalent of Go's `errors.Is(err, ErrTimeout)`.
   Use it; never `if "timeout" in str(e)`.
6. **`raise … from <cause>` is mandatory** on every translation. Bare
   `raise SentinelClass(...)` orphans `__cause__`.
7. **`asyncio.CancelledError` is sacred** — never catch-and-wrap at the
   classification boundary. `BaseException` lineage in 3.8+ exists for this.

## Cross-references

- `go-error-handling-patterns` — `fmt.Errorf %w` chain, sentinel definition (Go-specific)
- `python-class-design` — sentinel class hierarchy + `__init__` validation patterns (Python-specific; pairs with §P1)
- `python-asyncio-patterns` — `CancelledError` propagation rules + `asyncio.TimeoutError` semantics (Python-specific; pairs with §P2)
- `idempotent-retry-safety` — which ops are safe to retry on a retriable sentinel (language-neutral)
- `client-rate-limiting` — 429 / `Retry-After` plumbs into retry decision (language-neutral)
- `client-tls-configuration` — `ErrTLS` sentinel pairing (Go-specific)
- `credential-provider-pattern` — `ErrAuth` triggers provider refresh (Go-specific)

## Guardrail hooks

- **G38.sh** family — sentinel error presence + precedence order in `mapErr`
- **G48.sh** — no `init()`; sentinels are package-level `var`, not registered in init
- **G98/G99** — every sentinel + `mapErr` symbol carries `[traces-to:]` marker
- Devil: `sdk-convention-devil` — rejects custom error struct when sentinel would suffice; `sdk-security-devil` — rejects PII in wrapped error messages
