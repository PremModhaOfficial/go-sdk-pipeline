---
name: idempotent-retry-safety
description: >
  Use this when designing retry behaviour for an SDK method that causes a
  side effect — picking the IsRetryable predicate, requiring an idempotency
  envelope (Idempotency-Key header, MessageID, upsert key) before any retry
  is legal, and capping attempts with jittered exponential backoff.
  Triggers: retry, backoff, jitter, idempotent, at-least-once, exactly-once, IsRetryable, MaxAttempts, MessageID, dedup.
---

# idempotent-retry-safety (v1.0.0)

## Rationale

A retry that isn't proved idempotent is a correctness bug, not a resilience feature. Duplicated side effects (double-charge, double-publish, double-insert) are far worse than the transient failure the retry was meant to mask. Retry safety rests on three legs: (1) a predicate that only retries errors whose causes admit repetition (transient, not permanent), (2) an idempotency envelope (message ID, upsert key, request ID) so the receiver can dedupe, (3) capped exponential backoff with jitter so a dependency recovery window isn't clobbered by a thundering herd. HTTP idempotency (safe verbs — GET/PUT/DELETE are idempotent by contract; POST is not without an `Idempotency-Key` header) is a special case of this principle. The target SDK ships `events/middleware/retry.go` + `events/utils.IsRetryable` — reuse both.

## Activation signals

- A method causes a side effect (publish, write, mutation) and the TPRD requests retry
- An error taxonomy is being designed and you need to decide which errors are retriable
- A publisher/client is getting `MaxAttempts`/`MaxRetries` config options
- Integration tests observe duplicate deliveries or double-processing
- HTTP client work: deciding whether POST/PATCH can retry on 502/503
- Reviewer cites "retries on non-idempotent op" or "no jitter → thundering herd"

## GOOD examples

### GOOD 1: SDK retry predicate — sentinel-based, err-as-value

Source: `motadatagosdk/events/utils/errors.go`. Permissive default (unknown → retriable), but deterministic failures (invalid input, config, permission, dup-message, shutdown, closed connection) explicitly opt OUT. `errors.As` handles wrapped typed errors.

```go
func IsRetryable(err error) bool {
    if err == nil { return false }
    switch {
    case errors.Is(err, ErrInvalidSubject),
        errors.Is(err, ErrInvalidMessage),
        errors.Is(err, ErrInvalidConfig),
        errors.Is(err, ErrSerializationFailed),
        errors.Is(err, ErrPermissionDenied),
        errors.Is(err, ErrDuplicateMsg),       // already dedup'd — retry = double-effect
        errors.Is(err, ErrShutdownInProgress),
        errors.Is(err, ErrConnectionClosed):
        return false
    }
    var serErr SerializationError
    if errors.As(err, &serErr) { return false }
    var cfgErr ConfigError
    if errors.As(err, &cfgErr) { return false }
    return true
}
```

### GOOD 2: Exponential backoff with jitter, context-aware wait

Source: `motadatagosdk/events/middleware/retry.go`. Formula: `base = Initial * Multiplier^N`, cap at `MaxInterval`, jitter = `cap * Jitter * rand(-1,1)`, floor at `Initial`. Uses `crypto/rand` (goroutine-safe, no mutex) — and crucially, the wait uses `select` on `ctx.Done()` so a cancelled context aborts immediately instead of sleeping through the deadline.

```go
func (r *RetryMiddleware) executeWithRetry(ctx context.Context, msg *nats.Msg, next PublishHandler) error {
    var lastErr error
    for attempt := 0; attempt <= r.config.MaxAttempts; attempt++ {
        if err := ctx.Err(); err != nil { return firstNonNil(lastErr, err) }
        if err := next(ctx, msg); err == nil { return nil } else { lastErr = err }
        if !r.shouldRetry(lastErr) || attempt >= r.config.MaxAttempts { return lastErr }
        if r.waitBackoff(ctx, attempt) != nil { return lastErr } // ctx cancel aborts sleep
    }
    return lastErr
}

func (r *RetryMiddleware) waitBackoff(ctx context.Context, attempt int) error {
    select {
    case <-ctx.Done():                    return ctx.Err()
    case <-time.After(r.calculateBackoff(attempt)): return nil
    }
}
```

### GOOD 3: Idempotency envelope — the receiver can dedupe before retry matters

Source: `motadatagosdk/events/jetstream/publisher.go` (`buildAsyncHandler`). When `msg.Header` carries `HeaderMessageID`, it flows to JetStream as `natsjs.WithMsgID(msgID)`. JetStream's server-side dedup window collapses a duplicate publish into one stored message — so even if the client retries, the receiver sees one event.

```go
var opts []natsjs.PublishOpt
if msg.Header != nil {
    if msgID := msg.Header.Get(core.HeaderMessageID); msgID != "" {
        opts = append(opts, natsjs.WithMsgID(msgID)) // server dedup key
    }
}
ack, err := p.js.PublishMsg(ctx, msg, opts...)
```

**HTTP equivalent**: GET/PUT/DELETE are idempotent by HTTP contract (RFC 9110 §9.2.2) — retry freely on transport errors. POST/PATCH need a caller-generated `Idempotency-Key` header; without it, retry on 5xx is unsafe.

## BAD examples (anti-patterns)

### BAD 1: Retrying a non-idempotent op with no envelope

