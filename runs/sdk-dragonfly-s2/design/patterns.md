<!-- Generated: 2026-04-18T06:30:00Z | Run: sdk-dragonfly-s2 | Agent: pattern-advisor -->
# Patterns — `dragonfly` vs existing SDK conventions

Cross-check the proposed design against current target-SDK conventions. Resolve apparent contradictions.

## P1. Config + Options reconciliation

### Observed existing SDK patterns

| Package | Entry point | Style |
|---|---|---|
| `motadatagosdk/events` | `events.Connect(ctx, ConnectionConfig{...})` | Config struct directly to constructor; no functional options exported |
| `motadatagosdk/core/pool/resourcepool` | `resourcepool.New(cfg Config, callbacks ...)` | Config struct directly; no functional options |
| `motadatagosdk/otel` | `otel.Init(cfg Config)` / `otel.InitFromEnv()` | Config struct directly |
| `motadatagosdk/otel/metrics` | `metrics.NewCounter(name, desc)` | Positional args, no Option type |

**Verdict:** existing SDK consistently uses `Config struct + ConstructorTakingConfig`. There is no precedent for functional `With*` options in the target SDK today.

### TPRD requirement

TPRD §6 explicitly says "All setters in `options.go`" AND "All fields in `Config`". Intake mode.json `options_expected` enumerates 15 `With*` options.

### Resolution (chosen)

`dragonfly` introduces functional options **as the primary user-facing surface**, because:

1. TPRD §6 + Appendix B usage sketch (`dragonfly.New(dragonfly.WithAddr(...), ...)`) explicitly prescribe it.
2. Slice-1 baseline already ships 15 `With*` options (per intake mode.json).
3. Functional options improve evolvability: adding a 16th knob is additive without touching constructor signature.

**But** `Config` remains exported (fulfilling "All fields in `Config`"). Advanced callers can use a single `func(c *Config) { *c = myCfg }` option to inject a pre-built Config. This preserves both directions.

**Deviation from convention acknowledged in `design-summary.md`:** dragonfly is the first SDK package to export functional options. This is justified by TPRD directive and by the very large knob count (15 runtime + 1 stats-interval = 16). Future packages may follow or stick with struct-direct — the convention-devil should accept, with a note.

## P2. TLSConfig shape

Existing: `events.TLSConfig` has `CertFile`, `KeyFile`, `CAFile`, `SkipVerify` (no `ServerName`, no `MinVersion`).

Proposed `dragonfly.TLSConfig`: adds `ServerName` (required unless SkipVerify — §9 validator rule) and `MinVersion` (TLS 1.2 default, 1.3 preferred — §9 requirement).

**Verdict:** superset shape. Not a conflict with `events`; different package, different knobs. Convention-devil should accept.

**Optional future consolidation:** promote a shared `config.TLSConfig` (currently `events.TLSConfig` is local to `events`). Out of scope for this run — filed as skill-gap observation.

## P3. OTel integration

TPRD §8 + intake non-negotiable #3: use `motadatagosdk/otel` ONLY, not raw `go.opentelemetry.io/otel`.

Existing `motadatagosdk/otel/{tracer,metrics,logger}` provides:
- `tracer.Start(ctx, name, opts...)` → `(ctx, Span)` with `Span.SetError`, `Span.SetOK`, `Span.SetAttributes`.
- `metrics.NewCounter(name, desc)`, `NewGauge`, `NewHistogram` with `Inc`/`Observe(ctx, val, Labels{})`.
- `logger.Info/Warn/Error/Debug(ctx, msg, fields...)`.

The `instrumentedCall` wrapper (algorithms §D) uses exactly these APIs. No raw `otel.Tracer()` or `metric.NewMeterProvider()` calls. Compliant.

**Namespace:** TPRD §8.2 says "Namespace `l2cache`". The existing `metrics.ServiceMetrics(ns)` provides namespace prefixing, but calling `NewCounter("l2cache.requests", ...)` directly also works (the registry handles the fully-qualified name). Pick the direct form — simpler, no extra handle to pass around.

## P4. Sentinel-only error model

Existing `events` package re-exports sentinels from `utils` + `middleware` as package-level `var`. Dragonfly follows the same shape: 26 package-level `var Err* = errors.New(...)`. Compatible.

`mapErr` is a single internal switch — matches events's `classify`-equivalents where present. No wrapping beyond `fmt.Errorf("%w: %v", Sentinel, cause)` — exactly what TPRD §1 prescribes.

## P5. Credential loader

Proposed `LoadCredsFromEnv(userEnv, passPathEnv)` — reads username directly from env, password from a file path pointed to by env var. Matches §9 ("env var points to path, code reads file").

### Target-SDK precedent

`motadatagosdk/config/loader.go` exists — inspect for convention consistency.

Reading the file (already surveyed): `config.LoadConfigFromEnv()` returns a full `config.Config`. Shape is orthogonal to what we need (ACL creds are a tiny subset).

**Decision:** dragonfly's `LoadCredsFromEnv` lives in the `dragonfly` package (not `config/`), because:
- It's specific to dragonfly's `Config.Username`/`Password`, not a shared cross-module concern.
- Placing in `config/` would create a `config → dragonfly` shape inversion.

It IS a helper function, NOT a `With*` option — the caller combines them: `dragonfly.New(dragonfly.WithUsername(u), dragonfly.WithPassword(p))` where `u, p, _ := dragonfly.LoadCredsFromEnv(...)`.

