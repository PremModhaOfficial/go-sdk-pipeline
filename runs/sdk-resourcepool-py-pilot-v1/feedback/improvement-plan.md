<!-- Generated: 2026-04-29T18:55:00Z | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 | Pack: python | Mode A · Tier T1 -->
<!-- Author: improvement-planner | Cap: existing_skill_patches_per_run=3, new_skills_per_run=0, new_guardrails_per_run=0 -->

# Improvement Plan — Python Adapter Pilot

Run: `sdk-resourcepool-py-pilot-v1` · first Python pipeline run · pipeline quality 0.959

## Summary

| Metric | Value |
|---|---|
| Total improvements | 14 |
| Category A (auto-patchable, learning-engine consumes) | 3 (capped per settings.json) |
| Category B (human-PR new artifact — file to docs/PROPOSED-*) | 4 |
| Category C (next-run target-SDK changes, ride a Mode C maintenance run) | 4 |
| Category D (process / threshold proposals) | 3 |
| HIGH confidence | 8 |
| MEDIUM confidence | 4 |
| LOW confidence | 2 |

Per CLAUDE.md rule 28, learning-engine MUST append every Category A patch to
`runs/sdk-resourcepool-py-pilot-v1/feedback/learning-notifications.md` for H10 user review. User
may revert any individual patch before merge.

This is the first Python run. There is no prior improvement plan to dedup against; nothing carries
forward as "recurring".

---

## Category A — Pipeline auto-patches (existing-skill body patches; minor version bump)

The 3 picks below are HIGH-confidence, low-blast-radius, and address the highest-leverage skill
drift findings (SKD-001, SKD-002, SKD-003) all surfacing in the python pack with explicit
remediation paths. learning-engine applies them as **existing-skill body patches** with minor
version bump (X.Y.0 → X.Y+1.0); the new skill body acquires a clearer prescriptive paragraph or
example block. **No new skill files** are created — strictly bumps to bodies that already exist.

### A1 — `python-asyncio-leak-prevention` v1.0.0 → v1.1.0

```json
{
  "category": "A",
  "confidence": "HIGH",
  "target_skill": "python-asyncio-leak-prevention",
  "skill_path": ".claude/skills/python-asyncio-leak-prevention/SKILL.md",
  "current_version": "1.0.0",
  "bumped_version": "1.1.0",
  "patch_summary": "Strengthen §Test-gates Rule 1 to make the autouse=True directive non-negotiable. Add explicit BAD example showing a non-autouse fixture (mirroring this run's conftest.py:26 defect SKD-001). Add explicit GOOD example: @pytest.fixture(autouse=True) plus opt-out marker @pytest.mark.no_task_tracker plumbing. Add a single sentence: 'A non-autouse leak fixture is a no-op for every test that does not name it; the leak guarantee is forfeited.' Append a row to evolution-log.md citing run_id and the SKD-001 defect.",
  "rationale": "SKD-001 (conftest.py asyncio_task_tracker not autouse) is the highest-severity skill-drift finding in the run. 59/62 tests run unguarded against the very leak class the skill exists to prevent. The skill body already contains the correct prescription; it just was not loud enough to override the pattern of writing fixtures opt-in. Sharper BAD/GOOD pair + a one-sentence anti-pattern caption closes the drift. Blast radius: minimal — only the python pack consumes this skill; existing implementations that already use autouse=True are unaffected; future generations get the corrected guidance. HIGH confidence: defect is precisely localized, fix is text-only, no semantic change to the skill — only emphasis."
}
```

### A2 — `python-exception-patterns` v1.0.0 → v1.1.0

```json
{
  "category": "A",
  "confidence": "HIGH",
  "target_skill": "python-exception-patterns",
  "skill_path": ".claude/skills/python-exception-patterns/SKILL.md",
  "current_version": "1.0.0",
  "bumped_version": "1.1.0",
  "patch_summary": "Strengthen §Rule 4 ('except is not a catch-all') with an explicit refactoring recipe: when intent is 'catch any user-hook failure but propagate cancellation', the canonical form is `except CancelledError: raise / except Exception as e:` — NOT `except BaseException`. Add a BAD example block citing this run's _pool.py L247/L381/L451/L536 pattern and the GOOD refactor (drop BaseException to Exception with the preceding CancelledError arm intact). Note: 'BaseException keyword combined with a preceding CancelledError arm is fragile under future edits; if the CancelledError arm is dropped the BaseException catch silently swallows cancellation.' Append evolution-log.md row.",
  "rationale": "SKD-002: `except BaseException` appears 4× in _pool.py. Skill already says don't do this; the failure mode is that authors who handle CancelledError upstream feel licensed to use BaseException for the broad arm. The fix is a refactoring recipe, not a new rule — code authors need a concrete drop-in answer. Blast radius: minimal — refactor recipe is well-defined; the skill's existing rule is not weakened, only operationalized. HIGH confidence: same pattern likely to recur in every Python adapter that has user-supplied callbacks (every event-bus client, every connection-pool client); recipe transfers directly."
}
```

