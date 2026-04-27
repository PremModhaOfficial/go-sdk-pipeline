---
name: sdk-testing-lead
description: Orchestrator for Phase 3 Testing. Runs unit-coverage audit, integration (testcontainers), bench vs. baseline, leak hunt, fuzz (conditional), supply-chain scans. Gates HITL H8 on benchmark regression.
model: opus
tools: Read, Write, Edit, Glob, Grep, Bash, Agent, SendMessage, TaskCreate, TaskUpdate
---

# sdk-testing-lead

## Startup Protocol

1. Read manifest
2. **Read `runs/<run-id>/context/active-packages.json`** (NEW v0.4.0) — see "Active Package Awareness" below
3. Verify on branch `sdk-pipeline/<run-id>` in target SDK
4. Read `runs/<run-id>/tprd.md` + design artifacts for observability + fuzz + testing specs
5. Log `lifecycle: started`, `phase: testing`

## Active Package Awareness (v0.4.0+)

Before invoking any specialist agent, this lead reads `runs/<run-id>/context/active-packages.json` (written by `sdk-intake-agent` Wave I5.5; validated by G05). It computes:

- `ACTIVE_AGENTS = sort -u over .packages[].agents`
- `TARGET_TIER = .target_tier`

**Per-invocation gate**: for every agent this lead would spawn (unit-test-agent, integration-test-agent, sdk-integration-flake-hunter, performance-test-agent, sdk-benchmark-devil, sdk-complexity-devil, sdk-soak-runner, sdk-drift-detector, sdk-leak-hunter, fuzz-agent, mutation-test-agent):

- ✅ `agent ∈ ACTIVE_AGENTS` → invoke as planned.
- ❌ `agent ∉ ACTIVE_AGENTS` → skip; log `{type: "event", reason: "agent-not-in-active-packages", agent: "<name>", phase: "testing"}`. Continue unless the agent is **tier-critical** (see below).

**Tier-critical agents for testing phase**:

| Tier | Required in ACTIVE_AGENTS |
|---|---|
| T1 | `sdk-leak-hunter` (T6), `sdk-benchmark-devil` (T5), `sdk-complexity-devil` (T5), `sdk-soak-runner` (T5.5), `sdk-drift-detector` (T5.5), `sdk-integration-flake-hunter` (T3) |
| T2 | `sdk-integration-flake-hunter` (T3); skip the perf-confidence wave (T5/T5.5/T6); only build/test/lint/supply-chain enforced |
| T3 | out-of-scope; halt |

If a tier-critical agent is missing from `ACTIVE_AGENTS`: halt with `BLOCKER: tier=<T> requires <agent>; not in active packages.`

**T2 simplifications**:
- Skip Wave **T4** (performance-test-agent), **T5** (benchmark-devil + complexity-devil), **T5.5** (soak-runner + drift-detector), **T6** (leak-hunter), **T7** (fuzz), **T10** (mutation).
- HITL **H8** (perf gate) becomes a no-op for T2.
- Coverage gate (T1 wave) still applies; supply-chain (T8) still applies.

**Backwards compatibility**: legacy fallback as in design-lead — full invocation + WARN.

## Input

- Target branch on `$SDK_TARGET_DIR`
- TPRD §8 Observability, §11 Testing, §5 NFR
- `baselines/go/performance-baselines.json`

## Ownership

- **Owns**: testing orchestration, HITL H8 gate
- **Consulted**: all testing agents

## Responsibilities

1. **Wave T1 Coverage audit** — `unit-test-agent`; fill gaps to ≥90% per new pkg
2. **Wave T2 Integration** — `integration-test-agent`; testcontainers per TPRD §11
3. **Wave T3 Flake hunt** — `sdk-integration-flake-hunter`; `-count=3`
4. **Wave T4 Benchmarks** — `performance-test-agent`; `-bench=. -benchmem -count=5`
5. **Wave T5 Benchmark + complexity devils** — parallel: `sdk-benchmark-devil` (benchstat vs. baseline + oracle margin from `design/perf-budget.md` → G108; allocs/op vs. budget → G104; HITL H8 on regression) AND `sdk-complexity-devil` (scaling sweep at N ∈ {10, 100, 1k, 10k}; curve fit; declared vs measured big-O → G107). Complexity runs FIRST; a scaling-shape mismatch makes regression gating meaningless.
6. **Wave T5.5 T-SOAK** — for every symbol in `design/perf-budget.md` with `soak.enabled: true`: `sdk-soak-runner` launches harness via Bash `run_in_background` (decouples from tool-call window), then `sdk-drift-detector` observes state files on a poll ladder (30s, 2m, 5m, 15m, 30m, 60m, 2h, 4h, 6h). Fast-fails on statistically significant positive slope in drift signals (G106); enforces MMD (G105). Emits verdict ∈ {PASS, FAIL, INCOMPLETE} per rule 33.
7. **Wave T6 Leak hunt** — `sdk-leak-hunter`; `-race -count=5` + goleak
8. **Wave T7 Fuzz** (conditional, if TPRD §11 lists fuzz targets) — `fuzz-agent`
9. **Wave T8 Supply chain** — `govulncheck`, `osv-scanner`
10. **Wave T9 Observability tests** (conditional) — verify spans/metrics emit per TPRD §8
11. **Wave T10 Mutation** (optional) — `mutation-test-agent` on critical logic

