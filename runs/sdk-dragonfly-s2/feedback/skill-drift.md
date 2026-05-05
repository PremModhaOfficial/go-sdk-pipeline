# Skill Drift Report
<!-- Generated: 2026-04-18T15:05:00Z | Run: sdk-dragonfly-s2 -->

**Pipeline version:** 0.2.0
**Run mode:** A (greenfield override of Mode-B TPRD; see seq 3)
**Target SDK branch:** `sdk-pipeline/sdk-dragonfly-s2` @ `a4d5d7f`
**Scope:** `motadata-go-sdk/src/motadatagosdk/core/l2cache/dragonfly/`

Scope-note on method: of the 19 PRESENT skills in the TPRD §Skills-Manifest, **8 are draft seed-stubs (v0.1.0, status `draft`)** with no prescriptive body — only a `Purpose (seed)` one-liner and an activation-signal placeholder. For those skills, "drift" is measured against the seed-purpose statement plus the TPRD sections that keyed them in as MUST. The remaining 11 are `stable` v1.0.0/v1.1.0 skills with full prescriptive content.

---

## Invoked skills (this run)

Per `feedback/skill-coverage.md` Table 3, 16 of 19 PRESENT skills were invoked. The three declared-but-unused are noted in §Drift not triggered below and left out of drift scan (no code to compare to).

| Skill | Version | Status | Invoked phases |
|---|---|---|---|
| sdk-config-struct-pattern | 0.1.0 | draft-seed | intake, design, impl |
| otel-instrumentation | 1.0.0 | stable | intake, design, impl, testing |
| sdk-otel-hook-integration | 0.1.0 | draft-seed | intake, design, impl, testing |
| network-error-classification | 0.1.0 | draft-seed | intake, design, impl |
| go-error-handling-patterns | 1.0.0 | stable | (declared-but-unused; see coverage.md §Table 2) |
| go-concurrency-patterns | 1.0.0 | stable | design, impl |
| goroutine-leak-prevention | 0.1.0 | draft-seed | intake, design, impl, testing |
| client-shutdown-lifecycle | 0.1.0 | draft-seed | intake, design, impl |
| client-tls-configuration | 0.1.0 | draft-seed | intake, design, impl |
| connection-pool-tuning | 0.1.0 | draft-seed | intake, design, impl |
| credential-provider-pattern | 0.1.0 | draft-seed | intake, design, impl |
| testcontainers-setup | 1.0.0 | stable | design, testing |
| table-driven-tests | 1.0.0 | stable | impl, testing |
| testing-patterns | 1.0.0 | stable | impl, testing |
| fuzz-patterns | 1.0.0 | stable | impl, testing |
| tdd-patterns | 1.0.0 | stable | impl |
| sdk-marker-protocol | 0.1.0 | draft-seed | intake, design, impl |
| sdk-semver-governance | 0.1.0 | draft-seed | intake, design |
| go-dependency-vetting | 0.1.0 | draft-seed | intake, design, testing |

---

## Drift findings

### SKD-001: sdk-config-struct-pattern — MINOR drift (informed divergence)

**Skill prescribes (seed purpose):** `Config struct + New(cfg)` — "when to use functional options instead".

**Code does:** `Config struct` is exported (`config.go:40`), but construction is functional-options only: `New(opts ...Option) (*Cache, error)` at `cache.go:78`. No `New(cfg Config)` form is exposed.

**Drift type:** pattern-shape divergence from the bare seed-purpose line, **but explicitly authorized** by TPRD §6 ("all setters in `options.go`") and CLAUDE.md Rule #6 ("`Config struct + New(cfg)` OR functional options — match target SDK convention"). The target SDK `motadatagosdk/events` uses the same `With*` shape. Pattern-advisor and sdk-designer documented the choice in `design/context/pattern-advisor-summary.md`.

**Severity:** MINOR. The TPRD explicitly overrides the default; Config is still exported so power users can build one directly. Consistent with sibling `events` package.

