<!-- Generated: 2026-04-27T00:00:15Z | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 -->

# Intake Summary — `sdk-resourcepool-py-pilot-v1`

## Verdict
- **G05 / G06 / G20 / G21 / G22 / G23 / G24 / G93 / G116**: PASS
- **G90**: **BLOCKER** (real, surfaced to user — see H1 section below)
- **HITL H1**: NOT auto-passed; user resolution required on G90 before Phase 1 Design may start.

## Mode + targeting
- **Mode**: A (new package)
- **Target language**: `python`
- **Target tier**: `T1` (full perf-confidence regime per pipeline rule 32)
- **Required packages**: `["shared-core@>=1.0.0", "python@>=1.0.0"]` resolved cleanly
- **Target SDK dir**: `/home/prem-modha/projects/nextgen/motadata-py-sdk` (git repo, branch `main`, scaffold commit `b6c8e38`, layout = `src/motadata_py_sdk/`, `tests/`, `pyproject.toml`, `docs/`)
- **Target package** (to be created): `motadata-py-sdk/src/motadata_py_sdk/resourcepool/` (currently empty `__init__.py` only)
- **Pipeline branch planned**: `sdk-pipeline/sdk-resourcepool-py-pilot-v1`

---

## RULE 0 — User Hard Constraint: ZERO TPRD Tech Debt

The following block is copied **verbatim** from `state/run-manifest.json` `user_hard_constraints.zero_tprd_tech_debt`. It is **rule 0** for this run, ranked above CLAUDE.md rule 14 and every other quality gate. Every downstream lead inherits this constraint via this context dir.

```json
{
  "stated_at": "2026-04-27 (run start, before intake spawn)",
  "rule": "ZERO tech debt on the TPRD. No deferring, skipping, or partial implementation of any TPRD-declared functionality, test type, performance gate, milestone slice, or retrospective hook. Every §2 Goal, every §5 API symbol, every §10 Perf Target, every §11 Test Strategy item (unit + integration + bench + leak + race), every §13 milestone S1-S6, and every Appendix C retrospective question MUST ship complete in this run.",
  "explicit_carve_outs": [
    "§3 Non-Goals are written contracts (e.g. 'no OTel wiring this pilot', 'no Python 3.10 backport', 'no thread pool', 'no streaming acquire'). These remain out of scope as the TPRD already accepted that scope decision — they are NOT tech debt.",
    "Skills/guardrails the TPRD §Skills-Manifest / §Guardrails-Manifest declare as missing/WARN are filed to docs/PROPOSED-SKILLS.md / docs/PROPOSED-GUARDRAILS.md per pipeline rule 23 — that is not skipping; it is the documented promotion path."
  ],
  "forbidden_artifacts": [
    "TODO / FIXME / XXX / HACK comments in pipeline-authored code",
    "pass # placeholder",
    "raise NotImplementedError",
    "@pytest.mark.skip without an issue link AND user H7/H9 sign-off",
    "Empty test bodies",
    "Bench files that don't actually run a measured loop",
    "[traces-to:] markers pointing at TPRD-§ entries that have no implementation",
    "Stub Example_* docstrings without runnable assertions",
    "Retrospective answers like 'TBD' / 'see follow-up' on Appendix C questions"
  ],
  "enforcement": [
    "sdk-intake-agent records this constraint in intake/intake-summary.md so every downstream lead inherits it via the context dir.",
    "sdk-impl-lead must run an explicit 'tech-debt scan' (grep -nE 'TODO|FIXME|XXX|HACK|NotImplementedError|pass\\s*#\\s*placeholder' on all pipeline-authored files) at end of every wave.",
    "sdk-testing-lead must verify every §11 test category produced ≥1 real test, every §10 bench is runnable + measured, and §11.5 --count=10 flake detection actually ran.",
    "Phase 4 retrospective MUST answer all 5 Appendix C questions with concrete data drawn from this run's artifacts; no 'will-revisit-next-run' answers.",
    "guardrail-validator G14 (Implementation Completeness, CLAUDE.md rule 14) is BLOCKER for this run — no waivers."
  ]
}
```

---

## §Skills-Manifest validation (G23 = WARN, non-blocking)

20 skills declared in TPRD §Skills-Manifest; 20 present at ≥ declared min version.

