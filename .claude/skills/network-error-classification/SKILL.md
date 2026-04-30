---
name: network-error-classification
description: Classify wire errors into retriable / fatal / auth-failure sentinel classes; wrap with fmt.Errorf %w so errors.Is composes; typed errors.As for tls.CertificateVerificationError and net.Error.Timeout.
version: 1.0.0
status: stable
authored-in: v0.3.0-straighten
priority: MUST
tags: [error-handling, retry, network, sentinel, wrapping, errors-is, errors-as]
trigger-keywords: ["errors.Is", "errors.As", "fmt.Errorf %w", "sentinel", "ErrTimeout", "ErrAuth", "ErrUnavailable", "net.Error", "tls.CertificateVerificationError", "mapErr"]
---

# network-error-classification (v1.0.0)

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
- `sdk-convention-devil-go` requires sentinel taxonomy
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

Precedence rules:

1. **Check sentinel identity before message string.** `errors.Is` on our own sentinels short-circuits double-wrapping.
2. **Use `errors.As` for typed stdlib errors** (`net.Error`, `*tls.CertificateVerificationError`, `x509.UnknownAuthorityError`). Never rely on `strings.Contains("tls:")` alone.
3. **String scan is LAST.** Server wire-protocol strings ("WRONGPASS") only checked after typed checks fail.
4. **Sentinel set is semver-public.** Adding is minor; removing or renaming is major. Document the set in the package godoc.

## Cross-references

- `go-error-handling-patterns` — `fmt.Errorf %w` chain, sentinel definition
- `idempotent-retry-safety` — which ops are safe to retry on a retriable sentinel
- `go-client-rate-limiting` — 429 / `Retry-After` plumbs into retry decision
- `go-client-tls-configuration` — `ErrTLS` sentinel pairing
- `go-credential-provider-pattern` — `ErrAuth` triggers provider refresh

## Guardrail hooks

- **G38.sh** family — sentinel error presence + precedence order in `mapErr`
- **G48.sh** — no `init()`; sentinels are package-level `var`, not registered in init
- **G98/G99** — every sentinel + `mapErr` symbol carries `[traces-to:]` marker
- Devil: `sdk-convention-devil-go` — rejects custom error struct when sentinel would suffice; `sdk-security-devil` — rejects PII in wrapped error messages
