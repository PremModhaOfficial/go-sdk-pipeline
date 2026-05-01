# Phase 3: Testing

## Purpose

Exhaustive verification beyond the TDD tests written in Phase 2. Adds integration tests against real backends, benchmarks vs. baseline, fuzz, leak verification, and flake detection.

## Input

- Target branch (`sdk-pipeline/<run-id>`) in `$SDK_TARGET_DIR`
- `runs/<run-id>/design/*`
- `baselines/go/performance-baselines.json`

## Waves

### Wave T1 — Unit Coverage Audit
**Agent**: `unit-test-agent`
- Run `toolchain.coverage`
- Report per-package branch coverage
- Fill gaps with new table-driven tests (error paths, edge cases, boundary values, nil inputs, concurrent access)
- Target: ≥90% per new package; zero delta on existing (Mode B/C)

### Wave T2 — Integration (testcontainers)
**Agent**: `integration-test-agent`
- Set up testcontainers recipe per backend: redis, dragonfly, minio, localstack, kafka, rabbitmq, etc.
- Tag files `//go:build integration`
- Test full lifecycle: connect → operate → close → verify cleanup
- Tenant isolation NOT applicable (SDK is a library)

### Wave T3 — Flake Hunt
**Agent**: Integration Flake Hunter (per-pack, resolved from `waves.T3_flake_hunt`)
- Run integration tests `-count=3`
- Any failure = flaky; BLOCKER until investigated + fixed

### Wave T4 — Benchmarks
**Agent**: `performance-test-agent`
- Write `*_benchmark_test.go` for every hot path declared in TPRD §5 NFR
- Run `toolchain.bench`
- Capture output to `runs/<run-id>/testing/bench-raw.txt`

### Wave T5 — Benchmark Devil
**Agent**: Benchmark Devil (per-pack, resolved from `waves.T5_bench_complexity`)
- Compare raw output against `baselines/go/performance-baselines.json` for shared packages
- For new package: capture baseline (first run = baseline)
- benchmark-comparison tool (per-pack) compare; verdict PASS / REGRESS / ACCEPT-WITH-WAIVER
- Regression gate (from settings.json): hot path +5%, shared +10%
- FAIL = BLOCKER unless `--accept-perf-regression <n>`

### Wave T6 — Leak Hunt
**Agent**: leak hunter (per-pack, resolved from `waves.T6_leak`)
- Ensure the pack's leak-detection harness (`toolchain.leak_check`) in new package's TestMain
- Run `toolchain.test` (with race detection if supported)
- Any leak = BLOCKER

### Wave T7 — Fuzz (conditional)
**Agent**: `fuzz-agent` (new, minimal)
- If TPRD §11 lists fuzz targets, write `FuzzXxx` functions
- Seed corpus from happy path + edge cases
- Run fuzz harness (per-pack)
- Record crashes

### Wave T8 — Supply Chain
**Agent**: `guardrail-validator`
- the pack's vulnerability scanner (`toolchain.supply_chain[0]`) — zero HIGH/CRITICAL
- the pack's lockfile vulnerability scanner (`toolchain.supply_chain[1]`) — zero HIGH/CRITICAL

### Wave T9 — Observability Tests (conditional)
**Agent**: `observability-test-agent`
- If TPRD §8 listed required spans/metrics: verify they actually emit
- In-memory OTel exporter; span matchers

### Wave T10 — Mutation (optional)
**Agent**: `mutation-test-agent`
- Run on critical business logic packages
- Target: 70%+ mutation score
- Kill surviving mutants with additional tests

### Wave T11 — HITL Gate H8 (if any regression)
**Artifact**: `runs/<run-id>/testing/perf-delta.md`
**Options**: Accept (+ file follow-up) / Reject
**Default**: Reject
**Bypass**: `--accept-perf-regression <n>`

## Exit artifacts

- Test files merged onto branch
- `runs/<run-id>/testing/coverage.txt`
- `runs/<run-id>/testing/bench-raw.txt`
- `runs/<run-id>/testing/bench-compare.md`
- `runs/<run-id>/testing/supply-chain.txt`
- `runs/<run-id>/testing/osv-scan.txt`
- `runs/<run-id>/testing/testing-summary.md`

## Guardrails (exit gate)

G60 (all tests pass (with race detection if supported)), G61 (coverage ≥90%), G62 (leak harness wired in test entrypoint), G63 (no flakes under repeat-count=3), G64 (benchmark produces numeric results), G65 (bench within gate), G66 (integration test exclusion tag), G67 (runnable examples per area, per pack — `Example_*` in Go, doctest in Python), G68 (traces-to in tests), G69 (no hardcoded creds).

## Metrics

- `test_coverage_pct` (target ≥90%)
- `benchmark_delta_pct`
- `vuln_count` (must be 0)
- `leak_count` (must be 0)
- `flake_rate` (must be 0)
- `mutation_score_pct` (if run)
- `testing_duration_sec`

## Typical durations

- Mode A simple: ~45 min (integration containers take most time)
- Mode B extension: ~30 min (fewer new tests, existing bench re-runs)
- Mode C incremental: ~20 min
