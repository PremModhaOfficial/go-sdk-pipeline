<!-- Generated: 2026-04-18T15:00:00Z | Run: sdk-dragonfly-s2 -->
# Metrics Summary — sdk-dragonfly-s2 Wave F1

**Pipeline version:** 0.1.0 | **Mode:** A (greenfield) | **Target:** `motadatagosdk/core/l2cache/dragonfly`

---

## Pipeline Quality Score

| Metric | Value |
|--------|-------|
| **pipeline_quality** | **0.95 / 1.00** |
| Coverage | 90.4% (threshold 90%) |
| Defects | 0 |
| Leak count | 0 |
| Flake rate | 0.0 |
| New vulns (dragonfly scope) | 0 |
| Bench delta vs baseline | N/A (first run) |
| Total HITL approvals | 5 (H1, H5, H6-conditional, H7, H8-waiver, H9) |

---

## Per-Agent Quality Scores

| Agent | Phase | Status | Duration (est) | Quality Score | Needs Attention? |
|-------|-------|--------|---------------|---------------|-----------------|
| sdk-intake-agent | Intake | completed | 7m | **1.00** | No |
| sdk-design-lead | Design | completed | 75m | **0.85** | Minor — rework+G32/G33 tool gap |
| sdk-impl-lead | Impl | completed | 150m | **0.98** | No |
| sdk-testing-lead | Testing | completed | 90m | **0.98** | No |

**Mean quality score:** 0.95 | **Min:** 0.85 (sdk-design-lead) | **Max:** 1.00 (sdk-intake-agent)

---

## Quality Score Components (sdk-design-lead — lowest scorer)

| Component | Weight | Raw | Weighted |
|-----------|--------|-----|---------|
| Completeness | 20% | 1.00 | 0.20 |
| Review Severity | 25% | 1.00 | 0.25 |
| Guardrail Pass Rate | 15% | 0.67 | 0.10 |
| Rework Score | 15% | 0.50 | 0.075 |
| Communication Health | 10% | 1.00 | 0.10 |
| Failure Recovery | 10% | 1.00 | 0.10 |
| Downstream Impact | 5% | 0.50 | 0.025 |
| **Total** | 100% | | **0.85** |

Design-lead scored 0.85 due to: (a) 2 NEEDS-FIX findings from D3 devils requiring 1 rework iteration (rework_score=0.5), (b) G32/G33 tool-unavailability at phase execution time penalizing guardrail_pass_rate (4/6 = 0.67), (c) 1-2 downstream observation gaps (BenchmarkHSet, integration matrix) flagged by testing (downstream_impact=0.5). Both NEEDS-FIX were properly resolved in D4 iter-1; design artifact quality is high.

---

## Agents Needing Attention (quality_score < 0.90)

**sdk-design-lead (0.85)**
- Root cause 1: Guardrail tools govulncheck + osv-scanner not available at D2 execution. G32/G33 PENDING for 2 waves, resolved at H6. Penalty: guardrail_pass_rate 0.67.
- Root cause 2: 1 design rework iteration required (F-D3 scraper stop timeout + S-9 credential-rotation Dialer). Both resolved cleanly in single iteration; no recurrence.
- Root cause 3: BenchmarkHSet declared in TPRD §11.3 not carried through to impl. Minor traceability gap (TPRD constraint not fully reflected in test plan handoff).
- Recommendation: Add govulncheck/osv-scanner to pipeline startup preflight (Phase 0). Document benchmark completeness check in sdk-design-lead agent prompt.

---

## Anomaly Flags

| ID | Severity | Agent | Description |
|----|----------|-------|-------------|
| A1 | medium | sdk-design-lead | G32/G33 tools absent at design time; 2-wave PENDING state |
| A2 | medium | sdk-impl-lead | DEP-BUMP-UNAPPROVED escalation (testcontainers MVS chain); required run-driver intervention |
| A3 | medium | sdk-testing-lead | TPRD §10 allocs-per-GET <= 3 constraint unachievable with go-redis v9.18 floor (resolved via H8 waiver) |
| A4 | low | sdk-testing-lead | T10 mutation testing skipped (gremlins/go-mutesting not installed) |
| A5 | low | sdk-design-lead | BenchmarkHSet in TPRD §11.3 not emitted by impl |

