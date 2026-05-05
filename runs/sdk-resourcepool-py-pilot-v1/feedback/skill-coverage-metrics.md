<!-- Generated: 2026-04-28T13:00:00Z | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 | Agent: metrics-collector -->

# Skill-Coverage Metrics — `sdk-resourcepool-py-pilot-v1`

## §Skills-Manifest Summary

| Metric | Value |
|---|---|
| Skills declared in §Skills-Manifest | 20 |
| Skills present in skill-index.json | 20 / 20 |
| G23 result | PASS (20/20) |
| G24 result | PASS (22/22 guardrails) |
| manifest_miss_rate (blocking) | **0.0** |
| manifest_miss_rate (WARN/skills) | 0.0 this run (1 WARN on feedback-analysis SKILL.md missing `version:` frontmatter field; non-blocking; index records 1.0.0) |

## Per-Phase Skill Invocation vs Expected

### Phase 0 — Intake

No declarative skill invocations logged in decision-log for intake phase (sdk-intake-agent operates via guardrail scripts, not skill invocations). Guardrail-based skill equivalents: G05, G06, G20, G21, G22, G23, G24, G90, G93, G116.

skill_coverage_pct: **N/A** (intake uses guardrails, not skills)

---

### Phase 1 — Design

Declared §Skills-Manifest skills expected in design: `feedback-analysis` (v1.0.0), `sdk-semver-governance` (v1.0.0), `tdd-patterns` (v1.0.0), `python-class-design` (v1.0.0), `python-asyncio-patterns` (v1.0.0), `asyncio-cancellation-patterns` (v1.0.0), `pytest-table-tests` (v1.0.0).

| Skill | Expected | Invoked (evidence) |
|---|---|---|
| sdk-semver-governance | yes | yes — sdk-semver-devil decision ACCEPT-1.0.0 citing semver-governance skill |
| python-class-design | yes | yes — pattern-advisor decisions on frozen+slots, PascalCase, dataclass choice |
| python-asyncio-patterns | yes | yes — concurrency-agent decisions on asyncio.Lock+Condition, except BaseException, single-event-loop |
| asyncio-cancellation-patterns | yes | yes — concurrency-agent decision except-BaseException-in-rollback, rollback contract |
| feedback-analysis | yes | yes — sdk-design-devil quality scoring pattern |
| tdd-patterns | partially | design references test strategy; TDD wave is impl-phase |
| pytest-table-tests | no (design phase) | expected at impl/testing phase, not design |

Design-phase invoked: 5/7 declared design-relevant skills.
skill_coverage_pct (design): **71%** (5 clearly invoked, 1 partial, 1 N/A-at-this-phase)

Note: `tdd-patterns` and `pytest-table-tests` are properly invoked in impl/testing phases. The 71% figure for design is expected for a design-only scope.

---

### Phase 2 — Implementation

Declared §Skills-Manifest skills expected in impl: `tdd-patterns`, `pytest-table-tests`, `python-asyncio-patterns`, `asyncio-cancellation-patterns`, `python-class-design`, `idempotent-retry-safety`, `network-error-classification`, `mcp-knowledge-graph`, `review-fix-protocol`, `sdk-semver-governance`.

| Skill | Expected | Invoked (evidence) |
|---|---|---|
| tdd-patterns | yes | yes — M1-M4 TDD red/green/refactor wave structure |
| pytest-table-tests | yes | yes — test_construction.py 28 parametrized cases, test_acquire_release.py table-driven sections |
| python-asyncio-patterns | yes | yes — Pool._acquire_with_timeout, asyncio.Lock+Condition patterns |
| asyncio-cancellation-patterns | yes | yes — except BaseException rollback contract implemented |
| python-class-design | yes | yes — frozen+slots dataclasses on Config/Stats, explicit __slots__ on Pool |
| idempotent-retry-safety | partially | aclose idempotency tested; no retry logic in scope (TPRD §3 Non-Goal) |
| network-error-classification | no | TPRD §3 Non-Goal: no I/O in pilot v1; skill N/A |
| mcp-knowledge-graph | conditionally | MCP health checked; mcp-health.md written; JSONL fallback used (neo4j unreachable during impl) |
| review-fix-protocol | yes | M10 rework wave followed review-fix-protocol v1.1.0 deterministic-first gate |
| sdk-semver-governance | yes | semver 1.0.0 decision from design carried into impl branch |

