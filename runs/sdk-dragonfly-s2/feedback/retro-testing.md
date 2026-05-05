<!-- Generated: 2026-04-18T15:00:00Z | Run: sdk-dragonfly-s2 -->
# Phase Retrospective — Testing (Phase 3)

## What Went Well
- All hard gates cleared with zero failures: 0 races, 0 leaks, 0 flakes, 0 fuzz crashes, 0 new CVEs in dragonfly scope.
- Fuzz corpus grew meaningfully (FuzzMapErr: 659k execs / 17 new seeds; FuzzKeyEncoding: 180k execs / 9 new seeds) with no panics — strong confidence in mapErr and key-encoding surfaces.
- Flake hunt (count=3, -race) produced 217 PASS / 0 FAIL across all integration iterations — container bootstrap is stable.
- OTel conformance suite (T9, 4 AST-based tests) validated wiring invariants without requiring a live OTLP exporter. Static approach is portable across CI environments.
- goleak.VerifyTestMain documented the go-redis reaper goroutine ignore correctly — no false-positive leak alerts.

## Recurring Patterns
| Pattern | Occurrences | Affected Agents | Severity |
|---------|------------|-----------------|----------|
| TPRD §10 numeric constraint unachievable due to underlying client floor | 1 (allocs ≤ 3 vs go-redis v9 floor of ~25-30) | performance-test-agent, sdk-benchmark-devil, sdk-testing-lead | High — required H8 gate; waiver accepted; constraint calibration deferred |
| miniredis HPExpire-family gap causes integration test matrix to be partial | 1 SKIP (unit) + HPExpire/HExpireAt/HTTL/HPersist not live-tested via TLS/ACL matrix | integration-test-agent | Medium — known fake-client limitation; not documented in TPRD §11.1 |
| OTel conformance test added in testing phase rather than impl phase | 1 (observability_test.go, T9) | sdk-testing-lead | Medium — represents implicit skill-drift in impl-lead; testing-lead had to fill the gap |
| SDK-overhead-vs-raw-client constraint UNMEASURED | 1 (no A/B harness for BenchmarkGet_Raw vs BenchmarkGet) | performance-test-agent, sdk-benchmark-devil | Medium — TPRD §10 declares ≤5% wrapper overhead; this was never measured |
| Mutation testing skipped due to tool absence | 1 (T10 skip) | sdk-testing-lead | Low — no gremlins/go-mutesting installed; 90.4% + static AST conformance partially compensates |

## Surprises
- The allocs-per-GET constraint failure was the only hard numeric miss across all of Phase 3, and it traced directly to an aspirational TPRD target set without reference to the go-redis v9 allocation baseline. This was not a test failure — it was a requirement calibration failure.
- The observability_test.go approach (AST-based static analysis rather than a live in-memory exporter) is novel and worked cleanly. The `motadatagosdk/otel/tracer` package not exposing an in-memory exporter hook forced this design; the AST approach is actually more robust for CI parity.
- Integration TLS/ACL matrix coverage was lower than TPRD §11.2 specified. Basic flow and HExpire were tested live; chaos kill, TLS on/off, and ACL on/off remain skeleton/skip. This was accepted at H9 but represents a known gap against spec.

## Agent Coordination Issues
- sdk-testing-lead correctly identified that the OTel conformance test gap originated in impl-lead (no static wiring check authored in M6). The gap was filled in T9 rather than escalated as a BLOCKER — pragmatically correct for this run, but the pattern should be addressed via impl-lead prompt.
- No inter-agent coordination issues within the testing phase itself; testing agents were sequential and dependencies were clean.

## Communication Health
| Metric | Value |
|--------|-------|
| Total communications logged | 0 formal inter-agent comms (lead-orchestrated sequential phase) |
| Assumptions raised | 1 (OTel hook absence; testing-lead self-resolved via AST approach) |
| Escalations sent | 0 within Phase 3 |
| H8 gate triggered | 1 (allocs constraint fail) |