---

## Per-Phase Summary

| Phase | Duration (est) | Rework Iters | Devil Block Rate | HITL Gates |
|-------|---------------|-------------|----------------|-----------|
| Intake | 7m | 0 | 0.0 | H1 approved |
| Design | 75m | 1 | 0.4 | H5 approved, H6 approved-conditional |
| Impl | 150m | 0 | 0.0 | H7 approved |
| Testing | 90m | 0 | 0.0 | H8 approved-waiver, H9 approved |
| **Total** | **~5h22m** | **1** | **0.10 (avg)** | **5 gates approved** |

---

## Test and Quality Gate Summary

| Gate | Result |
|------|--------|
| Unit test pass | 71 PASS, 1 SKIP, 0 FAIL |
| Integration test | 2 PASS, 1 SKIP, 0 FAIL |
| Observability conformance | 4 PASS |
| Flake hunt (3 iters) | 217 PASS, 0 FAIL |
| Fuzz (FuzzMapErr + FuzzKeyEncoding, 60s each) | 839,670 execs, 0 crashes |
| Goroutine leaks | 0 |
| Data races | 0 |
| New CVEs in dragonfly deps | 0 |
| govulncheck new (dragonfly scope) | 0 |
| Coverage | 90.4% (threshold met) |
| Exported symbols | 94 (design-stub 93, +1 justified) |
| traces-to markers | 145 across 14 files |

---

## Benchmark Baseline (first run — no regression gate)

| Benchmark | ns/op | allocs/op | bytes/op | Constraint |
|-----------|-------|-----------|----------|-----------|
| BenchmarkGet | 26,600 | 32 | 1,257 | PROVISIONAL-PASS (miniredis) |
| BenchmarkSet | 26,670 | 37 | 1,426 | PROVISIONAL-PASS (miniredis) |
| BenchmarkHExpire | 25,050 | 47 | 1,815 | PROVISIONAL-PASS (miniredis) |
| BenchmarkEvalSha | 136,100 | 729 | 178,583 | PASS (P99 <= 1ms) |
| BenchmarkPipeline_100 | 955,900 | 1,917 | 50,514 | PASS (amortised ~9.56us/cmd) |

H8 waiver: allocs-per-GET target revised to <= 35 (from <= 3). Baseline 32. Regression gate: 34 (32+5%).

---

## SDK-Specific Metrics

| Metric | Value |
|--------|-------|
| skill_coverage_pct | 70% (19/27 skills present) |
| skill_gaps_filed | 8 (all WARN-expected by TPRD) |
| skills_created | 0 (human-authored only per Rule #23) |
| dep_escalations | 1 (resolved Option A) |
| user_clarifications_asked | 0 |
| determinism_diff_bytes | N/A (no second run) |
| hitl_timeout_count | 0 |

---

## Open Phase 4 Backlog Items

1. A/B harness (BenchmarkGet_Raw vs BenchmarkGet) — resolves SDK-overhead constraint (H8 option c intent)
2. BenchmarkHSet — TPRD §11.3 declared, not emitted
3. Integration matrix completion (TLS on/off x ACL on/off x full HEXPIRE family)
4. Mutation testing (T10 skip due to missing binaries)
5. Pipeline startup preflight: govulncheck + osv-scanner availability check
6. otel/tracer in-memory exporter hook for live observability testing

---

## Trend

First run for this package. No prior telemetry exists. All scores serve as the baseline for sdk-dragonfly-s2 future runs.

---

## Data Quality Notes

- Duration estimates are derived from decision-log timestamps (not wall-clock profiling); actual wall time may differ.
- Token budgets not tracked in pipeline_version 0.1.0 (phase_token_pct_of_budget = null).
- Sub-agent scores (sdk-designer, interface-designer, algorithm-designer, concurrency-designer, pattern-advisor) rolled up under sdk-design-lead; individual granularity would require per-agent decision-log seq tagging.
- G32/G33 PENDING at design time counted as neutral (0.5 default per missing-data rule), then resolved at H6 — final phase score reflects resolved state.