### A3 — `python-doctest-patterns` v1.0.0 → v1.1.0

```json
{
  "category": "A",
  "confidence": "HIGH",
  "target_skill": "python-doctest-patterns",
  "skill_path": ".claude/skills/python-doctest-patterns/SKILL.md",
  "current_version": "1.0.0",
  "bumped_version": "1.1.0",
  "patch_summary": "Add a new mandatory section §CI Wiring at the head of the body: '**Examples blocks are only worth writing if the build runs them.** A pyproject.toml [tool.pytest.ini_options].addopts entry MUST include `--doctest-modules` (or a dedicated tests/test_doctests.py invoking doctest.testmod on each public module). A pyproject without --doctest-modules is the same as having no examples — the build cannot detect drift.' Add GOOD pyproject snippet showing addopts including --doctest-modules + --doctest-glob. Add note for asyncio-flavored examples: use `# doctest: +SKIP` on `asyncio.run(...)` lines or refactor to a sync result-display style. Append evolution-log.md row citing SKD-003.",
  "rationale": "SKD-003: 9/9 public symbols carry Examples blocks but pyproject.toml addopts omits --doctest-modules. The skill's whole rationale ('the example IS a test') is forfeited. Highest blast radius reduction per word of patch: a single GOOD pyproject snippet immediately closes a class of silent docstring drift across every future Python adapter. HIGH confidence: fix is mechanical, well-known idiom, zero ambiguity. Blast radius: zero — Examples already exist; adding the test-discovery flag only enforces what the skill already prescribes."
}
```

**Cap honored**: 3/3 used. Other skill-patch candidates (python-sdk-config-pattern slots/kw_only,
python-asyncio-patterns wait_for→timeout) are LOWER priority + LOW severity and ride next run.

---

## Category B — Human-PR new artifacts (file to docs/PROPOSED-SKILLS.md / docs/PROPOSED-GUARDRAILS.md)

Pipeline runtime caps for new skills/guardrails/agents are 0. learning-engine appends these
proposal blocks to the appropriate docs file; a human authors the artifact via PR before any TPRD
can reference it.

### B1 — NEW SKILL `python-bench-harness-shapes` (proposal for docs/PROPOSED-SKILLS.md)

```markdown
## python-bench-harness-shapes

- **scope**: python
- **proposed_version**: 1.0.0
- **priority**: SHOULD
- **target_consumers**: sdk-impl-lead (python overlay), sdk-profile-auditor-python, sdk-benchmark-devil-python
- **provenance**: feedback-derived(PA-001, PA-002, run sdk-resourcepool-py-pilot-v1)
- **confidence**: HIGH
- **source_evidence**: defect-log DEF-001, DEF-002; root-cause-traces "PA-001 / PA-002"; retrospective Skill Gaps row 1
- **rationale**: pytest-benchmark's per-call timing model assumes `setup → measure → teardown` per iteration. Two real symbol shapes break that assumption: (a) **sync-fast-path-in-async** (`try_acquire`: a sync method called inside an asyncio context that returns immediately) — pytest-benchmark cannot reliably measure sub-µs sync calls; (b) **bulk-teardown** (`aclose`: drains N resources in one call) — per-iteration timing is meaningless because the work is amortized. Both shapes need bespoke harness templates. Without the skill, every Python adapter rediscovers the gap; PA-001/PA-002 will recur in every Python pack release.
- **proposed_body_outline**:
  1. §When-to-apply: any benchmarking task on a Python SDK client with sync/async or bulk-amortized methods
  2. §Three harness shapes — per-call (default; pytest-benchmark group), sync-fast-path-in-async (loop.call_soon timing harness; warmup loop sized to 10k iters; uses time.perf_counter_ns delta for sub-µs precision), bulk-teardown (parametrize over N ∈ {10, 100, 1k}; report µs/resource not µs/call; assert linear scaling)
  3. §GOOD examples for each shape (harness fixture + bench function + result-assertion pattern)
  4. §BAD example: pytest-benchmark @benchmark on a sync method called from async context (exhibits the PA-001 INCOMPLETE symptom)
  5. §Cross-reference: `python-pytest-patterns`, `sdk-marker-protocol` (constraint:bench markers)