**Recommendation:** Promote `sdk-config-struct-pattern` from draft to stable with a full body that codifies the "Config struct + functional options" shape used in this run as the canonical target-SDK convention (not just the minimal `New(cfg)` form). This is a skill-body upgrade, not a code fix.

---

### SKD-002: otel-instrumentation — NONE

**Skill prescribes (stable body):** TracerProvider/MeterProvider via OTel SDK; graceful shutdown; batched exporters; trace-context propagation.

**Code does:** all instrumentation routes through `motadatagosdk/otel/tracer` and `motadatagosdk/otel/metrics` (ref `cache.go:46`, `metrics.go:7`). Every data-path call starts a client span `dfly.<cmd>` via `c.instrumentedCall` (`cache.go:201`). Span attrs match TPRD §8.1 (`db.system=redis`, `server.address`, `dfly.cmd`). Metrics namespace `l2cache.*` per TPRD §8.2. Span error via `span.SetError`; cardinality guarded (cmd is a compile-time literal, enforced by AST test `observability_test.go` T9).

**Severity:** NONE. Full alignment; Phase 3 T9 added AST-based conformance suite to lock it in.

---

### SKD-003: sdk-otel-hook-integration — NONE

**Skill prescribes (seed purpose):** wire new clients into `motadatagosdk/otel` (not raw OTel); span names + attribute conventions.

**Code does:** imports `motadatagosdk/otel/logger`, `motadatagosdk/otel/metrics`, `motadatagosdk/otel/tracer` exclusively. Zero imports of `go.opentelemetry.io/otel/*` direct API in client code. Observability AST test explicitly forbids forbidden attribute names (`key`, `value`, `password`, `payload`, `secret`, `token`).

**Severity:** NONE.

**Recommendation:** Promote this skill from draft to stable; the dragonfly code is a textbook worked example for the future skill body.

---

### SKD-004: network-error-classification — NONE

**Skill prescribes (seed purpose):** transient / permanent / retryable taxonomy; wraps sentinels with retry intent.

**Code does:** 26 sentinels in `errors.go:19-128`; `mapErr` is an 11-step precedence switch (`errors.go:137-224`); `classify()` emits a bounded 6-value metric label (`errors.go:232-255`). Retry-intent is implicit in the taxonomy (timeout / unavailable / nil are transient; wrong_type / auth / syntax are permanent). No retry policy is embedded in the SDK itself per TPRD §3 non-goal — that is an external-compose concern.

**Severity:** NONE (depth actually exceeds seed purpose).

**Recommendation:** When `sentinel-error-model-mapping` (currently WARN-absent) is human-authored, this dragonfly `mapErr` is the reference implementation.

---

### SKD-005: go-error-handling-patterns — MODERATE coverage-drift (not code-drift)

**Skill prescribes (stable body):** `AppError` hierarchy, `fmt.Errorf("%w: %v", Sentinel, cause)` wrapping, `errors.Is`/`errors.As`, PII-safe messages.

**Code does:** uses `fmt.Errorf("%w: %v", Sentinel, cause)` consistently (25 sites across `errors.go`, `config.go`, `loader.go`, `cache.go`). `errors.Is` is the documented matcher in TPRD §7 and is used in tests. The TPRD explicitly rejects the skill's `AppError` hierarchy in favor of a sentinel-only model ("no custom error types, no wrapping beyond `fmt.Errorf("%w: %v", ...)` — §1 goals).

**Drift type:** the code pattern is aligned with the skill's mid-level prescription (sentinel + %w wrap) but diverges from the skill's top-level prescription (AppError hierarchy with Code, HTTPStatus, Stack fields). The TPRD §1 explicitly rejects this. Additionally, per skill-coverage Table 2, no agent cited this skill by name during the run — it was not invoked despite being declared in the manifest. The work was done under the (draft) `network-error-classification` skill instead.