### P5a. Credential rotation semantics (S-9 resolution)

TPRD §9 states: "`ConnMaxLifetime=10m` forces reconnect → picks up rotated creds from mounted file. Re-dial reads file fresh."

**Phase 2 implementation contract:** the `Dialer` closure passed to `redis.Options{Dialer: ...}` MUST re-read the password file on every invocation. This is achieved by capturing the env-var name (NOT the password value) in the closure, calling `os.ReadFile(passPath)` inside the Dialer, and injecting the fresh password via `HELLO` or `AUTH` as go-redis performs during dial.

**Concrete plan** (documented here, enforced in Phase 2 `cache.go`):

```go
// Pseudocode for Phase 2 New() body:
dialer := func(ctx context.Context, network, addr string) (net.Conn, error) {
    // If caller wired credentials via LoadCredsFromEnv, re-read them here.
    // Implementation: store the env-var names on Config (new fields:
    // UsernameEnv, PasswordPathEnv) when LoadCredsFromEnv is used,
    // and have the Dialer re-resolve.
    //
    // If caller passed static WithUsername/WithPassword, use those verbatim.
    return net.Dial(network, addr)
}
redisOpts := &redis.Options{
    Addr:            cfg.Addr,
    Username:        cfg.Username,
    Password:        cfg.Password,
    Dialer:          dialer,
    ConnMaxLifetime: cfg.ConnMaxLifetime,
}
```

**Caveat for callers using `WithPassword(staticValue)`:** rotation does NOT happen. Only `LoadCredsFromEnv` + the re-reading Dialer path refreshes credentials. This is documented in the godoc of both `LoadCredsFromEnv` and `WithPassword`.

**Alternative considered + rejected:** a background goroutine watching the file via `fsnotify` and mutating `redis.Options.Password`. Rejected because (a) `redis.Options.Password` is not re-read by go-redis after `NewClient`; (b) adds a second goroutine + fsnotify dep; (c) the simple re-read-on-dial pattern is sufficient when `ConnMaxLifetime` is set.

**Action for Phase 2:** extend `Config` with `passwordPathEnv` (unexported) + `usernameEnv` (unexported), populated when `LoadCredsFromEnv` is used. Cache struct holds the env-var name, Dialer reads it.

Raised by sdk-security-devil finding S-9 (D3).

## P6. Pool alignment

TPRD §3 says "No connection multiplexing beyond go-redis pool" and "No internal circuit breaker" — so we do NOT use `motadatagosdk/core/pool/resourcepool` or `motadatagosdk/core/circuitbreaker`. go-redis has its own pool. Compliant.

## P7. Test discipline

Existing target SDK test style (peek `events/events_test.go`, `otel/tracer/tracer_test.go`):
- `stretchr/testify` assertions.
- Table-driven tests.
- Package-level `TestMain` where needed.
- Benchmarks in `*benchmark_test.go` with `-benchmem`.

Our `*_test.go` and `cachebenchmark_test.go` follow the same shape. Compliant.

## P8. Docs

Existing: each subpackage has `README.md`. Some have `USAGE.md` (events/, pool/memorypool/pool.go-adjacent). Dragonfly adds both:
- `README.md` — one-pager.
- `USAGE.md` — cookbook (see package-layout.md).

Godoc-first (package godoc at top of `cache.go` per events convention). Compliant.

## P9. Godoc marker conventions (G99, G103)

Every exported symbol gets a godoc block that begins with the symbol name (Go convention) and ends with `[traces-to: TPRD-§<n>-<id>]` on a trailing line or in brackets. Pipeline NEVER forges `[owned-by: MANUAL]` markers (G103) — Mode A override confirmed in intake/mode.json.

Example:
```go
// Get returns the string value stored at key, or ErrNil if the key is missing.
// [traces-to: TPRD-§5.2-Get] [constraint: P50 ≤ 200µs | bench/BenchmarkGet]
func (c *Cache) Get(ctx context.Context, key string) (string, error)
```

## P10. What the design explicitly does NOT bring in

Per §3 non-goals, and enforced by package-layout.md:

- No `retry.go` — `MaxRetries=0` fixed (TPRD §3 "No internal retries"). `WithMaxRetries(n)` is still exposed (intake mode.json lists it) to let callers opt out of the default when they know what they're doing; validator should warn if `n>0` in prod. (Design note to impl: log a `Warn` in `New()` if `cfg.MaxRetries != 0`.)
- No `circuitbreaker.go`.
- No `rate_limit.go`.
- No `l1.go` (coherence logic).
- No `tiering.go`.
- No `cluster.go` / hashtag helpers.
- No `scriptregistry.go`.

## P11. Reconciliation summary

| Concern | Existing convention | Dragonfly approach | Deviation? |
|---|---|---|---|
| Constructor arg | Config struct | `opts ...Option` (Config still exported) | **yes, intentional** — TPRD §6 directive |
| TLS shape | `{CertFile, KeyFile, CAFile, SkipVerify}` | +`ServerName`, +`MinVersion` | superset, additive |
| Error model | sentinel vars | sentinel vars | no |
| OTel access | `motadatagosdk/otel/*` | `motadatagosdk/otel/*` | no |
| Pool | package-local (`core/pool/*`) or external | go-redis internal (§3 non-goal) | no |
| Tests | testify + table | testify + table | no |
| Docs | README + USAGE | README + USAGE | no |

Net: **1 intentional deviation (functional options)**, fully justified by TPRD. All else aligned.
