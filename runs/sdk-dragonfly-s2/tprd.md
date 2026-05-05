# TPRD — Dragonfly L2 Cache Module

**Module:** `motadatagosdk/core/l2cache/dragonfly`
**Owner:** Platform SDK
**Status:** Draft v0.1
**Date:** 2026-04-17
**Scope:** Phase P0 only. P1/P2 deferred to future TPRD revisions.

---

## 1. Purpose

Thin, opinionated wrap of `github.com/redis/go-redis/v9` targeting **Dragonfly** as the server. Provides a stable internal SDK surface for L2 caching primitives. Upstream composition layers (L1 cache coherence, circuit breaker, retry, rate limit) are built **outside** this module.

## 2. Goals

- Native Redis 9 API parity where Dragonfly supports the command.
- Dragonfly-specific features first-class (HEXPIRE hash-field TTL, emulated cluster semantics).
- Deterministic defaults via package constants; every knob overridable via `With*` option.
- OTEL tracing + metrics + structured logs on every data-path op.
- Sentinel-only error model. No custom error types, no wrapping beyond `fmt.Errorf("%w: %v", Sentinel, cause)`.
- Zero surprise: signatures mirror `go-redis/v9` return types (`string`, `int64`, `time.Duration`, etc).
- K8s-native security: TLS material + credentials resolved from secret-mounted files.

## 3. Non-Goals

- No Redis Sentinel support.
- No Redis Enterprise / Cloud SaaS adapters.
- No client-side tracking (RESP3 invalidation). L1 invalidation is the L1 layer's concern.
- No internal circuit breaker. External compose only.
- No L1↔L2 coherence logic. L1 wraps L2 externally.
- No automatic retry at SDK layer. `MaxRetries = 0` fixed default.
- No hashtag enforcement, no cluster sharding logic.
- No cross-slot transaction helpers.
- No tiering-awareness (cold-read timeout bumps etc).
- No Lua script pre-load registry (caller owns EVALSHA cache).
- No schema migration tooling.
- No connection multiplexing beyond go-redis pool.

## 4. Compat Matrix

| Target | Version |
|---|---|
| Go | 1.26 (per `go.mod`) |
| go-redis | v9.18.0 (pinned) |
| Dragonfly | latest stable at GA, greenfield |
| Redis wire protocol | RESP2 + RESP3 |
| Redis command parity | Redis 9 command set |

## 5. API Surface (P0)

### 5.1 Lifecycle (Slice 1 — **done**)
```go
func New(opts ...Option) (*Cache, error)
func (c *Cache) Ping(ctx context.Context) error
func (c *Cache) Close() error
```

### 5.2 String / Key (P0)
```go
func (c *Cache) Get(ctx, key string) (string, error)
func (c *Cache) Set(ctx, key, value string, ttl time.Duration) error
func (c *Cache) SetNX(ctx, key, value string, ttl time.Duration) (bool, error)
func (c *Cache) SetXX(ctx, key, value string, ttl time.Duration) (bool, error)
func (c *Cache) GetSet(ctx, key, value string) (string, error)
func (c *Cache) GetEx(ctx, key string, ttl time.Duration) (string, error)
func (c *Cache) GetDel(ctx, key string) (string, error)
func (c *Cache) MGet(ctx, keys ...string) ([]any, error)
func (c *Cache) MSet(ctx, kv ...string) error
func (c *Cache) Del(ctx, keys ...string) (int64, error)
func (c *Cache) Exists(ctx, keys ...string) (int64, error)
func (c *Cache) Expire(ctx, key string, ttl time.Duration) (bool, error)
func (c *Cache) ExpireAt(ctx, key string, at time.Time) (bool, error)
func (c *Cache) Persist(ctx, key string) (bool, error)
func (c *Cache) TTL(ctx, key string) (time.Duration, error)
func (c *Cache) Incr(ctx, key string) (int64, error)
func (c *Cache) IncrBy(ctx, key string, n int64) (int64, error)
func (c *Cache) Decr(ctx, key string) (int64, error)
func (c *Cache) DecrBy(ctx, key string, n int64) (int64, error)
```

