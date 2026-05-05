<!-- Generated: 2026-04-27 | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 | Author: sdk-impl-lead -->

# Impl-Lead Brief — `motadata_py_sdk.resourcepool` Phase 2

Every sub-agent spawned during Phase 2 (red, green, refactor, docs, marker-scanner, profile-auditor, every devil reviewer, fix agents) MUST read this file before starting work. It is the canonical RULE 0 plus design digest plus per-wave acceptance criteria.

---

## RULE 0 — User Hard Constraint: ZERO TPRD Tech Debt (verbatim)

```
ZERO tech debt on the TPRD. No deferring, skipping, or partial implementation
of any TPRD-declared functionality, test type, performance gate, milestone slice,
or retrospective hook. Every §2 Goal, every §5 API symbol, every §10 Perf Target,
every §11 Test Strategy item (unit + integration + bench + leak + race), every
§13 milestone S1-S6, and every Appendix C retrospective question MUST ship
complete in this run.
```

### Forbidden artifacts in any pipeline-authored file

- `TODO`, `FIXME`, `XXX`, `HACK` comments
- `pass  # placeholder`
- `raise NotImplementedError`
- `@pytest.mark.skip` (without H7/H9 sign-off)
- Empty test bodies
- Bench files that don't actually run a measured loop
- `[traces-to:]` markers pointing at TPRD-§ entries that have no implementation
- Stub `Example_*` / docstring examples without runnable assertions

### Carve-outs (already accepted by user at H5)

1. TPRD §3 Non-Goals (no OTel wiring this pilot, no Python 3.10 backport, no thread-pool variant, no streaming acquire, no sync `Pool` variant, no automatic resource expiry/TTL, no rate limiting, no circuit breaker integration, no dynamic resizing, no load-shedding, no sync-callable hook coercion via `asyncio.to_thread`, no distributed pool, no integration with Go target SDK).
2. `design/perf-exceptions.md` is intentionally empty for v1.0.0; only add entries if impl + bench prove a hand-optimized path is needed AND the entry is design-time pre-declared (CLAUDE.md rule 29 + G110). If profile-auditor proposes an exception, **escalate** to impl-lead, do not silently add.

### Per-wave enforcement

At end of every wave, run:

```bash
cd /home/prem-modha/projects/nextgen/motadata-py-sdk
grep -rnE 'TODO|FIXME|XXX|HACK|NotImplementedError|pass[[:space:]]*#[[:space:]]*placeholder' \
     src/motadata_py_sdk/resourcepool/ tests/ 2>/dev/null
```

Any hits = wave does NOT exit; fix before proceeding.

---

## Environment + branch facts

- **Target SDK**: `/home/prem-modha/projects/nextgen/motadata-py-sdk`
- **Branch**: `sdk-pipeline/sdk-resourcepool-py-pilot-v1`
- **Base SHA**: `b6c8e383b825a241e8e0efb1a09014bedbffa0b2`
- **Python**: 3.12.3 (venv at `.venv/`); TPRD pins `>=3.11`
- **Mode**: A (new package); `src/motadata_py_sdk/resourcepool/__init__.py` is empty
- **Pipeline version**: `0.5.0` (stamp every decision-log entry)
- **Tier**: T1 (full perf-confidence regime)
- **Dev deps installed**: pytest 9.0.3, pytest-asyncio 1.3.0, pytest-benchmark 5.2.3, pytest-cov 7.1.0, mypy 1.20.2, ruff 0.15.12, safety 3.7.0, pip-audit 2.10.0

### Toolchain commands (use these exact invocations)