| Skill | Declared | Found | Source pack |
|---|---|---|---|
| `python-asyncio-patterns` | 1.0.0 | 1.0.0 | python (v0.5.0 Phase A) |
| `python-class-design` | 1.0.0 | 1.0.0 | python |
| `pytest-table-tests` | 1.0.0 | 1.0.0 | python |
| `asyncio-cancellation-patterns` | 1.0.0 | 1.0.0 | python |
| `tdd-patterns` | 1.0.0 | 1.0.0 | shared-core |
| `idempotent-retry-safety` | 1.0.0 | 1.0.0 | shared-core (debt-bearer) |
| `network-error-classification` | 1.0.0 | 1.0.0 | shared-core (debt-bearer) |
| `spec-driven-development` | 1.0.0 | 1.0.0 | shared-core |
| `decision-logging` | 1.0.0 | 1.1.0 | shared-core |
| `guardrail-validation` | 1.0.0 | 1.2.0 | shared-core |
| `review-fix-protocol` | 1.0.0 | 1.1.0 | shared-core |
| `lifecycle-events` | 1.0.0 | 1.0.0 | shared-core |
| `feedback-analysis` | 1.0.0 | 1.0.0 (per index) | shared-core — see note below |
| `sdk-marker-protocol` | 1.0.0 | 1.0.0 | shared-core |
| `sdk-semver-governance` | 1.0.0 | 1.0.0 | shared-core |
| `api-ergonomics-audit` | 1.0.0 | 1.0.0 | shared-core |
| `conflict-resolution` | 1.0.0 | 1.0.0 | shared-core |
| `environment-prerequisites-check` | 1.0.0 | 1.1.0 | shared-core |
| `mcp-knowledge-graph` | 1.0.0 | 1.0.0 | shared-core |
| `context-summary-writing` | 1.0.0 | 1.0.0 | shared-core |

**Zero entries filed to `docs/PROPOSED-SKILLS.md`** — the four python-* skills shipped in v0.5.0 Phase B-prep commit `474eead` as expected.

**Note on `feedback-analysis`**: the SKILL.md frontmatter does not carry a `version:` field, but `skill-index.json` records it as `1.0.0` (under `ported_verbatim`). G23 reads the index, so the gate passes. This is a minor authorship gap in the SKILL.md itself — out of intake scope; flagged for a future minor PR (not pipeline-blocking).

---

## §Guardrails-Manifest validation (G24 = BLOCKER) — PASS

22 guardrails declared; 22 present + executable. Verified scripts: G01, G02, G03, G04, G05, G06, G07, G20, G21, G22, G23, G24, G69, G80, G81, G83, G84, G85, G86, G90, G93, G116.

The TPRD's `> Notes` block under §Guardrails-Manifest mentions `G30–G65, G95–G110` to explicitly document them as out-of-scope. G24's range expander naively interpreted those en-dash ranges as additional in-scope declarations, causing a false-positive failure. **Fixed in the run-staged copy of the TPRD only** (`runs/sdk-resourcepool-py-pilot-v1/tprd.md`, lines 477-478) by re-phrasing the range references as English text. Source TPRD (`runs/sdk-resourcepool-py-pilot-tprd.md`) is untouched. Semantics fully preserved.

---

## Active packages resolution (G05 = PASS)

`runs/sdk-resourcepool-py-pilot-v1/context/active-packages.json` — 22 agents, 20 skills, 22 guardrails union over `shared-core@1.0.0` + `python@1.0.0`. Round-trips through G05 cleanly.

`runs/sdk-resourcepool-py-pilot-v1/context/toolchain.md` digests:
- build = `python -m build`
- test = `pytest -x --no-header`
- lint = `ruff check .`
- vet = `mypy --strict .`
- fmt = `ruff format --check .`
- coverage = `pytest --cov=src --cov-report=json --cov-report=term` (min 90 %)
- bench = `pytest --benchmark-only --benchmark-json=bench.json`
- supply chain = `pip-audit` + `safety check --full-report`
- leak check = `pytest tests/leak --asyncio-mode=auto`
- file ext = `.py`; marker line = `#`; module file = `pyproject.toml`

---

## §5 API symbols that MUST exist post-impl (for sdk-design-lead)

Every symbol below MUST have: (a) impl, (b) ≥1 unit test, (c) docstring with first word = symbol name, (d) `# [traces-to: TPRD-§<n>-<symbol>]` marker, (e) `Example_*` style runnable docstring example where applicable.