- **suggested_path**: `.claude/skills/python-bench-harness-shapes/SKILL.md`
```

### B2 — NEW SHARED-CORE GUARDRAIL `G-toolchain-probe` (proposal for docs/PROPOSED-GUARDRAILS.md)

```markdown
## G-toolchain-probe.sh — language-agnostic toolchain preflight at H0

- **scope**: shared-core
- **phase header**: intake
- **rationale**: TOOLCHAIN-ABSENCE was the single-largest cost driver in the Python pilot run — 3 impl sub-runs, 2 user re-engagements, full M3.5/M5/M7/M9 INCOMPLETE cascade. H0 currently checks only that the target dir is a git repo; no per-language toolchain assertion runs. Reading `toolchain.<command>` from the active language manifest and probing each declared command with `--version` would have surfaced the gap before any Phase 1 design work.
- **source_evidence**: root-cause-traces "TOOLCHAIN-ABSENCE" (highest-leverage trace in the run); retrospective Process Changes row 1; retrospective Guardrail Additions row 1
- **confidence**: HIGH
- **check_logic**:
  1. Read `runs/<run-id>/context/active-packages.json` to resolve active language manifest
  2. For each manifest with a `toolchain.<command>` block, iterate declared commands
  3. For each command, exec `<command> --version` (or manifest-declared probe form, e.g. `python -c 'import sys; print(sys.version)'`)
  4. Pass: every probe returns exit 0; capture and log version strings
  5. Fail (BLOCKER): any probe fails; emit list of missing commands + suggested install hint per manifest
- **pass_criteria**: all toolchain commands probe successfully
- **fail_criteria**: any toolchain command absent or unversioned
- **why_shared_core**: every language pack inherits the check by manifest declaration alone — no need for `G-py-toolchain-probe.sh`, `G-go-toolchain-probe.sh`, etc. The retrospective initially proposed `G-py-toolchain-probe`; root-cause-tracer confirmed the shared-core form is correct.
- **suggested_path**: `scripts/guardrails/G-toolchain-probe.sh`
- **manifest_action**: add to `shared-core.json` `aspirational_guardrails` until script lands; promote to `guardrails` array on PR-merge.
```

### B3 — NEW SKILL `python-floor-bound-perf-budget` (proposal for docs/PROPOSED-SKILLS.md)

```markdown
## python-floor-bound-perf-budget

- **scope**: python
- **proposed_version**: 1.0.0
- **priority**: SHOULD
- **target_consumers**: sdk-perf-architect-python, sdk-benchmark-devil-python
- **provenance**: feedback-derived(PA-013, run sdk-resourcepool-py-pilot-v1)
- **confidence**: HIGH
- **source_evidence**: defect-log DEF-013; root-cause-traces "PA-013 / FLOOR-BOUND-ORACLE"; retrospective Skill Gaps row 2 + Agent Prompt Improvements row 1
- **rationale**: PoolConfig.__init__ and AcquiredResource.__aenter__ both hit the Python language floor (frozen+slotted dataclass init ~2µs; async ctx-mgr enter ~1.5µs). The Go×10 oracle margin is mechanically unreachable for these symbols regardless of impl quality. perf-architect-python has no idiom for declaring "floor-bound" symbols; the gap costs a calibration round-trip (PA-013) on every Python adapter that wraps stdlib runtime primitives.
- **proposed_body_outline**:
  1. §When-to-apply: any §7 symbol that wraps a CPython runtime primitive (frozen+slotted dataclass __init__, asyncio.Lock ctx-mgr enter, asyncio.Queue.get_nowait, etc.)
  2. §Floor-type taxonomy: `language-floor` (interpreter overhead; ≥1µs per Python frame), `hardware-floor` (memory allocator floor, syscall floor), `none` (no floor binding)
  3. §perf-budget.md schema extension: add `floor_type: language-floor | hardware-floor | none` and `measured_floor_us: <number>` per §7-symbol entry
  4. §Oracle calibration: when `floor_type ≠ none`, set oracle relative to measured floor × `oracle.margin_multiplier`, NOT against Go reference impl
  5. §G108 interaction: benchmark-devil-python reads `floor_type` and `measured_floor_us`; CALIBRATION-WARN suppressed when within margin of declared floor; BLOCKER triggered only if measured p50 exceeds floor × margin
  6. §Detection rubric: identify floor-bound candidates by signature pattern (frozen-dataclass init, async-ctx-mgr enter, single-attribute reads on slotted classes)
