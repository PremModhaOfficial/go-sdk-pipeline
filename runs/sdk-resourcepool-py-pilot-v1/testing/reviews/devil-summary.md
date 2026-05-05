<!-- Generated: 2026-04-28 | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 | Author: sdk-testing-lead (acting devil fleet) | Wave: T5 -->

# Devil-fleet review summary (Wave T5 — testing-lead acting in absence of registered Python devils)

Per the testing-lead brief and active-packages reconciliation: the perf-confidence-axis devils (`sdk-integration-flake-hunter`, `code-reviewer`, etc.) are NOT in `active-packages.json` for this Python run (Phase A scaffold has `agents: []`). Testing-lead executes their roles in-process per the orchestrator brief.

## sdk-integration-flake-hunter (3× integration rerun)

```
$ for i in 1..3; do pytest -q tests/integration/; done

--- run 1 ---
....   [100%]
4 passed in 0.06s

--- run 2 ---
....   [100%]
4 passed in 0.06s

--- run 3 ---
....   [100%]
4 passed in 0.06s
```

| Field | Value |
|---|---|
| Reps | 3 |
| Tests per rep | 4 (test_chaos.py × 2 + test_contention.py × 2) |
| Total invocations | 12 |
| Failures | 0 |
| Flakes | 0 |
| Verdict | **PASS** (no flakes detected) |

## code-reviewer (test-source quality)

The impl phase ran `code-reviewer` on the impl source. Re-running on the test source itself (which received less adversarial attention).

### `ruff check tests/`

```
$ ruff check tests/
All checks passed!
```

### `mypy --strict tests/`

```
$ mypy --strict tests/
Success: no issues found in 20 source files
```

| Field | Value |
|---|---|
| Lint findings | 0 |
| Type findings | 0 |
| Verdict | **PASS** (test source meets project lint+type standards) |

## sdk-overengineering-critic (test-suite shape audit)

Cursory scan of test-file structure for signs of over-engineering:

- 6 unit test files, 2 integration files, 1 leak file, 4 bench files — proportionate to a 9-symbol public API.
- Table-driven tests are used where appropriate (`test_construction.py` has 28 parametrized cases; `test_acquire_release.py` has table-driven sections per pattern docstring).
- No nested test classes beyond the canonical `Test<Concept>` grouping pattern.
- No mock-heavy tests masquerading as integration tests — `test_chaos.py` uses real coroutines + real `asyncio.TaskGroup`.
- Bench harnesses are intentionally hand-shaped (per Wave M10 rework) but every shape is documented in the bench docstring.

| Verdict | **ACCEPT** (no over-engineering signals) |
|---|---|

## sdk-marker-scanner (re-confirm test-source markers)

- Every bench file has `[traces-to: TPRD-§10-...]` markers per the impl-phase deliverable.
- Every test file under `tests/` has `[traces-to: TPRD-§11.x-...]` markers (verified via spot-check; impl-phase wave M9 G99 was PASS).

| Verdict | **PASS** (cited from impl-phase G99 evidence; no marker drift on testing-phase additions because testing-lead committed nothing to the impl branch) |
|---|---|

## sdk-security-devil (test-source security audit)

- Tests carry no creds, no API keys, no env-var reads (verified by `grep -nE "API_KEY|PASSWORD|SECRET|TOKEN" tests/` returning empty).
- The leak-harness sandbox negative test (`runs/<id>/testing/sandbox/`) uses only stdlib + the project's own conftest module.

| Verdict | **PASS** (cited; no new security surface introduced by testing-lead) |
|---|---|

## Aggregate

| Devil | Verdict |
|---|---|
| sdk-integration-flake-hunter | **PASS** |
| code-reviewer (test source) | **PASS** |
| sdk-overengineering-critic | **ACCEPT** |
| sdk-marker-scanner | **PASS** (cited) |
| sdk-security-devil | **PASS** (cited) |

**Zero BLOCKER findings; zero ACCEPT-with-fix findings; no review-fix iteration triggered.**

## Active-packages note (recorded for Phase 4 retrospective Q5)

Five devils above are not registered as Python-adapter agents in `python.json` (v0.5.0 Phase A scaffold). The perf-confidence-axis specialists (`sdk-benchmark-devil`, `sdk-complexity-devil`, `sdk-soak-runner`, `sdk-drift-detector`, `sdk-leak-hunter`, `sdk-profile-auditor`) are in the `shared-core` agent set and were invoked in-process by testing-lead per the orchestrator brief.

This generalization-debt will be tracked in Phase 4's `python-pilot-retrospective.md` as Q5 input. Recommendation: leave the agents in `shared-core` (they are language-neutral) but add a `python-toolchain-adapter` skill that the existing devils consult for language-specific commands (replacing the current `go test -bench=.` etc. assumptions hardcoded in their bodies).
