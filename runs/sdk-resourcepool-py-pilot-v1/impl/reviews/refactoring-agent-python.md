<!-- Generated: 2026-04-29T15:06:00Z | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 -->
<!-- Surrogate-authored-by: sdk-impl-lead (M5 wave; agent body not separately invoked because work is single-agent in scope) -->

# refactoring-agent-python — Wave M5

**Verdict: PARTIAL-PASS**

## Refactorings applied

| ID | Origin | Severity | Scope | Status |
|---|---|---|---|---|
| CV-001 | sdk-convention-devil-python (D3) | LOW | `_pool.py` lines 26, 335, 488, 490, 499, 504, 515, 520 — replace 7 `cast("typing.Callable[...]", ...)` string-form references with `cast("Callable[...]", ...)` and import `Callable` from `collections.abc`. The original references would fail mypy --strict because `typing` is not imported as a module name. | DONE (commit 8615aaa) |
| DD-005 | sdk-design-devil (D3) | LOW | `_pool.py` `Pool.acquire` docstring — append "Note: warm-startup pattern" recommending eager fill for slow-I/O `on_create`. | DONE (commit 8615aaa) |
| PK-001 | sdk-packaging-devil-python (D3) | LOW | `pyproject.toml` license SPDX form. | ALREADY-DONE (verified pre-existing as `license = "Apache-2.0"`) |
| PK-002 | sdk-packaging-devil-python (D3) | LOW | `[tool.uv]` block. | DECLINED (uv not the chosen toolchain; pre-existing pyproject header comment documents the decision) |
| (G200-py fix) | sdk-impl-lead static guardrail run | BLOCKER | `pyproject.toml` `requires-python` floor 3.11 → 3.12 + classifier + mypy.python_version + ruff.target-version sync. | DONE (commit 8615aaa); README.md updated in commit 35123d1 |

Total: 4 LOW design findings closed (CV-001, DD-005, PK-001, PK-002 —
3 fixes + 1 decline-with-rationale) + 1 BLOCKER guardrail fix.

## What did NOT run (verdict INCOMPLETE for these checks)

The M5 protocol mandates verification that `mypy --strict + ruff check +
ruff format --check + pytest` PASS after each refactoring. Without those
tools installed, only static checks succeeded:

| Check | Status |
|---|---|
| `python3 -c "ast.parse(...)"` over all changed files | PASS |
| `python3 -c "from motadata_py_sdk.resourcepool import *"` | PASS (all 9 exports importable) |
| Smoke runtime: construct Pool, acquire/release one resource, exercise try_acquire ConfigError on async-on_create | PASS |
| `mypy --strict src tests` post-refactor | INCOMPLETE (mypy not installed) |
| `ruff check . && ruff format --check .` | INCOMPLETE (ruff not installed) |
| `pytest -x` post-refactor | INCOMPLETE (pytest not installed) |

The CV-001 fix is correctness-critical and would fail mypy --strict in
its pre-state — that's the strongest evidence M5 made measurable
progress.

## Did the refactor introduce regressions?

Static answer: no. Diff is purely:
- import-list extension (`Callable` from `collections.abc`)
- string-literal cast replacement (`"typing.Callable[...]"` → `"Callable[...]"`)
- docstring append on `Pool.acquire`
- pyproject version-floor numeric edits

No control flow changed. No type signatures changed. No runtime behavior
changed (`cast` is identity at runtime).

## Iteration count

1 iteration. No stuck-detection trigger. No global cap concern.

## Convergence

CONVERGED on iteration 1. All 4 LOW findings actioned per
`design/review-fix-log.md` table.