- **suggested_path**: `.claude/skills/python-floor-bound-perf-budget/SKILL.md`
```

### B4 — NEW SHARED-CORE SKILL `soak-sampler-cooperative-yield` (proposal for docs/PROPOSED-SKILLS.md)

```markdown
## soak-sampler-cooperative-yield

- **scope**: shared-core
- **proposed_version**: 1.0.0
- **priority**: SHOULD
- **target_consumers**: sdk-soak-runner-python, sdk-soak-runner-go, future <lang>-soak-runners
- **provenance**: feedback-derived(PA-012, run sdk-resourcepool-py-pilot-v1; cross-language carry-over from existing Go-pack soak skill)
- **confidence**: MEDIUM
- **source_evidence**: defect-log DEF-012, DEF-019; root-cause-traces "PA-012 / SAMPLER-STARVATION" (called out as 'clearest example in the run of insufficient skill-content abstraction across languages'); retrospective Surprises bullet 2 + Skill Gaps row 3
- **rationale**: Python pack rediscovered a sampler-starvation bug already documented in the Go pack's soak skill, because that documentation is Go-specific. Cooperative-yield starvation in any single-threaded scheduler (asyncio event loop, goroutine scheduler, future Java virtual-thread carrier) under hot worker loops causes the soak sampler to under-sample during high-throughput phases — soak verdicts then reflect sampling artifacts rather than steady-state behavior. A shared-core skill ensures every future language pack inherits the warning by reading one shared body, not by re-deriving from runtime-specific symptoms.
- **proposed_body_outline**:
  1. §The pattern: cooperative-yield starvation under hot worker loops; symptom = sampler reports flat / dropped metrics during high-throughput phase, recovers during cooldown
  2. §Why language-neutral: applies to any cooperative scheduler — asyncio (Python), goroutine (Go), virtual-thread carrier (Java loom), tokio current_thread (Rust)
  3. §Mitigations: dedicated sampler thread/process (preferred); explicit `await asyncio.sleep(0)` / `runtime.Gosched()` between sample interval batches; subprocess sampler that observes process from outside (py-spy / pprof)
  4. §Per-language overlays: short subsection naming the language-native symptom + concrete cite into language-pack skills (`python-asyncio-patterns`, Go soak skill section X)
  5. §Validation: how to confirm sampler health post-soak — sample-count vs. expected per-second rate, gap detection