| Step | Command (run from `motadata-py-sdk/`) |
|---|---|
| build | `.venv/bin/python -m build` |
| test | `.venv/bin/pytest -x --no-header` |
| lint | `.venv/bin/ruff check src/motadata_py_sdk/resourcepool/ tests/` |
| vet | `.venv/bin/mypy --strict src/motadata_py_sdk/resourcepool/` |
| fmt | `.venv/bin/ruff format --check src/motadata_py_sdk/resourcepool/ tests/` |
| coverage | `.venv/bin/pytest --cov=src/motadata_py_sdk/resourcepool --cov-report=term --cov-fail-under=90` |
| bench | `.venv/bin/pytest --benchmark-only --benchmark-json=bench.json tests/bench/` |
| supply chain | `.venv/bin/pip-audit && .venv/bin/safety check --full-report` |
| leak | `.venv/bin/pytest tests/leak/ --asyncio-mode=auto` |

### Constraints on writes

- WRITES allowed only to:
  - `runs/sdk-resourcepool-py-pilot-v1/impl/`, `…/decision-log.jsonl`, `…/state/run-manifest.json`
  - `/home/prem-modha/projects/nextgen/motadata-py-sdk/` on branch `sdk-pipeline/sdk-resourcepool-py-pilot-v1` ONLY (verify branch before every write)
- DO NOT touch pipeline repo source (other agents/skills/guardrails)
- DO NOT push to remote, merge to main, or force-push
- Commit msg format: `<wave>(resourcepool): <one-line summary>` + `Co-Authored-By: Claude <noreply@anthropic.com>`
- Decision-log cap: 15 entries per agent per run

---

## Design summary digest (READ before authoring code)

### TPRD §5 — 9 API symbols (all MUST ship)

| Symbol | File | Kind |
|---|---|---|
| `PoolConfig` | `_config.py` | `@dataclass(frozen=True, slots=True) class PoolConfig(Generic[T])` |
| `Pool` | `_pool.py` | `class Pool(Generic[T])` with `__slots__` (13 fields per design) |
| `AcquiredResource` | `_acquired.py` | `class AcquiredResource(Generic[T])` with `__slots__` |
| `PoolStats` | `_stats.py` | `@dataclass(frozen=True, slots=True)` |
| `PoolError` | `_errors.py` | `class PoolError(Exception)` |
| `PoolClosedError` | `_errors.py` | `class PoolClosedError(PoolError)` |
| `PoolEmptyError` | `_errors.py` | `class PoolEmptyError(PoolError)` |
| `ConfigError` | `_errors.py` | `class ConfigError(PoolError)` |
| `ResourceCreationError` | `_errors.py` | `class ResourceCreationError(PoolError)` |

Public `__init__.py` re-exports exactly the 9 names above; `__all__` lists them in design order.

### Pool methods (all MUST ship)

`__init__`, `acquire` (sync, returns `AcquiredResource`), `acquire_resource` (async), `try_acquire` (sync), `release` (async), `aclose` (async, idempotent), `stats` (sync), `__aenter__` (async, returns self), `__aexit__` (async, calls `aclose()`).

### Algorithm + concurrency invariants

- Idle storage: `collections.deque[T]` LIFO (`pop()` from right; `append()` to right).
- Wait wakeup: `asyncio.Condition(self._lock)` with `wait_for(predicate)` + `notify(n=1)` per release.
- Outstanding tracker: `set[asyncio.Task]` with `add_done_callback(self._outstanding.discard)`.
- Cancellation rollback: `except BaseException` in `_acquire_with_timeout` after lock-drop must decrement `_created` AND `notify(n=1)` then re-raise.
- Timeout: `asyncio.timeout(timeout)` (3.11+) wrapped in `nullcontext()` when `timeout is None`.
- `try_acquire` is sync, never touches the async Lock; relies on single-event-loop GIL serialization.
- `aclose`: notify_all parked waiters → wait for outstanding to drain (or cancel them at timeout) → drain idle deque via `on_destroy` → set `_close_event`. Idempotent.
- Hook detection cached at `__init__` via `inspect.iscoroutinefunction` — three bool flags `_on_create_is_async`, `_on_reset_is_async`, `_on_destroy_is_async`.
- Hook policy: `on_create` raise → `ResourceCreationError(__cause__=user_exc)` + rollback; `on_reset` raise → destroy + drop silently; `on_destroy` raise → log WARN + swallow.

