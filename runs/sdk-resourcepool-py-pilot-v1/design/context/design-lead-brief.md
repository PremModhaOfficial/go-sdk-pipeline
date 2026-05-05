<!-- Generated: 2026-04-27T00:00:30Z | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 -->

# Design-Lead Brief — Phase 1 Wave D1 + D2 Sub-Agent Inheritance Doc

**Read this BEFORE doing any design work.** Every sub-agent (designer, interface, algorithm, concurrency, pattern-advisor, perf-architect, every devil) inherits this brief.

---

## Rule 0 — Zero TPRD Tech Debt (USER HARD CONSTRAINT, RANKED ABOVE EVERYTHING)

The user declared at run start (before intake spawn): **ZERO tech debt on the TPRD.** No deferring, no skipping, no partial implementation, no missing tests, no missing benches, no missing retrospective answers.

**What this means for design**:
- Every TPRD §5 API symbol MUST be fully designed (signature, docstring, type hints, behavior contract, error model). No "stub" / "placeholder" / "see follow-up".
- Every TPRD §10 perf target MUST appear in `perf-budget.md` with concrete numbers (latency, allocs, throughput, oracle, floor, complexity, MMD). No "TBD" cells.
- Every TPRD §11 test category MUST be representable by the design (i.e. the API + algorithm + concurrency design must be testable along all five axes — unit, integration, bench, leak, race).
- Every TPRD §13 milestone S1–S6 MUST be addressable by the design (no "design covers S1–S4, S5–S6 deferred").
- Every TPRD Appendix C question MUST be answerable from artifacts produced this phase (D2 verdict, D6 verdict, T2-3 rename, T2-7 adapter shape, generalization-debt update).

**Forbidden in any design artifact** (`design/*.md`):
- `TODO` / `FIXME` / `XXX` / `HACK` markers anywhere
- "TBD" / "see follow-up" / "deferred to next run" / "will revisit" cells in any table
- Empty sections under headings the TPRD requires
- `pass # placeholder` examples
- `raise NotImplementedError` examples
- Skipped retrospective questions
- Bench declarations without a named bench file

**Legitimate carve-outs** (already approved by user, NOT tech debt):
- TPRD §3 Non-Goals (no OTel wiring this pilot, no Python 3.10 backport, no thread pool, no streaming acquire, no sync Pool variant, no dynamic resize, no TTL, no load-shedding, no circuit-breaker, no rate limit, no anyio/trio support, no integration with Go SDK). These are written-contract scope decisions.
- Skills/guardrails declared WARN in §Skills-Manifest filed to `docs/PROPOSED-SKILLS.md` per pipeline rule 23 (this is the documented promotion path).

If you find that a TPRD-declared symbol/test/bench/budget/milestone CANNOT be designed because it conflicts with another TPRD-declared item or with Python's stdlib reality, **do NOT silently drop it**. Send `ESCALATION: DESIGN-CONFLICT` via SendMessage to the design-lead with: (a) the conflicting items, (b) the impossibility evidence, (c) a proposed resolution. The lead surfaces to the user; user decides; design proceeds only after resolution.

---

## Run context (one-page summary)

- **Run ID**: `sdk-resourcepool-py-pilot-v1`
- **Pipeline version**: `0.5.0` (stamp every decision-log entry)
- **Mode**: A — new package; no existing API to preserve; no merge planning; no breaking-change-devil.
- **Target language**: Python 3.11+ (asyncio.timeout + TaskGroup + exception groups required)
- **Target tier**: T1 — full perf-confidence regime per pipeline rule 32 (declaration / profile shape / allocation / complexity / regression+oracle / drift+MMD / profile-backed exceptions).
- **Target package** (impl phase will create): `motadata-py-sdk/src/motadata_py_sdk/resourcepool/`
- **Target SDK dir**: `/home/prem-modha/projects/nextgen/motadata-py-sdk` (READ-ONLY for design phase — DO NOT WRITE there).
- **Go reference impl** (oracle calibration source): `/home/prem-modha/projects/nextgen/motadata-go-sdk/src/motadatagosdk/core/pool/resourcepool/` (`pool.go`, `poolbenchmark_test.go`).
- **Active packages**: `shared-core@1.0.0` + `python@1.0.0` (read `runs/sdk-resourcepool-py-pilot-v1/context/active-packages.json` for the agent/skill/guardrail union).
- **Toolchain**: read `runs/sdk-resourcepool-py-pilot-v1/context/toolchain.md`.

## TPRD anchors you MUST honor

