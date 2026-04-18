---
name: miniredis-testing-patterns
version: 0.1.0-draft
status: candidate
priority: MUST
tags: [testing, redis, dragonfly, miniredis, unit-test]
target_consumers: [sdk-testing-lead, sdk-impl-lead]
provenance: synthesized-from-tprd(sdk-dragonfly-s2, §11.1)
---

# miniredis-testing-patterns

## When to apply
Unit testing any `go-redis/v9` or Dragonfly client — to avoid test-container overhead in the fast tier.

## Core prescriptions

### 1. Per-test instance, always
```go
func newTestCache(t *testing.T) (*dragonfly.Cache, *miniredis.Miniredis) {
    t.Helper()
    mr := miniredis.RunT(t)   // RunT auto-closes on t.Cleanup
    c, err := dragonfly.New(dragonfly.WithAddr(mr.Addr()))
    if err != nil { t.Fatalf("New: %v", err) }
    t.Cleanup(func() { _ = c.Close() })
    return c, mr
}
```

Never share a miniredis across tests. `RunT` (not `Run`) ensures cleanup + isolates state.

### 2. Feature gaps — know what miniredis/v2 does NOT support

Verified as of miniredis/v2 latest (2026):

| Feature | miniredis v2 support | Fallback |
|---|---|---|
| Strings (GET/SET/INCR/MSET...) | full | — |
| Hashes (HGET/HSET/HDEL...) | full | — |
| **HEXPIRE family (hash-field TTL)** | **partial / version-dependent** | testcontainers (S7) |
| Pipeline | full (non-atomic) | — |
| Transactions (WATCH/MULTI/EXEC) | partial — WATCH semantics simplified | testcontainers for race cases |
| Pub/Sub | basic publish/subscribe | — |
| **Lua (EVAL/EVALSHA)** | **very limited — no redis.call side effects reliably** | testcontainers |
| SCRIPT LOAD / EXISTS | basic | — |
| RESP3 | no | testcontainers / defer to P1 |
| CLIENT TRACKING | no | not in P0 scope |
| TLS | no | testcontainers |
| ACL (AUTH user+pass) | partial (accepts any) | testcontainers for auth-rejection |

Rule: when a test depends on a "partial" or "no" feature, SKIP it at the unit tier with `t.Skip("requires real Dragonfly — see integration test")` and ensure coverage exists in S7 integration tests.

### 3. Time control — use `mr.FastForward`
For TTL tests, never `time.Sleep`. Use `mr.FastForward(ttl + time.Millisecond)`. Deterministic and fast.

```go
err := c.Set(ctx, "k", "v", 2*time.Second)
mr.FastForward(3 * time.Second)
_, err = c.Get(ctx, "k")
require.ErrorIs(t, err, dragonfly.ErrNil)
```

### 4. Error injection
- `mr.SetError("ERR intentional")` makes the NEXT command fail. One-shot.
- For closed-client tests: call `c.Close()` first, then the op → expect `ErrNotConnected`.
- For timeout tests: use `ctx` with `context.WithTimeout(ctx, 0)` — expects `ErrTimeout` without touching miniredis.

### 5. Address pool pitfalls
miniredis runs on a random port; `cfg.PoolSize` should stay small (4–8) in unit tests to avoid noise. Default SDK `PoolSize=10` is fine; only tune down in leak-sensitive tests.

### 6. Assertion style — state-based, not mock-based
Prefer verifying state via `mr.Exists("k")`, `mr.Get("k")`, `mr.HGet("h","f")` over mocking go-redis. miniredis IS the mock.

### 7. Fuzz harness compatibility
`FuzzMapErr` does not need miniredis — pure function. `FuzzKeyEncoding` should use miniredis but with `mr.FlushAll()` between iterations.

## Test-pyramid slotting

- Unit (this tier, miniredis): ~70% of assertions — happy path + basic error classification.
- Integration (testcontainers, S7): ~25% — HEXPIRE real codes, TLS/ACL, WATCH race, Lua side-effects, chaos.
- Benchmark: 5% — real latency only meaningful vs real Dragonfly.

## Anti-patterns
- Sharing one miniredis across the whole package (use `RunT` per test).
- Using `time.Sleep` in TTL tests instead of `FastForward`.
- Trying to assert HEXPIRE return codes precisely on miniredis (wire parity not guaranteed).
- Hand-rolling a mock `redis.Cmdable` interface — use miniredis or real go-redis.

## References
TPRD §11.1, §14 (risks).
miniredis/v2 README & CHANGELOG.