### Devil-review notes carried into impl

- **DD-001** (design-devil): 13 `__slots__` is on the high side but justified; document each slot's role inline; no refactor.
- **DD-002** (design-devil): two acquire methods — `acquire` (sync→ctx mgr) vs `acquire_resource` (async→T) — caller mental-model burden mitigated by mypy strict + docstrings; ensure both have prominent runnable examples.
- **SD-001** (security-devil): hook execution is caller-trusted code; add a "Security Model" section to `Pool`'s docstring noting hooks run in caller-trust boundary.
- All devil verdicts ACCEPT; carry SD-001 + DD-001/DD-002 documentation into impl docs (M6 wave).

### Marker rules (Python `#` syntax)

Every pipeline-authored symbol MUST carry `# [traces-to: TPRD-§<n>-<symbol>]`. Constraint markers per `constraint-bench-plan.md`:

| Symbol | Marker |
|---|---|
| `Pool._acquire_with_timeout` | `# [constraint: complexity O(1) amortized acquire bench/bench_scaling.py::bench_acquire_release_cycle_sweep]` |
| `Pool.release` | `# [constraint: complexity O(1) amortized release bench/bench_scaling.py::bench_acquire_release_cycle_sweep]` |
| `Pool.try_acquire` | `# [constraint: latency p50 ≤5µs bench/bench_acquire.py::bench_try_acquire]` |
| `Pool.acquire` | `# [constraint: alloc ≤4 per acquire bench/bench_acquire.py::bench_acquire_happy_path]` |
| `Pool.acquire@contention` (annotation on `acquire` mentioning the bench) | `# [constraint: throughput ≥500k acq/s bench/bench_acquire_contention.py::bench_contention_32x_max4]` |
| `Pool.aclose` | `# [constraint: wallclock ≤100ms drain 1000 bench/bench_aclose.py::bench_aclose_drain_1000]` |

Every public symbol gets `# [stable-since: v1.0.0]`. No `# [perf-exception:]` markers — `design/perf-exceptions.md` is empty.

---

## Wave plan + acceptance criteria

| Wave | Scope | Files written | Acceptance |
|---|---|---|---|
| **M0** | Branch + brief + tooling sanity | this file + base-sha.txt | branch live; pip-audit + safety green; pyproject `version=1.0.0` already set later in M1 |
| **M1 (S1)** | `_errors.py`, `_stats.py`, `_config.py` + `tests/unit/test_construction.py` | 3 src + 1 test | red→green→refactor→docs; pytest green; mypy strict green; ruff clean; tech-debt scan empty |
| **M2 (S2)** | `_acquired.py`, `_pool.py` core (init, acquire, try_acquire, release, idle path) + `tests/unit/test_acquire_release.py` | 2 src + 1 test | same gates; pool can do happy-path acquire/release |
| **M3 (S3)** | extend `_pool.py` with cancellation + timeout + hook awaiting + `tests/unit/test_cancellation.py` + `tests/unit/test_timeout.py` | 2 tests | same gates; cancel-mid-acquire does NOT leak slot (pool.stats().waiting == 0 post-cancel) |
| **M3.5** | profile audit (after M3 green) | profile artifacts under impl/profile/ | py-spy CPU profile + tracemalloc heap; G104 + G109 PASS; alloc ≤ design budget |
| **M4 (S4)** | `aclose` + idempotency + `tests/unit/test_aclose.py` | 1 test (impl in `_pool.py`) | same gates; second aclose is no-op; outstanding drain on timeout cancels correctly |
| **M5 (S5)** | bench files + scaling sweep | 4 bench files + tracemalloc adapter | each bench produces measured numbers; scaling sweep at N ∈ {10, 100, 1k, 10k}; pytest-benchmark JSON output |
| **M6 (S6)** | hook panic recovery + sync/async hook detection edge cases + `tests/unit/test_hook_panic.py` + integration + leak harness + docs (USAGE.md, DESIGN.md) | 1 unit test + 2 integration tests + 1 leak harness + docs | full pytest green; coverage ≥90%; leak harness clean; runnable docstring examples in every public symbol |
| **M7** | parallel devil review (marker-scanner, marker-hygiene-devil, overengineering-critic, code-reviewer, security-devil, api-ergonomics-devil) | review files | every devil verdict logged; review-fix loop runs until convergence |
| **M8** | review-fix loop | code edits + re-runs | per-issue retry cap 5; deterministic-first gate; convergence |
| **M9** | h7b mid-impl checkpoint summary + h7 final summary | 2 sign-off files | tables for §5 / §11 / §10 / §13; recommendation APPROVE/REVISE/REJECT |

