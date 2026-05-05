<!-- Generated: 2026-04-28 | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 | Author: sdk-testing-lead | Wave: T1 -->

# Flake-detection report (Wave T1, TPRD §11.5)

Per TPRD §11.5: pytest-asyncio strict mode + `--count=10` flake detection.

```
$ pytest --count=10 -q tests/unit/ tests/integration/ tests/leak/
```

| Metric | Value |
|---|---|
| pytest plugin | `pytest-repeat==0.9.4` (installed at T0) |
| asyncio mode | `strict` (per `pyproject.toml [tool.pytest.ini_options].asyncio_mode`) |
| Test set | 69 tests in `tests/unit/` + `tests/integration/` + `tests/leak/` |
| Repetitions | 10 |
| Total invocations | 690 |
| **Passed** | **690** |
| **Failed** | **0** |
| **Flaky** | **0** |
| Wallclock | 5.54 s |

## Per-test 10/10 table (summary)

All 69 tests passed 10/10 (no flakes). Full per-test 10/10 confirmation captured in pytest-repeat's progress meter (each test prints once per iteration; all 10 dots green for every test):

- `tests/unit/test_aclose.py` — 6 tests × 10 = 60/60 PASS
- `tests/unit/test_acquire_release.py` — 9 tests × 10 = 90/90 PASS
- `tests/unit/test_cancellation.py` — 4 tests × 10 = 40/40 PASS
- `tests/unit/test_construction.py` — 28 tests × 10 = 280/280 PASS
- `tests/unit/test_hook_panic.py` — 9 tests × 10 = 90/90 PASS
- `tests/unit/test_timeout.py` — 4 tests × 10 = 40/40 PASS
- `tests/integration/test_chaos.py` — 2 tests × 10 = 20/20 PASS
- `tests/integration/test_contention.py` — 2 tests × 10 = 20/20 PASS
- `tests/leak/test_no_leaked_tasks.py` — 5 tests × 10 = 50/50 PASS

**Total: 690/690 PASS. Zero flakes detected.**

## Verdict

**PASS** — TPRD §11.5 requirement satisfied; no flakes under strict asyncio mode at 10× repetition.