### 5.3 Hash + hash-field TTL (Dragonfly / Redis 7.4+)
```go
func (c *Cache) HGet(ctx, key, field string) (string, error)
func (c *Cache) HSet(ctx, key string, values ...any) (int64, error)
func (c *Cache) HMGet(ctx, key string, fields ...string) ([]any, error)
func (c *Cache) HGetAll(ctx, key string) (map[string]string, error)
func (c *Cache) HDel(ctx, key string, fields ...string) (int64, error)
func (c *Cache) HExists(ctx, key, field string) (bool, error)
func (c *Cache) HLen(ctx, key string) (int64, error)
func (c *Cache) HIncrBy(ctx, key, field string, n int64) (int64, error)

// Hash-field TTL (HEXPIRE family)
func (c *Cache) HExpire(ctx, key string, ttl time.Duration, fields ...string) ([]int64, error)
func (c *Cache) HPExpire(ctx, key string, ttl time.Duration, fields ...string) ([]int64, error)
func (c *Cache) HExpireAt(ctx, key string, at time.Time, fields ...string) ([]int64, error)
func (c *Cache) HTTL(ctx, key string, fields ...string) ([]time.Duration, error)
func (c *Cache) HPersist(ctx, key string, fields ...string) ([]int64, error)
```

### 5.4 Pipeline + Transaction (explicit)
```go
func (c *Cache) Pipeline() redis.Pipeliner
func (c *Cache) TxPipeline() redis.Pipeliner
func (c *Cache) Watch(ctx, fn func(*redis.Tx) error, keys ...string) error
```

Rationale: expose go-redis `Pipeliner` directly. No custom wrapper — callers get full command surface without SDK churn when Dragonfly adds commands.

### 5.5 Pub/Sub
```go
func (c *Cache) Publish(ctx, channel, message string) (int64, error)
func (c *Cache) Subscribe(ctx, channels ...string) *redis.PubSub
func (c *Cache) PSubscribe(ctx, patterns ...string) *redis.PubSub
```

### 5.6 Scripting
```go
func (c *Cache) Eval(ctx, script string, keys []string, args ...any) (any, error)
func (c *Cache) EvalSha(ctx, sha string, keys []string, args ...any) (any, error)
func (c *Cache) ScriptLoad(ctx, script string) (string, error)
func (c *Cache) ScriptExists(ctx, shas ...string) ([]bool, error)
```

### 5.7 Raw escape hatch
```go
func (c *Cache) Do(ctx, args ...any) (any, error)
func (c *Cache) Client() *redis.Client   // direct handle; for features not yet wrapped
```

## 6. Config Surface

All fields in `Config` (already defined). All defaults in `const.go`. All setters in `options.go`.

Additions for P0 data path: **none** — current Slice 1 Config covers it. Future P1 may add `ReadOnly`, `MasterName`, etc — out of scope.

### Credential + TLS resolution (K8s)
- `Password` / `Username` loaded from mounted secret file path (env var points to path, code reads file).
- TLS cert/key/ca from mounted paths via existing `config.TLSConfig`.
- No inline secrets in code / YAML commits.
- Loader helper reads path from env var, dereferences, populates `Config`.

## 7. Error Model

All exported as package sentinels. Callers use `errors.Is`.

```go
// Lifecycle / transport
ErrNotConnected      // client closed or never dialed
ErrInvalidConfig     // New() validation failure
ErrTimeout           // ctx deadline, net timeout
ErrUnavailable       // dial refused, TLS handshake fail, server close
ErrCanceled          // ctx canceled (distinct from timeout)

// Data-path semantic
ErrNil               // redis.Nil — key miss
ErrWrongType         // WRONGTYPE
ErrOutOfRange        // ERR value out of range
ErrSyntax            // ERR syntax

// Cluster / topology (emit even if unused today — forward compat)
ErrMoved             // MOVED redirect
ErrAsk               // ASK redirect
ErrClusterDown       // CLUSTERDOWN
ErrLoading           // LOADING (replica sync)
ErrReadOnly          // READONLY on replica
ErrMasterDown        // server explicit

// Auth / TLS
ErrAuth              // WRONGPASS, NOAUTH
ErrNoPerm            // NOPERM (ACL)
ErrTLS               // handshake / cert verify

// Txn / scripting
ErrTxnAborted        // EXEC returned nil (WATCH fired)
ErrScriptNotFound    // NOSCRIPT
ErrBusyScript        // BUSY script timeout

// Pool
ErrPoolExhausted     // PoolTimeout exceeded
ErrPoolClosed        // pool shut

// Protocol / feature gate
ErrRESP3Required     // op needs RESP3, client is RESP2

// Pubsub
ErrSubscriberClosed

// External compose surface (exported but SDK never returns)
ErrCircuitOpen       // reserved for upstream composition
```

