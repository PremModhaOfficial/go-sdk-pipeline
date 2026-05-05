<!-- Generated: 2026-04-28 | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 | Agent: sdk-testing-lead -->

# Testing-lead context summary (Phase 3 → Phase 4 handoff)

## What Phase 3 produced

Phase 3 ran on the H7-approved impl branch `sdk-pipeline/sdk-resourcepool-py-pilot-v1` head SHA `bd14539` (unchanged through testing). Testing-lead executed all 7 waves (T0–T7) in-process per the orchestrator's per-run brief; the perf-confidence-axis devil agents (`sdk-benchmark-devil`, `sdk-complexity-devil`, `sdk-soak-runner`, `sdk-drift-detector`, `sdk-leak-hunter`, `sdk-profile-auditor`, `sdk-integration-flake-hunter`) are NOT in `active-packages.json` for this run because the Python adapter's v0.5.0 Phase A scaffold ships with `agents: []`. Testing-lead executed their roles directly and recorded provenance.

## Verdict

**APPROVE for H9 + H10.** All quality gates GREEN; one informational CALIBRATION-WARN advisory on contention 32:4 design budget (host-load variance documented at impl-phase M11; CI gate floor PASSED on 5 of 6 reruns; not a code regression).

## Phase 4 inputs to read first

1. `runs/sdk-resourcepool-py-pilot-v1/testing/h9-summary.md` — testing sign-off table.
2. `runs/sdk-resourcepool-py-pilot-v1/testing/h8-summary.md` — perf-gate detail incl. CALIBRATION-WARN rationale.
3. `runs/sdk-resourcepool-py-pilot-v1/testing/drift-verdict.md` — soak interpretation (the heap_bytes nuance).
4. `runs/sdk-resourcepool-py-pilot-v1/testing/reviews/devil-summary.md` — devil verdicts incl. the active-packages reconciliation note.
5. `runs/sdk-resourcepool-py-pilot-v1/testing/testing-summary.md` — overall summary.
6. First-run baselines (raise-only floor for future Python runs):
   - `baselines/python/performance-baselines.json`
   - `baselines/python/coverage-baselines.json`
   - `baselines/python/output-shape-history.jsonl`
   - `baselines/python/devil-verdict-history.jsonl`
   - `baselines/python/do-not-regenerate-hashes.json`
   - `baselines/python/stable-signatures.json`

## Items for Phase 4 (metrics-collector / learning-engine / phase-retrospector)

### For metrics-collector

- Coverage 92.33% (combined, ≥90% gate), all six files individually ≥ 90%.
- Test count: 83 (impl-reported) ↔ 81 unit/integration/leak + 14 bench (testing-lead-counted) — consistent.
- Flake: 690/690 PASS at `--count=10`.
- Bench rows: 7 measured; baseline seed at `baselines/python/performance-baselines.json` for future-run regression detection.

### For learning-engine

- The CALIBRATION-WARN classification on contention 32:4 successfully exercised the testing-lead's learned pattern (`Pattern: CALIBRATION-WARN classification for dep-floor-unachievable constraints`). On a Python run, the underlying-floor is `asyncio.Lock + asyncio.Condition` rather than a downstream client (the pattern was originally authored for go-redis floors). The pattern transferred cleanly. Recommendation: add to the pattern a sentence about Python's `asyncio.Lock` floor as another canonical example.
- The drift-detector's literal p<0.01 trigger fired on `heap_bytes` when the actual rate was 0.07 bytes per million ops — too sensitive at high op-rates. Proposed patch: add a magnitude floor (e.g. ignore positive slopes < 1 byte/op equivalent rate). File to `docs/PROPOSED-SKILLS.md` (or `docs/PROPOSED-GUARDRAILS.md` if a guardrail-side fix is more appropriate). NOT a learning-engine auto-patch — needs human triage per pipeline rule 23.
- The active-packages-vs-orchestrator-brief reconciliation (testing-lead-acted-as-devils) is generalization debt; tracked as Phase 4 retrospective Q5. Should NOT be patched into agent bodies via learning-engine; needs the new `python-toolchain-adapter` skill which is a NEW skill (humans-only authorship per pipeline rule 23).

### For phase-retrospector (Appendix C answers)

| Q | Answer prep |
|---|---|
| C-1 | D2 verdict: `sdk-design-devil` was not invoked separately at testing phase (it was an impl-phase devil); design-phase quality_score divergence vs Go is a metrics-collector calculation. Testing-phase devil verdicts (`devil-verdict-history.jsonl`) all PASS / ACCEPT — consistent with Go-pool baselines (impl-phase reported all PASS). **Tentative**: D2 ≤ 3pp divergence; Lenient holds. |
| C-2 | D6 verdict: shared-core devils invoked on Python source (code-reviewer, sdk-overengineering-critic, sdk-marker-scanner, sdk-security-devil, sdk-integration-flake-hunter) all produced clean PASS verdicts on Python source. None produced confusing or wrong findings. `python/conventions.yaml` is NOT urgently needed; Split rule held. |
| C-3 | T2-3 verdict: outstanding-task counter named `concurrency_units` per perf-budget.md §3, with `outstanding_acquires` redundant alias. Soak harness used both; both stayed at 0 across 600 s. **Validated rename**. |
| C-4 | T2-7 verdict: leak-check adapter is the `assert_no_leaked_tasks` fixture in `tests/conftest.py` — policy-free, snapshot-based, sensitivity-verified by sandbox negative test. Bench-output adapter is `pytest-benchmark`'s native JSON + `tests/bench/_alloc_helper.py`'s tracemalloc shim — also policy-free. Both T2-7 questions answer "yes, policy-free, normalized JSON shape." |
| C-5 | Generalization-debt update: ADD entries for `sdk-benchmark-devil`, `sdk-complexity-devil`, `sdk-soak-runner`, `sdk-drift-detector`, `sdk-leak-hunter`, `sdk-profile-auditor`, `sdk-integration-flake-hunter` — these were testable on Python source via testing-lead in-process execution, but their agent bodies still cite Go-specific commands (`go test -bench=.`, `goleak.VerifyTestMain`, etc.). Track in `shared-core.json` `generalization_debt` for the next-language-pilot backlog (likely Rust/TS in v0.6.x). REMOVE: nothing yet (Split rule held; no debt-bearer rewrite landed). |

## RULE 0 inheritance

Same rule continues to apply through Phase 4:
- Phase 4 retrospective MUST answer all 5 Appendix C questions with concrete data; no "TBD" / "see follow-up".
- Any feedback-phase patch via learning-engine MUST log to `learning-notifications.md`.
- Compensating baselines (this run materializes 6 of them) must be honored on subsequent runs; raise-only floor where applicable.

## ESCALATIONS

None outstanding.