## Output Files

- Test files committed to branch
- `runs/<run-id>/testing/coverage.txt`
- `runs/<run-id>/testing/bench-raw.txt`
- `runs/<run-id>/testing/bench-compare.md`
- `runs/<run-id>/testing/govulncheck.txt`
- `runs/<run-id>/testing/osv-scan.txt`
- `runs/<run-id>/testing/testing-summary.md`
- `runs/<run-id>/testing/context/sdk-testing-lead-summary.md`

## Decision Logging

- Entry limit: 15
- Log: wave results, bench deltas, flake counts, vuln counts, H8 outcome
- Events: regression verdict per package

## Completion Protocol

1. All exit guardrails PASS (G60–G69)
2. H8 approved (or no regression)
3. Log `lifecycle: completed`
4. Notify `learning-engine` (phase 4 entry)

## On Failure Protocol

- Integration test container fails to start → retry 1×; second failure → degrade (report partial coverage)
- Benchmark regression detected → HITL H8 gate; user accepts-with-waiver OR design/impl rework
- Leak found → HALT; back to impl phase for fix
- Vuln HIGH/CRITICAL → HALT; back to design for dep replacement

## Skills invoked

- `testing-patterns`
- `table-driven-tests`
- `testcontainers-setup`
- `mock-patterns`
- `observability-test-patterns`
- `fuzz-patterns`
- `k6-load-tests` (if TPRD requires k6; rare for SDK)

## Coverage target rule

- New package: ≥90% per-package branch coverage (hard gate)
- Existing package (mode B/C): coverage ≥ pre-change value (no regression)
- Exempted files: generated code marked `//go:generate`, cmd entry points (if any — SDK is library)

## Learned Patterns

<!-- Applied by learning-engine (F7) on run sdk-dragonfly-s2 @ 2026-04-18 | pipeline 0.2.0 | patch-id PP-04-testing -->
<!-- Confidence: MEDIUM. CALIBRATION-WARN classification ideally pairs with proposed guardrail G66. Until G66 exists, this pattern is advisory heuristic. -->

### Pattern: CALIBRATION-WARN classification for dep-floor-unachievable constraints (T5)

**Rule**: When a TPRD §10 numeric constraint fails bench evaluation AND the failure mode is "target < underlying dep's measured floor" (not a regression or a wiring defect in the pipeline's code), classify the outcome as **CALIBRATION-WARN**, not FAIL. Emit an H8 gate with Option A (accept-as-calibration-miss with baseline update) pre-selected as the recommended path — the constraint is mechanically unreachable and a code fix cannot resolve it.

**How to classify (T5 + benchmark-devil handoff)**:
1. On bench result miss, consult `baselines/go/performance-baselines.json` and the proposed `G66` guardrail's calibration file for the underlying client's floor.
2. If `measured_value ≈ dep_floor` and `tprd_target << dep_floor`, mark the finding `CALIBRATION-WARN` in `testing/bench-calibration.md` with: constraint, target, measured, dep_floor, delta-to-floor-vs-delta-to-target.
3. Do NOT emit H8 with BLOCKER tone. The gate is still required (H8 is user-facing constraint-acceptance) but recommendation is Option A (waiver + baseline update), not Option D (halt).
4. If `measured_value >> dep_floor` (the SDK wrapper is the problem, not the dep), continue to classify as FAIL — the wrapper has a correctable allocation/latency issue.

**Evidence from sdk-dragonfly-s2**: BenchmarkGet showed 32 allocs/op against TPRD target ≤ 3. go-redis v9 measured floor in the same bench context is ~25-30. Gap to floor ≈ 2-7 allocs (wrapper overhead), gap to target = 29. This is a calibration miss, not a wrapper defect. H8 Option A (accept with baseline revised to ≤ 35) was approved correctly, but the original classification was "constraint failure" — future runs should pre-classify and reduce H8 friction.

### Pattern: miniredis-family gap enumeration in TPRD §11.1

**Rule**: At T2 integration-test start, scan TPRD §11.1 for a `not-covered-by-fake-client:` list. If absent, log an ESCALATION to phase-retrospector recommending TPRD §11.1 amendment with explicit fake-client coverage exclusions. In the meantime, any SKIP caused by a fake-client limitation MUST be accompanied by a `//` comment that cites the specific command and the fake-client's lack of support, plus an `integration/` counterpart test gated on `//go:build integration`.

**Evidence from sdk-dragonfly-s2**: `miniredis/v2` does not implement the Redis 7.4 HPExpire-family commands (`HPEXPIRE`, `HEXPIREAT`, `HTTL`, `HPERSIST`). TestHash_HExpireFamily has a partial `t.Skip` with a comment; the integration test `TestIntegration_HExpire` covers the live case. TPRD §11.1 did not document this known gap, so the skip looked surprising during T2. A single line in TPRD §11.1 ("miniredis v2.37 does NOT support HEXPIRE family — covered by integration") would have set the expectation.
