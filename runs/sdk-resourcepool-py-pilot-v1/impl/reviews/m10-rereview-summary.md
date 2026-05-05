<!-- Generated: 2026-04-28 | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 | Wave: M10 re-review (CLAUDE.md rule 13) -->

# M10 Re-Review — devil fleet pass on bench-file rework

Per CLAUDE.md rule 13 (Post-Iteration Review Re-Run), after Wave M10 rework re-runs the M7 devil fleet on the changed code. Scope of changes:

- `tests/bench/bench_acquire.py` — Fix 1 (try_acquire counter-mode harness)
- `tests/bench/bench_acquire_contention.py` — Fix 2 (drop sleep(0) + optimal-harness strict gate)
- `runs/<id>/impl/profile/g109-py-spy-top20.txt` (new) — Fix 3 (G109 evidence)
- `runs/<id>/impl/profile/profile-audit.md` (updated) — refreshed verdicts
- `runs/<id>/impl/profile/py-spy.txt` + `py-spy.svg` — raw profile artifacts
- No changes to `_pool.py`, `_acquired.py`, `_config.py`, `_stats.py`, `_errors.py`, `__init__.py`, or any unit/integration/leak test.

## Devil verdicts (all read-only)

### sdk-marker-scanner — PASS

The bench-file rewrites preserve all existing `[traces-to: TPRD-§...]` markers. The new strict-gate test functions added (`test_bench_try_acquire_per_op_under_5us`, `test_contention_throughput_meets_500k_per_sec_budget`) each carry the appropriate `[traces-to:]` marker in their docstring. No new pipeline-authored impl symbols (so no new constraint markers needed).

### sdk-marker-hygiene-devil — PASS

No marker forgery. No marker deletions. New tests have markers. Same vacuous PASS for G103 / G110 (still no MANUAL code, still empty `design/perf-exceptions.md`).

### sdk-overengineering-critic — ACCEPT (1 advisory note)

The counter-mode harness in `bench_try_acquire` adds local helpers (`_setup`, `_runner`) to interface with `pytest-benchmark.pedantic`. The `held: list[int]` accumulator carried across rounds via closure is intentional (the only way to release-outside-timed-window with pytest-benchmark's per-round semantics). Not over-engineered for the goal.

The strict-gate `test_bench_try_acquire_per_op_under_5us` duplicates some logic of the pytest-benchmark version. Justification: the strict-gate test runs WITHOUT `--benchmark-only`, so it asserts the budget on every normal `pytest tests/` run; the pytest-benchmark version produces the visible round-by-round table for human review. Different audiences, both useful. Not duplication.

ME-001 (advisory): The contention strict-gate test assertion currently FAILS (458k < 500k). This is intentional — it surfaces the impl ceiling to the H7 reviewer as a visible test failure. NOT skipped; NOT marked xfail; the FAIL is the data the reviewer needs.

### code-reviewer — ACCEPT (no new findings)

PEP 8: clean (ruff 0 findings).
Type hints: clean (mypy --strict 0 errors across 26 files).
Asyncio: the new harnesses correctly use `asyncio.gather` instead of `TaskGroup` where amortization matters; `nullcontext` semantics exploited correctly via `timeout=None`; `acquire_resource` raw form used with explicit `try/finally`-equivalent close semantics.
Error handling: no new exception paths introduced.
Naming: `BATCH` and `ROUNDS` upper-case-locals carry `# noqa: N806` with rationale (bench-harness constants kept upper-case for clarity).

### sdk-security-devil — ACCEPT (no new findings)

Bench files don't change the security posture. No new credentials, no new I/O, no new deserialization. `py-spy` profile artifacts are CPU sample data — they contain no credentials, no payload data, and no PII. Safe to ship in the run dir.

### sdk-api-ergonomics-devil — ACCEPT (no public-surface change)

The user-facing API (Pool, PoolConfig, etc.) is unchanged. All M10 work was in tests + profile tooling. No callsite friction added; no new defaults; no new error messages on public paths.

---

## Re-review verdict: ACCEPT

Zero BLOCKER findings on the M10 changes. One advisory note (overengineering ME-001) explicitly documents the intentional FAIL of the contention strict-gate test as the ESCALATION mechanism. Recommend H7 review proceed; the FAIL is the signal, not noise.