### Mapping (`mapErr`)
Single switch: matches `redis.Nil`, `redis.ErrClosed`, `context.*`, server error string prefixes (`MOVED `, `ASK `, `CLUSTERDOWN`, `LOADING`, `READONLY`, `WRONGPASS`, `NOAUTH`, `NOPERM`, `WRONGTYPE`, `NOSCRIPT`, `BUSY`), `net.Error.Timeout()`, pool errors. Default → `ErrUnavailable`.

## 8. Observability

### 8.1 Tracing
- Every data-path call starts client span `dfly.<cmd>` (lowercase cmd).
- Standard attrs on all spans: `db.system=redis`, `server.address=<addr>`, `dfly.cmd=<CMD>`.
- Error → `span.SetError(mapped)`; success → `span.SetOK()`.
- No key values in attrs (cardinality).

### 8.2 Metrics (via `motadatagosdk/otel/metrics`)
Namespace `l2cache`. Per-cmd:
- Counter `requests{cmd}`
- Counter `errors{cmd, error_class}` (`error_class` ∈ `{timeout, unavailable, nil, wrong_type, auth, other}` — bounded)
- Histogram `duration_ms{cmd}`
- Gauge `pool_total`, `pool_idle`, `pool_stale`, `pool_hits`, `pool_misses`, `pool_timeouts` (scraped from `rdb.PoolStats()` every N sec)

Label dims (bounded): `cmd`, `error_class`. **Never**: key, value, tenant prefix.

### 8.3 Logs (zap via `otel/logger`)
- Lifecycle: `New`, `Close`, `Ping` failure — Info / Warn.
- Data path: only `Error` on unmapped errors; no per-op Info spam.
- Redact: never log `Password`, `Username`, key values, payloads.

### 8.4 Cardinality guard
Hard rule: no label derived from user input may enter metrics. Compile-time review in PRs.

## 9. Security

- **TLS**: optional via `Config.TLS`. When enabled: min version TLS 1.2, prefer 1.3. ServerName required unless `SkipVerify` (disallowed in prod — validator warns).
- **Credentials**: resolved from file paths (K8s mounted secrets). Loader utility: `LoadCredsFromEnv(usernameEnvVar, passwordPathEnvVar)`.
- **ACL v2**: full support — `Username` + `Password` map to ACL user. Default-user deployments omit `Username`.
- **Transport**: plain TCP allowed in non-prod; validator emits warning log when TLS disabled.
- **No cleartext secrets** in logs, errors, span attrs, metrics.
- **Auth rotation**: `ConnMaxLifetime=10m` forces reconnect → picks up rotated creds from mounted file. Re-dial reads file fresh.

## 10. Perf Targets (greenfield — bench before GA)

| Metric | Target | Verify |
|---|---|---|
| P50 GET (local dfly) | ≤ 200µs | `cache_bench_test.go` |
| P99 GET (local dfly) | ≤ 1ms | `cache_bench_test.go` |
| SDK overhead vs raw go-redis | ≤ 5% | A/B bench |
| Alloc per GET | ≤ 3 alloc | `-benchmem` |
| 10k ops/sec sustained / pod | pass | load test |

Targets locked after first bench run.

## 11. Test Strategy

### 11.1 Unit (`_test.go`)
- `miniredis/v2` backend (already dep).
- Table-driven per method.
- Error-path coverage: Nil, WrongType, timeout, closed client.

### 11.2 Integration (`//go:build integration`)
- `testcontainers-go` spinning real Dragonfly image.
- Matrix: TLS on/off, ACL on/off.
- Chaos: kill container mid-flight → verify timeout/unavailable sentinels.

### 11.3 Benchmark (`*benchmark_test.go`)
- `BenchmarkGet`, `BenchmarkSet`, `BenchmarkPipeline_100`, `BenchmarkHSet`, `BenchmarkHExpire`, `BenchmarkEvalSha`.
- Report allocs + ns/op. Gate in CI.

### 11.4 Fuzz
- `FuzzMapErr` on error string → sentinel mapping.
- `FuzzKeyEncoding` on key arg pass-through.

### 11.5 Race
- All tests run under `-race` in CI.

## 12. Package Layout (post-P0)

