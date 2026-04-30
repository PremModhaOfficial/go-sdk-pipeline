<!-- Generated: 2026-04-29T13:43:00Z | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 | Phase: design -->

# Phase 1 — Design Phase Summary

Run: `sdk-resourcepool-py-pilot-v1` · Mode A · Tier T1 · Pipeline 0.5.0
Target: greenfield Python adapter — `motadata_py_sdk/resourcepool/`

## Per-wave verdicts

| Wave | Agents (active union) | Verdict | Notes |
|---|---|---|---|
| **D1 design authors** | sdk-perf-architect-python (only D1 contributor); lead synthesizes algorithm/concurrency/error/layout artifacts inline (no algorithm/concurrency/interface-designer agents in any active pack) | **PASS** | 8/8 §7 symbols budgeted in `perf-budget.md`; oracle margin 10× per TPRD §10. |
| **D2 mechanical** | guardrail-validator | **CONDITIONAL-PASS** | 4 PASS / 2 INCOMPLETE-deferred (G200-py + G32-py — Mode A greenfield: target lacks pyproject.toml; gates fire correctly at impl-exit). |
| **D3 devils** | sdk-design-devil, sdk-convention-devil-python, sdk-dep-vet-devil-python, sdk-semver-devil, sdk-security-devil, sdk-packaging-devil-python (Mode A union) | **6/6 ACCEPT** | 4 LOW findings, all deferred to impl. |
| **D4 review-fix** | (loop control, no agents) | **CONVERGED 1 iter** | No artifact modifications needed. |
| **D5 guardrails** | (D2 result re-surfaced) | See D2 |

## Public API surface (8 §7 symbols + 1 lifted from §7 inline-note)

| Symbol | Kind | Hot-path | Lines from `api.py.stub` |
|---|---|---|---|
| `Pool[T]` | class | yes | bounded async pool, generic over caller type T |
| `PoolConfig[T]` | frozen+slotted dataclass | no (one-shot) | immutable config; on_create/on_reset/on_destroy hooks |
| `PoolStats` | frozen+slotted dataclass | no | snapshot of created/in_use/idle/waiting/closed |
| `AcquiredResource[T]` | async ctx mgr | yes | yielded by Pool.acquire() async-with |
| `PoolError` | exception | — | base for all package errors |
| `PoolClosedError` | exception | — | post-aclose acquire/release |
| `PoolEmptyError` | exception | — | non-blocking try_acquire failure |
| `ConfigError` | exception | — | invalid config or sync/async mismatch |
| `ResourceCreationError` | exception | — | wraps user on_create exception (PEP 3134 chained) |

## perf-budget.md highlights (linchpin per CLAUDE.md rule 32)

| Symbol | hot? | latency p50 | heap_bytes/call | Big-O time | Oracle (Go) p50 → margin |
|---|---|---|---|---|---|
| Pool.acquire | **yes** | 50 µs | 1024 B | O(1) amortized | Go 5 µs × 10 = 50 µs ✓ |
| Pool.acquire_resource | yes | 40 µs | 512 B | O(1) | Go 4 µs × 10 |
| Pool.try_acquire | yes | 5 µs | 0 B | O(1) | Go 1 µs × 5 (sync, no await) |
| Pool.release | yes | 30 µs | 256 B | O(1) | Go 3 µs × 10 |
| Pool.aclose | no | 100 ms (drain 1k) | 65 KB | O(n) | Go 12 ms × ~8 |
| Pool.stats | no | 2 µs | 96 B | O(1) | Go 0.3 µs × ~7 |
| PoolConfig.__init__ | no | 3 µs | 320 B | O(1) | Go 0.1 µs × 30 |
| AcquiredResource.__aenter__ | yes | 8 µs | 0 B | O(1) | n/a |
| **Contention** (32 acq, max=4) | — | — | — | — | **≥450k op/s** target; Python ceiling ~500k |

Drift signals declared (6): `asyncio_pending_tasks`, `rss_bytes`,
`tracemalloc_top_size_bytes`, `gc_count_gen2`, `open_fds`, `thread_count`.
TPRD §15 Q7 resolved → use `asyncio_pending_tasks` (language-explicit; not
`outstanding_tasks` — collides with pool's own concept; not
`concurrency_units` — D2/T2-3 decision still open).

## Dep-vet aggregate

| Bucket | Count | Result |
|---|---|---|
| Runtime deps | 0 | ACCEPT (vacuous) — TPRD §4 contractual zero |
| Dev deps | 11 | 11 ACCEPT, 0 CONDITIONAL, 0 REJECT |
| License allowlist hits | 11/11 | MIT, Apache-2.0, BSD-2/3, MPL-2.0 |
| pip-audit | clean (per offline DB at 2026-04-29) | — |
| safety | clean | — |