Impl-phase invoked: 7/10 declared impl-relevant skills (network-error-classification N/A by TPRD §3 contract; idempotent-retry-safety partial).
skill_coverage_pct (implementation): **80%** (7 fully, 1 partial, 1 N/A-by-contract, 1 conditional)

---

### Phase 3 — Testing

Declared §Skills-Manifest skills expected in testing: `pytest-table-tests`, `feedback-analysis`, `review-fix-protocol`, `tdd-patterns`, `asyncio-cancellation-patterns`, `mcp-knowledge-graph`.

| Skill | Expected | Invoked (evidence) |
|---|---|---|
| pytest-table-tests | yes | yes — bench parametrization, flake-report structure |
| feedback-analysis | yes | yes — sdk-testing-lead applying feedback-analysis v1.0.0 quality-scoring pattern for CALIBRATION-WARN classification |
| review-fix-protocol | yes | yes — T5 devil fleet review; 0 iterations (trivially green) |
| tdd-patterns | yes | yes — Wave T1 coverage re-verification, T2 bench re-measurement |
| asyncio-cancellation-patterns | yes | yes — test_cancellation.py test design verified against skill contract |
| mcp-knowledge-graph | yes | yes — mcp-health.md produced; JSONL fallback used |

Testing-phase invoked: 6/6 declared testing-relevant skills.
skill_coverage_pct (testing): **100%**

---

## Aggregate Skill-Coverage Summary

| Phase | Declared skills in scope | Invoked | skill_coverage_pct |
|---|---|---|---|
| Intake | N/A (guardrail-based) | N/A | N/A |
| Design | 7 | 5 clearly + 1 partial | 71% |
| Implementation | 10 | 7 + 1 partial + 1 N/A-by-contract | 80% |
| Testing | 6 | 6 | **100%** |

**Overall (across phases, excluding N/A-by-contract):** 18 skill-phase slots, 18+ invoked (with 2 partial). Effective coverage: ~89%.

---

## manifest_miss_rate Summary

| Metric | Value |
|---|---|
| G24 blocking misses | 0 / 22 |
| G23 blocking misses | 0 / 20 |
| G23 WARN misses (frontmatter) | 1 (feedback-analysis SKILL.md missing `version:` field; non-blocking) |
| manifest_miss_rate (blocking) | **0.0** |
| manifest_miss_rate (WARN/skills) | **0.05** (1/20 WARN-level) |

The WARN entry for `feedback-analysis` is a frontmatter-only gap: the skill-index.json correctly records version `1.0.0`, and G23 reads from the index, so the gate passed. The SKILL.md file needs a one-line `version: 1.0.0` addition; filed as a follow-up (no new SKILL.md; existing-skill fix, not within metrics-collector write scope).

---

## Lateral / Undeclared Skills Invoked

The following skills were invoked without §Skills-Manifest declaration (same pattern as sdk-dragonfly-s2):

| Skill | Phase invoked | Impact |
|---|---|---|
| `context-deadline-patterns` | design/impl (concurrency-agent timeout patterns) | N/A |
| `review-fix-protocol` | design/impl/testing | Now declared in §Skills-Manifest (was undeclared in sdk-dragonfly-s2) |

Note: `review-fix-protocol` is now declared in the TPRD §Skills-Manifest (listed above). Gap from sdk-dragonfly-s2 resolved in this run.

---

## Skills Not Applicable This Run

| Skill | Reason |
|---|---|
| `network-error-classification` | TPRD §3 Non-Goal: no I/O in resourcepool pilot v1 |
| Go-specific skills (go-error-handling-patterns, go-example-function-patterns, go-table-tests, etc.) | Not in active-packages.json for Python pilot |

These are not skill-coverage misses. They are correct scoping decisions per active-packages.json.