```
core/l2cache/dragonfly/
├── TPRD.md              (this doc)
├── README.md            (usage quickstart)
├── USAGE.md             (cookbook)
├── const.go             (all defaults)
├── config.go            (Config struct)
├── options.go           (With* options)
├── errors.go            (sentinels + mapErr)
├── loader.go            (env/file credential + TLS loader)
├── cache.go             (Cache struct; New/Close/Ping)
├── string.go            (Get/Set/... §5.2)
├── hash.go              (HGet/... + HExpire §5.3)
├── pipeline.go          (§5.4)
├── pubsub.go            (§5.5)
├── script.go            (§5.6)
├── raw.go               (Do, Client)
├── poolstats.go         (scraper goroutine)
├── cache_test.go        (miniredis)
├── string_test.go
├── hash_test.go
├── pipeline_test.go
├── pubsub_test.go
├── script_test.go
├── cache_integration_test.go  (testcontainers)
└── cachebenchmark_test.go
```

## 13. Milestones

| Slice | Scope | Status |
|---|---|---|
| S1 | New, Ping, Close, Config, Options, Errors (lifecycle) | ✅ done |
| S2 | §5.2 strings + §5.7 raw + pool-stats scraper + errors.mapErr full switch | P0 |
| S3 | §5.3 hash + HEXPIRE family | P0 |
| S4 | §5.4 pipeline + txn | P0 |
| S5 | §5.5 pubsub | P0 |
| S6 | §5.6 scripting | P0 |
| S7 | Integration tests (testcontainers) + bench + USAGE.md | P0 |
| — | Streams, Cluster, JSON module | **P1 (future TPRD)** |
| — | Vector sets, TimeSeries, Bloom | **P2 (future TPRD)** |

## 14. Risks

| Risk | Mitigation |
|---|---|
| Dragonfly divergence from Redis 9 on edge commands | Integration tests pin to stable Dragonfly tag; document known gaps in USAGE.md |
| go-redis v9 breaking changes | Pinned `v9.18.0`; upgrade via explicit PR w/ bench diff |
| Hash-field TTL wire compat between Redis 7.4 and Dragonfly | Integration test HEXPIRE return codes against both |
| Credential rotation staleness | `ConnMaxLifetime` forces re-dial → fresh file read |
| Cardinality blowup from misuse | Code review gate; no dynamic label construction allowed |
| Pool exhaustion under burst | `PoolTimeout` returns `ErrPoolExhausted` fast; upstream handles with rate limit |
| RESP2/3 negotiation surprises | Validator logs chosen protocol at `New` |
| Large pipeline OOM | No cap by design; caller owns sizing. Doc in USAGE.md |

## 15. Open Questions

- HEXPIRE return code `[]int64` vs friendlier enum? → keep raw for parity; helper can come in v2.
- Pool stats scrape interval default? → propose 10s, confirm in S2.
- Do we expose `redis.Cmdable` as interface for test doubles? → no, return concrete `*Cache`; tests use miniredis.

---

## Appendix A — Call Flow

```
caller (app)
  │
  ▼
[external compose: CB → retry → rate-limit → L1]   ← out of this module
  │
  ▼
Cache.Method(ctx, …)        ← this module
  │ start span dfly.<cmd>
  │ metrics.Requests(cmd).Inc
  ▼
go-redis/v9  *redis.Client
  │ pool checkout (PoolTimeout)
  ▼
Dragonfly (TCP / TLS)
  │
  ▼
mapErr → sentinel
  │
  ▼
span.SetError / SetOK
metrics.Errors{cmd, class}.Inc  |  Duration{cmd}.Observe
  │
  ▼
return (value, sentinel-wrapped err)
```

## Appendix B — Usage Sketch

```go
cache, err := dragonfly.New(
    dragonfly.WithAddr("dfly.prod.svc:6379"),
    dragonfly.WithUsername("sdk-user"),
    dragonfly.WithPassword(loadSecretFile("/var/run/secrets/dfly/password")),
    dragonfly.WithTLS(loadTLS("/var/run/secrets/dfly")),
    dragonfly.WithTLSServerName("dfly.prod.svc"),
    dragonfly.WithPoolSize(32),
)
if err != nil { return err }
defer cache.Close()

if err := cache.Ping(ctx); err != nil { return err }

val, err := cache.Get(ctx, "tenant42:user:99")
switch {
case errors.Is(err, dragonfly.ErrNil):        // cache miss
case errors.Is(err, dragonfly.ErrTimeout):    // degrade
case err != nil:                              // hard fail
}
```

