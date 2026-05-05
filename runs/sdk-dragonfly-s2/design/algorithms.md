<!-- Generated: 2026-04-18T06:20:00Z | Run: sdk-dragonfly-s2 | Agent: algorithm-designer -->
# Algorithms — `dragonfly`

Four algorithmic surfaces carry meaningful logic; everything else delegates to `go-redis/v9` with tracing + metrics + `mapErr`.

## A. `mapErr` — single-switch error classifier (§7)

Input: any `error` returned by `go-redis`. Output: wrapped sentinel for `errors.Is` matching.

### Match order (first-match-wins; precedence matters for correctness)

1. `err == nil` → return nil.
2. `errors.Is(err, redis.Nil)` → `ErrNil`.
3. `errors.Is(err, context.Canceled)` → `ErrCanceled`.
4. `errors.Is(err, context.DeadlineExceeded)` → `ErrTimeout`.
5. `errors.Is(err, redis.ErrClosed)` → `ErrPoolClosed`.
6. Pool-specific (go-redis uses distinct sentinels — check both by target string and by `errors.Is` where available):
   - pool timeout → `ErrPoolExhausted`
   - pool closed → `ErrPoolClosed`
7. Network check — `var ne net.Error; errors.As(err, &ne) && ne.Timeout()` → `ErrTimeout`.
8. TLS check — `strings.Contains(msg, "tls:")` OR `errors.As(&tls.RecordHeaderError)` OR `errors.As(&x509.*Error)` → `ErrTLS`.
9. Server-error string-prefix switch (go-redis surfaces these as `redis.Error` with the raw server message). Ordered for longest-prefix / most-specific-first:
   - `MOVED ` → `ErrMoved`
   - `ASK ` → `ErrAsk`
   - `CLUSTERDOWN` → `ErrClusterDown`
   - `LOADING` → `ErrLoading`
   - `READONLY` → `ErrReadOnly`
   - `MASTERDOWN` → `ErrMasterDown`
   - `WRONGPASS` → `ErrAuth`
   - `NOAUTH` → `ErrAuth`
   - `NOPERM` → `ErrNoPerm`
   - `WRONGTYPE` → `ErrWrongType`
   - `NOSCRIPT` → `ErrScriptNotFound`
   - `BUSY` → `ErrBusyScript`
   - `ERR value is not an integer or out of range` / `ERR increment would overflow` → `ErrOutOfRange`
   - `ERR syntax error` → `ErrSyntax`
   - `ERR unknown command` → `ErrSyntax` (syntactically wrong at protocol level)
10. Dial refused / connection reset (net.OpError family, `errors.Is(err, syscall.ECONNREFUSED)`, etc.) → `ErrUnavailable`.
11. Default → `ErrUnavailable`.

### Wrapping

`return fmt.Errorf("%w: %v", Sentinel, err)` — preserves sentinel for `errors.Is`, preserves raw message for diagnostics via `err.Error()`, does NOT double-wrap with `%w` on the cause (matches TPRD §1 "no wrapping beyond …").

### Fuzz target (§11.4)

`FuzzMapErr(f *testing.F)` seeds with every server-error prefix, verifies `mapErr(errors.New(corpus))` returns a bounded sentinel from the 26-set. Property: output is always one of the declared sentinels; never `nil` for non-nil input.

### `classify(err)` → metric label

Single `switch` over sentinel identity:
- `ErrTimeout` → `"timeout"`
- `ErrUnavailable` / `ErrClusterDown` / `ErrLoading` / `ErrReadOnly` / `ErrMasterDown` / `ErrPoolExhausted` / `ErrPoolClosed` → `"unavailable"`
- `ErrNil` → `"nil"`
- `ErrWrongType` → `"wrong_type"`
- `ErrAuth` / `ErrNoPerm` / `ErrTLS` → `"auth"`
- default → `"other"`

Label cardinality = 6 values × `cmd` dim (bounded to command set, ~46) = ~276 series max per instance. Well under any tolerable cap.

## B. Pool-stats scraper (§8.2)

### Goal
Periodically read `rdb.PoolStats()` (go-redis) and emit six gauges:
`pool_total`, `pool_idle`, `pool_stale`, `pool_hits`, `pool_misses`, `pool_timeouts`.

### Sizing heuristic (§15.Q2 resolution)

Interval default: **10s**. Floor: **1s** (`minPoolStatsInterval`). Ceiling: **5m** (sanity — scraper should always refresh stale gauges).

Rationale:
- 10s matches Prometheus default scrape interval — downstream dashboards get fresh gauges within one scrape cycle without doubling the work.
- 1s floor prevents accidental tight loops (e.g., caller passes `100 * time.Millisecond`). Validated in `Config.validate()`.
- Counter-style fields (`pool_hits`, `pool_misses`, `pool_timeouts`) are exposed as **gauges** even though they are monotonic in go-redis, because they are absolute snapshots (go-redis does not reset them). Downstream should apply `rate()` / `increase()`.

### Loop structure

```
ticker := time.NewTicker(interval)
defer ticker.Stop()
for {
    select {
    case <-done: return
    case <-ticker.C:
        s := rdb.PoolStats()
        gaugeTotal.Set(ctx, float64(s.TotalConns))
        gaugeIdle.Set(ctx, float64(s.IdleConns))
        gaugeStale.Set(ctx, float64(s.StaleConns))
        gaugeHits.Set(ctx, float64(s.Hits))
        gaugeMisses.Set(ctx, float64(s.Misses))
        gaugeTimeouts.Set(ctx, float64(s.Timeouts))
    }
}
```

