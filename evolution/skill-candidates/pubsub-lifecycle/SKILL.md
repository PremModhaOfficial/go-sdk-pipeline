---
name: pubsub-lifecycle
version: 0.1.0-draft
status: candidate
priority: MUST
tags: [redis, dragonfly, pubsub, goroutine-leak, shutdown]
target_consumers: [sdk-impl-lead, sdk-leak-hunter, sdk-testing-lead]
provenance: synthesized-from-tprd(sdk-dragonfly-s2, §5.5, §7)
---

# pubsub-lifecycle

## When to apply
Any SDK method returning `*redis.PubSub` or owning a background subscriber goroutine.

## TPRD surface (§5.5)
```go
Publish(ctx, channel, message string) (int64, error)
Subscribe(ctx, channels ...string) *redis.PubSub
PSubscribe(ctx, patterns ...string) *redis.PubSub
```

## Core prescriptions

### 1. Ownership transfer on return
`Subscribe` / `PSubscribe` return `*redis.PubSub`. Ownership TRANSFERS to the caller. SDK does NOT track them. Caller MUST call `ps.Close()` to release pool connection and stop the receive goroutine inside go-redis.

Godoc wording: "Caller owns the returned *redis.PubSub and MUST Close it when done. Failure to Close leaks one go-redis goroutine and one pooled connection per call."

### 2. Ping context on methods that accept it
`Subscribe` takes `ctx` — used only for the SUBSCRIBE command itself. The long-lived receive stream (`ps.Channel()` / `ps.Receive()`) has its OWN lifecycle — ctx cancellation does NOT auto-close the PubSub. This is a go-redis design; document it.

### 3. Cache.Close() behavior with live PubSubs
When `Cache.Close()` is called while PubSubs are still alive:
- Outstanding PubSubs receive `redis.ErrClosed` on next Receive.
- `mapErr` surfaces this as `ErrNotConnected`. Callers using `*redis.PubSub` directly see raw `redis.ErrClosed` — document.
- Pending `ps.Close()` from callers is safe post-Cache-Close (idempotent).

### 4. ErrSubscriberClosed
Reserved for future when SDK introduces a wrapped subscriber that owns a goroutine. P0 does NOT introduce that wrapper — `ErrSubscriberClosed` exists in the sentinel catalog for forward compat; do NOT return it in S5.

### 5. Goroutine leak prevention (S5 test contract)
Every pub/sub test MUST:
- `defer ps.Close()`.
- `defer goleak.VerifyNone(t)` (via `goleak.VerifyTestMain` in TestMain) — already SDK policy.
- Any test that publishes but never subscribes must NOT spawn a goroutine on the SDK side.

### 6. Backpressure
`ps.Channel()` buffered internally (go-redis default 100). Under slow-consumer: messages dropped per go-redis behavior, NOT blocked. Document, do not override.

### 7. Publish is synchronous
`Publish` returns the receiver count (`int64`). Zero receivers is NOT an error. Do NOT classify `0` as failure in metrics.

### 8. Metrics
- `cmd=publish` — request/error/duration.
- `cmd=subscribe` — request on call (subscribe ack), no error-on-zero-msgs.
- DO NOT meter per-received-message — caller's concern; cardinality risk.

## Test matrix (S5)
- Publish with no subscribers → (0, nil).
- Subscribe + Publish → message roundtrip via `ps.Channel()`.
- Subscribe + Cache.Close() → next Receive returns `redis.ErrClosed`.
- PSubscribe + pattern match.
- Leak test: 100× Subscribe+Close cycle under goleak.

## Anti-patterns
- Tracking `*redis.PubSub` inside Cache for auto-close — breaks TPRD "expose directly" principle.
- Buffering message channel inside SDK — unnecessary wrapper.
- Treating zero-receiver Publish as error.
- Exposing a `SubscribeCh(ctx) <-chan Msg` helper — postpone to v2.

## References
TPRD §5.5, §7 (ErrSubscriberClosed reserved), §11 (leak discipline).
go-redis/v9 `PubSub` godoc.