**H6 verdict: AUTO-PASS** — no human ask required.

## Findings recap (4 total, all LOW)

| ID | Reviewer | Severity | Status |
|---|---|---|---|
| DD-005 | sdk-design-devil | low | DEFERRED-TO-IMPL — docstring note on acquire |
| CV-001 | sdk-convention-devil-python | low | DEFERRED-TO-IMPL — collections.abc.Callable import |
| PK-001 | sdk-packaging-devil-python | low | DEFERRED-TO-IMPL — PEP 639 SPDX license |
| PK-002 | sdk-packaging-devil-python | low | DEFERRED-TO-IMPL — `[tool.uv]` if uv chosen |

No finding required >1 fix iteration. Retry-cap-5 not approached.

## Guardrail D2 results (filtered active-packages ∩ design-phase)

| Bucket | Count |
|---|---|
| RAN — PASS | 4 (G01, G07, G31-py, G34-py) |
| RAN — FAIL → reclassified INCOMPLETE-deferred | 2 (G200-py, G32-py — pre-mature for Mode A greenfield) |
| SKIP (not in active packages) | 24 (Go-pack guardrails) |
| SKIP (phase mismatch) | 24 |
| **Total registered** | **54** |

The 2 INCOMPLETE-deferred gates re-fire at impl-exit (M9) where the target
will have a populated `pyproject.toml`. Filed as Phase 4 improvement-planner
candidate: tighten `G200-py` / `G32-py` phase headers to remove `design` so
Mode A runs do not produce a false-blocker on every future Python pilot.

## H4 (review-fix convergence) verdict

**AUTO-PASS** — converged in 1 iteration, 0 BLOCKER/HIGH/MEDIUM, no
artifact modifications, no fleet re-run required.

## Cross-language pilot (D2 / D6 / T2-3 / T2-7 hooks)

- **D2 (Lenient holds)**: `sdk-design-devil` quality_score 87 vs Go pool
  baseline ~85 → within ±3pp. No flip to per-language partition needed.
- **D6 (Split working)**: shared-core devils (design-devil, semver, security)
  applied universal rules + python overlay cleanly; no Go-flavored noise.
  Python siblings (convention/dep-vet/packaging) carry pack-native bodies and
  produce sharper findings on Python-specific concerns (PEP 639, src-layout,
  py.typed). **Empirical confirmation D6=Split is delivering.**
- **T2-3 drift signal naming**: `asyncio_pending_tasks` chosen by this design;
  feed into Phase 4 retrospective.
- **T2-7 adapter shape**: leak-check + py-spy adapter scripts deferred to impl
  (M3.5 + M9). No design-phase blocker.

## Lead waivers issued (require user awareness, not user approval)

1. G200-py/G32-py INCOMPLETE-deferred to impl-exit (Mode A greenfield).
   Rationale + improvement-planner candidacy in `guardrail-results.md`.

## H5 ask (presented to user by orchestrator)

The user is asked to approve the design package and authorize transition
to Phase 2 (Implementation). Approval scope:
- The 9 public symbols in `api.py.stub` (1 lifted from TPRD §7 inline-note).
- The perf-budget targets (8 symbols + contention scenario + scaling sweep).
- The algorithm + concurrency model (lock-around-on_create accepted).
- The error taxonomy (5 exception classes).
- The package-layout (src/ layout, hatchling backend, py.typed).
- The 0-runtime-deps + 11-dev-deps decision.
- The two INCOMPLETE-deferred guardrails (G200-py/G32-py at impl-exit).

## Pointers

- `runs/.../design/phase-summary.md` — this file
- `runs/.../design/api.py.stub` — public surface
- `runs/.../design/perf-budget.md` — 8-symbol perf contract
- `runs/.../design/dependencies.md` — 0 runtime + 11 dev deps
- `runs/.../design/algorithm-design.md` — state machine + invariants
- `runs/.../design/concurrency-model.md` — asyncio.Lock/Condition usage
- `runs/.../design/error-taxonomy.md` — 5-class exception hierarchy
- `runs/.../design/package-layout.md` — src/ layout + pyproject.toml
- `runs/.../design/guardrail-results.md` — D5 guardrail verdicts
- `runs/.../design/review-fix-log.md` — D4 loop trace
- `runs/.../design/reviews/*.md` + `*.findings.json` — 6 devil reports
- `runs/.../design/guardrail-report.json` — machine-readable D5 results
