<!-- Generated: 2026-04-18T12:55:00Z | Run: sdk-dragonfly-s2 -->
# sdk-impl-lead — Phase 2 Context Summary (COMPLETED, AWAITING H7)

For downstream `sdk-testing-lead` (Phase 3). Self-contained.

## Status

Phase 2 COMPLETE through Wave M10. H7 summary at `runs/sdk-dragonfly-s2/impl/H7-summary.md`. Awaiting run-driver H7 sign-off before Phase 3 launch.

Branch: `sdk-pipeline/sdk-dragonfly-s2` at HEAD `b83c23e`, 6 commits ahead of base `bd3a4f7`.

## What testing-lead should know

### Test surface
1. **All unit tests pass:** `go test -race -count=1 ./src/motadatagosdk/core/l2cache/dragonfly/...` → 71 PASS, 1 SKIP (HEXPIRE family skipped when miniredis doesn't implement HPEXPIRE family beyond base), 0 FAIL. Overall coverage **90.4%**.
2. **`goleak.VerifyTestMain` wired** in `cache_test.go` with `IgnoreTopFunction("github.com/redis/go-redis/v9/internal/pool.(*ConnPool).reaper")`. If go-redis reaper path changes upstream, update ignore list.
3. **Integration tests** gated on `//go:build integration` — spin up real Dragonfly via testcontainers-go. Use `go test -tags=integration -timeout=5m ./core/l2cache/dragonfly/...` to run. Expected to exercise the full HEXPIRE family (which miniredis doesn't implement beyond base HEXPIRE).
4. **Fuzz targets:** `FuzzMapErr` + `FuzzKeyEncoding` in `errors_test.go`. Run via `go test -fuzz=FuzzMapErr -fuzztime=60s` per TPRD §11.4.
5. **Benchmarks:** `BenchmarkGet`, `BenchmarkSet` (string_test.go), `BenchmarkHExpire` (hash_test.go), `BenchmarkPipeline_100` (pipeline_test.go), `BenchmarkEvalSha` (script_test.go). All carry `[constraint: ...]` markers. Phase 3 must bench with `-benchmem` and verify constraints (P50 ≤ 200µs for Get/Set, P99 ≤ 1ms for HExpire/EvalSha).

### Implementation notes
6. **`runCmd[T any]`** is the hot-path generic wrapper in `cache.go` that dedupes data-path boilerplate. Every string/hash/script/pubsub/raw method delegates through it. Internally it short-circuits on `c.isClosed()` and routes through `instrumentedCall` → `mapErr`.
7. **Metrics lazy-init** via `globalMetrics()` sync.Once — NO `init()` functions. All metrics live in namespace `l2cache.` (`requests`, `errors`, `duration_ms`, six pool gauges).
8. **Pool-stats scraper** bounded via `scraperStopTimeout=5s`. On timeout, logs a Warn and proceeds; goleak may observe the late exit in pathological tests — acceptable. Close ordering: scraper.stop → rdb.Close.
9. **Credential rotation** via `WithCredsFromEnv(userEnv, passPathEnv)` option: captures env-var names on `Config.usernameEnv`/`passwordPathEnv`; go-redis `CredentialsProviderContext` is wired to re-read them on every dial. Combined with default `ConnMaxLifetime=10m`, rotated K8s mounted-secret creds are picked up automatically. Use this (NOT `WithPassword`) for rotation semantics.
10. **HTTL conversion** extracted into `secondsToDurations` helper — go-redis v9 returns `[]int64` seconds; we widen to `[]time.Duration` preserving negative wire sentinels (-1 no TTL, -2 no field).
11. **Watch** returns user errors unchanged; only go-redis transport/tx errors are mapped. Test `TestWatch_PropagatesError` asserts this.

### Dep-policy status
12. Approved bumps landed in commit `08d2b15`: testcontainers-go v0.42.0 + goleak v1.3.0 + otel v1.41.0 (core/metric/trace) + klauspost/compress v1.18.5. All per Option-A directive.
13. Forbidden pins preserved: `golang.org/x/crypto@v0.48.0`, `go 1.26` toolchain, `redis/go-redis/v9@v9.18.0`, `alicebob/miniredis/v2@v2.37.0`, `testify@v1.11.1`.
14. **One new govulncheck finding** beyond H6 baseline: `go.opentelemetry.io/otel/sdk@v1.39.0` (GO-2026-4394, PATH hijacking; fixed in v1.40.0). Pre-existing; NOT reachable from dragonfly. Bumping requires a new escalation (otel/sdk was NOT in Option-A's approved list — only otel/core, metric, trace were).

### Marker / guardrail compliance
15. **145 `[traces-to: TPRD-…]` markers** across 14 production `.go` files. Every exported symbol covered (G99). Zero forged `[owned-by: MANUAL]` markers (G103). Constraint markers on Get/Set/HExpire/EvalSha reference their bench IDs (G97).

## Guardrails pre-Phase-3

All G40 / G41 / G42 / G43 / G50 / G52 / G63 / G69 / G97 / G99 / G103 PASS per H7-summary §J. G95/G96/G100/G101 N/A for Mode A.

## Hand-off items for testing-lead

1. Bench the package with `-benchmem` and validate constraint markers.
2. Run integration tests with `-tags=integration` for full HEXPIRE family coverage.
3. Fuzz `FuzzMapErr` + `FuzzKeyEncoding` ≥60s each per §11.4.
4. Re-run `govulncheck` + `osv-scanner` as Phase 3 pre-gate; confirm nothing new surfaces from the dragonfly change.
5. If benchmarks show regressions vs pre-bump baseline (otel v1.39 → v1.41), escalate per Rule 20 (>5% on new-pkg hot path = BLOCKER).