## Failure & Recovery Summary
| Metric | Value |
|--------|-------|
| Total failures logged | 1 soft-gate fail (allocs_per_GET constraint) |
| Recovered (H8 waiver option-a) | 1 — baseline revised to ≤35 allocs |
| Technical debt created | 1 — A/B wrapper-overhead harness deferred to Phase 4 backlog |
| Unrecovered | 0 |
| T10 skip (mutation tool absent) | 1 — filed to Phase 4 backlog |

## Refactor Summary
| Metric | Value |
|--------|-------|
| Total refactors | 0 (no prod code changed in Phase 3) |
| New test files added | 1 (observability_test.go, 270 LOC) |
| Phase-3 commits | 1 (a4d5d7f) |

## Improvement Suggestions

### Agent Prompt Improvements
| Agent | Suggestion | Expected Impact | Source Pattern |
|-------|-----------|----------------|----------------|
| sdk-benchmark-devil | At T5, compare each TPRD §10 constraint against known dep-floor benchmarks (from design dep docs or baselines/); flag any constraint where target < dep_floor as CALIBRATION-WARN before running bench | Would have pre-classified allocs constraint as calibration issue at T5, not a FAIL requiring H8 | allocs ≤ 3 vs go-redis v9 floor |
| integration-test-agent | At T2 start, read TPRD §11.1 for explicit fake-client coverage exclusions; log each exclusion as a known-gap rather than a skip; recommend TPRD §11.1 amendment | Makes miniredis HPExpire-family gap visible in the TPRD, not just in test output | miniredis HPExpire-family skip |
| sdk-testing-lead | Add T9.5 wave: check whether impl-lead authored a static OTel conformance test; if absent, author it in T9 AND log an ESCALATION noting impl-lead skill drift | Ensures OTel conformance test is produced regardless; surfaces impl prompt gap | observability_test.go authored at T9 not M6 |

### Process Changes
| Change | Current State | Proposed State | Justification |
|--------|--------------|----------------|---------------|
| TPRD §11.1 miniredis coverage limits | Implicit (discovered at test runtime) | Require TPRD §11.1 to enumerate commands NOT covered by miniredis + expected coverage strategy (integration or skip) at TPRD authoring time | Prevents surprise skips from becoming planning gaps |
| A/B bench harness for wrapper overhead | UNMEASURED; deferred to Phase 4 | Require BenchmarkGet_Raw (direct go-redis) alongside BenchmarkGet (dragonfly wrapper) in T4 for any TPRD §10 SDK-overhead constraint | Makes the ≤5% overhead constraint measurable in the same phase where it is declared |
| H8 constraint calibration | Triggered by failure at bench time | At H1 or H6, cross-reference TPRD §10 constraints against dep-declared baselines; pre-classify aspirational constraints before they reach Phase 3 | Reduces unplanned H8 gates |

### Guardrail Additions
| Guardrail | Check Logic | Phase | Rationale |
|-----------|------------|-------|-----------|
| G66 — Bench constraint calibration | For each `[constraint: allocs/latency ≤ N]` marker, check `baselines/performance-baselines.json` for the underlying client's measured floor; emit WARN if N < floor × 0.9 | Testing T5 | Catches mechanically unachievable constraints early in bench wave |
| G67 — Integration matrix completeness | Parse TPRD §11.2 TLS/ACL matrix; count test functions exercising each cell; WARN if any cell is 0 | Testing T2 | Surfaces integration matrix gaps vs TPRD spec |

## Systemic Patterns
- The TPRD-constraint-vs-client-floor gap appeared at both intake (accepted without check) and testing (forced H8 waiver). This is the strongest cross-phase systemic pattern in this run. G25 (intake) + G66 (testing) together would close it at both ends.
- OTel conformance test ownership gap (impl-lead vs testing-lead) is an impl-prompt issue that testing-lead compensated for. If this recurs in a future run, it should be classified systemic.
