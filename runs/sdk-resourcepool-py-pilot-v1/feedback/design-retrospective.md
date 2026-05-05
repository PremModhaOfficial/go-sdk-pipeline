<!-- Generated: 2026-04-28T00:00:00Z | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 -->
# Phase Retrospective — Design

## What Went Well
- All 6 D1 sub-agents completed in parallel with zero conflicts; design-lead did not need to
  adjudicate a single ESCALATION: CONFLICT.
- D2 review-fix loop required 0 iterations — all devil verdicts were ACCEPT or PASS.
- RULE 0 mechanical grep (forbid TODO/FIXME/TBD/etc.) came back clean across all 23 artifacts.
- Perf-architect correctly documented the oracle-recalibration path (derive from Go docstring;
  impl phase re-measures). Not tech debt — legitimate first-run approximation with a documented
  path to closing it.
- Concurrency agent's `except BaseException` decision pre-empted a class of cancellation bugs
  that would otherwise have required M10-class rework.
- Pattern-advisor's explicit `avoid-cached_property-weakref-contextvars` documentation blocked
  overengineering-critic false positives at review time.

## Recurring Patterns
| Pattern | Occurrences | Affected Agents | Severity |
|---|---|---|---|
| Surrogate review (design-lead covers agents not in active-packages.json) | 3 (dep-vet, convention, constraint devils) | sdk-design-lead | MEDIUM |
| Go-bench INCOMPLETE at design time (wallclock cap hit) | 1 | sdk-perf-architect | LOW |
| D2 Go-specific guardrails (G30-G38, G108) skipped as not-in-active-packages | 1 (structural gap) | guardrail-validator | MEDIUM |

## Surprises
- Three review agents (sdk-dep-vet-devil, sdk-convention-devil, sdk-constraint-devil) are absent
  from both `shared-core.json` and `python.json` — design-lead had to produce surrogate reviews.
  These agents are language-neutral in role. Filing them as a `shared-core` addition is low-risk
  and eliminates the surrogate pattern on future Python (and Rust/etc) runs.
- sdk-design-devil quality score reported as 0.91 in decision-log (delta = -2pp from Go baseline
  of 0.93 implied by quality-baselines.json; actually the baseline shows 0.85 for Go run). See
  python-pilot-retrospective.md Q1 for the full cross-language comparison analysis.

## Agent Coordination Issues
- Zero intra-design communications logged. Six agents working in parallel with no visible
  coordination tension — a sign that the design-lead-brief.md did its job as the single source
  of truth for decisions already made (§15 Q1-Q6).

## Communication Health
| Metric | Value |
|---|---|
| Total communications logged | 0 (all resolved via design-lead-brief.md pre-decisions) |
| Assumptions raised | 0 |
| Escalations sent | 0 |
| Escalations resolved | N/A |

## Failure & Recovery Summary
| Metric | Value |
|---|---|
| Total failures logged | 0 |
| Top failure type | N/A |

## Refactor Summary
| Metric | Value |
|---|---|
| Total refactors | 0 |
| Review-fix iterations | 0 |

## Improvement Suggestions

### Agent Prompt Improvements
| Agent | Suggestion | Expected Impact | Source Pattern |
|---|---|---|---|
| sdk-design-lead | Add sdk-dep-vet-devil, sdk-convention-devil, sdk-constraint-devil to shared-core.json agents; remove surrogate pattern | Correct ownership; no surrogate reviews | 3 missing review agents |
| sdk-perf-architect | When empirical Go bench cannot complete, document oracle source + uncertainty range explicitly (done here; make it a template) | Consistent oracle provenance | Go-bench INCOMPLETE |

### Process Changes
| Change | Current State | Proposed State | Justification |
|---|---|---|---|
| Add dep-vet/convention/constraint devils to shared-core manifest | Absent (not in active-packages.json) | Present in shared-core.json agents[] | They are language-neutral; their absence forces surrogates |

### Guardrail Additions
| Guardrail | Check Logic | Phase | Rationale |
|---|---|---|---|
| G-ACTIVE-PACKAGES-REVIEW-COMPLETENESS | Verify that all TPRD-declared D2 review agent roles have a real (non-surrogate) agent in active-packages.json | Design | Surrogate reviews are weaker; gap caught here only by design-lead discipline |

## Systemic Patterns
- Surrogate-review anti-pattern: same pattern was present in sdk-dragonfly-s2 (Go baseline run).
  Elevating to systemic — both the Go and Python first runs required at least one surrogate review.
