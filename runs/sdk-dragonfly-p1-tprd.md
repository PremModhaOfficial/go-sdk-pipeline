# TPRD — Dragonfly L2 Cache Module · P1 Extension Pack

**Module:** `motadatagosdk/core/l2cache/dragonfly`
**Owner:** Platform SDK
**Status:** Draft v0.1
**Date:** 2026-04-22
**Request Mode:** **B — Extension** of existing GA'd Dragonfly client (P0 shipped in run `sdk-dragonfly-s2`).
**Scope:** Six additive slices: `WithKeyPrefix`, typed JSON helpers, circuit-breaker bridge, `Scan`/`HScan` iterators, Sets, Sorted Sets. Streams, JSON-module, Lists, and Dragonfly-specific ops (MEMORY USAGE, DBSIZE, ACL) deferred to P2.

---

## 1. Purpose

Extend the GA'd P0 Dragonfly client with the highest-value production features missing from the Redis-command parity surface:

1. **Multi-tenant key namespacing** via `WithKeyPrefix` — removes the `"tenantN:..."` string-prefix boilerplate callers currently write at every call site.
2. **Type-safe JSON helpers** `GetJSON[T]` / `SetJSON[T]` — ties the existing `motadatagosdk/core/codec` package into the cache surface, eliminates per-caller marshal/unmarshal boilerplate.
3. **Circuit-breaker bridge** `WithCircuitBreaker` — connects the existing `motadatagosdk/core/circuitbreaker` module to `instrumentedCall`, removing the need for callers to manually compose.
4. **Idiomatic iterators** `Scan` / `HScan` returning `iter.Seq2[string, error]` — gives callers a safe way to walk large keyspaces that today is only reachable via the `Do()` escape hatch.
5. **Sets** (`SADD`, `SMEMBERS`, `SISMEMBER`, `SCARD`, `SREM`, `SINTER`, `SUNION`, `SDIFF`) — covers tag-based lookups, unique-constraint tracking, set math.
6. **Sorted Sets** (`ZADD`, `ZRANGE`, `ZRANGEBYSCORE`, `ZRANK`, `ZSCORE`, `ZREM`, `ZCARD`, `ZINCRBY`) — leaderboards, windowed rate limiting, priority queues.

All features are **additive-only**. No existing P0 symbol changes.

## 2. Goals

- Multi-tenant key isolation without per-call-site boilerplate.
- Compile-time-checked typed serialization via `codec` — zero caller-owned marshal code.
- One-line circuit-breaker adoption (`WithCircuitBreaker(cb)`); no hand-wired middleware.
- Go 1.23+ `range-over-func` iterators for all scan-class commands.
- Native `ZADD` / `SADD` / `ZRANGE` signatures that mirror go-redis v9 return types (no custom structs that require downstream churn).
- 100% preservation of P0 Slice 1–6 symbols (byte-hash enforced via `[owned-by: MANUAL]`).
- Single `instrumentedCall` wrapper remains the only data-path ingress point (keyprefix, CB, and metrics all layer on top; adding a new method must not bypass the wrapper).

## 3. Non-Goals

- **No** Streams / `XADD` / `XREAD` / `XGROUP` — deferred to P2 TPRD.
- **No** JSON module (`JSON.SET`, `JSON.GET`) — deferred to P2; `GetJSON[T]` here is client-side codec marshaling over plain `SET`, not the server-side RedisJSON module.
- **No** Lists (`LPUSH`, `RPUSH`, `BLPOP`) — P2.
- **No** Cluster / Sentinel adaptation — outside module scope per P0 TPRD §3.
- **No** retry / rate-limit built into the CB bridge — the bridge only wires an existing `*circuitbreaker.CircuitBreaker`; retry stays external.
- **No** automatic key-prefix redaction in logs / traces — callers who want to avoid leaking tenant IDs in span attrs must disable the default `db.statement` enrichment themselves.
- **No** wildcard or regex match support on key-prefix — the prefix is a literal string concatenated before every key.
- **No** server-side Lua-based set operations — stick to native SADD/SINTER etc.
- **No** streaming `ZRANGE WITHSCORES` result-set iteration — callers use bounded ranges.
- **No** schema versioning for `SetJSON[T]` payloads — encoding/decoding is caller-owned (same `T` expected).
- **No** change to the existing `Config` struct public shape — new options mutate private-by-composition fields added alongside.
- **No** breaking change to `instrumentedCall` signature — extended via closures over new per-call state.

## 4. Compat Matrix

| Target | Version |
|---|---|
| Go | 1.26 (pinned; range-over-func requires 1.23+) |
| go-redis | v9.18.0 (unchanged from P0) |
| Dragonfly server | any tag that passed P0 integration (latest stable at GA) |
| Redis wire protocol | RESP2 + RESP3 |
| Redis command parity | Redis 9 (Sets, Sorted Sets, Scan are all Redis 6+) |
| motadatagosdk dependencies | `core/codec` (existing), `core/circuitbreaker` (existing) — no new third-party deps |

## 5. API Surface (P1)

### 5.1 Key prefix (Slice 1)

```go
// WithKeyPrefix sets a literal string prepended to every key argument
// on every call. Empty (default) disables prefixing. The prefix is
// applied inside instrumentedCall just before the go-redis call, so
// every command — including Pipeline-authored batches created via
// Pipeline()/TxPipeline() and the Watch() fn callback — respects it.
// Key arguments to Pub/Sub (channels/patterns) and to Eval/EvalSha
// (scripted KEYS[i]) are also prefixed.
//
// Prefix is a literal — no interpolation, no regex, no delimiter
// insertion. Callers who want "tenant42:" must pass the trailing
// colon.
// [traces-to: TPRD-§5.1-WithKeyPrefix]
func WithKeyPrefix(prefix string) Option
```

Behavior matrix:

| Call class                              | Prefixed? | Notes |
|-----------------------------------------|-----------|-------|
| All String/Hash/Set/SortedSet commands  | Yes       | every `key` arg |
| `MGet`, `MSet`, `Del`, `Exists`         | Yes       | every vararg key |
| `Publish`, `Subscribe`, `PSubscribe`    | Yes       | channels + patterns |
| `Eval`, `EvalSha`                       | Yes       | every `keys[i]` (script args untouched) |
| `Scan`, `HScan`                         | Yes       | cursor unchanged; `match` pattern auto-prefixed |
| `Do()` raw escape                       | **No**    | caller owns raw args; prefix-skip is explicit |
| `Client()` direct handle                | **No**    | direct go-redis access bypasses wrapper |
| `Watch(fn, keys…)` top-level keys       | Yes       | also prefixed inside the fn's `*redis.Tx` calls |

### 5.2 Typed JSON helpers (Slice 2)

Generic helpers over plain `SET`/`GET` using the existing `motadatagosdk/core/codec` JSON encoder.

```go
// GetJSON fetches the key's value and unmarshals it into T using
// codec.JSON. Returns the decoded value, or ErrNil on key miss, or
// ErrCodec on unmarshal failure (new sentinel — see §7).
// [traces-to: TPRD-§5.2-GetJSON]
func GetJSON[T any](ctx context.Context, c *Cache, key string) (T, error)

// SetJSON marshals val via codec.JSON and writes it with the given TTL
// (0 = no expiry, matching Set semantics). Marshal failure returns
// ErrCodec before any network call.
// [traces-to: TPRD-§5.2-SetJSON]
func SetJSON[T any](ctx context.Context, c *Cache, key string, val T, ttl time.Duration) error

// MGetJSON batches N keys in one RTT and decodes each. Miss → zero
// value of T at that index, err[i] == ErrNil. Decode failure at index
// i stops the loop and returns a partial []T with err[i] == ErrCodec.
// [traces-to: TPRD-§5.2-MGetJSON]
func MGetJSON[T any](ctx context.Context, c *Cache, keys ...string) ([]T, []error)
```

Design notes:

- Helpers are **package-level generics**, not `*Cache` methods — Go forbids generic methods on non-generic receivers. Callers pass the cache as the second arg.
- All three helpers go through `instrumentedCall`; spans `dfly.getjson`, `dfly.setjson`, `dfly.mgetjson`. `cmd` metric label is `getjson` / `setjson` / `mgetjson` (distinct from plain `get`/`set` for per-feature SLO tracking).
- Codec choice is fixed to JSON in P1. Callers that want msgpack/proto stay on the raw `Get`/`Set`.

### 5.3 Circuit-breaker bridge (Slice 3)

```go
// WithCircuitBreaker wires an existing *circuitbreaker.CircuitBreaker
// into every data-path call via instrumentedCall. Breaker invocation
// happens INSIDE instrumentedCall, AFTER span start but BEFORE the
// go-redis call, so an open breaker:
//
//   - returns ErrCircuitOpen fast (no pool checkout, no dial)
//   - is recorded on the span as an error with class="circuit_open"
//   - increments metrics.errors{cmd, error_class="circuit_open"}
//
// On closed/half-open breaker, the go-redis call runs and the
// breaker's Execute() records success/failure per existing CB policy.
// Nil breaker (default) disables the bridge — identical behavior to
// P0.
// [traces-to: TPRD-§5.3-WithCircuitBreaker]
func WithCircuitBreaker(cb *circuitbreaker.CircuitBreaker) Option
```

Error classification: every mapped sentinel that the CB should treat as "failure" is enumerated in §7.1 (not every sentinel counts — `ErrNil` is a cache miss, not a server fault, and **does not** trip the breaker). Classification lives in `circuit_classify.go` and is covered by a dedicated table test.

### 5.4 Scan iterators (Slice 4)

```go
// Scan returns a Go 1.23+ iterator over keys matching the pattern.
// The iterator is lazy: it issues SCAN commands as the caller iterates,
// using the server-returned cursor. Terminates cleanly when the cursor
// returns to "0". The caller may stop early by breaking from the range
// — no resource leak, no goroutine, no cancellation required beyond
// the ctx.
//
//   for k, err := range cache.Scan(ctx, "session:*", 100) {
//       if err != nil { /* iteration aborted */ break }
//       // process k
//   }
//
// The match pattern is auto-prefixed by WithKeyPrefix. count is an
// advisory SCAN COUNT hint (server may return more or fewer per batch).
// [traces-to: TPRD-§5.4-Scan]
func (c *Cache) Scan(ctx context.Context, match string, count int64) iter.Seq2[string, error]

// HScan iterates fields of a single hash key. Emits (field, value)
// pairs (both as strings); the err channel is carried by a separate
// terminal call — see docstring for the (string, string) pair + a
// final (".", err) sentinel contract.
// [traces-to: TPRD-§5.4-HScan]
func (c *Cache) HScan(ctx context.Context, key, match string, count int64) iter.Seq2[HScanEntry, error]

// HScanEntry pairs a hash field name with its value.
type HScanEntry struct {
    Field string
    Value string
}
```

Iterator contract:

- Each `SCAN`/`HSCAN` RTT is one `instrumentedCall` (span `dfly.scan` / `dfly.hscan`). Metrics count each batch, not each yielded key.
- If `ctx` is canceled mid-iteration, the next `yield` receives `(_, ctx.Err())` and the iterator stops.
- An unmapped go-redis error yields `(_, ErrUnavailable)` (or the mapped sentinel) and stops.
- Zero-match iteration yields nothing, no error.
- Safe to re-enter — each call to `Scan(...)` returns a fresh iterator; no shared state on `*Cache`.

### 5.5 Sets (Slice 5)