```go
// BAD: POST with no Idempotency-Key, retries on 502. Every retry may
// have actually reached the server; the response was lost in transit.
// Result: double-billing.
for attempt := 0; attempt < 3; attempt++ {
    resp, err := http.Post(url, "application/json", body)
    if err == nil && resp.StatusCode < 500 { break }
    time.Sleep(time.Second)
}
```
Breaks: the caller doesn't know whether the server committed the op. Fix: add an `Idempotency-Key` header the server deduplicates on, OR switch to PUT with a deterministic path, OR treat 5xx-on-POST as permanent failure.

### BAD 2: Backoff without jitter

```go
// BAD: N clients hit the same dependency, all see the 503 in the same
// millisecond, all back off for exactly 1s, all retry in lockstep.
// The dependency comes up and gets immediately clobbered.
time.Sleep(time.Duration(attempt) * time.Second)
```
Breaks: thundering herd. Fix: follow `retry.go`'s `calculateBackoff` — `capped + jitter * rand(-1,1)` with `Jitter = 0.1` (±10%) as baseline.

### BAD 3: `shouldRetry` that returns `true` on context cancellation

```go
// BAD: ctx was cancelled by the caller (deadline, shutdown). Retrying
// means we're about to do work the caller no longer wants.
func shouldRetry(err error) bool { return err != nil }
```
Breaks: wastes resources, can mask a deadline-exceeded into a ResourceExhausted. Fix: either check `ctx.Err()` before each attempt (as GOOD 2 does) OR encode cancellation into the predicate (`errors.Is(err, context.Canceled) → false`).

### BAD 4: Blocking sleep inside a retry loop

```go
// BAD: time.Sleep ignores context. If the caller cancels mid-sleep,
// the goroutine blocks to completion. Leak hazard under shutdown.
time.Sleep(backoff)
```
Breaks: `goroutine-leak-prevention` violation. Fix: use `select { case <-ctx.Done(): ...; case <-time.After(backoff): ... }` as in GOOD 2.

## Decision criteria

| Situation | Retry? | Notes |
|---|---|---|
| GET / idempotent query returned 503 | YES | Safe — no side effect |
| PUT / upsert with deterministic key returned 503 | YES | Key dedupes server-side |
| POST without idempotency key returned 502 | NO | Cannot prove request didn't commit |
| POST with `Idempotency-Key` header returned 502 | YES | Server-side dedup makes retry safe |
| Publish with `HeaderMessageID` returned transient error | YES | JetStream dedup window handles it |
| `errors.Is(err, ErrDuplicateMsg)` | NO | Already delivered; retry = bug |
| `errors.Is(err, ErrInvalidConfig)` | NO | Deterministic failure; retrying = same result |
| Any `ctx.Err() != nil` | NO | Caller no longer wants the op |

**Tuning**: baseline `MaxAttempts=3`, `Initial=100ms`, `Multiplier=2.0`, `Max=5s`, `Jitter=0.1`. Raise `MaxAttempts` only for long-deadline batch ops; never raise `Max` above the caller's likely context timeout.

**Community note on `cenkalti/backoff`**: the Go community's common retry library. Equivalent API; if a TPRD specifies it, it's acceptable — but prefer the SDK's in-house `RetryMiddleware` when the client lives in `events/` so the error taxonomy stays coherent. `cenkalti/backoff.Permanent(err)` equals the SDK's `!IsRetryable(err)` short-circuit.

## Target SDK Convention

Current convention in motadatagosdk:
- `events/middleware/retry.go` for publish-side retries (composable middleware)
- `events/utils.IsRetryable(err)` as the default retry predicate
- `core/pool/workerpool.WithRetry(retries, delay)` for in-process task retries
- Dragonfly cache (`core/l2cache/dragonfly/`) deliberately ships with `MaxRetries=0` — retries are caller-composed via `RetryMiddleware`, not baked into the data-path call (see `cache.go` line 124 warning)

If TPRD requests divergence (in-client retry baked into the data path): declare in TPRD §5; `sdk-design-lead` records deviation; `sdk-impl-lead` uses the middleware composition pattern, NOT a new retry helper.

## Cross-references

- `go-circuit-breaker-policy` — breaker + retry are dual: breaker caps total attempts system-wide; retry caps attempts per call. The same error taxonomy (`IsRetryable` / `isCBFailure`) feeds both.
- `network-error-classification` — sentinel taxonomy (transient vs. permanent) every predicate reads.
- `go-context-deadline-patterns` — `executeWithRetry` MUST respect the caller's deadline; no retry may outlast `ctx.Deadline()`.
- `go-error-handling-patterns` — `errors.Is` / `errors.As` usage, wrapping rules.
- `go-otel-instrumentation` — emit a `retries_total` counter labelled by reason; the per-retry span links back to the parent.

## Guardrail hooks

- **G63** (goleak) — catches blocking-sleep retry loops that don't honor `ctx.Done()` (BAD 4).
- **G65** (bench regression) — retry fast-path (first attempt success) MUST not regress; regressions here usually mean a lock was added in the wrong scope.
- **G104** (alloc budget) — `IsRetryable` is called on every error; MUST be alloc-free (sentinel comparison only). Test this with `BenchmarkIsRetryable`.
- **G60 / integration flake-hunter** — if `sdk-integration-flake-hunter-go` catches a duplicate delivery under `-count=3`, the retry lacks an idempotency envelope (BAD 1).
