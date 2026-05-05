<!-- Generated: 2026-04-28 | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 | Author: sdk-testing-lead -->

# Phase 3 testing summary

## Overall verdict: **APPROVE for H9** (one informational CALIBRATION-WARN advisory)

## Wave-by-wave

| Wave | Scope | Verdict | Detail |
|---|---|---|---|
| **T0** | Phase prep (env, branch, MCP) | PASS | branch on `bd14539` clean; venv reinstalled; G04 MCP OK |
| **T1** | Coverage + flake + leak | PASS | coverage 92.33% (≥90% gate); flake 690/690 PASS; leak 5× clean + sandbox negative-test confirms fixture sensitive |
| **T2** | Bench + perf gates | PASS / CALIBRATION-WARN | 6/7 oracle margins PASS; contention is host-load CALIBRATION-WARN; G104 PASS; G107 slope -0.085 PASS; G109 cited from impl |
| **T3** | Soak + drift | PASS | 600.38 s ≥ 600 s MMD; 20 samples; controlling signals (concurrency_units, outstanding_acquires, gen1, gen2) all flat; heap_bytes positive slope annotated as GC oscillation |
| **T4** | Supply chain | PASS | pip-audit + safety both clean; 11/11 dev deps on license allowlist; pyproject `dependencies = []` |
| **T5** | Devil reviews | PASS / ACCEPT | 8 devils evaluated (5 cited from impl, 3 re-run); zero BLOCKER, zero ACCEPT-with-fix |
| **T6** | Review-fix loop | N/A | no findings to fix |
| **T7** | H8 + H9 prep | DONE | both summaries written |

## RULE 0 attestation

The user's "ZERO tech debt on the TPRD" constraint is fully satisfied for the testing phase. Every TPRD §11 category has ≥ 1 real test running and passing; every TPRD §10 perf row is benched and measured (with the contention CALIBRATION-WARN being a documented host-load advisory, not tech debt). §11.5 `--count=10` flake detection actually ran. Coverage was independently re-verified by testing-lead. Leak harness sensitivity was independently re-verified by sandbox negative test. No `@pytest.mark.skip`-without-link; no empty bodies; no benches-without-loops. The impl branch was NOT modified (no new commits; head still `bd14539`).

## Files written

### Testing artifacts (`runs/sdk-resourcepool-py-pilot-v1/testing/`)

```
context/testing-lead-brief.md
context/sdk-testing-lead-summary.md         (this wave's downstream context)
mcp-health.md
coverage-report.json                          (machine output)
coverage-summary.md                            (testing-lead authored)
htmlcov/                                       (pytest-cov HTML)
flake-report.md
leak-harness-report.md
sandbox/test_leak_harness_negative.py        (negative test, NOT committed to impl)
bench-results.json                            (pytest-benchmark JSON)
bench-report.md                                (testing-lead authored)
complexity-report.md
soak/soak_runner.py                          (v2 thread-poller harness)
soak/state.jsonl                              (22 lines: sentinel + 20 samples + complete)
soak/soak.log                                 (background-process stdout/err)
soak-verdict.md                                (G105)
drift-verdict.md                               (G106)
supply-chain-report.md
reviews/devil-summary.md                      (Wave T5 aggregate)
h8-summary.md                                  (perf-gate sign-off)
h9-summary.md                                  (testing sign-off)
testing-summary.md                             (this file)
```

### Baselines (first-run seeds, `baselines/python/`)

```
performance-baselines.json                    (per-symbol measured numbers)
coverage-baselines.json                       (per-file %; aggregate 92.33%)
output-shape-history.jsonl                    (9-symbol exported surface)
devil-verdict-history.jsonl                   (per-skill verdict for compensating-baseline tracking)
do-not-regenerate-hashes.json                 (empty — Mode A new package)
stable-signatures.json                        (v1.0.0 signature lock per [stable-since:])
```

### Run-state mutation

- `runs/<id>/state/run-manifest.json` `phases.testing` updated to `completed` (next message).
- `runs/<id>/decision-log.jsonl` lifecycle entry appended.

## Key numbers

- **Tests**: 81 unit/integration/leak + 14 bench tests = 95 active suites.
- **Coverage**: 92.33% combined; all six files ≥ 90%.
- **Flake stress**: 690 / 690 PASS at `--count=10`.
- **Soak**: 40,256,000 ops in 600.38 s; 20 samples; controlling generational signals flat.
- **Bench rows measured**: 7 design-budget rows (6 PASS, 1 CALIBRATION-WARN).
- **Complexity slope**: −0.085 (consistent with declared O(1) amortized).
- **Alloc budget**: 0.04 allocs / op vs 4 budget (100× headroom).
- **Vulnerabilities**: 0 across 79 packages.

## ESCALATIONS

**None.** No ESCALATION:IMPL-BUG-FOUND-DURING-TESTING; no ESCALATION:LEAK-HARNESS-INSENSITIVE; no ESCALATION:FLAKY-TEST.

The CALIBRATION-WARN on contention is informational; surfaced for H10 awareness but does not block sign-off (CI gate floor met across reruns; v1.1.0 follow-up TPRD already filed at impl-phase M11).

## Recommendation

**APPROVE** for H9 testing sign-off and H10 merge verdict.