```go
func (c *Cache) SAdd(ctx context.Context, key string, members ...any) (int64, error)
func (c *Cache) SRem(ctx context.Context, key string, members ...any) (int64, error)
func (c *Cache) SMembers(ctx context.Context, key string) ([]string, error)
func (c *Cache) SIsMember(ctx context.Context, key string, member any) (bool, error)
func (c *Cache) SCard(ctx context.Context, key string) (int64, error)
func (c *Cache) SInter(ctx context.Context, keys ...string) ([]string, error)
func (c *Cache) SUnion(ctx context.Context, keys ...string) ([]string, error)
func (c *Cache) SDiff(ctx context.Context, keys ...string) ([]string, error)
func (c *Cache) SInterStore(ctx context.Context, dest string, keys ...string) (int64, error)
func (c *Cache) SRandMember(ctx context.Context, key string) (string, error)
func (c *Cache) SPop(ctx context.Context, key string) (string, error)
```

Return-type parity with go-redis v9. `SRandMember` and `SPop` return `ErrNil` on empty set (matches go-redis `redis.Nil`). All multi-key commands auto-prefix every key arg.

### 5.6 Sorted Sets (Slice 6)

```go
// Z is the score-member pair used by ZAdd family.
type Z struct {
    Score  float64
    Member any
}

func (c *Cache) ZAdd(ctx context.Context, key string, members ...Z) (int64, error)
func (c *Cache) ZAddNX(ctx context.Context, key string, members ...Z) (int64, error)
func (c *Cache) ZAddXX(ctx context.Context, key string, members ...Z) (int64, error)
func (c *Cache) ZIncrBy(ctx context.Context, key string, increment float64, member string) (float64, error)
func (c *Cache) ZRange(ctx context.Context, key string, start, stop int64) ([]string, error)
func (c *Cache) ZRangeWithScores(ctx context.Context, key string, start, stop int64) ([]Z, error)
func (c *Cache) ZRevRange(ctx context.Context, key string, start, stop int64) ([]string, error)
func (c *Cache) ZRangeByScore(ctx context.Context, key string, min, max float64, offset, count int64) ([]string, error)
func (c *Cache) ZRank(ctx context.Context, key, member string) (int64, error)
func (c *Cache) ZRevRank(ctx context.Context, key, member string) (int64, error)
func (c *Cache) ZScore(ctx context.Context, key, member string) (float64, error)
func (c *Cache) ZRem(ctx context.Context, key string, members ...any) (int64, error)
func (c *Cache) ZCard(ctx context.Context, key string) (int64, error)
func (c *Cache) ZCount(ctx context.Context, key string, min, max float64) (int64, error)
func (c *Cache) ZPopMin(ctx context.Context, key string) (Z, error)
func (c *Cache) ZPopMax(ctx context.Context, key string) (Z, error)
```

Notes:
- `Z` intentionally mirrors `redis.Z` but is defined in-package so callers never import `github.com/redis/go-redis/v9` directly (same reasoning as P0 sentinel-only errors).
- `ZRank`, `ZRevRank`, `ZScore` return `ErrNil` when the member is absent (go-redis surfaces `redis.Nil`).
- `ZPopMin`/`ZPopMax` return `(Z{}, ErrNil)` on empty key.
- Range commands with +inf/-inf: pass `math.Inf(+1)` / `math.Inf(-1)`. Dragonfly emits these as `+inf` / `-inf` strings on the wire; the helper validates finite-vs-infinity via `math.IsInf`.

## 6. Config Surface

New fields on existing `Config` struct (append-only, zero-initialized preserves P0 behavior):

```go
type Config struct {
    // ... existing P0 fields ...

    // KeyPrefix is the literal string prepended to every key argument.
    // Empty disables prefixing. [traces-to: TPRD-§5.1]
    KeyPrefix string

    // CircuitBreaker optionally wraps every data-path call. Nil
    // disables the bridge. [traces-to: TPRD-§5.3]
    CircuitBreaker *circuitbreaker.CircuitBreaker
}
```

New `With*` options: `WithKeyPrefix`, `WithCircuitBreaker` (signatures in §5). All defaults stay zero — a caller who doesn't set them gets identical P0 behavior.

No existing field is modified. `applyDefaults` is untouched. `validate` gains one new check: if `KeyPrefix` contains a NUL byte (`\x00`), `validate()` returns `ErrInvalidConfig` (sanity guard).

## 7. Error Model

### 7.1 New sentinels

```go
// ErrCodec wraps any codec-layer marshal/unmarshal failure from
// GetJSON / SetJSON / MGetJSON. [traces-to: TPRD-§5.2]
var ErrCodec = errors.New("dragonfly: codec failure")

// ErrCircuitOpen is returned by any data-path call when the
// configured circuit breaker is OPEN. Re-exported from the CB layer
// but wrapped so callers can rely on a single import path.
// [traces-to: TPRD-§5.3]
// (Already declared in P0 §7 as "reserved for upstream composition";
//  P1 promotes it to actively returned.)
```

### 7.2 Error-class extensions for `metrics.errors{cmd, error_class}`

P0 taxonomy: `{timeout, unavailable, nil, wrong_type, auth, other}`.
P1 adds: `{codec, circuit_open}`. Bounded; no caller-derived classes.

### 7.3 CB failure classification (§5.3)

| Sentinel | Counts as CB failure? | Rationale |
|---|---|---|
| `ErrTimeout` | Yes | transport degradation |
| `ErrUnavailable` | Yes | server down / dial refused |
| `ErrLoading`, `ErrClusterDown`, `ErrMasterDown` | Yes | server not ready |
| `ErrPoolExhausted` | Yes | local saturation — treat as fault |
| `ErrNil` | **No** | cache miss is normal |
| `ErrWrongType`, `ErrOutOfRange`, `ErrSyntax` | **No** | caller bug, not server fault |
| `ErrAuth`, `ErrNoPerm`, `ErrTLS` | **No** | config fault; breaker won't heal it |
| `ErrCodec` | **No** | payload fault, not server fault |
| `ErrCanceled` | **No** | caller canceled |
| All others (unmapped) | Yes (conservative) | default-deny |