- `PoolConfig` (frozen + slotted dataclass, generic, fields: `max_size`, `on_create`, `on_reset`, `on_destroy`, `name`)
- `Pool` (generic class; methods `__init__`, `acquire`, `acquire_resource`, `try_acquire`, `release`, `aclose`, `stats`, `__aenter__`, `__aexit__`)
- `PoolStats` (frozen + slotted dataclass: `created`, `in_use`, `idle`, `waiting`, `closed`)
- `AcquiredResource` (async context manager class)
- `PoolError` (base exception)
- `PoolClosedError`
- `PoolEmptyError`
- `ConfigError`
- `ResourceCreationError` (referenced in §7 prose; must exist)

---

## §10 Perf targets that MUST be benched (for sdk-perf-architect at D1)

| Symbol | Metric | Budget | Bench file |
|---|---|---|---|
| `Pool.acquire` happy path | latency p50 | ≤ 50 µs | `bench_acquire.py` |
| `Pool.acquire` happy path | allocs/op | ≤ 4 user-level objects | `bench_acquire.py` |
| `Pool.try_acquire` | latency p50 | ≤ 5 µs | `bench_acquire.py` |
| `Pool.acquire` contention (32 acq, max=4) | throughput | ≥ 500k acq/s (10× Go oracle) | `bench_acquire_contention.py` |
| `Pool.aclose` | wallclock to drain 1000 outstanding | ≤ 100 ms | `bench_aclose.py` |
| `acquire/release` cycle scaling sweep | complexity | O(1) amortized | `bench_scaling.py` (G107) |

Hot paths (G109): `_acquire_idle_slot`, `_release_slot`, `_create_resource_via_hook`. Profiler: py-spy (T2-7 adapter must emit normalized JSON).

---

## §11 Test categories that MUST have ≥1 real test (for sdk-testing-lead)

- **§11.1 Unit** — construction · happy path · contention · cancellation (slot-leak guard) · timeout · shutdown · hook panics · idempotent close. Coverage ≥ 90 % line + branch.
- **§11.2 Integration** — chaos: 100 acquirers, max=10, 50 % `on_create` failure rate; assert no slot leaks, no hung tasks, all acquirers see success or `ResourceCreationError`.
- **§11.3 Bench** — every §10 row has a runnable bench under `tests/bench/`; JSON output parsed by `sdk-benchmark-devil` against `baselines/python/performance-baselines.json` (first-run = seed).
- **§11.4 Leak** — `assert_no_leaked_tasks` fixture snapshotting `asyncio.all_tasks()` before/after each test (T2-7 adapter shape).
- **§11.5 Race** — `pytest-asyncio` strict mode + `--count=10` flake detection MUST run.

---

## §13 Milestones (for sdk-impl-lead's wave plan)

| Slice | Scope |
|---|---|
| **S1** | `_config.py` + `_errors.py` + `_stats.py` + tests |
| **S2** | `_pool.py` core: `__init__`, `acquire`, `release`, `try_acquire` (idle-slot fast-path) |
| **S3** | Cancellation correctness + timeout + hook awaiting |
| **S4** | `aclose` graceful shutdown + idempotency |
| **S5** | All bench files + scaling-sweep bench |
| **S6** | Hook panic recovery + edge cases (sync hook + async hook detection) |

All six slices are pilot-scope. Skipping any = tech-debt-rule violation.

---

## Appendix C retrospective questions (for Phase 4 retrospector)

All 5 MUST be answered with concrete data drawn from this run's artifacts; no "TBD" / "see follow-up" allowed (rule 0).

1. **D2 verdict**: did `sdk-design-devil`'s `quality_score` differ ≥3pp from the Go-pool baseline? (`baselines/shared/quality-baselines.json` Go entry.)
2. **D6 verdict**: which shared-core agents produced useful Python reviews vs. confusing/wrong ones? Author `python/conventions.yaml` for the latter.
3. **T2-3 verdict**: what did the soak harness call the outstanding-task counter? (`concurrency_units` vs. `outstanding_tasks` vs. `pending_acquires`)
4. **T2-7 verdict**: shape of leak-check + bench-output adapter scripts — are they policy-free (just normalized JSON)?
5. **Generalization-debt update**: which `shared-core.json` `generalization_debt` entries should be removed (Split landed) vs. kept vs. added?

---

## H1 status — BLOCKED

See `intake/h1-summary.md` for the resolution path. Pipeline must NOT proceed to Phase 1 Design until G90 is resolved.
