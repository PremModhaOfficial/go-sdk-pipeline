<!-- Generated: 2026-04-18T06:25:00Z | Run: sdk-dragonfly-s2 | Agent: concurrency-designer -->
# Concurrency — `dragonfly`

Three goroutines / synchronization surfaces exist in this package. All three must be `goleak`-clean (G63).

## G1. Pool-stats scraper goroutine

### Ownership
Spawned by `New()` after a successful `rdb` construction; owned by `*Cache`; torn down by `(*Cache).Close()`. Not user-visible.

### Lifecycle state machine

```
[unstarted]
     │ New() → spawn
     ▼
[running]  ──── ticker fires every Config.PoolStatsInterval
     │
     │ Close() sends signal
     ▼
[stopping] ── goroutine observes done chan, drains ticker
     │
     ▼
[stopped]  ── Close() returns after confirmation
```

### Struct

```go
type poolStatsScraper struct {
    rdb      *redis.Client
    interval time.Duration
    done     chan struct{}      // closed by Stop; signals run() to exit
    stopped  chan struct{}      // closed by run() after exit; allows Stop to wait
    once     sync.Once          // idempotent Stop
}
```

### `run(ctx context.Context)` body

```go
func (s *poolStatsScraper) run(ctx context.Context) {
    defer close(s.stopped)
    t := time.NewTicker(s.interval)
    defer t.Stop()
    for {
        select {
        case <-s.done:
            return
        case <-ctx.Done():
            return
        case <-t.C:
            stats := s.rdb.PoolStats()
            // Set 6 gauges (see algorithms §B)
            _ = stats
        }
    }
}
```

### `stop()` implementation (bounded wait — F-D3 resolution)

```go
// stopTimeout bounds Close() wait when metrics backend applies backpressure.
const stopTimeout = 5 * time.Second

func (s *poolStatsScraper) stop() {
    s.once.Do(func() { close(s.done) })
    select {
    case <-s.stopped:
        // clean exit
    case <-time.After(stopTimeout):
        // Scraper did not exit within bound (e.g., OTLP push blocking).
        // Emit a Warn and proceed; the goroutine will eventually exit
        // when the metrics backend recovers. goleak may observe this as
        // a leak in pathological tests — acceptable signal.
        logger.Warn(context.Background(), "dragonfly: pool-stats scraper stop timed out",
            logger.String("timeout", stopTimeout.String()))
    }
}
```

Rationale: a deadlocked scraper must not deadlock `(*Cache).Close()`. Bounding the wait converts a latent hang into an observable warning. Raised by sdk-design-devil finding F-D3 (D3).

### Close() sequencing in `*Cache`

```go
func (c *Cache) Close() error {
    // 1. Signal scraper to stop and WAIT for confirmation.
    //    Must happen BEFORE rdb.Close() so scraper's in-flight PoolStats() call
    //    is not racing a closed pool.
    if c.scraper != nil {
        c.scraper.stop()
    }
    // 2. Close the underlying go-redis client. This drains the pool and
    //    fails any in-flight commands with redis.ErrClosed.
    return c.rdb.Close()
}
```

**Why order matters:** if `rdb.Close()` runs first, `PoolStats()` is still safe to call (go-redis returns zero stats on a closed pool), so the race is not a correctness bug. But emitting a "pool_total = 0" gauge on a deliberately closed pool is misleading for operators. Scraper-first avoids that false-reading flash.

## G2. go-redis internal goroutines

`go-redis/v9` internally spawns goroutines for:
- pool idle-conn reaper (one per `*redis.Client`)
- each `*redis.PubSub` subscriber (one reader goroutine per `Subscribe`/`PSubscribe`)

All are torn down by `rdb.Close()` / `ps.Close()`. We don't spawn them; we guarantee shutdown via:
- `Cache.Close()` calls `rdb.Close()`.
- PubSub: we return `*redis.PubSub` directly; **caller owns `ps.Close()`**. Document this in `Subscribe`/`PSubscribe` godoc.

### PubSub leak story

The `goleak.VerifyTestMain` gate (G63) catches leaks in *our* test processes. If a test calls `c.Subscribe(...)` and forgets `defer ps.Close()`, it will leak one goroutine and fail G63. Design decision: add an explicit note in the godoc of `Subscribe` and `PSubscribe`:

> Caller MUST call `ps.Close()` to release the underlying subscriber goroutine.
> Failing to do so leaks one goroutine per subscription; `goleak` will flag it in tests.

We do NOT wrap `*redis.PubSub` in a managed handle. Reason: hides the lifecycle from the caller; `go-redis` already provides a clean API. Wrapping forces us to proxy the `.Channel()`, `.Receive()`, `.Ping()` methods — breaks TPRD "signatures mirror go-redis".

