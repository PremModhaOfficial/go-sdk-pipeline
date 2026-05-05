<!-- Generated: 2026-04-28 | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 | Author: sdk-testing-lead | Wave: T1 (leak-hunter equivalent) -->

# Leak-harness report (Wave T1)

Two parts:

1. **Leak-suite stability** — `tests/leak/test_no_leaked_tasks.py` re-run 5×, all green.
2. **Sensitivity check** — sandbox negative test confirms the `assert_no_leaked_tasks` fixture actually catches a deliberate leak.

## Part 1: leak-suite stability (5× re-run)

```
$ for i in 1..5; do pytest -q tests/leak/; done
```

| Run | Tests | Result | Wallclock |
|---|---|---|---|
| 1 | 5 | 5 passed | 0.14 s |
| 2 | 5 | 5 passed | 0.13 s |
| 3 | 5 | 5 passed | 0.14 s |
| 4 | 5 | 5 passed | 0.14 s |
| 5 | 5 | 5 passed | 0.13 s |

**5/5 reps × 5 tests = 25/25 PASS. No leaks across acquire / cancel / timeout / aclose / outstanding-cancel paths.**

## Part 2: fixture-sensitivity check (sandbox negative test)

A negative test is at `runs/<id>/testing/sandbox/test_leak_harness_negative.py` — NOT committed to the impl branch (per orchestrator brief boundary).

The test loads `tests/conftest.py` as a module, drives the `assert_no_leaked_tasks` async-generator manually, and asserts:

1. **`test_fixture_catches_deliberate_leak`** — drives the fixture with a body that creates an asyncio task and never awaits it. The fixture should raise `pytest.fail("Leaked …")` at teardown. Test PASSES if the fixture raises (sensitivity confirmed); FAILS if the fixture completes silently (insensitivity = ESCALATION:LEAK-HARNESS-INSENSITIVE).

2. **`test_fixture_does_not_false_positive_on_clean_body`** — drives the fixture with a clean body. Test PASSES if the fixture exhausts cleanly without raising.

```
$ pytest --rootdir=. -v testing/sandbox/test_leak_harness_negative.py
collected 2 items

::test_fixture_catches_deliberate_leak PASSED                            [ 50%]
::test_fixture_does_not_false_positive_on_clean_body PASSED              [100%]

============================== 2 passed in 0.02s ===============================
```

**Both negative tests PASS — fixture is sensitive (catches deliberate leaks) AND specific (no false positives on clean bodies).**

## Verdict

**PASS** — leak suite is stable across 5 reps; the underlying detector logic is verified sensitive on a deliberate leak. No ESCALATION:LEAK-HARNESS-INSENSITIVE.

Sandbox file: `runs/sdk-resourcepool-py-pilot-v1/testing/sandbox/test_leak_harness_negative.py`
