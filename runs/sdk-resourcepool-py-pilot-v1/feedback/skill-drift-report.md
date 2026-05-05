<!-- Generated: 2026-04-28 | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 | Author: sdk-skill-drift-detector | Phase: 4 -->

# Skill Drift Report — `sdk-resourcepool-py-pilot-v1`

Comparison of what each invoked skill PRESCRIBED against what the generated code (branch
`sdk-pipeline/sdk-resourcepool-py-pilot-v1` head `bd14539`, package
`motadata-py-sdk/src/motadata_py_sdk/resourcepool/`) ACTUALLY does. READ-ONLY analysis;
findings feed `improvement-planner` + `learning-engine`.

## Inputs

- 20 invoked skills (intake-summary §Skills-Manifest, all PRESENT at ≥ declared min version).
- 7 generated source files (`__init__.py`, `_acquired.py`, `_config.py`, `_errors.py`, `_pool.py`, `_stats.py`).
- `tests/` (unit + integration + bench + leak; 81 + 14 tests).
- Decision log (97 entries; rule-11 cap exceeded by leads, NOT by drift-detector).

---

## §1 Per-skill drift table

| # | Skill (vN) | Prescription (1-line) | Actual code observation | Drift | Rationale |
|---|---|---|---|---|---|
| 1 | python-asyncio-patterns 1.0.0 | TaskGroup for fan-out; `set` + done_callback for fire-and-forget | `_pool.py:131` `_outstanding: set[asyncio.Task]`; `_track_outstanding` (L525-534) adds `add_done_callback(self._outstanding.discard)`. NO TaskGroup used (none of the API methods fan out N children). | **NONE** | Pool tracks already-running caller tasks (not children it spawned), so TaskGroup is not the right tool. Skill's task-storage prescription is followed precisely. |
| 2 | asyncio-cancellation-patterns 1.0.0 | `asyncio.timeout()` ctx mgr; re-raise `CancelledError` after cleanup; `shield()` only on critical sections | `_pool.py:478` `asyncio.timeout(timeout)` correctly used; `_pool.py:512-518` `except BaseException:` rolls back reservation and **bare `raise`** (re-propagates `CancelledError`); `_pool.py:375` `asyncio.shield(wait_task)` scoped to the inner drain wait only. `aclose` itself catches `CancelledError`, cleans up inner waiter, **re-raises** (L390-396). | **NONE** | Textbook adherence. Even the subtle `try/finally` pattern in `_acquire_with_timeout` (L506) for `_waiting -= 1` matches skill §"Leaking resources on cancel — no try/finally" pitfall. |
| 3 | python-class-design 1.0.0 | `@dataclass(frozen=True, slots=True)` Generic config + factory function + `__slots__` on hot-path classes | `_config.py:45-47` `@dataclass(frozen=True, slots=True) class PoolConfig(Generic[T])` ✓; `_stats.py:12` same on `PoolStats` ✓; `_pool.py:99-113` `class Pool` declares 13-element `__slots__` ✓; `_acquired.py:46` `__slots__` on AcquiredResource ✓. **However: NO `new_pool(config) -> Pool` factory function — caller does `Pool(config)` directly.** | **MINOR** | Skill prescribes `def new_client(config) -> Client` factory as the analog of Go's `New(cfg)`. Pilot uses direct `Pool(config)` construction (validation lives in `__init__`, not in a factory). Functionally equivalent (validation still runs at construction); cosmetically diverges from skill body. Documented in design `patterns.md`. |
| 4 | python-class-design 1.0.0 (cont) | Validation in `__post_init__` | `PoolConfig.__post_init__` is **absent**; validation lives in `Pool.__init__` (L120-123). | **MINOR** | Same root cause as above — design chose `Pool.__init__` as the validation locus because Pool needs config-derived flags (`_on_create_is_async`) anyway. Pythonic but not what the skill body says. |
| 5 | python-class-design 1.0.0 (cont) | `@dataclass(frozen=True, slots=True)` ON exception classes optional, but no `__slots__` on Exceptions per common Python guidance | `_errors.py` exception classes carry **no `__slots__`** (intentional — `Exception` + `__slots__` is awkward, decision logged at `decision-log.jsonl:41`). | **NONE** | Decision log shows pattern-advisor explicitly chose this. Skill body doesn't mandate slots on exceptions. |
| 6 | pytest-table-tests 1.0.0 | `@pytest.mark.parametrize` with `pytest.param(..., id="...")`; `pytest.raises(..., match=)` on negative paths | `test_construction.py:97` uses `@pytest.mark.parametrize("size", [1, 2, 8, 1024])` — bare values, **no `pytest.param` ids**. `test_construction.py:90-95` uses `pytest.raises(ConfigError, match="max_size")` ✓. Other tests (e.g. `test_cancellation.py`) prefer separate `def test_*` functions over parametrize tables. | **MODERATE** | Skill's central GOOD example (L46-52) shows mandatory `pytest.param(..., id="human-readable")` to keep CI failure triage readable. Pilot uses bare lists 4× and class-style `def test_*` for cancellation/timeout/aclose where a parametrized table would have been natural. `match=` discipline is honored throughout. Test bodies are correct, just structurally not table-driven. |
| 7 | sdk-marker-protocol 1.0.0 | Every pipeline-authored exported symbol carries `[traces-to: TPRD-<section>-<id>]`; constraint markers reference an extant bench; no forged MANUAL markers | Every public symbol carries `[traces-to: TPRD-§...]` ✓ (e.g. `_pool.py:19,95,118,173,201,227,294,332,414,432,448,460,473,529,540,560,573`). `[constraint:]` markers attached at `_pool.py:149-150,206,264,332,466,536` and all reference `bench/bench_*.py::bench_*` which exist in `tests/bench/`. `[stable-since: v1.0.0]` markers correctly pinned to first release. **Marker syntax**: pilot uses `# [traces-to: ...]` inside docstrings AND as bare `# ` comments — matches Python `marker line = '#'` declared in `toolchain.md`. | **NONE** | Skill body uses Go `// [traces-to:]` examples; pilot adapted to Python `#` cleanly. G99/G102 design-time skill body is Go-flavored but operational rules ported correctly. (Note: this is a debt-bearer adaptation success.) |
| 8 | tdd-patterns 1.0.0 | RED → GREEN → REFACTOR cycle; failing test before impl | Decision log entries 70-92 (impl phase) show waves M0..M11 but **no per-symbol RED entries** ("test for X fails", "impl for X makes test green"). Wave structure is M0/M3.5/M7/M9/M10/M11 — slice-based (S1..S6 from milestones) not red/green/refactor named. Tests + impl appear committed together per slice, not test-first. | **MODERATE** | Cannot prove TDD from decision log. The skill is Go-flavored ("code-generator (SKELETON) → test-spec-generator (RED) → code-generator (GREEN)") and the pipeline does not have a `test-spec-generator` agent in `active-packages.json` — `sdk-impl-lead` writes both impl and tests in the same wave. Drift is **structural**: TDD discipline is documented in skill but the agent fleet does not enforce a separate test-first agent. NOT a Python-specific drift; same drift would appear on Go runs. |
| 9 | idempotent-retry-safety 1.0.0 (debt-bearer) | Sentinel-based retry predicate `IsRetryable`; expo backoff with jitter; idempotency envelope | resourcepool **has no retry path** — TPRD §3 Non-Goal explicitly excludes retries. Skill body cites `events/middleware/retry.go` + Go sentinel patterns. | **N/A (skill not applicable)** | Skill was in §Skills-Manifest but TPRD scope makes it inert. Drift: skill *wasn't usable* on this run — no Python guidance for the resource-acquisition retry that DOES happen implicitly (waiter parking on `Condition`, which is functionally a retry loop). Documented as expected debt-bearer behavior. |
| 10 | network-error-classification 1.0.0 (debt-bearer) | Sentinel error catalog; `mapErr` adapter; `errors.Is/As` matchable | `_errors.py` follows the *spirit* (sentinel classes via Python class hierarchy: `PoolError` + 4 descendants, `isinstance` check is the Python `errors.Is` equivalent). Skill body uses Go `errors.New`+`fmt.Errorf %w` exclusively. **`ResourceCreationError` correctly uses `raise ... from user_exc`** preserving `__cause__` (Python's `%w` analog). | **MINOR** | Skill body is 100% Go; pilot's adaptation is correct in spirit but not guided by anything in the skill text. The class-hierarchy translation was a designer-agent inference. Skill body should ship a Python "GOOD example" block (PoolError class hierarchy + `raise ... from`) — that's the v0.5.0 generalization-debt entry already on file in `shared-core.json`. |
| 11 | spec-driven-development 1.0.0 (shared) | TPRD section → impl symbol traceability; every §5 symbol has impl + test + doc | All 9 §5 symbols have impl + test + docstring + `[traces-to:]` marker (verified §1 row 7 above). Coverage 92.33%. | **NONE** | Adhered. |
| 12 | decision-logging 1.1.0 (shared) | Cap 15 entries/agent/run; structured JSONL; types from {decision, lifecycle, communication, event, failure, refactor, skill-evolution, budget} | Decision log has 97 entries. Per-agent counts: `sdk-intake-agent`=15 (cap), `sdk-design-lead`=10, `designer`=5, `interface`=5, `algorithm`=6, `concurrency`=6, `pattern-advisor`=5, `sdk-perf-architect`=6, `sdk-design-devil`=4, `sdk-security-devil`=4, `sdk-semver-devil`=3, `sdk-impl-lead` = **23** (CAP BREACH), `sdk-testing-lead`=5. | **MODERATE** | `sdk-impl-lead` exceeded the 15-entry cap by 8 (23 entries across 7 wave checkpoints). CLAUDE.md rule 11 says "Decision log ≤15 entries per agent per run". Pilot rationale: M10/M11 rework waves added per-fix entries. Drift is procedural (cap not enforced), not a skill-body bug. |
| 13 | guardrail-validation 1.2.0 (shared) | All declared guardrails run; PASS/FAIL/INCOMPLETE verdict | All 22 declared guardrails ran. G108 contention CALIBRATION-WARN documented as advisory. | **NONE** | Adhered. |
| 14 | review-fix-protocol 1.1.0 (shared) | Deterministic-first gate before review fleet re-run; loop cap 10 | Zero review-fix iterations needed (all D2 verdicts ACCEPT first pass). M10 rework triggered by *user* H7-revise, not by review-fix loop. | **NONE** | Adhered (vacuously). |
| 15 | lifecycle-events 1.0.0 (shared) | `started`/`completed` lifecycle entries per agent | Every agent has both. `sdk-intake-agent` has TWO `completed` entries (entry 15 supersedes a prior one per its detail field). | **NONE** | Adhered with documented superseding. |
| 16 | feedback-analysis 1.0.0 (shared) | Phase 4 feedback consumer | This skill is invoked by Phase 4 — current run-time. Drift detector runs alongside feedback-analysis; neither modifies the other. | **N/A** | Concurrent skill. |
| 17 | sdk-semver-governance 1.0.0 (shared) | First public ship of new package = 1.0.0; signature change rules | sdk-semver-devil (decision-log entry 63) chose 1.0.0 stable correctly (Mode A new package, TPRD §16 declares `experimental=false`). | **NONE** | Adhered. |
| 18 | api-ergonomics-audit 1.0.0 (shared) | Param count discipline; 4-or-fewer user-facing params | sdk-design-devil (entry 55) confirmed every public method ≤4 params; PoolConfig + PoolStats dataclass `__init__` synthesized at 5 are dataclass-exempt. | **NONE** | Adhered. |
| 19 | conflict-resolution 1.0.0 (shared) | Lead resolves conflicts per ownership matrix | No conflicts surfaced. | **N/A** | Vacuous PASS. |
| 20 | environment-prerequisites-check 1.1.0 (shared) | Toolchain digest + version check | `toolchain.md` digest written at intake; impl-lead verified `python 3.12.3`, `pytest 9.0.3`, etc. (decision-log entry 72). | **NONE** | Adhered. |
| 21 | mcp-knowledge-graph 1.0.0 (shared) | MCP read/write + fallback; never block | MCP-related entries absent from this run's log; pipeline used filesystem fallbacks throughout. | **NONE** | Skill's fallback contract explicitly permits this. |
| 22 | context-summary-writing 1.0.0 (shared) | ≤200 lines per context summary | `intake/intake-summary.md` = 186 lines ✓; `testing/h9-summary.md` = 124 lines ✓. (Did not audit every summary.) | **NONE (sampled)** | Adhered in samples. |

(Rows 11–22 = the 6 shared-core process skills explicitly listed in the manifest plus 5 covered above; total 20 skills inspected, plus tdd-patterns from shared-core.)

---

## §2 Per-skill drift level summary

- **NONE**: 14 (asyncio-cancellation, sdk-marker-protocol, spec-driven, guardrail-validation, review-fix, lifecycle-events, sdk-semver, api-ergonomics, environment-prereqs, mcp-knowledge-graph, context-summary, python-asyncio-patterns row 1, python-class-design row 5, conflict-resolution vacuous)
- **MINOR**: 3 (python-class-design rows 3 & 4 — missing factory + missing `__post_init__`; network-error-classification — body-Go-only adaptation needed)
- **MODERATE**: 3 (pytest-table-tests — bare-list parametrize w/o ids; tdd-patterns — no RED/GREEN trace; decision-logging — impl-lead 23/15 cap breach)
- **SEVERE**: 0
- **N/A**: 3 (idempotent-retry-safety inert by TPRD non-goal; feedback-analysis concurrent; conflict-resolution no conflicts)

---

## §3 Top-3 drift findings (with concrete file:line citations)

### SKD-001: pytest-table-tests — `pytest.param(..., id=...)` not used  [MODERATE]
- **Where**: `motadata-py-sdk/tests/unit/test_construction.py:97` (`@pytest.mark.parametrize("size", [1, 2, 8, 1024])`); same shape repeats across other unit tests.
- **Skill body** (`pytest-table-tests/SKILL.md:46-52,177`): "Always wrap each case in `pytest.param(..., id="human-readable")`. Test report shows `test_publish[empty-subject-rejected]` instead of `test_publish[--True]`."
- **Effect**: CI failure triage degraded — `test_accepts_positive_max_size[1024]` is readable now (single int param) but the pattern won't scale when the next pilot adds 3-tuple params.

### SKD-002: tdd-patterns — no RED→GREEN trace in decision log  [MODERATE]
- **Where**: Decision log entries 70-92 (impl waves M0..M11). No `event: red-test-written` then `event: impl-makes-test-green` per symbol. Tests + impl appear shipped together per slice.
- **Skill body** (`tdd-patterns/SKILL.md:17-23`): three-agent cycle (`code-generator (SKELETON)` → `test-spec-generator (RED)` → `code-generator (GREEN)`).
- **Effect**: Cannot retroactively prove TDD discipline. `test-spec-generator` agent is not in `active-packages.json` for either python or shared-core (the python adapter's `agents: []` is itself a documented gap, see testing-lead entry 94).
- **Note**: This drift is **structural at the agent-fleet level**, not a Python-specific issue. Same drift would appear on a fresh Go run.

### SKD-003: decision-logging — `sdk-impl-lead` exceeded 15-entry cap  [MODERATE]
- **Where**: Decision log; `sdk-impl-lead` author count = 23 entries (entries 70-92).
- **Skill body / CLAUDE.md rule 11**: "Decision log ≤15 entries per agent per run".
- **Effect**: Procedural (no functional harm); but if the cap were enforced as BLOCKER, the impl phase would have failed validation at H7. The cap is not currently mechanically enforced anywhere (no guardrail). Likely the right answer is to relax the cap on rework waves OR add a guardrail.

---

## §4 Recommendations (per drift)

| ID | Drift | Recommendation | Owner |
|---|---|---|---|
| SKD-001 | pytest-table-tests `id=` not used | **Skill is correct + code is wrong** — but fix-impl is impl-phase's job and H7+H9 already passed. **For learning-engine**: file as a v1.0.1 minor patch to `pytest-table-tests/SKILL.md` adding a Python pilot post-mortem note: "Run `sdk-resourcepool-py-pilot-v1` shipped with bare-list `parametrize` — the skill body should add a `## Pilot lessons` section with a one-paragraph "scale matters" justification so this doesn't regress." | learning-engine |
| SKD-002 | tdd-patterns no RED→GREEN | **Drift is intentional at fleet level** — no `test-spec-generator` agent for either lang. **For improvement-planner**: file a v0.6.0 proposal to either (a) split `sdk-impl-lead` into a per-slice red/green pair, or (b) demote `tdd-patterns` to "advisory" and update its Activation signals to acknowledge it's not enforced. NOT a learning-engine candidate (this is fleet topology). | improvement-planner |
| SKD-003 | decision-logging cap breach | **Skill is correct + code (impl-lead body) didn't enforce** — but the skill itself doesn't say HOW to enforce. **For learning-engine**: file as a v1.1.1 patch to `decision-logging/SKILL.md` adding a "Rework waves" subsection: "Per-wave caps reset on every wave OR a wave-level meta-entry rolls up sub-entries." | learning-engine |
| SKD-MINOR-1 | python-class-design factory absent | **Drift is intentional** — `Pool.__init__` already does the validation work (designer's `decision-log.jsonl:43` rationale). **For learning-engine**: file as v1.0.1 minor patch adding "Construction-locus: when `__init__` MUST hold derived state (cached-flag patterns), the factory function is optional." | learning-engine |
| SKD-MINOR-2 | python-class-design `__post_init__` absent | Same as above — coupled. | learning-engine (same patch) |
| SKD-MINOR-3 | network-error-classification all-Go body | **Skill is correct in spirit but unusable as-is for Python**. This is the explicit `generalization_debt` entry in `shared-core.json` ("network-error-classification" body cites Go-only patterns). **For learning-engine**: file as v1.1.0 minor patch adding a Python "GOOD example" block (PoolError hierarchy + `raise ... from` as the `%w` analog). | learning-engine |
| ALL N/A rows | retry-safety inert, feedback-analysis concurrent, conflict-resolution vacuous | No action. | — |

---

## §5 Generalization-debt snapshot (for retrospective Q5)

Three shared-core debt-bearer skills observed:

1. **`idempotent-retry-safety`** — INERT for resourcepool (TPRD §3 Non-Goal). No translation cost incurred. KEEP debt entry.
2. **`network-error-classification`** — body 100% Go; pilot adapted correctly in spirit (PoolError class hierarchy + `raise ... from`) but received zero guidance from the skill text. ADD Python GOOD example to body (SKD-MINOR-3 above). REMOVE debt entry once patched.
3. **`tdd-patterns`** — body cites Go agents (`code-generator`/`test-spec-generator`) that don't exist in the python adapter. KEEP debt entry; deeper restructure is a v0.6.0 fleet topology question (SKD-002).

---

## §6 SEVERE-drift blocker check for retrospector

**Zero SEVERE drifts.** No retrospector blocker. H7+H9 already passed; this report is purely informational input for `improvement-planner` and `learning-engine`.

## §7 Skill-body-patch candidates for learning-engine

Total: **4 minor-bump candidates**.

1. `pytest-table-tests` v1.0.0 → v1.0.1: append "Pilot lessons — `pytest.param(id=)` enforcement" subsection.
2. `decision-logging` v1.1.0 → v1.1.1: append "Rework waves" subsection (cap reset semantics).
3. `python-class-design` v1.0.0 → v1.0.1: append "Construction-locus" caveat (factory optional when `__init__` already holds derived state).
4. `network-error-classification` v1.0.0 → v1.1.0: add Python GOOD example block (class hierarchy + `raise ... from`); minor bump because new examples are additive.

All four are existing-skill body patches per CLAUDE.md rule 23 — no new SKILL.md files. Per-patch notification line will be required in `runs/sdk-resourcepool-py-pilot-v1/feedback/learning-notifications.md` (G85).