---

## §16. Breaking-Change Risk

**Mode B — extension to existing package** `motadatagosdk/core/l2cache/dragonfly`.

| Area | Assessment |
|---|---|
| Semver bump | **Minor** (v0.x.0 → v0.(x+1).0). Slices 2–6 add new exported methods to the existing `*Cache` receiver. No existing exported symbol is modified. |
| Slice-1 preservation | `New`, `(*Cache).Ping`, `(*Cache).Close`, `Config`, `Option`, `ErrNotConnected`, `ErrInvalidConfig` MUST be byte-identical post-run. `sdk-marker-scanner` will tag these `[owned-by: MANUAL]` during Phase 0.5. Guardrails G95 + G96 enforce. |
| Downstream callers | None — Slice 1 is greenfield (per §1 Purpose). New methods are additive. |
| Dependency graph | `github.com/redis/go-redis/v9` already pinned to v9.18.0 by Slice 1. No new transitive deps expected. `sdk-dep-vet-devil` re-vets on each design wave. |
| Sentinel additions | New `Err*` sentinels in §7 are additive; existing `ErrNotConnected` / `ErrInvalidConfig` unchanged. No `errors.Is` callers will break. |

`sdk-breaking-change-devil` verdict required: **ACCEPT** (Mode B, additive only).
`sdk-semver-devil` verdict required: **ACCEPT minor**.

---

## §Skills-Manifest

| Skill | Min version | Why required |
|---|---|---|
| `sdk-config-struct-pattern` | 1.0.0 | §6 Config + `With*` options conventions |
| `otel-instrumentation` | 1.0.0 | §8.1 client spans + W3C trace context |
| `sdk-otel-hook-integration` | 1.0.0 | §8.2 metrics via `motadatagosdk/otel/metrics` namespace |
| `network-error-classification` | 1.0.0 | §7 sentinel taxonomy (transient / permanent / retryable) |
| `go-error-handling-patterns` | 1.0.0 | §7 `errors.Is` + `fmt.Errorf("%w: %v", Sentinel, cause)` |
| `go-concurrency-patterns` | 1.0.0 | §12 `poolstats.go` scraper goroutine, sync primitives |
| `goroutine-leak-prevention` | 1.0.0 | §5.1 `Close` + `goleak.VerifyTestMain` (§11.5 race) |
| `client-shutdown-lifecycle` | 1.0.0 | §5.1 `Close` semantics + §9 ConnMaxLifetime credential rotation |
| `client-tls-configuration` | 1.0.0 | §9 TLS min 1.2, prefer 1.3, ServerName, SkipVerify guard |
| `connection-pool-tuning` | 1.0.0 | go-redis pool knobs + §8.2 PoolStats scraper sizing |
| `credential-provider-pattern` | 1.0.0 | §9 K8s mounted-secret file-based loader |
| `testcontainers-setup` | 1.0.0 | §11.2 integration matrix (TLS on/off, ACL on/off) |
| `table-driven-tests` | 1.0.0 | §11.1 unit table-driven per method |
| `testing-patterns` | 1.0.0 | §11 general test discipline |
| `fuzz-patterns` | 1.0.0 | §11.4 `FuzzMapErr`, `FuzzKeyEncoding` |
| `tdd-patterns` | 1.0.0 | impl-phase red→green→refactor cycle |
| `sdk-marker-protocol` | 1.0.0 | Mode B — `[owned-by: MANUAL]` on Slice 1; `[traces-to: TPRD-…]` on new symbols |
| `sdk-semver-governance` | 1.0.0 | §16 minor-bump verdict |
| `go-dependency-vetting` | 1.0.0 | go-redis v9.18.0 + miniredis/v2 license/CVE/maintenance gate |
| `redis-pipeline-tx-patterns` | 1.0.0 | §5.4 Pipeline + TxPipeline + Watch — **WARN expected (skill not in library; see `evolution/skill-candidates/`)** |
| `hash-field-ttl-hexpire` | 1.0.0 | §5.3 HEXPIRE/HPEXPIRE/HTTL/HPersist family — **WARN expected** |
| `pubsub-lifecycle` | 1.0.0 | §5.5 Subscribe/PSubscribe lifetime + cancellation — **WARN expected** |
| `miniredis-testing-patterns` | 1.0.0 | §11.1 miniredis fakes for unit tests — **WARN expected** |
| `lua-script-safety` | 1.0.0 | §5.6 Eval/EvalSha/ScriptLoad — **WARN expected** |
| `testcontainers-dragonfly-recipe` | 1.0.0 | §11.2 Dragonfly container image + readiness probe — **WARN expected** |
| `k8s-secret-file-credential-loader` | 1.0.0 | §9 `LoadCredsFromEnv` helper — **WARN expected** |
| `sentinel-error-model-mapping` | 1.0.0 | §7 `mapErr` switch + 30 sentinels — **WARN expected** |

