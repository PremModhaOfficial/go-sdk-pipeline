<!-- Generated: 2026-04-29T18:30:00Z | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 | Pack: python -->
<!-- Authored-by: sdk-skill-drift-detector -->

# Skill Drift Report

**language**: python

This run is the first Python adapter pilot. All findings carry a `language: python`
tag so `improvement-planner` can route fixes through the python pack and avoid
cross-language consolidation with Go findings.

## Invoked skills (this run)

Drawn from `runs/sdk-resourcepool-py-pilot-v1/context/active-packages.json` and
TPRD §Skills-Manifest. All ten skills audited below were referenced by Phase 1
or Phase 2 artifacts and have prescriptive content for the generated code.

- `python-sdk-config-pattern` v1.0.0 (scope: python)
- `python-asyncio-patterns` v1.0.0 (scope: python)
- `python-asyncio-leak-prevention` v1.0.0 (scope: python)
- `python-exception-patterns` v1.0.0 (scope: python)
- `python-client-shutdown-lifecycle` v1.0.0 (scope: python)
- `python-mypy-strict-typing` v1.0.0 (scope: python)
- `python-otel-instrumentation` v1.0.0 (scope: python)
- `python-doctest-patterns` v1.0.0 (scope: python)
- `python-pytest-patterns` v1.0.0 (scope: python)
- `python-hypothesis-patterns` v1.0.0 (scope: python)

## Audit summary table

| Skill | Prescription excerpt | Impl evidence | Drift? | Severity |
|---|---|---|---|---|
| python-sdk-config-pattern | `@dataclass(frozen=True, slots=True, kw_only=True)` primary form | `_config.py:21` `@dataclass(frozen=True)` only — `slots=True` and `kw_only=True` both omitted (Generic[T] interaction documented in docstring) | minor | LOW |
| python-asyncio-patterns | Use TaskGroup; Lock + Condition for sync; `asyncio.timeout` ≻ `wait_for` | `_pool.py:110-111` Lock + Condition correct; `_pool.py:276-279` uses `asyncio.wait_for` rather than `asyncio.timeout` ctx-mgr | minor | LOW |
| python-asyncio-leak-prevention | `asyncio_task_tracker` fixture MUST be `autouse=True` | `tests/conftest.py:26` declares the fixture but is NOT autouse — only invoked when tests opt-in by name | major | MEDIUM |
| python-exception-patterns | Subclass `MotadataError` (or pkg base); never bare except; PEP 3134 `from e` chaining; never except `BaseException` | `_errors.py` correct hierarchy under `PoolError`; `_pool.py:247,381,451,536` use `except BaseException` (skill rule 4 explicit anti-pattern); however, in each case `CancelledError` is filtered upstream and a re-raise/cleanup is performed — partial mitigation | major | MEDIUM |
| python-client-shutdown-lifecycle | `async with` canonical; `aclose` (not `close`); idempotent `_closed`; ordered teardown | `_pool.py:129/146/396` ✓ canonical; `_pool.py:103` `_closed` flag; `_pool.py:417-418` fast-path idempotent; `_pool.py:434-440` polling drain via `asyncio.sleep(0.001)` rather than `asyncio.timeout` + `gather` skill pattern | minor | LOW |
| python-mypy-strict-typing | Full annotations; `X \| None`; `Self` for factories; `py.typed`; minimize `cast` | `py.typed` ✓ present; `mypy --strict` PASS per impl/phase-summary; `_pool.py:331,487-489,497-503,526-532` use `cast()` 5 times; per-line rationale not given | minor | LOW |
| python-otel-instrumentation | Module-scope `tracer`/`meter`; `start_as_current_span` for spans; OTLP shutdown | TPRD §10 explicitly defers OTel for v1.0.0 (resourcepool is a non-network primitive). No OTel imports in source — consistent with TPRD scope | none | n/a |
| python-doctest-patterns | Examples block on every public symbol; `pytest --doctest-modules` wiring | All public symbols carry Examples blocks (`_config.py:57-64`, `_pool.py:62-72`, etc.); pyproject.toml `[tool.pytest.ini_options].addopts` does NOT include `--doctest-modules` — examples exist but are never executed by `pytest` invocation | major | MEDIUM |
| python-pytest-patterns | `pytest`, not unittest; parametrize ≻ for-loops; `asyncio_mode = "auto"`; conftest layered | `pyproject.toml:70` ✓ `asyncio_mode = "auto"`; `tests/conftest.py` ✓ shared fixtures; `tests/unit/test_construction.py` uses TestClass + parametrize | none | n/a |
| python-hypothesis-patterns | `@given` strategies; `@settings` deadlines; `st.composite` for domain | `tests/unit/test_properties.py:20-27` `@given` + `@settings(max_examples=10, deadline=2000)` ✓ ; only one property test rather than multiple invariants — minor coverage gap rather than skill drift | none | n/a |