---

## Tech-debt scan (run at end of EVERY wave; log as `event: tech-debt-scan`)

```bash
cd /home/prem-modha/projects/nextgen/motadata-py-sdk
grep -rnE 'TODO|FIXME|XXX|HACK|NotImplementedError|pass[[:space:]]*#[[:space:]]*placeholder' \
     src/motadata_py_sdk/resourcepool/ tests/ 2>/dev/null
```

Empty output = wave may exit. Any hit = blocker; fix and re-scan.

---

## Quality gates that MUST be green at end of every wave

1. `.venv/bin/pytest -x --no-header tests/` — green (or, for waves where new red tests are intentional during the red phase, green by end of green phase).
2. `.venv/bin/mypy --strict src/motadata_py_sdk/resourcepool/` — zero errors.
3. `.venv/bin/ruff check src/motadata_py_sdk/resourcepool/ tests/` — zero findings.
4. `.venv/bin/ruff format --check src/motadata_py_sdk/resourcepool/ tests/` — clean.
5. Tech-debt scan above — empty.
6. Coverage gate at end of M6 (post-test): `≥90%` per `--cov-fail-under=90`.
7. Supply-chain (M7): `pip-audit` + `safety check` clean.
8. Leak harness (end of M6): clean (no leaked tasks).

---

## Cross-references

- TPRD: `runs/sdk-resourcepool-py-pilot-v1/tprd.md`
- Intake summary (RULE 0 verbatim): `runs/sdk-resourcepool-py-pilot-v1/intake/intake-summary.md`
- Run manifest (`user_hard_constraints.zero_tprd_tech_debt`): `runs/sdk-resourcepool-py-pilot-v1/state/run-manifest.json`
- Design: `runs/sdk-resourcepool-py-pilot-v1/design/{api-design,interfaces,algorithm,concurrency-model,patterns,perf-budget,perf-exceptions}.md`
- Devil verdicts: `runs/sdk-resourcepool-py-pilot-v1/design/reviews/*.md`
- Active packages: `runs/sdk-resourcepool-py-pilot-v1/context/active-packages.json`
- Toolchain: `runs/sdk-resourcepool-py-pilot-v1/context/toolchain.md`
- Go reference impl (oracle calibration): `/home/prem-modha/projects/nextgen/motadata-go-sdk/src/motadatagosdk/core/pool/resourcepool/`

---

## Sub-agent contract

When this lead spawns a sub-agent (red/green/refactor/docs/devil), the sub-agent MUST:

1. Re-read this brief.
2. Run lifecycle event `started` on `decision-log.jsonl`.
3. Honor the write constraints above.
4. Produce output ONLY in its designated paths.
5. Run the tech-debt scan before declaring done.
6. Write a `≤200 line` summary to `runs/sdk-resourcepool-py-pilot-v1/impl/context/<agent-name>-summary.md`.
7. Run lifecycle event `completed` (or `failed`).
8. Decision-log entries cap at 15.