- **suggested_path**: `.claude/skills/soak-sampler-cooperative-yield/SKILL.md`
- **note**: explicitly cross-link from existing Go soak skill body and from `python-asyncio-patterns` SKILL.md once authored.
```

---

## Category C — Next-run target-SDK changes (Mode C maintenance run, NOT skill patches)

These items live in target SDK code/config; they are addressed by a follow-up Mode C maintenance
run on the same TPRD with the existing branch. learning-engine does NOT touch these — the next
pipeline run regenerates them with the patched skills (A1/A2/A3) already applied.

### C1 — Bench harness rework for `try_acquire` and `aclose` (PA-001, PA-002)

- **target**: `motadata-go-sdk` branch `sdk-pipeline/sdk-resourcepool-py-pilot-v1` → `tests/bench/test_bench_pool.py`
- **change**: rewrite the two INCOMPLETE bench functions using the harness shapes from B1 once the skill is authored. `try_acquire` → sync-fast-path-in-async harness (manual `time.perf_counter_ns` warmup + 10k-iter loop); `aclose` → bulk-teardown harness (parametrize over N ∈ {10, 100, 1k}, report µs/resource).
- **confidence**: HIGH (after B1 lands)
- **source**: PA-001, PA-002 from phase4_backlog
- **owner**: next-run sdk-impl-lead (python pack)

### C2 — `pyproject.toml` ruff bump 0.4 → 0.6.5 + 26-finding triage (PA-004)

- **target**: `motadata-go-sdk:pyproject.toml`, dev-extras pin
- **change**: bump `ruff>=0.6.5,<0.7` (PEP 639 license-files supported); promote `python.json` `toolchain.lint.min_version: 0.6.5` from informational to enforced; triage all 26 ruff findings (especially ASYNC109 vs TPRD §10 timeout contract); confirm pytest-CVE response (PA-009: `pytest>=8.4.3` once available, or pin around CVE-2025-71176)
- **confidence**: MEDIUM (lint bumps frequently surface unrelated findings)
- **source**: PA-004, PA-009 from phase4_backlog; defect-log DEF-004, DEF-009
- **owner**: next-run sdk-impl-lead (python pack) + python manifest maintainer

### C3 — `perf-budget.md` floor-bound amendment (PA-013)

- **target**: `motadata-go-sdk:design/perf-budget.md` (current run's design output) → next-run regeneration
- **change**: add `floor_type: language-floor` + `measured_floor_us` to PoolConfig.__init__ and AcquiredResource.__aenter__ entries per the B3 skill once authored. Re-run G108; CALIBRATION-WARN should clear.
- **confidence**: HIGH (after B3 lands)
- **source**: PA-013, defect-log DEF-013
- **owner**: next-run sdk-perf-architect-python

### C4 — `scripts/run-guardrails.sh` realpath one-liner (PA-005)

- **target**: pipeline `scripts/run-guardrails.sh`
- **change**: `ACTIVE_PACKAGES_JSON=$(realpath "$ACTIVE_PACKAGES_JSON")` before child guardrails cd into TARGET. One line; closes path-resolution breakage when child guardrails change cwd.
- **confidence**: HIGH
- **source**: PA-005, defect-log DEF-005
- **owner**: pipeline-infra / shared-core maintainer (small PR)

---

## Category D — Process / threshold proposals (recorded; ultimately human-PR territory)

### D1 — Promote `toolchain.<command>.min_version` from informational to enforced (manifest schema)

- **current**: `python.json` `toolchain.lint.min_version` is informational only; mismatches surface at M9 as G43-py INCOMPLETE
- **proposed**: any `min_version` declared in a manifest's `toolchain` block becomes enforced; G43-py treats version-below-min as `INCOMPLETE-by-tooling` from intake (not at M9)
- **justification**: PA-004 exhibited a structural false-negative — the ruff 0.4 vs PEP 639 mismatch fired late and cost a M9 round-trip. Min-version enforcement is mechanical at intake.
- **confidence**: HIGH
- **owner**: shared-core schema PR (manifest authoring guide §toolchain)

### D2 — Guardrail header schema: add `mode_skip` and `min_phase` predicates

- **current**: G200-py and G32-py have only `phase: design` headers; they fire at design phase for Mode A greenfield where pyproject.toml does not exist yet, requiring lead waivers
- **proposed**: add `mode_skip: [A]` (skip in Mode A entirely) and/or `min_phase: impl` (skip until impl phase) predicates to guardrail header schema. Patch G200-py and G32-py headers in same PR.
- **justification**: prevents false-BLOCKER + waiver overhead on every future Python Mode A run; one-time schema fix
- **confidence**: HIGH
- **owner**: package-authoring-guide doc owner (schema PR) + python pack maintainer (header patches)

### D3 — Pipeline impl-lead halt policy: ≥2 INCOMPLETE-by-tooling in same wave → halt + user-ask

- **current**: TOOLCHAIN-CASCADE — sdk-impl-lead correctly tagged each gate INCOMPLETE during run-2 but kept marching, accumulating M3.5/M5/M7/M9 INCOMPLETEs before user re-engagement
- **proposed**: amend `.claude/agents/sdk-impl-lead.md` (general; not python-specific) — halt policy: when ≥2 INCOMPLETE-by-tooling verdicts accumulate within a single wave, halt and request user re-engagement; do NOT continue to subsequent waves
- **justification**: Rule 33 disambiguates verdicts but does not prescribe escalation policy. The cascade was technically correct but cost three sub-runs of pipeline work.
- **confidence**: MEDIUM (impl-lead is a general agent; per-language overlays may need to add their own halt clauses)
- **owner**: sdk-impl-lead author (prompt PR)

---

## Generalization-debt items addressed

Per CLAUDE.md `generalization_debt` field in package manifests, two run-derived items contribute:

1. **PA-006 — CLAUDE.md rules 20, 24, 28, 32 prose names Go-specific agents** (defect-log DEF-006).
   Addressed in **Category D** as a separate human-PR doc fix: replace `sdk-perf-architect-go`,
   `sdk-benchmark-devil-go`, `sdk-profile-auditor-go` etc. in language-neutral rule prose with
   `<lang>`-parameterized notation. Out-of-scope for learning-engine (touches CLAUDE.md);
   filed for human PR by docs owner. **NOT counted in the 14-item total above.**
2. **`scripts/compute-shape-hash.sh` not authored for Python pack (PA-014)**. Tracked in python
   pack `generalization_debt`. Addressed in B2/B4 indirectly (the shared-core path forward), but
   the script itself is a Mode-C-style improvement: author once, reusable across packs. Filed
   to **Category D** as a follow-up: pipeline-infra maintainer authors `scripts/compute-shape-hash.sh`
   with `--lang python|go` switch reading active-packages.json. **NOT counted in 14-item total.**

---

## D2 progressive-trigger response (sdk-impl-lead −19.5pp delta)

Per per-agent-scorecard.md D2 cross-language analytics, `sdk-impl-lead` scored 0.78 in Python vs.
0.975 in Go baseline — a −19.5pp debt that exceeds the 3pp WARN threshold. D2=Lenient logged WARN
without blocking, correctly per posture.

**Direct response items**:

- **Category D — D3** (impl-lead halt policy on INCOMPLETE-cascade) addresses the highest single
  rework-score driver in this run (M3.5 INCOMPLETE → resume+rerun, M5b mechanical-fix iteration).
- **Category B — B1** (`python-bench-harness-shapes`) addresses the 6 PA items on impl-lead's
  downstream-impact penalty (PA-001/002 are the largest contributors to the 0.5 downstream-impact
  component score).
- **Category B — B2** (G-toolchain-probe shared-core) eliminates the toolchain-absent failure
  cause that forced impl-lead's 1 retry + 0.5 failure-recovery penalty.

**Combined effect (when all 3 land)**: rework_score 0.5 → ~1.0; failure_recovery 0.5 → 1.0;
downstream_impact 0.5 → ~1.0. Projected impl-lead score: 0.78 → ~0.94, closing the −19.5pp delta
to ~−3.5pp (within D2's 3pp tolerance, no longer a progressive-trigger candidate).

This run's D2 trigger is **language-pack-specific** (Python toolchain absence + missing harness
shapes skill), not a structural cross-language regression. Per D2=Lenient, no per-language
partition needed yet; revisit at rolling-3 if delta persists.

---

## Items not auto-applicable but recorded (≤30-line cap honored above)

- SKD-004 (PoolConfig slots/kw_only): defer — already documented in code; LOW severity; rides next run as Mode-C target-SDK change if user requests.
- SKD-005 (asyncio.wait_for vs asyncio.timeout): LOW; skill itself classes wait_for "still acceptable"; defer.
- SKD-006 (drain polling vs Condition): LOW; same as SKD-002 PA-002 path; addressed via C1.
- SKD-007 (cast() overuse): LOW; mechanically necessary given current callable-union types; defer.

These are not in the 14-item count.

---

## Pointers

- Metrics: `runs/sdk-resourcepool-py-pilot-v1/feedback/metrics.json`
- Per-agent scorecard: `runs/sdk-resourcepool-py-pilot-v1/feedback/per-agent-scorecard.md`
- Skill coverage: `runs/sdk-resourcepool-py-pilot-v1/feedback/skill-coverage.md`
- Skill drift: `runs/sdk-resourcepool-py-pilot-v1/feedback/skill-drift.md`
- Retrospective: `runs/sdk-resourcepool-py-pilot-v1/feedback/retrospective.md`
- Defect log: `runs/sdk-resourcepool-py-pilot-v1/feedback/defect-log.jsonl`
- Root-cause traces: `runs/sdk-resourcepool-py-pilot-v1/feedback/root-cause-traces.md`
- Run manifest: `runs/sdk-resourcepool-py-pilot-v1/state/run-manifest.json`
- Settings (caps source): `.claude/settings.json` (existing_skill_patches_per_run=3, new_*=0)

learning-engine consumes this plan, applies Category A items to the listed skill files (minor
version bumps, evolution-log appends), files Category B proposals to docs/PROPOSED-SKILLS.md or
docs/PROPOSED-GUARDRAILS.md, and writes a per-patch line to
`runs/sdk-resourcepool-py-pilot-v1/feedback/learning-notifications.md` for H10 user review.