## Drift findings (detail)

### SKD-001: python-asyncio-leak-prevention — autouse fixture not applied

**Language**: python
**Skill scope**: python
**Skill prescribes**: `python-asyncio-leak-prevention` SKILL.md §"Test gates" Rule 1
states that `asyncio_task_tracker` is a `@pytest.fixture(autouse=True)` that
fails any test where the running-task count grew. The whole point is that
EVERY async test inherits the leak guard for free. The skill body explicitly
shows `@pytest.fixture(autouse=True)` and discusses an opt-out marker
`@pytest.mark.no_task_tracker`.

**Code has**: `tests/conftest.py:26` declares
```python
@pytest.fixture()
def asyncio_task_tracker() -> Iterator[None]:
```
NOT autouse. Tests must opt IN by listing the fixture as a parameter (e.g.
`tests/leak/test_no_leaked_tasks.py:18`). Only the 3 leak-suite tests use it;
the other 59 unit + property tests in the suite have no leak guard.

**Severity**: MEDIUM. The leak suite passed with `leaks: 0` (decision-log
ts 17:11:30). However, the 59 non-leak tests run unguarded, so a leak
introduced inside the unit suite would not be caught at CI time. This is
exactly the failure mode the skill warned against ("Most leaks ship because
the test suite never exercises shutdown.").

**Recommendation**: Add `autouse=True` to the fixture decorator. Add the opt-out
`@pytest.mark.no_task_tracker` marker plumbing per the skill body. Verify all
62 tests still pass.

### SKD-002: python-exception-patterns — `except BaseException` violates Rule 4

**Language**: python
**Skill scope**: python
**Skill prescribes**: `python-exception-patterns` SKILL.md §"Rule 4 — `except`
is not a catch-all" explicitly lists `except BaseException:` as an anti-pattern
because it catches `KeyboardInterrupt`, `SystemExit`, and
`asyncio.CancelledError`. The BAD anti-patterns block #5 makes the rule
literal: "WRONG: `except BaseException`".

**Code has**: `_pool.py` uses `except BaseException as e:` four times:
- L247 (in `acquire_resource`, on_create wrapping)
- L381 (in `release`, on_reset failure)
- L451 (in `aclose`, on_destroy failure)
- L536 (in `_maybe_destroy`)

In every case the impl FIRST handles `asyncio.CancelledError` in a preceding
`except` arm and re-raises, so the `BaseException` arm cannot in practice
catch cancellation. This is a deliberate design choice (see comments at
L244-246, L376-380 — "NEVER wrap CancelledError"). Correctness is preserved.

**Severity**: MEDIUM. Skill literal says do not write `except BaseException`.
The impl satisfies the SPIRIT (CancelledError propagates) but violates the
LETTER (the keyword combination is on disk). A future edit that drops the
preceding `except CancelledError` would silently start swallowing cancels.

**Recommendation**: Refactor to `except Exception as e:` since the
preceding `CancelledError` arm makes BaseException unnecessary. Same
defensive intent (catch any user-hook failure), no rule violation.
Alternative: keep BaseException with an in-line `# noqa` and a comment
citing the skill's Rule-4 carve-out — explicit acknowledgment of the
deviation.

### SKD-003: python-doctest-patterns — Examples blocks present but never executed

**Language**: python
**Skill scope**: python
**Skill prescribes**: `python-doctest-patterns` SKILL.md §"Rationale" makes the
test-side of the Examples contract explicit: "the example IS a test, run via
`pytest --doctest-modules`". The whole rationale of the skill is that
docstring examples cannot lie because CI runs them.

**Code has**: Public symbols carry Examples blocks per the skill (`_config.py:57`
PoolConfig, `_pool.py:62` Pool, README.md / USAGE.md. However,
`pyproject.toml:72-75` `[tool.pytest.ini_options].addopts` is:
```toml
addopts = ["--strict-markers", "--strict-config"]
```
with no `--doctest-modules`. The 62 tests counted in phase-summary do NOT
include doctest discovery. The Pool docstring example
(`asyncio.run(main())` returning `42`) is therefore never validated by the
build.

**Severity**: MEDIUM. Examples currently look correct on inspection, but the
skill's whole guarantee — "the example cannot lie" — is forfeited. A future
refactor could drift example outputs without breaking CI.

**Recommendation**: Add `--doctest-modules` to `pyproject.toml` addopts, or
add a dedicated `tests/test_doctests.py` that programmatically runs
`doctest.testmod` on each public module. Verify all current examples run
clean (some may need `# doctest: +SKIP` for `asyncio.run(...)` or
`# doctest: +ELLIPSIS` per skill Rules 2 + 3).

### SKD-004: python-sdk-config-pattern — slots/kw_only omitted from PoolConfig

**Language**: python
**Skill scope**: python
**Skill prescribes**: `python-sdk-config-pattern` SKILL.md §"Primary: frozen
@dataclass" gives the canonical form as
`@dataclass(frozen=True, slots=True, kw_only=True)`. The §"Compatibility
table" shows all three flags ship on Python 3.10+.

**Code has**: `_config.py:21` is `@dataclass(frozen=True)` — `slots=True`
and `kw_only=True` both omitted. The docstring (lines 26-32) explains the
`slots=True` omission as a CPython 3.11-3.13 interaction with `Generic[T]`
that raises `TypeError`. The `kw_only=True` omission is NOT explained in
the docstring.

**Severity**: LOW. The `slots` omission has a concrete
documented technical reason (CPython generic-dataclass slot bug); deviation
from the skill is justified and surfaced in the docstring. The `kw_only`
omission is undocumented but practically harmless: every callsite in the
code + tests + USAGE.md uses keyword arguments
(`PoolConfig[int](max_size=4, on_create=factory)`). A caller could legally
write `PoolConfig[int](4, factory)` today, which the skill says should not
be possible.

**Recommendation**: Either (a) add `kw_only=True` (compatible — none of
the current call sites would change), OR (b) add a one-line note next to
the `slots=True` rationale explaining the `kw_only` choice. Option (a)
preferred — closes the drift with no behavior change.

### SKD-005: python-asyncio-patterns — `asyncio.wait_for` instead of `asyncio.timeout` ctx-mgr

**Language**: python
**Skill scope**: python
**Skill prescribes**: `python-asyncio-patterns` SKILL.md §"Rule 5 —
`asyncio.timeout` over `asyncio.wait_for`" prescribes the context-manager form
for Python 3.11+. Decision tree at the bottom of the skill: "Single-shot
deadline: `async with asyncio.timeout(s):`".

**Code has**: `_pool.py:276-279` uses
```python
await asyncio.wait_for(
    self._slot_available.wait(),
    remaining,
)
```
inside `acquire_resource`. The skill's "still acceptable but older API"
language is permissive but the convention pushes toward the ctx-mgr form.

**Severity**: LOW. The skill itself classes `wait_for` as "still acceptable".
The two forms have a subtle behavioral difference: `asyncio.timeout(remaining)`
is composable with outer timeouts in a stack-respecting way, whereas
`wait_for` raises a fresh `TimeoutError` regardless of which deadline was
hit. For `acquire_resource` the difference is unlikely to matter.

**Recommendation**: Track for follow-up; not urgent. If future work adds
nested timeouts (e.g., a higher-level "publish with timeout" wrapper that
calls into `acquire_resource`), refactor to the ctx-mgr form to preserve
deadline composition.

### SKD-006: python-client-shutdown-lifecycle — drain implementation diverges from skill template

**Language**: python
**Skill scope**: python
**Skill prescribes**: `python-client-shutdown-lifecycle` SKILL.md §"Rule 5 —
Drain with bounded timeout" gives the canonical drain as
`asyncio.timeout(timeout_s)` + `asyncio.gather(*self._inflight,
return_exceptions=True)`. The pattern operates on a tracked set of
in-flight tasks.

**Code has**: `_pool.py:434-440` uses a polling loop:
```python
while True:
    async with self._slot_available:
        if self._in_use == 0: break
    if deadline is not None and monotonic() >= deadline: break
    await asyncio.sleep(0.001)
```
This is structurally different from the skill template. The pool tracks
an `_in_use` counter rather than a `set[Task]`, so the gather-pattern would
have nothing to gather. The polling form is functionally correct but adds
ms-granularity latency and pre-empts the loop on a 1ms timer.

**Severity**: LOW. The pool's primitive is "wait for caller-driven release",
not "cancel my own in-flight tasks", so the skill's exact gather template
doesn't apply. The substantive contract (idempotency, bounded timeout,
ordered teardown) is honored.

**Recommendation**: Replace the busy-poll with an `asyncio.Condition.wait()`
on a dedicated drain-condition that `release()` notifies. Eliminates the
1ms wakeup and matches the spirit of the skill (event-driven, not timer-driven).
Already filed as PA-002 in Phase 4 backlog (aclose bench INCOMPLETE-by-harness).

### SKD-007: python-mypy-strict-typing — `cast()` overuse vs `assert isinstance`

**Language**: python
**Skill scope**: python
**Skill prescribes**: `python-mypy-strict-typing` SKILL.md §"Rule 8 —
`assert isinstance` over `cast`": "`cast` is the last resort. Most legitimate
uses of `cast` are when interfacing with `**kwargs` or third-party untyped
libraries."

**Code has**: `_pool.py` uses `cast()` 5 times:
- L331 `cast("Callable[[], T]", self._config.on_create)` — narrowing inside `try_acquire`
- L487-489, L497-503, L526-532 — narrowing sync/async hook callable
  unions (`Callable[[], T] | Callable[[], Awaitable[T]]`)

**Severity**: LOW. The hook fields in `PoolConfig` are typed as
`Callable[[], T] | Callable[[], Awaitable[T]]`, and the runtime branch is
keyed off a cached `inspect.iscoroutinefunction` boolean
(`self._async_on_create` etc.). Mypy cannot narrow a callable union from a
boolean attribute, so `cast` is mechanically necessary. This is a legitimate
"third-party-untyped-library-shape" case the skill carves out. However,
each `cast` adds zero-cost type-system noise the user has to read.

**Recommendation**: Acceptable as-is. If a future refactor moves the
sync/async dispatch to a strategy object (`SyncHookDispatcher` /
`AsyncHookDispatcher` chosen at `__init__`), the casts vanish. Filed as
non-urgent improvement; do not block on it.

### SKD-008: python-otel-instrumentation — no OTel wiring (consistent with TPRD)

**Language**: python
**Skill scope**: python
**Skill prescribes**: `python-otel-instrumentation` SKILL.md §"Rule 1 —
`tracer` and `meter` are MODULE-SCOPED" and downstream rules apply WHENEVER
the SDK client emits spans. Activation signal: "TPRD §6 declares
OTel-required."

**Code has**: No OTel imports in any source file. TPRD §10 explicitly
defers OTel ("v1.0.0 ships without OTel; the resourcepool primitive is a
non-network in-memory data structure and emits no spans"). The skill's
activation signals are NOT met for this run.

**Severity**: NONE. This is correctly NOT a drift — the skill's activation
predicate ("TPRD declares OTel-required") was false. Recording this row so
future audits don't re-flag it.

**Recommendation**: When a future event-bus / publisher client is added
under `motadata_py_sdk.events` (per TPRD §17 roadmap), the skill activates
and the audit must verify module-scope `tracer = trace.get_tracer(__name__)`.

### SKD-009 / SKD-010: python-pytest-patterns + python-hypothesis-patterns — no drift

Tests live under `tests/`; pyproject.toml has `asyncio_mode = "auto"`;
fixtures use `yield` for cleanup; `tests/conftest.py` is at the right level;
parametrize is used over for-loops; hypothesis test uses `@given` +
`@settings(deadline=2000)`. Both skills' patterns are satisfied.

The hypothesis test could exercise more invariants (currently 1 property),
but that's a coverage observation, not a skill drift.

## Roll-up

| Verdict | Count | Severity bucket |
|---|---|---|
| No drift | 3 | n/a (otel, pytest, hypothesis) |
| Minor drift | 4 | LOW (config-slots, wait_for, drain-poll, cast) |
| Major drift | 3 | MEDIUM (autouse, BaseException, doctest-modules) |

All findings carry `language: python`. None are scope `shared-core` —
shared skills (`idempotent-retry-safety`, `network-error-classification`)
were not invoked by this run because resourcepool is an in-memory primitive
with no retry / network surface.

## Pointers

- Decision log: `runs/sdk-resourcepool-py-pilot-v1/decision-log.jsonl`
- Active packages: `runs/sdk-resourcepool-py-pilot-v1/context/active-packages.json`
- Generated source: `motadata-sdk:sdk-pipeline/sdk-resourcepool-py-pilot-v1` HEAD `11c772c` under `src/motadata_py_sdk/resourcepool/`
- Skills audited: 10 (all prescriptive Python pack skills cited in §Skills-Manifest)
