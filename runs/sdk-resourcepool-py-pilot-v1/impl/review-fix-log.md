<!-- Generated: 2026-04-29T16:26:00Z | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 | Pack: python -->
<!-- Authored-by: sdk-impl-lead-toolchain-rerun (rewrites prior wave-M8 log to reflect M8-DYN) -->

# Wave M8 / M8-DYN — Review-Fix Loop

Per `review-fix-protocol` v1.1.0 (deterministic-first gate, per-issue
retry cap 5, stuck detection 2, global cap 10).

## Iteration 1 — original M7 (static-only)

Prior run, toolchain absent.

| Reviewer | Verdict | BLOCKER / HIGH / MEDIUM / LOW / INFO |
|---|---|---|
| code-reviewer-python | PARTIAL-PASS (static AST checks only) | 0 / 0 / 0 / 1 / 2 |
| sdk-api-ergonomics-devil-python | ACCEPT | 0 / 0 / 0 / 0 / 0 |
| sdk-overengineering-critic | ACCEPT | 0 / 0 / 0 / 1 / 0 |
| sdk-marker-hygiene-devil | PASS | 0 / 0 / 0 / 0 / 0 |

Findings: CR-001-INFO (`raise asyncio.TimeoutError` → bare), CR-002-INFO
(comment refinement), CR-003/OE-005-LOW (aclose poll-vs-wait — design
choice).

## Iteration 2 — M5b + M7-DYN (live toolchain)

Wave M5b applied **3 mechanical fixes** + ruff/mypy/format-driven test-side
cleanups:

| ID | Source | Severity | Status | Action |
|---|---|---|---|---|
| Pre-flight-RUF002 | live ruff | (lint) | **FIXED** in `c793c5e` | EN-DASH → HYPHEN-MINUS in `_config.py:28` |
| Pre-flight-UP041 / closes CR-001 | live ruff | INFO → (lint) | **FIXED** in `c793c5e` | `asyncio.TimeoutError` → bare `TimeoutError` |
| Pre-flight-mypy-unreachable | live mypy --strict | (type) | **FIXED** in `c793c5e` | `_is_closed_recheck` helper preserves double-checked-locking invariant under mypy `warn_unreachable` |
| 31 ruff residue + 5 mypy-test-strict | live ruff/mypy | (lint+type) | **FIXED** in `11c772c` | auto-fixes (22) + 9 manual (PT004/PT022 noqa, RUF006 task ref-holds, N818 *Error rename, PT012/PT017 helper-extract, RUF002 ×→x, mypy fixture-typing) |

**Wave M5b: CONVERGED in 2 commits.** Verification: ruff PASS, mypy
strict PASS, ruff format PASS, pytest 62/62 PASS, coverage 92.05 %.

## Iteration 3 — M7-DYN re-issue

| Reviewer | Verdict | New findings? |
|---|---|---|
| code-reviewer-python | **PASS** | None at MEDIUM+. CR-001 closed; CR-002/003 still INFO/LOW deferred. |
| sdk-api-ergonomics-devil-python | **ACCEPT** | Live first-time-consumer dry-run confirms 1:1 design surface. |
| sdk-overengineering-critic | **ACCEPT** | One INFO (OE-006: `_is_closed_recheck` helper) — accepted as cleaner than `# type: ignore`. |
| sdk-marker-hygiene-devil | **PASS** | Marker discipline 100 % preserved across M5b. |

**4/4 reviewers green dynamically.** No new BLOCKER / HIGH / MEDIUM
findings. Iter-cap-5 NOT approached.

## Issue tracker — final state

| ID | Severity | Status | Notes |
|---|---|---|---|
| CR-001 | INFO | **CLOSED** | M5b commit `c793c5e` |
| CR-002 | INFO | DEFERRED-TO-FOLLOWUP | comment refinement, non-blocking |
| CR-003 / OE-005 | LOW | DEFERRED-TO-FOLLOWUP | design-documented in `concurrency-model.md` |
| OE-006 | INFO | DEFERRED-TO-FOLLOWUP | helper added in M5b; documented at site |
| PA-001 | MEDIUM | FILED to Phase 4 | bench_try_acquire_idle harness uses async factory (out of M5b scope per orchestrator brief) |
| PA-002 | MEDIUM | FILED to Phase 4 | bench_aclose_drain_1000 cross-loop future bug |
| PA-003 | MEDIUM | FILED to Phase 4 | perf-budget.md hot_paths declares stub symbols (G109 substantive PASS) |

## Deterministic-first gate (CLAUDE.md rule 13)

Iteration 2 modified production source under M5b → fleet was re-run
(iteration 3) per the rule. Iteration 3 modified zero artifacts → gate
not re-exercised; fleet does not loop again.

## Stuck detection

Not triggered. Single converging cycle with toolchain becoming live.

## Global iteration cap

3 / 10. Well within budget.

## Wave M8 / M8-DYN final verdict

**CONVERGED-WITH-NO-NEW-FINDINGS** at iteration 3. Production source
clean against ruff (0.4.10), mypy --strict, pytest 62/62, coverage
92.05 %.
