<!-- Generated: 2026-04-29T15:08:25Z | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 -->

# sdk-impl-lead — Phase 2 Context Summary (≤200 LOC)

For sdk-testing-lead. Self-contained.

## What's done

- Branch `sdk-pipeline/sdk-resourcepool-py-pilot-v1` is at HEAD
  `35123d1` (off master `4f8856c`). Four commits.
- All 9 §7 public symbols implemented in `src/motadata_py_sdk/resourcepool/`
  across `_pool.py / _config.py / _stats.py / _acquired.py / _errors.py /
  __init__.py`. `py.typed` marker present.
- Test scaffolding: 8 unit modules, 5 bench modules, 1 integration
  module, 1 leak module. All 21 test files parse via stdlib `ast`.
- M5 closed 4 design-phase LOW findings (CV-001, DD-005, PK-001,
  PK-002) and fixed G200-py (`requires-python` floor 3.11→3.12).
- M6 shipped `docs/USAGE.md` (165 LOC) + `CHANGELOG.md`.

## What's NOT done — and why

The host has only stdlib Python 3.12. No `pip`, `pytest`, `mypy`,
`ruff`, `hypothesis`, `pytest-benchmark`, `py-spy`, `scalene`, `psutil`,
`pip-audit`, or `safety`. This blocks:

- M3.5 `sdk-profile-auditor-python` — INCOMPLETE; G104 + G109 cannot
  render a verdict.
- M9 `G41-py` (build) / `G42-py` (mypy) / `G43-py` (ruff) — INCOMPLETE.
- M5 / M6 / M7 dynamic verification (mypy/ruff/pytest after each
  change) — INCOMPLETE.

Per CLAUDE.md rule 33, INCOMPLETE NEVER silently promotes to PASS.

## What sdk-testing-lead should know

1. **The same toolchain gap applies to Phase 3.** `pytest`,
   `pytest-asyncio`, `pytest-benchmark`, `pytest-cov`, `hypothesis`,
   `pytest-repeat`, `pip-audit`, `safety` are all required by the
   testing-phase guardrails (G60-py, G61-py, G63-py, G69) and by every
   testing wave (T1 unit / T2 hypothesis / T3 flake hunt / T4
   integration / T5 bench-complexity / T5.5 soak / T6 leak).

2. **Hot-path symbols are stub-declared at `_pool.py:528-554`** to
   satisfy `sdk-profile-auditor-python` symbol resolution
   (`_acquire_idle_slot`, `_release_slot`, `_create_resource_via_hook`).
   Their bodies are intentional no-ops; the actual hot work happens
   inline inside `acquire_resource` and `release`. Declared in
   `perf-budget.md:hot_paths`.

3. **G110 is vacuously PASS** — zero `[perf-exception:]` markers exist,
   zero `design/perf-exceptions.md` entries exist. Both sides match.

4. **CV-001 was a real bug** — `_pool.py` had 7 `cast("typing.Callable[...]", ...)`
   string-form references but `typing` wasn't imported as a module.
   mypy --strict would have flagged `[name-defined]` on every one.
   Fixed in M5 commit `8615aaa`. The smoke-runtime check passed both
   pre- and post- because `cast` is identity at runtime.

5. **The 3 LOW/INFO findings I deferred to follow-up are documentation/idiom**
   issues only:
   - CR-001 / `raise asyncio.TimeoutError` vs `raise TimeoutError` — alias is stable
   - CR-002 / explanatory comment on `_pool.py:280-291` cancel rollback path
   - CR-003 + OE-005 / `aclose` poll-loop vs `Condition.wait_for` — design choice documented

6. **Branch will NOT be pushed to remote** (settings.json `never_push:
   true`). Testing-lead must operate on the local branch.

## Live state to inherit

- `runs/sdk-resourcepool-py-pilot-v1/impl/phase-summary.md` — top-level rollup
- `runs/sdk-resourcepool-py-pilot-v1/impl/branch-info.md` — branch + commits
- `runs/sdk-resourcepool-py-pilot-v1/impl/profile-audit.md` — M3.5 INCOMPLETE detail
- `runs/sdk-resourcepool-py-pilot-v1/impl/guardrail-results.md` — M9 detail
- `runs/sdk-resourcepool-py-pilot-v1/impl/review-fix-log.md` — M8 detail
- `runs/sdk-resourcepool-py-pilot-v1/impl/reviews/*.md` — 6 wave-reviewer reports
- `runs/sdk-resourcepool-py-pilot-v1/impl/guardrail-report.json` — machine-readable

## Open H7 ask

"Provision the Python toolchain and re-run M3.5+M9 OR accept
INCOMPLETE verdicts and proceed to Phase 3 (which will face the same
gap)." See `phase-summary.md` H7 section for full text.
