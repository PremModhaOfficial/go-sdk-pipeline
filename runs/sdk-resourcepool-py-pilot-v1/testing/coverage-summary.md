<!-- Generated: 2026-04-28 | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 | Author: sdk-testing-lead | Wave: T1 -->

# Coverage report (Wave T1)

Re-run by testing-lead at Wave T1; impl-reported number was 92.33% — verified.

```
$ pytest --cov=src/motadata_py_sdk/resourcepool \
         --cov-report=term --cov-report=json --cov-report=html \
         --cov-fail-under=90 --cov-branch \
         tests/unit/ tests/integration/ tests/leak/
```

| Metric | Value |
|---|---|
| Tests run | 69 (unit + integration + leak) |
| Tests passed | 69/69 |
| Total statements | 258 |
| Statements covered | 247 |
| Missing lines | 11 |
| Total branches | 68 |
| Branches covered | 54 |
| Missing branches | 14 (12 partial + 2 fully unreached counted by coverage) |
| Excluded lines | 6 (TYPE_CHECKING blocks + `raise NotImplementedError` lines per `[tool.coverage.report] exclude_lines`) |
| **% statements covered** | **95.74%** |
| **% branches covered** | **79.41%** |
| **% lines+branches combined (the gate)** | **92.33%** |
| `--cov-fail-under=90` gate | **PASS** |

## Per-file table

| File | Stmts | Miss | Branch | BrPart | Cover |
|---|---|---|---|---|---|
| `__init__.py` | 8 | 0 | 0 | 0 | **100%** |
| `_acquired.py` | 18 | 0 | 2 | 1 | **95%** |
| `_config.py` | 18 | 0 | 0 | 0 | **100%** |
| `_errors.py` | 6 | 0 | 0 | 0 | **100%** |
| `_pool.py` | 199 | 11 | 66 | 11 | **91%** |
| `_stats.py` | 9 | 0 | 0 | 0 | **100%** |
| **TOTAL** | **258** | **11** | **68** | **12** | **92%** |

All six files ≥ 90%. The 11 missing statements in `_pool.py` are concentrated in:

- `try_acquire` lines 241–243 — the sync-`on_create` raise-and-rollback path inside the `try_acquire` fast-path that is exercised in unit tests via `test_try_acquire_with_async_on_create_raises_config_error` but the lines are inside an exception handler invoking `_destroy_resource_via_hook(t, error_context)` whose `error_context` branch isn't fully covered.
- `aclose` lines 390, 392–396 — the inner cancel-and-await branch when `timeout` is set AND outstanding tasks survive the wait (an additional code path beyond what the existing `test_aclose_cancels_blocked_acquirers_after_timeout` exercises).
- `_create_resource_via_hook` line 549 — one branch of the sync-vs-async detection that is short-circuited by `inspect.iscoroutine` returning eagerly.
- `_reset_resource_via_hook` line 564 — one branch of the sync-vs-async detection.

These are real branch-coverage gaps but each falls inside a defensive code path. They are NOT TPRD-§11 categories that lack a test (every category has ≥1 test). The aggregate stays well above the 90% gate. Per RULE 0 the gate's hard floor is the 90% line — that is met (92.33%).

## Verdict

**PASS** — 92.33% combined coverage; all six files ≥ 90% individually; gate met.

Coverage JSON: `coverage-report.json`
HTML report: `htmlcov/index.html`
