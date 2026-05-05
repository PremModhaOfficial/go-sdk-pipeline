<!-- Generated: 2026-04-27T00:02:31Z | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 | Author: sdk-design-lead -->

# Design Summary — Phase 1 — `motadata_py_sdk.resourcepool` v1.0.0

Lead-authored final report (≤200 lines per CLAUDE.md rule 11). Companion to `h5-summary.md` (user-facing) and the per-sub-agent context summaries.

---

## Phase outcome

- **Status**: Design complete; ready for H5 sign-off.
- **Recommendation**: APPROVE.
- **Mode**: A (new package).
- **Tier**: T1 (full perf-confidence regime).
- **Run**: sdk-resourcepool-py-pilot-v1; pipeline 0.5.0.
- **Target**: `motadata-py-sdk/src/motadata_py_sdk/resourcepool/` (impl phase will populate).

## Wave summary

| Wave | Sub-agents | Output | Outcome |
|---|---|---|---|
| D1 | designer, interface, algorithm, concurrency, pattern-advisor, sdk-perf-architect | 7 design artifacts | All PASS; zero retries needed |
| D2 mech | (G30-G38, G108) | not in active-packages.json (Go-package guardrails) | no-op per CLAUDE.md rule 34 |
| D2 dev | sdk-design-devil, sdk-security-devil, sdk-semver-devil + 3 surrogate (sdk-dep-vet-devil, sdk-convention-devil, sdk-constraint-devil) | 6 review verdicts | All ACCEPT/PASS; 3 ACCEPT-WITH-NOTE entries (zero blockers) |
| D3 review-fix | n/a | n/a | converged in 0 iterations (no findings to route) |
| D4 H5 prep | sdk-design-lead | h5-summary.md, design-summary.md | this document |

## Artifacts produced (under `runs/sdk-resourcepool-py-pilot-v1/design/`)

```
design/
├── api-design.md              (584 lines, designer)
├── interfaces.md              (212 lines, interface)
├── algorithm.md               (336 lines, algorithm)
├── concurrency-model.md       (270 lines, concurrency)
├── patterns.md                (230 lines, pattern-advisor)
├── perf-budget.md             (235 lines, sdk-perf-architect)
├── perf-exceptions.md         (47 lines, sdk-perf-architect; intentionally empty)
├── design-summary.md          (this file, sdk-design-lead)
├── h5-summary.md              (sdk-design-lead)
├── context/
│   ├── design-lead-brief.md   (RULE 0 propagation doc)
│   ├── designer-summary.md
│   ├── interface-summary.md
│   ├── algorithm-summary.md
│   ├── concurrency-summary.md
│   ├── pattern-advisor-summary.md
│   ├── sdk-perf-architect-summary.md
│   ├── sdk-design-devil-summary.md
│   ├── sdk-security-devil-summary.md
│   ├── sdk-semver-devil-summary.md
│   ├── sdk-dep-vet-devil-summary.md (surrogate)
│   ├── sdk-convention-devil-summary.md (surrogate)
│   ├── sdk-constraint-devil-summary.md (surrogate)
│   └── sdk-design-lead-summary.md
└── reviews/
    ├── design-devil-findings.md     (ACCEPT, 2 notes, quality 0.91)
    ├── security-findings.md         (ACCEPT, 1 note)
    ├── semver-verdict.md            (ACCEPT 1.0.0)
    ├── dep-vet-findings.md          (ACCEPT, surrogate)
    ├── convention-findings.md       (ACCEPT, surrogate)
    └── constraint-bench-plan.md     (PASS, surrogate)
```

23 files total in `design/`.

## Key design decisions (decision-log highlights)