> Skills marked **WARN expected** are not yet promoted to `.claude/skills/` (drafts live in `evolution/skill-candidates/`). Per pipeline policy, missing skills are non-blocking warnings filed to `docs/PROPOSED-SKILLS.md` for human PR review. The pipeline proceeds without their guidance — the corresponding TPRD sections (§5.3 hash, §5.4 pipeline, §5.5 pubsub, §5.6 scripting, §11 testing) will be implemented from the in-pipeline general patterns (`go-concurrency-patterns`, `testing-patterns`, etc.) plus this TPRD's explicit prescriptions.

## §Guardrails-Manifest

| Guardrail | Phase | Enforcement | Purpose |
|---|---|---|---|
| G01 | all | BLOCKER | decision-log valid JSONL |
| G02 | all | BLOCKER | decision-log entry-limit (≤15/agent/run) |
| G03 | all | BLOCKER | run-manifest schema validity |
| G07 | impl | BLOCKER | target-dir discipline (writes only to `$SDK_TARGET_DIR` + `runs/`) |
| G20 | intake | BLOCKER | TPRD topic-area completeness |
| G21 | intake | BLOCKER | §Non-Goals populated (≥3 bullets — this TPRD §3 has 13) |
| G22 | intake | INFO | clarifications ≤3 (info-only) |
| G23 | intake | WARN | §Skills-Manifest validation (non-blocking; files misses to PROPOSED-SKILLS.md) |
| G24 | intake | BLOCKER | §Guardrails-Manifest validation (every G-id has executable script) |
| G30 | design | BLOCKER | API contract completeness |
| G31 | design | BLOCKER | interface-design conventions |
| G32 | design | BLOCKER | govulncheck on declared deps |
| G33 | design | BLOCKER | osv-scanner on declared deps |
| G34 | design | BLOCKER | license allowlist (MIT/Apache-2.0/BSD/ISC/0BSD/MPL-2.0) |
| G38 | design | BLOCKER | §Security review present + sentinel-only error model |
| G40 | impl | BLOCKER | godoc on every exported symbol |
| G41 | impl | BLOCKER | no `init()`, no global mutable state |
| G42 | impl | BLOCKER | `context.Context` first param on every I/O method |
| G43 | impl | BLOCKER | compile-time interface assertions (`var _ Iface = (*impl)(nil)`) |
| G48 | impl | BLOCKER | no `ErrNotImplemented` / `TODO` in committed code |
| G60 | testing | BLOCKER | unit coverage ≥90% on new files |
| G61 | testing | BLOCKER | `go test -race` clean |
| G63 | testing | BLOCKER | `goleak.VerifyTestMain` clean |
| G65 | testing | BLOCKER | bench regression: >5% on hot path / >10% on shared = FAIL |
| G69 | testing | BLOCKER | credential hygiene (no plaintext creds in source) |
| G80 | feedback | BLOCKER | evolution-report written |
| G82 | feedback | BLOCKER | golden-corpus regression PASS |
| G90 | meta | BLOCKER | skill-index ↔ filesystem consistency |
| G93 | meta | BLOCKER | settings.json schema valid |
| G95 | impl | BLOCKER | marker-ownership unchanged (Slice 1 MANUAL preserved) |
| G96 | impl | BLOCKER | MANUAL byte-hash match |
| G97 | impl | BLOCKER | `[constraint: …]` bench proof (§10 perf targets) |
| G98 | impl | BLOCKER | required `[traces-to: …]` marker per pipeline-authored file |
| G99 | impl | BLOCKER | exported symbol godoc has `[traces-to: …]` |
| G100 | impl | BLOCKER | `[do-not-regenerate]` hard lock |
| G101 | impl | BLOCKER | `[stable-since: vX]` signature-change guard |
| G102 | impl | BLOCKER | marker-syntax validity |
| G103 | impl | BLOCKER | no forged `[owned-by: MANUAL]` markers |
