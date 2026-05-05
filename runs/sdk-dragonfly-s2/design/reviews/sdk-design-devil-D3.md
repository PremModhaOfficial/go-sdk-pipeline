<!-- Generated: 2026-04-18T07:00:00Z | Run: sdk-dragonfly-s2 -->
# sdk-design-devil — D3 Review

Adversarial review of overall API design. Read: package-layout.md, api.go.stub, interfaces.md, algorithms.md, concurrency.md, patterns.md.

## Findings

### F-D1 — `Cache.Client()` bypass footgun (SEV=minor)
**Problem:** `Client() *redis.Client` exposes the raw handle. Any caller using it loses OTel instrumentation silently.
**TPRD stance:** §5.7 explicitly exposes it; §3 escape-hatch.
**Recommendation:** keep as-is; godoc MUST warn loudly that instrumentation is bypassed. Design stub already does (`// Use only for commands not yet wrapped by Cache. Bypasses OTel instrumentation.`). PASS on design; Phase 2 must preserve godoc text verbatim.
**Verdict:** ACCEPT-WITH-NOTE (no fix required).

### F-D2 — `WithMaxRetries(n)` contradicts §3 non-goal (SEV=info)
**Problem:** §3 says "No automatic retry at SDK layer. `MaxRetries = 0` fixed default." Yet `WithMaxRetries(n)` is exposed — a caller can set n=5 and re-enable go-redis internal retries.
**Design response:** `patterns.md` §P10 proposes a `Warn` log in `New()` when `cfg.MaxRetries != 0`. Acceptable.
**Risk:** operator confusion if retries silently enabled.
**Verdict:** ACCEPT (warn log is sufficient; caller opt-in is their own call).

### F-D3 — No timeout on `(*poolStatsScraper).stop()` wait (SEV=minor)
**Problem:** `concurrency.md` §G1 shows `stop()` does `<-s.stopped` unconditionally. If scraper goroutine somehow blocks (e.g., metrics backend hanging inside `gauge.Set`), `Close()` hangs forever.
**Likelihood:** low — `gauge.Set` on the OTel no-op/local provider is non-blocking. But an OTLP push-based provider could introduce backpressure.
**Recommendation:** bound wait with a `select { case <-s.stopped: case <-time.After(5*time.Second): ... }` + log warn if timeout elapses. Phase 2 must implement.
**Verdict:** **NEEDS-FIX** — amend `concurrency.md` §G1 `stop()` body.

### F-D4 — Missing method: `Pipeliner.Exec` wrapping story (SEV=info)
**Problem:** `Pipeline()` returns `redis.Pipeliner`. TPRD §5.4 is explicit: no wrapper. But callers will call `.Exec(ctx)` on the pipeliner and those calls emit ZERO `dfly.*` spans. USAGE.md must document this.
**Verdict:** ACCEPT-WITH-NOTE — `USAGE.md` is a Phase 2 artifact; note is already captured in `algorithms.md` §E. Phase 2 impl tasked to echo it in USAGE.md.

### F-D5 — `HTTL` negative-duration semantics are confusing (SEV=minor)
**Problem:** `algorithms.md` §C says `HTTL` preserves `-1` (no TTL) and `-2` (no field) as negative `time.Duration` values in the returned slice. Callers will `for _, d := range result { time.Sleep(d) }` and get panic-adjacent behavior.
**Recommendation:** document loudly in `HTTL` godoc; callers must check `d < 0` before treating as a duration. Consider a helper `IsMissing(d time.Duration) bool` in the future (out of scope now).
**Verdict:** ACCEPT-WITH-NOTE.

### F-D6 — `New` has 15+ options; no validation of conflicting combinations (SEV=minor)
**Problem:** e.g., `WithTLS(nil) + WithTLSServerName("x")` auto-creates a zero TLSConfig (see stub line ~99). `WithProtocol(2) + <RESP3-required-operation>` silently degrades.
**Recommendation:** `Config.validate()` should reject `SkipVerify=false && ServerName==""` when TLS is enabled. Already hinted in stub godoc. Phase 2 must enforce.
**Verdict:** ACCEPT — validate() contract documented; Phase 2 tests will verify.

### F-D7 — No surfaced `*redis.Cmdable` for test doubles (SEV=info)
**Problem:** TPRD §15.Q3 explicitly rejects this. But Phase 2/3 test authors may wish for one to stub `*Cache` in downstream-caller unit tests.
**Mitigation:** callers can wrap `*Cache` in their own interface at the call site. Matches Go idiom ("accept interfaces, return concrete types" — at the consumer boundary).
**Verdict:** ACCEPT (TPRD resolved this).

### F-D8 — `Watch` callback concurrency with scraper (SEV=info)
**Problem:** `Watch(ctx, fn, keys...)` runs `fn` on caller goroutine. Scraper reads `rdb.PoolStats()` concurrently. go-redis is concurrency-safe, so no actual race.
**Verdict:** ACCEPT.

## Summary

- **1 NEEDS-FIX** (F-D3 — scraper.stop timeout).
- 7 ACCEPT or ACCEPT-WITH-NOTE.

**Overall verdict:** NEEDS-FIX — one design artifact amendment required (concurrency.md §G1).
