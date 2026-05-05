<!-- Generated: 2026-04-28T00:00:00Z | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 -->
# Phase Retrospective — Implementation

## What Went Well
- Tech-debt scans empty at ALL seven wave checkpoints (M0/M1/M3/M5/M9/M10/M11).
- 9/9 API symbols shipped with impl + test + docstring + `[traces-to:]` + `[stable-since:]`.
- All 6 TPRD §13 milestones (S1-S6) complete; no deferred slices.
- G104 alloc budget: 380× margin (0.01 vs 4 budget) — `__slots__` design decision paid off.
- M7 devil fleet: 6 ACCEPT / 0 BLOCKER / 0 review-fix iterations.
- RULE 13 (post-iteration re-review) correctly triggered after M10; all verdicts ACCEPT.

## M10 Rework Sequence
Wave M10 was triggered by the user's H7-revise decision after M9's initial APPROVE was
re-examined under RULE 0 strict reading. Three required fixes:

| Fix | Root cause | Resolution | Verdict |
|---|---|---|---|
| Fix 1: `try_acquire` bench harness | async-release overhead polluting the timed window; actual op was measuring release latency | Counter-mode harness BATCH=128; releases outside timed window | 7.2 µs → **71 ns** (70× under 5 µs budget); PASS |
| Fix 2: contention 32:4 throughput | Original harness included `sleep(0)` + timeout overhead. Even with optimal harness, asyncio.Lock+Condition imposes ~2 µs/cycle = ~500k theoretical ceiling; 10× Go oracle assumption does not hold in Python | Optimal harness reached 458k best-of-3 (92% of 500k budget); structural ceiling confirmed | ESCALATED to user |
| Fix 3: G109 profile shape | M3.5 verdict was "PASS via code-path proxy; INCOMPLETE for strict surprise-hotspot" | py-spy v0.4.2 installed; 3338 samples collected; coverage 3/3 = 1.00; zero surprise hotspots | PASS (strict) |

## M11 Re-Baseline Sequence
User chose Option 1 (re-baseline) at the H7 contention ESCALATION. Impl-lead applied:
- `design/perf-budget.md §1.4`: `throughput_acquires_per_sec` 500k → 450k; original preserved
- `runs/.../tprd.md §10`: row updated "≥ 500k" → "≥ 450k (*)" + footnote + change-log
- Bench gate renamed: `test_contention_throughput_meets_450k_per_sec_budget`; CI gate floor 425k
- v1.1.0 perf-improvement TPRD draft filed for asyncio.Lock-replacement (≥ 1M acq/sec target)

The M11 approach is correct: preserves audit trail (`original_budget_v0` field), documents host
environment compromise transparently, provides regression floor (425k CI gate), and channels the
throughput ambition into a next-TPRD. NOT tech debt by RULE 0 definition.

## G90 Unblock Event
G90 BLOCKER at intake (v0.5.0 schema added `python_specific` section; G90 only iterated over
three hardcoded section names). Unblocked at H1 via user-authorised patch. Impact on impl:
zero — unblocked before design began. But the pattern warrants a preventive guardrail enhancement.

## Recurring Patterns
| Pattern | Occurrences | Affected Agents | Severity |
|---|---|---|---|
| Oracle budget derived from reference language (Go 10×) mismatches Python impl floor | 1 (M10 Fix 2) | sdk-perf-architect, sdk-impl-lead | HIGH |
| py-spy not pre-installed in venv; requires ad-hoc install for strict G109 | 1 (M10 Fix 3) | sdk-impl-lead | MEDIUM |
| Counter-mode harness needed for sub-µs sync ops | 1 (M10 Fix 1) | sdk-impl-lead | MEDIUM |

## Surprises
- The `bench_try_acquire` inflation was entirely harness-shape: 7.2 µs was measuring
  async-release, not try_acquire. Once the timed window was isolated, the actual operation
  is 71 ns — 70× under budget. This reveals a systemic risk: async harness overhead can
  mask fast synchronous operations by orders of magnitude.
- asyncio.Lock+Condition imposes a ~2 µs per-cycle floor that is structurally different from
  Go's `chan T` cost model. Cross-language oracle derivation ("10× Go") without an asyncio
  primitive-cost model is unreliable. The perf-budget template needs an explicit
  `cross_language_oracle_caveats` section.

## Agent Coordination Issues
- sdk-profile-auditor absent from python.json; sdk-impl-lead executed in-process.
  This means G109 "INCOMPLETE for strict surprise-hotspot" at M3.5 was a role gap, not
  an evidence gap. The py-spy fix in M10 resolved it but the pattern should be addressed
  by adding the profiling role to python.json for future runs.

## Communication Health
| Metric | Value |
|---|---|
| Total communications logged | 1 (ESCALATION: CONTENTION-BUDGET-UNREACHABLE-ON-CURRENT-IMPL at M10) |
| Escalations sent | 1 |
| Escalations resolved | 1 (user decision M11, same session) |

## Failure & Recovery Summary
| Metric | Value |
|---|---|
| Total failures logged | 1 (contention throughput budget unreachable) |
| Recovered (retry) | 2 of 3 fixes (Fix 1 and Fix 3) |
| Recovered (user re-baseline) | 1 (Fix 2 via M11) |
| Unrecovered | 0 |

## Improvement Suggestions

### Agent Prompt Improvements
| Agent | Suggestion | Expected Impact | Source Pattern |
|---|---|---|---|
| sdk-perf-architect | Add `cross_language_oracle_caveats` section to perf-budget.md template; flag when oracle is "N× Go" for Python | Catch asyncio.Lock cost-model mismatch at design time | M10 Fix 2 root cause |
| sdk-impl-lead | Pre-install py-spy in venv by default when G109 is in active-packages; document counter-mode harness shape for sub-µs sync ops | Eliminate M10-class bench-shape rework | M10 Fixes 1 + 3 |

### Guardrail Additions
| Guardrail | Check Logic | Phase | Rationale |
|---|---|---|---|
| G-HARNESS-SHAPE | Warn when a bench function awaits a non-timed async operation inside the timed window | Impl | Catch async-release pollution before devil review |
| G-PY-SPY-INSTALLED | Assert py-spy present in venv before M3.5 profile audit | Impl | Avoid "INCOMPLETE for strict" G109 at M3.5 |

## Systemic Patterns
- Bench harness correctness is a recurring gap (sdk-dragonfly-s2 also required bench rework).
  Elevating to systemic.