### Integration-test chaos (§11.2)

The chaos test kills the testcontainer mid-flight. Expected behavior:
- go-redis returns `read: connection reset by peer` → `mapErr` → `ErrUnavailable`.
- Scraper continues (it catches errors internally; `PoolStats()` never returns an error, so nothing to propagate — it just reads zero fields).
- No goroutine leak; scraper halts on next `Close()`.

## G3. `Cache` concurrent access

`*Cache` is safe for concurrent use. Fields are either:
- set once in `New()` and never mutated (`cfg`, `rdb`, `scraper`) — safe for concurrent reads.
- internal to go-redis (`rdb` is documented safe for concurrent use).

**No mutex on `*Cache`.** `Close` idempotency uses atomic flag:

```go
type Cache struct {
    rdb     *redis.Client
    cfg     Config
    scraper *poolStatsScraper
    closed  atomic.Bool     // set true in Close; data-path methods may check
}
```

Optional: data-path methods check `closed.Load()` early and return `ErrNotConnected` if true. This shortens the error path on a closed client (vs letting go-redis return its own closed-pool error). Matches TPRD §7 `ErrNotConnected` semantic: "client closed or never dialed".

### Race matrix

| Concurrent ops | Safe? | Notes |
|---|---|---|
| Two goroutines: `Get` + `Get` | Yes | go-redis pool handles concurrent checkouts. |
| `Get` + `Close` | Yes | Close sets `closed=true` first; in-flight `Get` may observe either ErrNotConnected or mapped redis.ErrClosed — both acceptable. |
| `Close` + `Close` | Yes | `sync.Once` + `atomic.Bool` ensure idempotency. |
| Scraper read + `Close` | Yes | Scraper gets `done` signal; Close waits on `stopped`. |

## G4. `Watch` callback concurrency

`Watch(ctx, fn, keys...)` delegates to `rdb.Watch(ctx, fn, keys...)`. The callback `fn(*redis.Tx)` runs on the caller goroutine; go-redis does NOT spawn a goroutine for it. No concurrency concerns beyond what the caller introduces inside `fn`. Document in godoc.

## G5. `context.Context` propagation

Every data-path method takes `ctx` and passes it to go-redis. go-redis respects ctx deadlines; timeouts surface as `context.DeadlineExceeded` → `mapErr` → `ErrTimeout`.

The scraper uses `context.Background()` (it doesn't have a caller ctx). This is intentional: the scraper's lifetime is tied to `*Cache`, not any request.

## G6. `goleak` test harness (G63)

Every `_test.go` has `TestMain`:

```go
func TestMain(m *testing.M) { goleak.VerifyTestMain(m) }
```

Subpackages: the package is flat (no subpackages), so a single `TestMain` in `cache_test.go` suffices. Ignore list: go-redis's internal `time.after` false positives (if any) — add `goleak.IgnoreTopFunction(...)` selectively if needed.

## G7. init() prohibition (G41)

No `init()` functions. Package-level metric creation (Counter/Histogram) happens lazily on first `New()` via a `sync.Once`:

```go
var (
    metricsOnce     sync.Once
    reqCounter      metrics.Counter
    errCounter      metrics.Counter
    durationHist    metrics.Histogram
    gaugeTotal      metrics.Gauge
    gaugeIdle       metrics.Gauge
    gaugeStale      metrics.Gauge
    gaugeHits       metrics.Gauge
    gaugeMisses     metrics.Gauge
    gaugeTimeouts   metrics.Gauge
)

func initMetricsOnce() {
    metricsOnce.Do(func() {
        reqCounter   = metrics.NewCounter("l2cache.requests", "Dragonfly request count")
        errCounter   = metrics.NewCounter("l2cache.errors",   "Dragonfly error count")
        durationHist = metrics.NewHistogram("l2cache.duration_ms", "Dragonfly op duration (ms)")
        // 6 gauges likewise
    })
}
```

Called from `New()`. The `metrics.Registry` behind `NewCounter` etc. dedupes by name, so multiple `Cache` instances share metrics (intended — per-instance metrics would blow cardinality).

## G8. Summary of concurrency decisions

| Decision | Value |
|---|---|
| # of pipeline-authored goroutines | 1 (`poolStatsScraper.run`) |
| Shutdown pattern | close-done + stopped-ack channel pair + `sync.Once` |
| Close ordering | scraper.stop → rdb.Close |
| PubSub lifecycle | caller-owned (`ps.Close()`) |
| Mutex on `*Cache` | none; only `atomic.Bool` for closed flag |
| init() | none (forbidden by G41); `sync.Once` for metrics |
| `goleak.VerifyTestMain` | yes, in the single `TestMain` in `cache_test.go` |
