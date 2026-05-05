<!-- Generated: 2026-04-18T06:40:00Z | Run: sdk-dragonfly-s2 -->
# concurrency-designer — D1 Summary

Output: `design/concurrency.md`.

## Goroutine inventory

1. **`poolStatsScraper.run`** (pipeline-authored) — 1 goroutine per `*Cache`. Done+stopped channels + `sync.Once`. Stopped BEFORE `rdb.Close()` in `(*Cache).Close()`.
2. **go-redis internal** — pool reaper + per-PubSub subscriber goroutines. Torn down by `rdb.Close()` / `ps.Close()`.

## PubSub leak story

- `Subscribe`/`PSubscribe` return raw `*redis.PubSub`.
- **Caller MUST call `ps.Close()`** — documented in godoc. No SDK-side wrapper.
- Rationale: wrapping would force us to proxy `.Channel()`/`.Receive()`/`.Ping()` and break TPRD "signatures mirror go-redis".

## Close ordering

```
(*Cache).Close():
  1. scraper.stop()      // close(done) + wait on <-stopped
  2. rdb.Close()         // drains pool, tears down go-redis goroutines
```

## init() prohibition (G41)

No `init()`. Metrics created lazily via `sync.Once` on first `New()`. Registry dedupes by name → multiple `*Cache` instances share metrics.

## goleak (G63)

Single `TestMain` in `cache_test.go`:
```go
func TestMain(m *testing.M) { goleak.VerifyTestMain(m) }
```

## Concurrency decisions

| Decision | Value |
|---|---|
| Pipeline goroutines spawned | 1 (scraper) |
| Shutdown pattern | done + stopped + sync.Once |
| `*Cache` mutex | none; atomic.Bool for `closed` |
| PubSub ownership | caller |
| init() | forbidden; sync.Once for metrics |