Implemented in `circuit_classify.go`; table-tested per sentinel.

## 8. Observability

### 8.1 Tracing

- New spans: `dfly.getjson`, `dfly.setjson`, `dfly.mgetjson`, `dfly.scan`, `dfly.hscan`, `dfly.sadd`, `dfly.srem`, … (one per §5.5/5.6 method, lowercase cmd).
- `WithKeyPrefix` does **not** add the prefix value to span attrs (cardinality). A boolean `dfly.keyprefix_enabled=true` is added when non-empty.
- `WithCircuitBreaker` adds `dfly.cb_state=<closed|half_open|open>` at span start when the bridge is configured.
- All other standard attrs from P0 §8.1 apply.

### 8.2 Metrics

Per-cmd Counter/Histogram set extended to all new methods. Labels stay bounded: `cmd` + `error_class`. `error_class` gains `codec`, `circuit_open` (§7.2).

New top-level counters:

- `circuit_transitions{from, to}` — populated via a CB state-change observer the bridge wires in `New`. Removed on `Close`.
- `scan_batches{cmd}` — how many SCAN/HSCAN RTTs per iteration (proxy for pagination health).

### 8.3 Logs

- CB transitions → Info level with `from`, `to`, `cmd_in_flight` context.
- Codec failures → Warn level, **no payload** logged (never log `T`'s fields).
- Scan iterator early-break due to ctx cancel → Debug level.

### 8.4 Cardinality guard

Same compile-time review rule as P0. No label derived from user input (key, prefix literal, tenant id) may enter metrics. Codec error class is fixed-string.

## 9. Security

- **KeyPrefix sanitization**: the literal string is passed verbatim to `go-redis`. Callers must not accept prefix values from untrusted input (e.g., user-controlled tenant IDs that weren't canonicalized). The validator logs a Warn at `New()` if the prefix contains `[*?\[\]]` glob metacharacters (likely a misuse: SCAN `match` patterns are processed by server, but data-path keys are byte-equal).
- **CB integration**: the bridge never stores credentials or keys on the CB instance. CB state lives in the injected `*circuitbreaker.CircuitBreaker`.
- **Typed JSON**: `codec.JSON` uses `encoding/json` under the hood; the wrapper inherits its escape-on-encode semantics. A Warn is logged (once, via `sync.Once`) at first `SetJSON[T]` call if `T` contains an unexported `io.Reader` or `*os.File` field (best-effort reflection check at config time — future hardening).
- **ACL**: Sets and Sorted Sets are additive Redis commands with default ACL visibility. No new auth surface; existing `Username`/`Password` applies.

## 10. Perf Targets

All measured against **existing P0 baselines** on `core/l2cache/dragonfly/` — not fresh greenfield.

| Metric | Target | Verify |
|---|---|---|
| `WithKeyPrefix` overhead (Get, 32-byte prefix) vs P0 Get | ≤ **3%** wall-clock, ≤ **0 extra allocs** (string concat is compiled out) | `bench_keyprefix_test.go` A/B |
| `GetJSON[SmallStruct]` (~100 B payload) | ≤ **P0 Get × 1.5** | `bench_json_test.go` |
| `SetJSON[SmallStruct]` | ≤ **P0 Set × 1.5** | `bench_json_test.go` |
| `WithCircuitBreaker` closed-state overhead | ≤ **2%** wall-clock vs no-CB | `bench_cb_test.go` |
| `WithCircuitBreaker` open-state fast-fail | ≤ **10µs** (no pool checkout, no RTT) | `bench_cb_test.go` |
| `Scan` iterator, 10k keys, `COUNT 100` | ≤ **110 SCAN RTTs** total, ≤ **1 alloc per yielded key** | `bench_scan_test.go` |
| `ZAdd` / `SAdd` (1 member) | ≤ **P0 Set × 1.1** | `bench_sortedset_test.go`, `bench_set_test.go` |
| `ZRangeWithScores`, range size 1k | ≤ **P0 MGet-1k × 1.2** | `bench_sortedset_test.go` |
| `MGetJSON` 10-key batch | ≤ **P0 MGet-10 × 1.4** | `bench_json_test.go` |

Hot-path regression threshold: **>5% on any of the above = BLOCKER** (enforced by `sdk-benchmark-devil` + G65). Shared-path regression on existing P0 benches: **>10% = BLOCKER** (enforced same gate). See §16 for the MANUAL-byte-hash preservation gate that makes the shared-path constraint load-bearing.

## 11. Test Strategy

### 11.1 Unit (`*_test.go`)
- `miniredis/v2` (already a dep) backs Sets, Sorted Sets, Scan, HScan natively.
- `WithKeyPrefix` tested by asserting the last-seen-by-miniredis key matches the expected prefix+key literal via `miniredis.Miniredis.Keys()`.
- `WithCircuitBreaker` tested with a fake `*circuitbreaker.CircuitBreaker` (in-memory; CB module already exposes a `NewForTest()` helper — confirm during design).
- `GetJSON` / `SetJSON` / `MGetJSON` tested with at least: happy path, `ErrNil`, `ErrCodec` on bad payload, `ErrCodec` on unmarshal-into-wrong-T.
- Iterator tests: break-early, ctx-cancel mid-iteration, zero-match, server-error mid-iteration, 1k-batch pagination.

### 11.2 Integration (`//go:build integration`)
- testcontainers Dragonfly (reuse P0 recipe).
- Cross-slice matrix: `WithKeyPrefix` + `WithCircuitBreaker` + `GetJSON[T]` together (all three options on one `*Cache`).
- CB state-transition test: force failures → verify OPEN; wait `cb.Timeout` → verify HALF_OPEN; success → CLOSED.
- ACL-restricted user: verify Sets/Sorted Sets honor command-level ACLs.
- HSCAN over 100k-field hash: verify no timeout, verify iteration count.

### 11.3 Benchmark (`*benchmark_test.go`)
All benches listed in §10, each with `b.ReportAllocs()`. Run in CI with `benchstat` vs P0 baseline (G65).

### 11.4 Fuzz
- `FuzzKeyPrefix` — random prefix + key combinations, assert `prefix+key` equality.
- `FuzzJSONRoundTrip` — arbitrary `T` (via `reflect`-backed harness) → `SetJSON` → `GetJSON` → `reflect.DeepEqual`.

### 11.5 Race
All tests under `-race`. `goleak.VerifyTestMain` in every `_test.go` file that uses CB (async state observer goroutine).

## 12. Package Layout (post-P1)

```
core/l2cache/dragonfly/
├── TPRD.md
├── README.md
├── USAGE.md
├── const.go
├── config.go                     (+ KeyPrefix, + CircuitBreaker fields)
├── options.go                    (+ WithKeyPrefix, + WithCircuitBreaker)
├── errors.go                     (+ ErrCodec sentinel + promoted ErrCircuitOpen)
├── loader.go                     (unchanged)
├── cache.go                      (instrumentedCall extended: prefix + CB layer)
├── string.go                     (MANUAL — P0)
├── hash.go                       (MANUAL — P0)
├── pipeline.go                   (MANUAL — P0, but Pipeliner callback must respect KeyPrefix: add tests)
├── pubsub.go                     (MANUAL — P0, but channel/pattern auto-prefixed: add tests)
├── script.go                     (MANUAL — P0, but KEYS[i] auto-prefixed: add tests)
├── raw.go                        (MANUAL — P0, Do/Client stay prefix-free by design)
├── poolstats.go                  (MANUAL — P0)
├── metrics.go                    (+ circuit_transitions, + scan_batches)
├── json.go                       (NEW — GetJSON, SetJSON, MGetJSON)
├── scan.go                       (NEW — Scan, HScan, HScanEntry)
├── set.go                        (NEW — SAdd/SRem/… §5.5)
├── sortedset.go                  (NEW — Z, ZAdd/ZRange/… §5.6)
├── circuit_classify.go           (NEW — sentinel→CB-failure map §7.3)
├── keyprefix.go                  (NEW — prefix-apply helpers used by cache.go)
├── cache_test.go                 (MANUAL — extend for prefix + CB; NEW file left untouched)
├── string_test.go                (MANUAL)
├── hash_test.go                  (MANUAL — extend with KeyPrefix assertion; additive only)
├── pipeline_test.go              (MANUAL — extend with KeyPrefix inside Pipeliner)
├── pubsub_test.go                (MANUAL — extend with prefixed channels)
├── script_test.go                (MANUAL — extend with prefixed KEYS[i])
├── raw_test.go                   (MANUAL — assert Do bypasses prefix)
├── json_test.go                  (NEW — miniredis)
├── scan_test.go                  (NEW)
├── set_test.go                   (NEW)
├── sortedset_test.go             (NEW)
├── circuit_classify_test.go      (NEW — table)
├── keyprefix_test.go             (NEW — fuzz + table)
├── cache_integration_test.go     (MANUAL — extend cross-slice matrix)
├── example_test.go               (MANUAL — add one Example_ per new feature)
├── bench_keyprefix_test.go       (NEW)
├── bench_json_test.go            (NEW)
├── bench_cb_test.go              (NEW)
├── bench_scan_test.go            (NEW)
├── bench_set_test.go             (NEW)
├── bench_sortedset_test.go       (NEW)
└── coverage_test.go              (MANUAL — extend to include new files; floor stays 90%)
```

"MANUAL" annotation = `[owned-by: MANUAL]` marker planted by `sdk-marker-scanner` during Phase 0.5 (Mode B). Byte-hash enforced by G96 — pipeline agents MUST NOT rewrite these files. Extensions to MANUAL test files (to cover KeyPrefix/CB behavior) land as **additive new test functions appended to the bottom** of each file; the existing test functions and imports stay byte-identical.

## 13. Milestones

| Slice | Scope | Priority |
|---|---|---|
| S1 | `WithKeyPrefix` + prefix-apply across every caller-key-ingress point; tests + bench | P1 |
| S2 | `GetJSON` / `SetJSON` / `MGetJSON` + codec bridge + `ErrCodec` | P1 |
| S3 | `WithCircuitBreaker` + `circuit_classify.go` + CB metrics + CB integration test | P1 |
| S4 | `Scan` / `HScan` `iter.Seq2` iterators + tests + bench | P1 |
| S5 | Sets (§5.5) + tests + bench | P1 |
| S6 | Sorted Sets (§5.6) + tests + bench + USAGE.md update | P1 |
| — | Streams, Lists, JSON-module (server-side RedisJSON), Dragonfly-specific ops | **P2 (future TPRD)** |

## 14. Risks

| Risk | Mitigation |
|---|---|
| `WithKeyPrefix` misses a caller-key-ingress point (e.g., a future `Pipeliner` command that bypasses `instrumentedCall`) | Add a lint test in `keyprefix_test.go` that uses `reflect` over `*Cache` to enumerate every method that takes a `key string` or `keys ...string`, and asserts each is covered by a dedicated prefix test. Refuses to compile if a new method lands without opt-in or opt-out registration. |
| `SetJSON[T]` with a huge `T` blows past `MaxWriteSize` | Document in USAGE.md; no runtime check (callers own payload sizing). |
| CB state-change metric emission leaks a goroutine on `Close` | `goleak.VerifyTestMain` + explicit `observer.Stop()` on `Cache.Close`; covered by leak test. |
| Sentinel→CB-failure classification disagrees with future sentinel additions | Any new sentinel in P2+ TPRDs MUST add a row to `circuit_classify_test.go` table, or the test fails with a compile-error-style assertion via `t.Fatal` listing unhandled sentinels. |
| `iter.Seq2` range-over-func requires Go 1.23+; target is 1.26 | No risk; `go.mod` already pins 1.26. |
| `Z{}` duplicating `redis.Z` creates drift if go-redis evolves the struct | Integration test asserts `redis.Z`-emitted values round-trip through `Z`; add a CI guard. |
| `WithCircuitBreaker(nil)` accidentally disables a feature the caller thinks they enabled | `validate()` emits a warning log line at `New()` when the option was called explicitly with `nil`; a truly-default nil passes silently. |
| P0 MANUAL file byte-hash drift during test extension | G95 + G96 enforce pre-phase-2 hash match; pipeline refuses to merge if any pre-existing test function line changed. New tests go in a clearly delimited `// --- P1 extensions (do not modify above) ---` footer block. |

## 15. Open Questions

- **Q1**: Should `WithKeyPrefix` apply to `Subscribe`/`PSubscribe` channel args? → **Decided: yes** (§5.1 table). Rationale: pub/sub within a tenant should be isolated. Callers who need cross-tenant subscribes use `Client()` (documented).
- **Q2**: Should `GetJSON[T]` support a `WithCodec(codec.Codec)` per-call override for msgpack/proto? → **Decided: no in P1** — fixed JSON. A generic `Get[T]` / `Set[T]` with codec injection is a P2 consideration.
- **Q3**: Should `WithCircuitBreaker` allow a per-command-class override (e.g., skip CB for `Ping`)? → **Decided: no in P1**. `Ping` goes through CB like everything else; callers who want a liveness probe that bypasses the breaker use `Client().Ping(ctx)`.
- **Q4**: HScan `iter.Seq2[HScanEntry, error]` vs a struct `iter.Seq2[struct{Field,Value string}, error]` → **Decided: named struct** (`HScanEntry`) — anonymous struct in iter signature complicates godoc.
- **Q5**: Batch-delete helper `DelPrefix(ctx, prefix) int64` as a convenience wrapper around `Scan`+`Del`? → **Decided: no in P1** — production footgun (unbounded latency on large keyspaces). Callers write the loop themselves using `Scan` iterator.
- **Q6**: Should `SetJSON` expose a `WithEncodeHook(func(T) any)` for pre-encode transforms? → **Decided: no** — overreach. Callers transform before calling.

## 16. Breaking-Change Risk

**Mode B — extension to existing package** `motadatagosdk/core/l2cache/dragonfly`.

| Area | Assessment |
|---|---|
| Semver bump | **Minor** (v0.x.0 → v0.(x+1).0). P1 adds new exported symbols (`WithKeyPrefix`, `WithCircuitBreaker`, `GetJSON`, `SetJSON`, `MGetJSON`, `Scan`, `HScan`, `HScanEntry`, `ErrCodec`, `Z`, and ~30 new `*Cache` methods across Sets/SortedSets). No existing exported symbol is modified or removed. |
| Slice 1–6 preservation | All of `New`, `(*Cache).Ping`, `(*Cache).Close`, `Get`/`Set`/`HGet`/etc., `Pipeline`, `Subscribe`, `Eval`, `Do`, `Client`, `Config`, `Option`, all P0 `Err*` sentinels — MUST be byte-identical post-run. `sdk-marker-scanner` tags these `[owned-by: MANUAL]` in Phase 0.5. G95 + G96 enforce byte-hash preservation. |
| `Config` struct | Appending `KeyPrefix string` + `CircuitBreaker *circuitbreaker.CircuitBreaker` is Go-compatible (zero-value callers unaffected; struct-literal callers who used named fields unaffected). Positional struct-literal callers — none exist in P0 or the broader codebase, verified during Phase 0.5 `sdk-existing-api-analyzer`. |
| `instrumentedCall` | Internal (unexported). Signature evolves but no external caller. Extension is layer-additive: prefix → CB → metrics, each a closure around the previous. |
| Downstream callers | P0 shipped GA; audit via `code-graph` + `serena` during Phase 0.5 to enumerate every caller of `*Cache` outside this package. Any caller that positional-destructures `Config` gets surfaced at H7b. |
| Dependency graph | `motadatagosdk/core/codec` + `motadatagosdk/core/circuitbreaker` — both internal, no new third-party deps. `sdk-dep-vet-devil` re-runs license/CVE on the transitive closure to confirm. |
| Sentinel additions | `ErrCodec` is new; `ErrCircuitOpen` already declared in P0 §7 (reserved but never returned) — P1 promotes it to actively returned. `errors.Is(err, ErrCircuitOpen)` callers unchanged. |
| Behavior change for existing callers | **One**: P0 callers who never set `MaxRetries` see zero behavior change. P0 callers who set `MaxRetries > 0` still get a warning at `New()` (behavior from P0 §6, unchanged). No other behavior shifts. |

`sdk-breaking-change-devil` verdict required: **ACCEPT** (Mode B, fully additive).
`sdk-semver-devil` verdict required: **ACCEPT minor**.
`sdk-convention-devil` must confirm: new methods respect P0 `(ctx, key, ...)` first-arg convention; new `Option`s respect `With*` naming; sentinels respect `Err*` naming; generics use package-level funcs (not methods) per §5.2 note.

---

## §Skills-Manifest

| Skill | Min version | Why required |
|---|---|---|
| `sdk-config-struct-pattern` | 1.0.0 | §6 Config extension + new `With*` options |
| `sdk-marker-protocol` | 1.0.0 | §12 + §16 — Mode B preservation, `[owned-by: MANUAL]` on P0 files, `[traces-to:]` on new |
| `sdk-semver-governance` | 1.0.0 | §16 minor-bump verdict |
| `otel-instrumentation` | 1.0.0 | §8.1 new spans per method |
| `sdk-otel-hook-integration` | 1.0.0 | §8.2 metrics extensions + `circuit_transitions` counter |
| `network-error-classification` | 1.0.0 | §7.3 sentinel→CB-failure classification |
| `go-error-handling-patterns` | 1.0.0 | §7 `ErrCodec` sentinel + `errors.Is` discipline |
| `circuit-breaker-policy` | 1.0.0 | §5.3 bridge design; CB state transitions; OPEN/HALF-OPEN/CLOSED semantics |
| `go-concurrency-patterns` | 1.0.0 | CB state-observer goroutine lifecycle; iterator concurrency safety |
| `goroutine-leak-prevention` | 1.0.0 | §14 CB observer + Scan iterator leak tests |
| `client-shutdown-lifecycle` | 1.0.0 | §5.1 — CB observer MUST stop on `Cache.Close` |
| `client-tls-configuration` | 1.0.0 | §9 unchanged from P0 but extensions must respect existing TLS plumbing |
| `connection-pool-tuning` | 1.0.0 | §10 perf — CB closed-state must not add pool pressure |
| `credential-provider-pattern` | 1.0.0 | §9 unchanged from P0 |
| `context-deadline-patterns` | 1.0.0 | §5.4 iterator — ctx cancel mid-iteration semantics |
| `testcontainers-setup` | 1.0.0 | §11.2 reuse P0 recipe; add cross-slice matrix |
| `table-driven-tests` | 1.0.0 | §11.1 Sets, SortedSets, circuit_classify |
| `testing-patterns` | 1.0.0 | §11 test hygiene |
| `tdd-patterns` | 1.0.0 | Red→green→refactor per slice |
| `fuzz-patterns` | 1.0.0 | §11.4 `FuzzKeyPrefix`, `FuzzJSONRoundTrip` |
| `mock-patterns` | 1.0.0 | §11.1 CB fake (via CB module's `NewForTest`) |
| `client-mock-strategy` | 1.0.0 | §11.1 miniredis for Sets/SortedSets/Scan |
| `idempotent-retry-safety` | 1.0.0 | §3 non-goal confirmation — CB bridge is NOT a retry |
| `go-struct-interface-design` | 1.0.0 | §5.6 `Z` struct design, `HScanEntry` naming |
| `go-dependency-vetting` | 1.0.0 | §4 confirm no new third-party deps |
| `api-ergonomics-audit` | 1.0.0 | §5.2 package-level generics vs method trade-off; §5.1 prefix-application matrix |
| `go-example-function-patterns` | 1.0.0 | §12 — one `Example_*` per new feature (WithKeyPrefix, GetJSON, WithCircuitBreaker, Scan, SAdd, ZAdd) |
| `go-module-paths` | 1.0.0 | Confirm `motadatagosdk/core/codec` + `motadatagosdk/core/circuitbreaker` import paths |
| `redis-pipeline-tx-patterns` | 1.0.0 | §5.1 — KeyPrefix inside `Pipeline()` callback — **WARN expected** (not yet promoted; see `docs/PROPOSED-SKILLS.md`) |
| `go-iter-seq-patterns` | 1.0.0 | §5.4 — Go 1.23+ `range-over-func` — **WARN expected** (new skill proposal; file to `PROPOSED-SKILLS.md`) |
| `redis-set-sortedset-semantics` | 1.0.0 | §5.5 + §5.6 — member encoding, score float semantics, `redis.Nil` edge cases — **WARN expected** |
| `generic-codec-helper-design` | 1.0.0 | §5.2 — package-level generic helpers over a non-generic receiver — **WARN expected** |

> Skills marked **WARN expected** are not yet promoted to `.claude/skills/`. Per pipeline Rule 23, missing skills are non-blocking warnings filed to `docs/PROPOSED-SKILLS.md`. The pipeline proceeds using the in-library generic patterns (`go-concurrency-patterns`, `testing-patterns`, etc.) plus this TPRD's explicit prescriptions in §5.

## §Guardrails-Manifest

| Guardrail | Phase | Enforcement | Purpose |
|---|---|---|---|
| G01 | all | BLOCKER | decision-log valid JSONL |
| G02 | all | BLOCKER | decision-log entry-limit |
| G03 | all | BLOCKER | run-manifest schema validity |
| G04 | all | WARN | MCP health (graceful degrade) |
| G07 | impl | BLOCKER | target-dir discipline |
| G20 | intake | BLOCKER | TPRD topic-area completeness |
| G21 | intake | BLOCKER | §Non-Goals populated (this TPRD has 11) |
| G22 | intake | INFO | clarifications ≤3 |
| G23 | intake | WARN | §Skills-Manifest (misses file to PROPOSED-SKILLS.md) |
| G24 | intake | BLOCKER | §Guardrails-Manifest validation |
| G30 | design | BLOCKER | API contract completeness |
| G31 | design | BLOCKER | interface conventions |
| G32 | design | BLOCKER | govulncheck on declared deps |
| G33 | design | BLOCKER | osv-scanner |
| G34 | design | BLOCKER | license allowlist |
| G38 | design | BLOCKER | §Security review + sentinel-only errors |
| G40 | impl | BLOCKER | godoc on every exported symbol |
| G41 | impl | BLOCKER | no `init()`, no global mutable state (CB observer is `*Cache`-owned, not package-level) |
| G42 | impl | BLOCKER | `ctx context.Context` first param on every I/O method |
| G43 | impl | BLOCKER | compile-time interface assertions |
| G48 | impl | BLOCKER | no TODO / ErrNotImplemented |
| G60 | testing | BLOCKER | unit coverage ≥90% on new files |
| G61 | testing | BLOCKER | `-race` clean |
| G63 | testing | BLOCKER | `goleak.VerifyTestMain` clean |
| G65 | testing | BLOCKER | bench regression (≤5% new hot, ≤10% shared) |
| G69 | testing | BLOCKER | credential hygiene |
| G80 | feedback | BLOCKER | evolution-report written |
| G81 | feedback | BLOCKER | baselines updated or rationale |
| G83 | feedback | BLOCKER | every patch logged in skill evolution-log.md |
| G84 | feedback | BLOCKER | per-run safety caps respected |
| G85 | feedback | BLOCKER | learning-notifications.md written when any patch applied |
| G86 | feedback | BLOCKER | quality regression ≥5% cap (when ≥3 prior runs exist) |
| G90 | meta | BLOCKER | skill-index ↔ filesystem consistency |
| G93 | meta | BLOCKER | settings.json schema valid |
| G95 | impl | BLOCKER | marker-ownership unchanged (P0 MANUAL preserved) |
| G96 | impl | BLOCKER | MANUAL byte-hash match (all P0 files; new tests land in footer block per §12) |
| G97 | impl | BLOCKER | `[constraint: ...]` bench proof (§10 perf targets with `bench/` references) |
| G98 | impl | BLOCKER | required `[traces-to:]` marker per pipeline-authored file |
| G99 | impl | BLOCKER | exported symbol godoc has `[traces-to:]` |
| G100 | impl | BLOCKER | `[do-not-regenerate]` hard lock |
| G101 | impl | BLOCKER | `[stable-since:]` signature-change guard |
| G102 | impl | BLOCKER | marker-syntax validity |
| G103 | impl | BLOCKER | no forged `[traces-to: MANUAL-*]` |
| G104 | impl (M3.5) | BLOCKER | alloc-budget per declared `allocs_per_op` in `design/perf-budget.md` |
| G105 | testing (T-SOAK) | BLOCKER | soak-MMD — not exercised in P1 (no soak-enabled symbol declared); gate no-ops |
| G106 | testing (T-SOAK) | BLOCKER | soak-drift — not exercised in P1 |
| G107 | testing (T5) | BLOCKER | complexity scaling — declared for `ZRangeWithScores` (O(log N + M)) and `Scan` iterator (O(N) amortized) |
| G108 | testing (T5) | BLOCKER | oracle-margin — declared for GetJSON vs raw Get ratio ≤ 1.5×, SetJSON vs raw Set ≤ 1.5× |
| G109 | impl (M3.5) | BLOCKER | profile-no-surprise — hot paths declared in perf-budget.md (instrumentedCall, mapErr, keyprefix concat) |
| G110 | impl (M7+M9) | BLOCKER | `[perf-exception:]` pairing — zero `perf-exception` markers expected in P1 (no hand-optimized paths) |

### Exit codes

- 0: all phases PASS, branch ready for review at H10
- 1: HITL gate declined
- 2: guardrail BLOCKER unresolved after review-fix
- 4: supply-chain REJECT (unexpected: no new deps)
- 5: target dir invalid
- 6: §Guardrails-Manifest validation FAIL (missing script)

---

## Appendix A — Usage Sketch

```go
import (
    "context"
    "errors"
    "time"

    "motadatagosdk/core/circuitbreaker"
    "motadatagosdk/core/l2cache/dragonfly"
)

type Session struct {
    UserID    string `json:"user_id"`
    IssuedAt  int64  `json:"issued_at"`
    ExpiresAt int64  `json:"expires_at"`
    Roles     []string `json:"roles"`
}

func run(ctx context.Context) error {
    cb, _ := circuitbreaker.New(circuitbreaker.Config{
        FailureThreshold: 5,
        ResetTimeout:     30 * time.Second,
    })

    cache, err := dragonfly.New(
        dragonfly.WithAddr("dfly.prod.svc:6379"),
        dragonfly.WithTLSServerName("dfly.prod.svc"),
        dragonfly.WithKeyPrefix("tenant42:"),   // NEW in P1
        dragonfly.WithCircuitBreaker(cb),       // NEW in P1
    )
    if err != nil { return err }
    defer cache.Close()

    // Typed JSON — no caller marshal
    s := Session{UserID: "u-99", IssuedAt: time.Now().Unix(), Roles: []string{"admin"}}
    if err := dragonfly.SetJSON(ctx, cache, "session:u-99", s, 15*time.Minute); err != nil {
        return err
    }

    got, err := dragonfly.GetJSON[Session](ctx, cache, "session:u-99")
    switch {
    case errors.Is(err, dragonfly.ErrNil):           // cache miss
    case errors.Is(err, dragonfly.ErrCodec):         // payload corruption
    case errors.Is(err, dragonfly.ErrCircuitOpen):   // breaker open, fail fast
    case err != nil:                                  // hard failure
    }
    _ = got

    // Safe iteration over a large keyspace
    for key, err := range cache.Scan(ctx, "session:*", 100) {
        if err != nil { break }
        _ = key
    }

    // Sets
    _, _ = cache.SAdd(ctx, "active-users", "u-1", "u-2", "u-99")
    members, _ := cache.SMembers(ctx, "active-users")
    _ = members

    // Sorted sets (leaderboard)
    _, _ = cache.ZAdd(ctx, "leaderboard",
        dragonfly.Z{Score: 100, Member: "u-1"},
        dragonfly.Z{Score: 350, Member: "u-99"},
    )
    top, _ := cache.ZRevRange(ctx, "leaderboard", 0, 9)
    _ = top

    return nil
}
```

## Appendix B — Call Flow (updated)

```
caller
  │
  ▼
Cache.Method(ctx, key, …)
  │
  ▼  keyprefix.apply(key)        ← NEW (§5.1)
  │
  ▼  span.start("dfly.<cmd>")
  │  metrics.Requests(cmd).Inc
  ▼
  CB.Execute(func() { ... })     ← NEW (§5.3), nil-CB = passthrough
  │
  ▼  go-redis *redis.Client
  │  pool checkout (PoolTimeout)
  ▼
Dragonfly (TCP / TLS)
  │
  ▼  mapErr → sentinel
  │  circuit_classify(sentinel)  ← NEW (§7.3) feeds CB success/fail
  ▼
  span.SetError/SetOK
  metrics.Errors{cmd, class}.Inc | Duration{cmd}.Observe
  │
  ▼
return (value, sentinel-wrapped err)
```
