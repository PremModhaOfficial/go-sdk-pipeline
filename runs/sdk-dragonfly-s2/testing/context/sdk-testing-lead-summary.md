<!-- Generated: 2026-04-18T14:35:00Z | Run: sdk-dragonfly-s2 -->
# sdk-testing-lead handoff to Phase 4 Feedback

## One-line status

Phase 3 Testing complete. All hard gates (coverage, race, goleak, flake, fuzz, vuln) PASS. One soft gate (bench allocs-per-GET constraint in TPRD §10) FAIL → H8 gate required before H9 close. Phase 4 may proceed post-H8 disposition.

## What Phase 4 feedback-lead should know

### Branch state

- `sdk-pipeline/sdk-dragonfly-s2` HEAD is `a4d5d7f` (+1 commit vs Phase 2 HEAD `b83c23e`).
- Testing-phase commit: `a4d5d7f test(dragonfly): Phase 3 T9 observability conformance tests` — 270 LOC, no prod changes, no new deps.
- All writes respected target-dir discipline (only `src/motadatagosdk/core/l2cache/dragonfly/` in target repo, only `runs/sdk-dragonfly-s2/` and `baselines/performance-baselines.json` in pipeline repo).

### Coverage and quality numbers for drift-tracking

- **Coverage:** 90.4% statements (threshold 90%; ratio 1.00x).
- **Test count:** 71 unit PASS + 2 integration PASS + 4 observability PASS = 77 tests passing.
- **Lifetime SKIP:** 2 (miniredis HPEXPIRE family, docker-chaos requires infra).
- **Bench baseline:** captured to `baselines/performance-baselines.json`; serves as the regression compare for any future dragonfly-scope run (Mode B/C).

### Outstanding H8 — one bench-constraint conflict

TPRD §10 says `≤3 allocs per GET`. Measured: 32 allocs/op on miniredis. `go-redis/v9.18` itself allocates ~25–30 per roundtrip; the dragonfly wrapper adds ~5. Target was likely set before client selection. Run driver is deciding between:
- (a) accept-with-waiver at 35 allocs (recommended for expediency)
- (b) client swap to rueidis (major design decision, not Phase-4 scope)
- (c) re-scope to wrapper-only allocs, proven via A/B bench (recommended as Phase-4 slice)

Phase 4 does NOT re-run this decision; it observes whichever resolution the run driver logs and records the post-H8 baseline.

### Supply-chain snapshot

- govulncheck: 10 call-reachable vulns, all pre-existing target-SDK baseline (Go 1.26.0 stdlib + otel/sdk 1.39.0). Exempt per H6/H7.
- osv-scanner: 17 distinct findings (nats-server, otel-exporters, otel-sdk, grpc) — all pre-existing; ZERO in dragonfly-introduced deps (testcontainers-go 0.42.0, goleak 1.3.0, otel 1.41.0, klauspost 1.18.5).
- Licenses: allowlist clean (Apache-2.0 confirmed for opencontainers/go-digest code; CC-BY-SA applies only to that repo's docs).

### Gaps filed for Phase 4 backlog

1. **BenchmarkHSet absent** (TPRD §11.3 listed; HSet cost profile similar to HExpire which IS benched) — minor.
2. **A/B harness absent** (raw go-redis vs wrapped Cache; blocks §10 "≤5% overhead" verification) — would resolve H8 option (c).
3. **Load-test absent** (10k ops/sec sustained constraint UNMEASURED; derived 37k ops/sec theoretical) — may be deferred to CI perf-lane.
4. **Integration matrix partial** (TLS on/off × ACL on/off × full HEXPIRE family not exercised live; basic flow + single HExpire call covered) — deferred to CI.
5. **Observability test uses static AST analysis, not live in-memory exporter** (motadatagosdk/otel/tracer has no test-recording hook). Follow-up: either add a tracetest hook to otel/tracer or run a proper OTLP capture test in CI.
6. **Mutation testing not run** (T10 skipped; no gremlins/go-mutesting installed).

### Decision-log entries written

seq 51–64 (14 entries; under per-agent-per-run cap of 15). All tagged and typed correctly.

### What NOT to do in Phase 4

- Do not open any new git-scope work on the dragonfly package. Testing added exactly one file (`observability_test.go`) to the target; nothing else should change until H10 merge.
- Do not re-run the T5 bench (numbers are already baseline'd). A re-run would capture slightly different ns/op due to CPU noise and could cause false-positive drift alerts.
- Do not attempt to bump `otel/sdk@1.39.0` → 1.40 to clear GO-2026-4394; this was deliberately deferred by H6/H7 as an out-of-scope target-SDK-wide change.

### Escalations open

**None from testing.** Only the run driver's H8 disposition remains.