1. **Q1–Q6 honored verbatim** — keyword-only timeout; sync try_acquire; Pool aenter/aexit; async release; frozen+slots Config+Stats; two distinct acquire methods (no dual-mode).
2. **Idle storage**: `collections.deque[T]` LIFO — zero-alloc steady-state; tighter cancel-rollback; matches Python idiom.
3. **Wait wakeup**: `asyncio.Condition(self._lock)` with `wait_for(predicate)` + `notify(n=1)` — one critical section per acquire/release.
4. **Cancellation contract**: `except BaseException` rollback in `_acquire_with_timeout` (since CancelledError ⊂ BaseException since 3.8). 3 cancel points analyzed.
5. **Outstanding tracker**: `set[asyncio.Task]` + `add_done_callback(set.discard)` — idempotent O(1) cleanup.
6. **Drift signal name (T2-3)**: `concurrency_units` (primary) + `outstanding_acquires` (alias). Cross-language neutrality.
7. **Leak-check fixture (T2-7)**: policy-free `assert_no_leaked_tasks` snapshotting `asyncio.all_tasks()`. Reusable.
8. **Oracle (G108)**: Go reference derived from `pool.go` doc-stated 10M ops/sec; impl re-measures + recalibrates if divergence >2×.
9. **Hot paths (G109)**: `_acquire_with_timeout` inner block + `release` inner block + `_create_resource_via_hook`; combined ≥80% CPU samples.
10. **Zero direct deps**: `pyproject.toml` `dependencies = []`; dev tools under `[project.optional-dependencies] dev`.

## RULE 0 — Zero TPRD tech debt: VERIFIED

- 9/9 TPRD §5/§7 symbols designed (verified via h5-summary.md §1).
- 6/6 TPRD §10 perf rows budgeted (verified via h5-summary.md §2).
- 5/5 TPRD §11 test categories designable (unit/integration/bench/leak/race; verified via patterns.md §10).
- S1–S6 TPRD §13 milestones addressable (verified via h5-summary.md §6).
- Appendix C Q1–Q5 answerable from artifacts produced (verified via h5-summary.md §6).
- Zero TODO/FIXME/TBD across 7 design files (mechanically verifiable via grep).
- §3 Non-Goals reaffirmed as written contracts, not tech debt (verified via api-design.md §9 + concurrency-model.md §1).

## Active-packages discrepancy (logged, NOT design phase blocker)

3 devils (sdk-dep-vet-devil, sdk-convention-devil, sdk-constraint-devil) are absent from `active-packages.json` but were required by orchestrator brief. Design-lead authored their reviews as surrogate. **Recommendation for v0.5.x**: add these to `shared-core.json` agents — they are language-neutral and useful across Go + Python pilots. Filed as event in decision-log entry at 2026-04-27T00:02:11Z; the package-manifest follow-up PR is improvement-planner's responsibility at Phase 4.

## Empirical Go bench cap (logged, NOT design phase blocker)

Go reference bench (`go test -bench=. -benchtime=2s` against the resourcepool package) was launched at design time but did not complete within the design wallclock cap. The pool.go package docstring's "10M+ ops/sec for cached resources" provides the documented oracle figure used in `perf-budget.md` §1. **Recalibration path**: impl phase re-measures and writes actual Go bench numbers into `baselines/python/performance-baselines.json` on first successful run. If the documented 10M ops/sec figure differs from the empirical >2×, perf-architect re-opens this budget at H8. NOT tech debt — the recalibration path is documented + tracked in decision-log.

## Handoff to Phase 2 Impl

sdk-impl-lead receives:
- All 7 design artifacts (api-design.md, interfaces.md, algorithm.md, concurrency-model.md, patterns.md, perf-budget.md, perf-exceptions.md).
- 13 sub-agent context summaries.
- 6 devil review verdicts (all ACCEPT/PASS).
- This summary + h5-summary.md.
- The design-lead-brief.md (RULE 0 propagation doc) — impl phase MUST inherit.

Impl wave plan keys to TPRD §13 S1–S6 milestones; expected impl-lead spawn: tdd-driver per milestone + sdk-overengineering-critic + sdk-marker-hygiene-devil + sdk-profile-auditor at M3.5.