Uses a `context.Context` derived from `context.Background()` (scraper does not inherit per-op deadlines). Ownership + shutdown story in `concurrency.md`.

## C. HEXPIRE wire semantics (§5.3, §15.Q1)

Dragonfly / Redis 7.4+ HEXPIRE family returns **per-field integer codes** (see redis.io/commands/hexpire):

| Code | Meaning |
|---|---|
| `-2` | Key or field does not exist. |
| `0` | TTL unchanged (NX/XX/GT/LT precondition failed) or TTL already the requested value. |
| `1` | TTL set / updated. |
| `2` | HEXPIRE called with TTL=0 and the field was deleted. |

**TPRD §15.Q1 resolution:** keep raw `[]int64`. Do not wrap in enum. Design decision: pass go-redis return value through unchanged via `cmd.Val()`. Document the 4-value space in the godoc string on `HExpire`.

`HTTL` returns `[]time.Duration` where:
- `< 0` sentinel values (`-1` no TTL, `-2` no field) are preserved as negative durations in the slice. Document explicitly.

This keeps parity with go-redis and preserves forward compat if Dragonfly adds new codes.

## D. `instrumentedCall` wrapper

Single hot-path helper used by every data-path method. Shape:

```
func (c *Cache) instrumentedCall(ctx context.Context, cmd string, fn func(context.Context) error) error {
    ctx, span := tracer.Start(ctx, "dfly."+strings.ToLower(cmd))
    defer span.End()
    span.SetAttributes(
        tracer.StringAttr("db.system", "redis"),
        tracer.StringAttr("server.address", c.cfg.Addr),
        tracer.StringAttr("dfly.cmd", cmd),
    )
    start := time.Now()
    reqCounter.Inc(ctx, metrics.Labels{"cmd": cmd})
    err := fn(ctx)
    mapped := mapErr(err)
    durationHist.ObserveDuration(ctx, start, metrics.Labels{"cmd": cmd})
    if mapped != nil {
        errCounter.Inc(ctx, metrics.Labels{"cmd": cmd, "error_class": classify(mapped)})
        span.SetError(mapped)
    } else {
        span.SetOK()
    }
    return mapped
}
```

Critical invariants:
- `cmd` is a **compile-time literal** at the call site (e.g., `c.instrumentedCall(ctx, "GET", ...)`). No user input enters labels (§8.4 cardinality guard).
- `reqCounter`, `errCounter`, `durationHist` are **package-level** metrics created once at `init`-free `New` time via `metrics.NewCounter/NewHistogram` — cached in package state per metric name. (Note: existing `motadatagosdk/otel/metrics` `Registry` dedupes by name across multiple `New*` calls, so calling `New*` per `Cache` instance still returns the same metric — confirmed by reading `registry.go`.)
- For methods that return a value, use typed wrappers (generics):

```
func instrumentedGet[T any](c *Cache, ctx context.Context, cmd string, fn func(context.Context) (T, error)) (T, error)
```

or a simpler pattern: each method defines a local closure that captures the return variable, and delegates the error path through `instrumentedCall`. Phase 2 impl picks one; both compile.

### Perf-target implications (§10)

- P50 GET ≤ 200µs, ≤3 alloc/GET. The wrapper must not add more than ~1 alloc + ~5 ns on top of go-redis.
- `tracer.Start` + `span.End` on a no-op tracer is ~nothing; on a real tracer, one allocation for the span. Acceptable.
- `metrics.Labels{"cmd": cmd}` creates a `map[string]string` each call → 1 alloc. If bench shows this dominates, switch to pre-built Labels values indexed by cmd enum (phase-2 refactor lever). Flag as `[constraint: ≤3 alloc/GET | bench/BenchmarkGet]`.
- `classify(err)` only runs on error path — off hot path.

## E. Scripting + pipeline — no special algorithms

- `Eval`, `EvalSha`, `ScriptLoad`, `ScriptExists`: pass-through to go-redis; wrap in `instrumentedCall` variants.
- `Pipeline()` / `TxPipeline()` return raw `redis.Pipeliner` — **no instrumentation wrapping** (TPRD §5.4 "callers get full command surface without SDK churn"). Document explicitly in godoc that pipeline commands do not emit `dfly.*` spans; callers wrap themselves if they want.
- `Watch` creates a span `dfly.watch` around the callback; inner commands go via raw pipeline → not wrapped.

## F. Open algorithm risks

1. `BUSY` vs `BUSYGROUP` — `BUSY` is script-timeout; `BUSYGROUP` is XGROUP. Prefix match `BUSY ` (with trailing space) to avoid collision. Encoded in match order #9.
2. `redis.ErrClosed` — go-redis versions may tag pool-closed errors differently between v9.x patch releases. The sentinel re-export in `errors.go` pins against `redis.ErrClosed` by identity; fuzz the message-prefix fallback too.
3. `mapErr` ordering against custom go-redis errors (e.g., `redis.TxFailedErr`) — treat `TxFailedErr` specially → `ErrTxnAborted` BEFORE the generic default. Add as match #0.5.

**Refinement:** insert rule "0a. `errors.Is(err, redis.TxFailedErr)` → `ErrTxnAborted`" immediately before rule 2.