**Severity:** MODERATE. Not a code-quality defect; it is a **skill-library drift**: the `go-error-handling-patterns` stable body is tuned for NATS/HTTP services (AppError+HTTPStatus), not SDK clients (sentinel-only). Either split the skill or add an "SDK client mode" decision branch.

**Recommendation:** feed into improvement-planner as Action-1 — split `go-error-handling-patterns` into a service-mode (AppError) and SDK-client-mode (sentinel-only) subskill, or expand its body to document both decision paths.

---

### SKD-006: go-concurrency-patterns — NONE

**Skill prescribes (stable body):** errgroup for worker pools, `context.Context` propagation, graceful shutdown, sync primitives.

**Code does:** single goroutine in `poolstats.go:42` (started via `sync.Once` in `start()`); teardown via `close(s.done)` with `sync.Once` guard in `stop()` and bounded `<-s.stopped || time.After(scraperStopTimeout)` at `poolstats.go:80-88`. `context.Context` first param on every I/O method (G42 PASS per impl-summary). No raw goroutine spawn without named shutdown channel.

**Severity:** NONE.

---

### SKD-007: goroutine-leak-prevention — NONE

**Skill prescribes (seed purpose):** goleak patterns, `-race` hygiene, ctx-cancelled goroutine exits.

**Code does:** `goleak.VerifyTestMain(m, goleak.IgnoreTopFunction("github.com/redis/go-redis/v9/internal/pool.(*ConnPool).reaper"))` at `cache_test.go:18-23`. Scraper goroutine bounded by `scraperStopTimeout = 5s` (`const.go`), warn-and-proceed on timeout, not leak. Phase 3 T6 leak-hunt reported 0 leaks across `-race -count=5`.

**Severity:** NONE.

**Recommendation:** Promote skill to stable. The `IgnoreTopFunction` entry for go-redis reaper is a reusable pattern worth codifying.

---

### SKD-008: client-shutdown-lifecycle — NONE

**Skill prescribes (seed purpose):** `Close()` / `Stop()` contract — drain in-flight, cancel loops, ordered sub-resource close.

**Code does:** `Close()` at `cache.go:166-185`: idempotent via `closed.CompareAndSwap(false, true)`; ordered teardown (scraper first, then `rdb.Close`); `redis.ErrClosed` swallowed on double-close race; returns `ErrUnavailable`-wrapped on real error. `isClosed()` short-circuit at top of every data-path call (via `runCmd`).

**Severity:** NONE.

---

### SKD-009: client-tls-configuration — NONE

**Skill prescribes (seed purpose):** min version, cipher suites, cert verification, system trust store integration.

**Code does:** `TLSConfig` struct (`config.go:14-34`) with `MinVersion` (defaults to `tls.VersionTLS12`, TPRD §9 prefers 1.3), `ServerName` required unless `SkipVerify` (validated at `config.go:127`), `systemCertPoolWithExtra` (`loader.go:66-78`) uses `x509.SystemCertPool()` fallback. `SkipVerify=true` does NOT block validation — TPRD §9 calls it prod-unsafe and "validator warns"; current code only warns at log level, no runtime error. Test coverage exists in `helpers_test.go` (AST inspection confirms `MinVersion`, `ServerName` validation paths).

**Severity:** NONE with one observation — the SkipVerify WARN signal is logged but never bubbles to caller as a prominent warning struct. TPRD §9 says "validator warns", which the code satisfies via `logger.Warn`, but this is easy to silence in prod log config. Not drift, just a defense-in-depth observation for improvement-planner.

---

### SKD-010: connection-pool-tuning — NONE

**Skill prescribes (seed purpose):** sizing heuristics for `motadatagosdk/core/pool/` — min/max, idle timeout, healthcheck cadence.

