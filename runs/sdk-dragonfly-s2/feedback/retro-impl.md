<!-- Generated: 2026-04-18T15:00:00Z | Run: sdk-dragonfly-s2 -->
# Phase Retrospective — Implementation (Phase 2)

## What Went Well
- All 5 inline devil reviews PASS in a single pass (marker-hygiene, leak-hunter, ergonomics, overengineering, code-reviewer) — no M8 review-fix iteration needed.
- `runCmd[T any]` generic extraction in M5 eliminated 336 LOC of boilerplate with zero behavior change; all tests stayed green.
- 145 `[traces-to: TPRD-*]` markers and 0 forged `[owned-by: MANUAL]` markers (G99 + G103 PASS).
- Coverage went from 74.8% to 90.4% through the coverage-test extraction in M6 — the threshold gate was met without any relaxation.
- Supply-chain pre-gate ran before committing go.mod, preventing a dirty vuln-state from ever landing on the branch.
- DEP-BUMP-UNAPPROVED escalation was well-documented (dep-escalation.md with 4 options and root-cause per dep), enabling a fast run-driver decision.

## Recurring Patterns
| Pattern | Occurrences | Affected Agents | Severity |
|---------|------------|-----------------|----------|
| MVS-forced bump of existing deps blocked impl until run-driver approval | 1 HALT (otel x3 + klauspost/compress via testcontainers-go) | sdk-impl-lead | High — halted impl wave; required unplanned HITL escalation |
| OTel conformance test missing from impl phase; added in testing phase | 1 (observability_test.go authored in T9, not M3/M6) | sdk-impl-lead, sdk-testing-lead | Medium — not a defect, but implies impl-lead had no static OTel wiring check |
| miniredis HPExpire-family gap causing test skip | 1 SKIP (TestHash_HExpireFamily partial) | sdk-impl-lead, unit-test-agent | Low — graceful skip with comment; real coverage deferred to integration tests |
| +1 export delta vs design stub (WithCredsFromEnv) | 1 | sdk-impl-lead, sdk-designer | Low — justified by design §P5a; documented in H7-summary |

## Surprises
- The DEP-BUMP-UNAPPROVED halt occurred even though H6 had already modeled the dep-addition scenario. The gap was that H6's scratch-module simulation pre-dated the "do not touch untouched deps" user directive, and the directive itself was not surfaced to the scratch module's go.mod state. Had H6 run MVS against the real target go.mod (not a scratch one), the forced bumps would have been visible before impl started.
- The `otel/sdk v1.39.0` GO-2026-4394 became newly call-reachable through a pre-existing target otel/tracer path — not from dragonfly — but was not in the Option-A approved bump list. This created a post-H7 supply-chain observation. The govulncheck scoping rules (reachable-from-dragonfly vs reachable-through-any-target-path) need to be made explicit in the pipeline.
- M8 (review-fix loop) was skipped entirely because all 5 devils returned PASS with zero BLOCKER findings. This is a positive signal: the 1-iteration design review-fix loop successfully prevented defects from reaching impl.

## Agent Coordination Issues
- impl-lead detected the dep-escalation issue independently and halted correctly. No missed inter-agent dependencies.
- The `observability_test.go` not being authored by impl-lead is a skill-drift signal: impl-lead's prompt does not require producing a static OTel conformance test, though it should (the conformance invariants are knowable from the design phase).

## Communication Health
| Metric | Value |
|--------|-------|
| Total communications logged | 1 formal ESCALATION (DEP-BUMP-UNAPPROVED, seq 38) |
| Assumptions raised | 0 |
| Escalations sent | 1 |
| Escalations resolved | 1 (Option A approved, seq 39) |

## Failure & Recovery Summary
| Metric | Value |
|--------|-------|
| Total failures logged | 1 (ESCALATION: DEP-BUMP-UNAPPROVED) |
| Recovered (retry after approval) | 1 — impl resumed from Wave M3 after run-driver approved Option A |
| Unrecovered | 0 |
| Top failure type | dep-policy-violation (MVS-forced bump of untouched deps) |

## Refactor Summary
| Metric | Value |
|--------|-------|
| Total refactors | 1 (M5 runCmd[T] extraction) |
| Trigger | planned refactor wave (M5), not review-finding |
| Net LOC change | −336 |
| High regression risk | 0 (all tests passed identically) |
| Refactor ratio (1 refactor / 14 prod files) | ~7% |

## Improvement Suggestions

### Agent Prompt Improvements
| Agent | Suggestion | Expected Impact | Source Pattern |
|-------|-----------|----------------|----------------|
| sdk-impl-lead | Require authoring a static OTel conformance test (span-prefix, bounded-label, no-key-in-attr assertions) as part of M6 Docs wave, using AST or compile-time patterns | Would have caught OTel wiring drift at impl, not Phase 3 T9 | observability_test.go authored in T9 |
| sdk-impl-lead | At M1 start, run `go get <all-new-deps> && go mod tidy -json` in a throwaway clone and compare resulting go.sum against the dep-untouchable list BEFORE writing any test files | Would have detected MVS bumps before the M1/M3 separation, avoiding mid-wave halt | DEP-BUMP-UNAPPROVED HALT |

### Process Changes
| Change | Current State | Proposed State | Justification |
|--------|--------------|----------------|---------------|
| govulncheck reachability scope | Defined implicitly as "call-reachable anywhere in target" | Explicitly scope G32 check to: (a) dragonfly-introduced deps only for BLOCKER gate; (b) full target for WARN/observation | Prevents otel/sdk pre-existing vuln from being logged as impl-phase ambiguity |
| OTel conformance test ownership | Produced by testing-lead in T9 | Owned by impl-lead in M6; testing-lead validates (read-only) | Shift-left: conformance invariants are design artifacts, not test artifacts |

### Guardrail Additions
| Guardrail | Check Logic | Phase | Rationale |
|-----------|------------|-------|-----------|
| G44 — OTel static conformance | Scan all `instrumentedCall`/`runCmd` call sites; verify cmd arg is string literal, no span attrs containing field from Config (addr excepted), error_class is bounded | Impl M9 mechanical wave | Catches OTel wiring drift without needing a running exporter |

## Systemic Patterns
- No prior retrospectives. MVS forced-bump gap (also seen in design) is the strongest candidate for a systemic fix via G36 guardrail addition.