| Section | Required deliverable | Owning sub-agent |
|---|---|---|
| §5.1 PoolConfig | frozen + slots dataclass, generic, fields = max_size, on_create, on_reset, on_destroy, name | designer |
| §5.1 Pool | generic class; methods __init__, acquire, acquire_resource, try_acquire, release, aclose, stats, __aenter__, __aexit__ | designer + interface |
| §5.3 PoolStats | frozen + slots dataclass: created, in_use, idle, waiting, closed | designer |
| §5.3 AcquiredResource | async-context-manager class; __aenter__ / __aexit__ | designer |
| §5.4 PoolError + 3 descendants | sentinel exception hierarchy: PoolError, PoolClosedError, PoolEmptyError, ConfigError | designer |
| §7 ResourceCreationError | additional sentinel; raised when on_create hook fails | designer |
| §7 cancellation correctness | `await self._restore_slot()` then re-raise CancelledError | concurrency |
| §10 perf targets (6 rows) | full perf-budget.md per rule 32 axis 1 | perf-architect |
| §11.1–§11.5 test categories | API/algorithm/concurrency must support unit + integration + bench + leak + race tests | designer + algorithm + concurrency |
| §12 package layout | 5 internal modules: _config, _pool, _stats, _errors, _acquired | designer |
| §15 Q1–Q6 DECIDED answers | honor verbatim — keyword-only timeout, sync try_acquire, Pool aenter/aexit, async release, frozen+slots, separate acquire vs acquire_resource | designer + interface |
| §15 Q7 drift signal name | pilot-driven decision: pick `concurrency_units` per the cross-language language-agnostic decision board | perf-architect (record rationale) |
| §16 Mode A semver | semver-devil → ACCEPT 1.0.0 | sdk-semver-devil (D2) |
| Appendix B mapping | inform algorithm choice (asyncio.Queue vs deque; LIFO via deque if oracle perf demands; set[Task]+done_callback for outstanding tracker) | algorithm + concurrency |
| Appendix C Q3 (T2-3) | drift-signal name decision lives in perf-budget.md `drift_signals` field | perf-architect |
| Appendix C Q4 (T2-7) | leak-check + bench-output adapter shape — informs concurrency design's `assert_no_leaked_tasks` fixture sketch | concurrency |

## §15 Q1–Q6 Decided Answers (verbatim — DO NOT re-litigate)

- **Q1**: `acquire(*, timeout: float | None = None)` — keyword-only.
- **Q2**: `try_acquire` is sync `def`, not `async def`. Async `on_create` + `try_acquire` → `ConfigError`.
- **Q3**: `Pool` is itself an async context manager. `__aenter__` returns `self`. `__aexit__` calls `aclose()`.
- **Q4**: `release()` is `async def`. (Forced by need to await async `on_reset`.)
- **Q5**: `PoolConfig` and `PoolStats` use `@dataclass(frozen=True, slots=True)`. `Pool` uses `__slots__` (perf-architect to confirm if benchmarks justify; default = yes).
- **Q6**: Two distinct methods (`acquire` returns context manager; `acquire_resource` returns `T` directly). NO dual-mode trick.

## Decision-log discipline

- Every sub-agent entry: stamp `pipeline_version: "0.5.0"`, `run_id: "sdk-resourcepool-py-pilot-v1"`.
- Cap: 15 entries per agent per run (CLAUDE.md rule 11).
- Required entry types per agent: 1 `lifecycle:started`, ≥1 `decision`, 1 `lifecycle:completed`. Add `event` / `failure` / `communication` as warranted.

## Context-summary discipline

Each sub-agent writes `runs/sdk-resourcepool-py-pilot-v1/design/context/<agent-name>-summary.md` ≤200 lines, self-contained, timestamp-headered, before lifecycle:completed.

## Sub-agent output ownership matrix

| Sub-agent | Writes ONLY to |
|---|---|
| designer | `design/api-design.md` + `design/context/designer-summary.md` |
| interface | `design/interfaces.md` + `design/context/interface-summary.md` |
| algorithm | `design/algorithm.md` + `design/context/algorithm-summary.md` |
| concurrency | `design/concurrency-model.md` + `design/context/concurrency-summary.md` |
| pattern-advisor | `design/patterns.md` + `design/context/pattern-advisor-summary.md` |
| sdk-perf-architect | `design/perf-budget.md` + `design/perf-exceptions.md` + `design/context/sdk-perf-architect-summary.md` |
| sdk-design-devil | `design/reviews/design-devil-findings.md` + `design/context/sdk-design-devil-summary.md` |
| sdk-dep-vet-devil | `design/reviews/dep-vet-findings.md` + `design/context/sdk-dep-vet-devil-summary.md` |
| sdk-semver-devil | `design/reviews/semver-verdict.md` + `design/context/sdk-semver-devil-summary.md` |
| sdk-convention-devil | `design/reviews/convention-findings.md` + `design/context/sdk-convention-devil-summary.md` |
| sdk-security-devil | `design/reviews/security-findings.md` + `design/context/sdk-security-devil-summary.md` |
| sdk-constraint-devil | `design/reviews/constraint-bench-plan.md` + `design/context/sdk-constraint-devil-summary.md` |

REVIEWERS ARE READ-ONLY (CLAUDE.md rule 5): never modify any other agent's outputs. If a finding requires a fix, file it; the design-lead routes the fix back to the owning sub-agent.

## Conflict escalation

If two sub-agents need contradictory decisions (e.g. designer wants `asyncio.Queue` for slot storage, algorithm wants `collections.deque`), send `ESCALATION: CONFLICT` via SendMessage to the design-lead with: (a) the conflict, (b) both positions with rationale, (c) preferred resolution. Lead resolves per ownership matrix and logs with `tags: ["conflict-resolution"]`.

## Acceptance criteria for D1 sub-agents

A sub-agent's deliverable PASSES if:
1. Its named output file(s) exist and are non-empty.
2. Every TPRD-anchor row above that names this sub-agent is addressed in its file.
3. Context summary written, ≤200 lines, headered with timestamp + run-id + pipeline version.
4. Decision log entries within budget (≤15) and stamped correctly.
5. No forbidden artifacts (TODO/FIXME/TBD/etc) anywhere in the file.
6. Lifecycle:completed entry written.

If any of (1)–(6) fails: design-lead retries once. Second failure: degraded; lead surfaces in H5 summary.