**Code does:** uses go-redis pool knobs directly (not `motadatagosdk/core/pool/` — that's events-layer). `PoolSize` default 10, `PoolTimeout` 1s, `ConnMaxLifetime` 10m (per `const.go`), `PoolStatsInterval` 10s with 1s floor and 5m ceiling validated (`config.go:130-137`). Six pool gauges scraped (`poolstats.go`). `WithPoolSize` / `WithPoolTimeout` / `WithConnMaxLifetime` / `WithPoolStatsInterval` options exposed.

**Drift type:** scope mismatch — skill seed-purpose targets `motadatagosdk/core/pool/`, but dragonfly uses go-redis's built-in pool (per TPRD §1: "Thin opinionated wrap of go-redis"). This is intentional; TPRD explicitly avoids a custom pool layer.

**Severity:** NONE (scope is out-of-bounds for seed-purpose, but code meets the intent of the skill as applied to go-redis's pool).

**Recommendation:** When promoting `connection-pool-tuning` to stable, broaden the scope to cover "any connection pool the SDK composes with" not just the house `core/pool/`.

---

### SKD-011: credential-provider-pattern — NONE

**Skill prescribes (seed purpose):** pluggable credential source — static / env / file / provider-chain; no creds in config literal.

**Code does:** `LoadCredsFromEnv(userEnv, passPathEnv)` (`loader.go:33-54`) — env-var-names point to live values/paths (username direct, password from file). `WithCredsFromEnv` option (`options.go:38-50`) wires `reloadPassword` / `reloadUsername` into go-redis's `CredentialsProviderContext` so the Dialer re-reads on every reconnect. `ConnMaxLifetime=10m` default forces reconnect cadence for K8s secret rotation. `WithPassword` docstring explicitly steers callers to `LoadCredsFromEnv` for rotation. No plaintext password in any config literal, span attr, or log (verified by T9 observability AST test forbidden-attr list).

**Severity:** NONE.

**Recommendation:** The `CredentialsProviderContext` pattern + `ConnMaxLifetime` reconnect trick is a novel target-SDK idiom. Worth codifying when promoting `credential-provider-pattern` + `k8s-secret-file-credential-loader` (WARN-absent) to stable.

---

### SKD-012: testcontainers-setup — NONE (with matrix gap)

**Skill prescribes (stable body):** testcontainers-go for Postgres/NATS/Redis; shared TestMain; sync.Once reuse.

**Code does:** `cache_integration_test.go` gated on `//go:build integration`, spins up `docker.dragonflydb.io/dragonflydb/dragonfly:latest` with `wait.ForListeningPort`. `t.Cleanup` terminates container. Three tests: `TestIntegration_BasicFlow`, `TestIntegration_HExpire`, `TestIntegration_ChaosKill` (last one t.Skip pending CI chaos infra). No `sync.Once` container reuse pattern — each test boots its own Dragonfly (7+ seconds per test observed in Phase 3 T2).

**Drift type:** the skill's sync.Once-reuse pattern is absent — each integration test bears the full container-boot cost. Phase 3 T2 observed 14+ seconds total for two live tests; this does not scale if the suite grows.

**Severity:** MINOR. Integration is gated behind a build tag and behind CI, so runtime cost is absorbed by infra not developers. The TPRD §11.2 calls for a TLS/ACL matrix that isn't implemented — if added, per-test boot will become painful.

**Recommendation:** For the future `testcontainers-dragonfly-recipe` skill (currently WARN-absent), codify sync.Once-shared-container and TLS/ACL matrix table-driven pattern.

---

### SKD-013: table-driven-tests — NONE

**Skill prescribes (stable body):** test struct, `t.Run` subtests, `t.Cleanup`, `t.Parallel` where safe.

**Code does:** `for _, tc := range cases` loops with `t.Run(tc.name, ...)` in `cache_test.go:71`, `errors_test.go:46`. `helpers_test.go`, `string_test.go`, `hash_test.go`, etc. use the pattern too (confirmed by impl-summary §test-surface). `t.Cleanup(func() { _ = c.Close() })` at `cache_test.go:38`. **Zero `t.Parallel()` calls** in the package.

**Drift type:** `t.Parallel()` is NOT used anywhere. Skill body: "Use `t.Parallel()` only when test cases share no mutable state." Since every test boots a fresh miniredis via `newTestCache`, parallelism would actually be safe. Missing opportunity, not a violation.

**Severity:** MINOR. Test suite takes ~30s; could be faster with `t.Parallel`.

**Recommendation:** Phase 4 improvement-planner could propose adding `t.Parallel()` to pure-table tests that use fresh `newTestCache` per subtest. Not load-bearing.

---

### SKD-014: testing-patterns — NONE

**Skill prescribes (stable body):** table-driven, testcontainers, gomock, httptest, fixtures, benchmarks, coverage ≥90%.

**Code does:** 90.4% coverage (T1 PASS, threshold 90%), 11 `_test.go` files, 5 benchmarks with `-benchmem`. `gomock` not used (dragonfly has no interface layers requiring mocks beyond the live miniredis backend — deliberate per TPRD §15 Q3: "return concrete *Cache; tests use miniredis"). `httptest` N/A (not an HTTP client).

**Severity:** NONE.

---

### SKD-015: fuzz-patterns — NONE

**Skill prescribes (stable body):** `f.Add()` seeds, `f.Fuzz(func(t, ...))`, corpus in `testdata/fuzz/`, crash triage, CI fuzztime bounded.

**Code does:** `FuzzMapErr(f *testing.F)` at `errors_test.go:143` with 16 seed strings covering every mapErr prefix; property assertion walks the error chain for a known sentinel (`errors_test.go:188-200`). `FuzzKeyEncoding(f *testing.F)` at `errors_test.go:205` seeds plain/spaces/unicode/NUL keys; property: round-trip Set→Get returns the same value. Phase 3 T7: 659k execs FuzzMapErr, 180k execs FuzzKeyEncoding, 0 crashes.

**Severity:** NONE.

---

### SKD-016: tdd-patterns — NONE

**Skill prescribes (stable body):** red → green → refactor cycle, interface-driven test design.

**Code does:** per impl-summary §test-surface and decision-log seq 42, M1 red-phase tests were committed BEFORE M3 green implementations. Each slice (S2/S3/S4/S5/S6) followed this cadence. The observability_test.go AST suite in T9 was added after green as an invariant-lock (valid refactor-phase addition).

**Severity:** NONE.

---

### SKD-017: sdk-marker-protocol — NONE

**Skill prescribes (seed purpose):** `[traces-to:]`, `[constraint:]`, `[stable-since:]`, `[owned-by:]`, etc.

**Code does:** 225 total marker occurrences across 28 files (14 production + 14 test/doc). 145 `[traces-to: TPRD-...]` markers across production `.go` files (per impl-summary §15). Every exported symbol has a `[traces-to:]` marker in godoc (G99 PASS). Constraint markers present: `[constraint: P50 ≤ 200µs | bench/BenchmarkGet]` on `Get` (`string.go:11`), same on `Set` (`string.go:20`), `[constraint: P99 ≤ 1ms | bench/BenchmarkEvalSha]` on `EvalSha` (`script.go:19`), `[constraint: P50 ≤ 200µs | bench/BenchmarkHExpire]` on `HExpire` (confirmed in hash.go). Zero forged `[owned-by: MANUAL]` markers (G103 PASS). Mode-A run so no `[do-not-regenerate]` or `[stable-since]` expected.

**Severity:** NONE.

---

### SKD-018: sdk-semver-governance — NONE (N/A for code drift)

**Skill prescribes (seed purpose):** public API diff; classify breaking changes; force correct semver bump.

**Code does:** N/A at code layer — this is a process skill. Design-phase `sdk-semver-devil` rendered ACCEPT-minor verdict (seq 62 + `design/reviews/sdk-semver-devil-D3.md`). Mode-A first-emission, so minor bump from v0.x.0 to v0.(x+1).0 is authoritative; no pre-existing exported surface was broken.

**Severity:** NONE.

---

### SKD-019: go-dependency-vetting — NONE

**Skill prescribes (seed purpose):** license / CVE / maintenance / size gate on every `go get`.

**Code does:** Phase 3 T8 supply chain: `govulncheck` and `osv-scanner` both clean within dragonfly reachability (one pre-existing finding on `otel/sdk v1.39.0` is upstream and not reachable from this package). Dep-vet-devil emitted CONDITIONAL-ACCEPT at design (seq 61). License allowlist honored (all deps MIT/Apache-2.0/BSD). Forbidden pins preserved: `go-redis v9.18.0`, `miniredis/v2 v2.37.0`, `testify v1.11.1`.

**Severity:** NONE.

---

## Drift not triggered

Three skills were DECLARED in the TPRD manifest but NEVER invoked by any agent (per skill-coverage.md §Table 2): `go-error-handling-patterns` (addressed above as SKD-005 due to declared-and-present status), `go-example-function-patterns`, and `tdd-patterns` during the testing phase specifically. These are **coverage gaps** (skill-not-fired), not **drift** (code-violates-skill). Escalated in Table 2 of skill-coverage.md; feed into improvement-planner.

---

## WARN-absent skills — observations

The 8 WARN-absent skills were filed to `docs/PROPOSED-SKILLS.md` at intake. Phase outputs show agents synthesized guidance from in-pipeline general patterns. Specific observations per `design/skill-gaps-observed.md`:

| WARN-absent skill | Would-have-helped area | Where compensated |
|---|---|---|
| sentinel-error-model-mapping | `mapErr` 11-step precedence chain | `network-error-classification` (draft) + TPRD §7 |
| pubsub-lifecycle | caller-owns-Close contract docs in `pubsub.go:23` | `goroutine-leak-prevention` + `client-shutdown-lifecycle` |
| hash-field-ttl-hexpire | Redis 7.4 HEXPIRE return-code semantics | TPRD §5.3 only; `secondsToDurations` helper invented in-pipeline |
| miniredis-testing-patterns | `newTestCache` helper pattern | `testing-patterns` + `table-driven-tests` |
| lua-script-safety | EVALSHA-fallback-to-EVAL NOSCRIPT retry | TPRD §5.6 only; caller owns EVALSHA cache per §3 non-goal |
| testcontainers-dragonfly-recipe | shared-container + TLS/ACL matrix | `testcontainers-setup` (but without sync.Once reuse — see SKD-012) |
| k8s-secret-file-credential-loader | env-pointer + file-content pattern | `credential-provider-pattern` (draft) |
| redis-pipeline-tx-patterns | explicit MULTI/EXEC + WATCH retry convention | TPRD §5.4 only; code returns raw `redis.Pipeliner` |

---

## Summary — drift count by severity

| Severity | Count | IDs |
|---|---:|---|
| NONE | 14 | SKD-002, 003, 004, 006, 007, 008, 009, 010, 011, 014, 015, 016, 017, 018, 019 |
| MINOR | 3 | SKD-001 (authorized divergence), SKD-012 (matrix gap), SKD-013 (t.Parallel missing opportunity) |
| MODERATE | 1 | SKD-005 (skill-body coverage-drift for `go-error-handling-patterns`) |
| MAJOR | 0 | — |

**Zero MAJOR drift.** No follow-up required by improvement-planner for correctness. Three MINOR items and one MODERATE item feed improvement-planner for skill-library evolution (not code fixes):

1. Promote 8 draft seed-stub skills to stable, using the dragonfly run as the reference implementation.
2. Split or branch `go-error-handling-patterns` for service-mode vs SDK-client-mode (SKD-005).
3. When authoring `testcontainers-dragonfly-recipe` (PROPOSED-SKILLS.md), codify sync.Once shared-container pattern (SKD-012).
4. Consider recommending `t.Parallel()` in table-driven tests for dragonfly package (SKD-013).

No HALT signal. No ESCALATION. Phase 4 F6 improvement-planner and F7 learning-engine (patch-level only per F5 golden-corpus advisory) may proceed.
