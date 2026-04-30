<!-- Generated: 2026-04-29T18:35:00Z | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 | Pack: python -->
<!-- Authored-by: root-cause-tracer -->
<!-- Note: defect-log.jsonl not present at trace time; defect-analyzer ran in parallel. -->
<!-- Sources: feedback/retrospective.md, feedback/skill-drift.md, intake/design/impl/testing phase-summary.md. -->

# Root Cause Traces — Python Adapter Pilot

This run is unusual: H7 was approved with one INCOMPLETE acceptance, H8/H9 with calibration disposition; no PASS→FAIL inversion occurred. "HIGH" defects therefore concentrate in **process / tooling / skill-prompt gaps that delayed the run or could let a future similar bug slip past**, not in code-correctness defects shipped on the branch.

Trace columns:

- **introduced-at** — phase × wave where the defect (or omission) entered the run
- **actually-caught-at** — phase × wave where the run first surfaced it
- **should-have-been-caught-at** — the idealized earlier gate; the gap between this and actual is the trace's payload
- **gap-classification** — `skill | agent | guardrail | spec | infra | no-gap-best-possible`

---

## CRITICAL / HIGH defects traced (8)

### CV-001 — `typing` module imported only as `cast` symbol; `cast("typing.Callable[...]", ...)` would NameError at runtime

| Field | Value |
|---|---|
| severity | HIGH (correctness; only caught by toolchain rerun) |
| introduced-at | Phase 2 / M3 — sdk-impl-lead green-phase emit; stringified annotation referenced `typing.X` symbol path while only `cast` was imported from `typing` |
| actually-caught-at | Phase 2 / **M5b** — `mypy --strict` in provisioned venv, post-toolchain-rerun |
| should-have-been-caught-at | Phase 1 / D3 — `sdk-convention-devil-python` flagged this as **LOW** (PEP 585 `collections.abc.Callable` style); the runtime-correctness implication was never elevated. Or Phase 2 / M3.5 if static mypy had run before toolchain rerun |
| gap-classification | **agent** + **skill** (compound) |
| gap detail | `sdk-convention-devil-python` lacks a severity bucket for "import-style finding whose runtime impact cannot be validated statically." When the only available severity buckets are LOW / MEDIUM / HIGH and "PEP 585 stylistic" reads as LOW, a real correctness bug rides under the LOW threshold. The retro proposes a `runtime-impact-unknown` bucket; that is the precise fix. |
| systemic? | YES — any future Python adapter run can repeat the same mis-classification cycle until the convention-devil's severity rubric grows the new bucket. |
| backpatch target | `.claude/agents/sdk-convention-devil-python.md` (severity rubric §); proposed `python-runtime-impact-classifier` skill OR amend `python-mypy-strict-typing` skill body with a "static-check-confirms-correctness" gate. |

---

### TOOLCHAIN-ABSENCE — Python interpreter / pip / venv / pytest / mypy / ruff / py-spy / scalene absent at H7

| Field | Value |
|---|---|
| severity | HIGH (process; cost: 1 stream-idle timeout, 1 fully-static impl pass with cascading INCOMPLETE on G41/G42/G43, 1 toolchain-provisioned rerun) |
| introduced-at | Phase 0 / **H0** — H0 preflight checks git-repo presence only; no language-toolchain probe |
| actually-caught-at | Phase 2 / **M9** — G41-py / G42-py / G43-py all returned INCOMPLETE-by-tooling because the pipeline could not invoke `python -m build`, `mypy`, `ruff` |
| should-have-been-caught-at | Phase 0 / **H0** — a `G-py-toolchain-probe` guardrail running at intake under active-language scope |
| gap-classification | **guardrail** (missing) + **infra** |
| gap detail | The shared-core H0 contract checks only `target dir is git repo`. There is no per-language toolchain assertion. The python pack manifest declares its toolchain commands (`python`, `pip`, `pytest`, `mypy`, `ruff`, `py-spy`, `scalene`) but no guardrail loops over them. Retrospective proposes `G-py-toolchain-probe` BLOCKER at intake; that is the canonical fix. |
| systemic? | YES — generalizes across all language packs. Every future `<lang>` adapter (Phase B onward) needs a `G-<lang>-toolchain-probe`. The clean form is **a shared-core guardrail that reads `toolchain.<command>` from the active language manifest and probes each declared command with `--version`**, so each new pack inherits the check by manifest declaration, not by authoring a sibling guardrail. |
| backpatch target | `scripts/guardrails/G-toolchain-probe.sh` (NEW, shared-core scope, intake phase header); shared-core manifest `aspirational_guardrails` entry; `phases/intake.md` H0 contract update. |

---

### TOOLCHAIN-CASCADE — INCOMPLETE-as-FAIL classification absent on dynamic gates during static-only impl pass

| Field | Value |
|---|---|
| severity | HIGH (process; trace-companion to TOOLCHAIN-ABSENCE) |
| introduced-at | Phase 2 / impl-run-2 — sdk-impl-lead proceeded statically and let M3.5 (G104, G109), M5-verify (mypy), M7 (devil dynamic checks), and M9 (G41/G42/G43) each emit INCOMPLETE without the lead halting on the cluster |
| actually-caught-at | End of Phase 2 / pre-H7 — accumulating INCOMPLETEs prompted the toolchain rerun |
| should-have-been-caught-at | Phase 2 / **M3.5 entry** — sdk-impl-lead should treat `≥2 INCOMPLETE-by-tooling` in a single wave as a halting condition that requires user re-engagement, not a continue condition |
| gap-classification | **agent** |
| gap detail | `sdk-impl-lead` (python pack) prompt does not instruct the lead to halt on cluster-of-INCOMPLETE-by-tooling. Rule 33 disambiguates PASS / FAIL / INCOMPLETE but does not prescribe the lead's escalation policy when N INCOMPLETEs accumulate. The impl-lead correctly tagged each gate INCOMPLETE but kept marching. The right policy: ≥2 INCOMPLETE-by-tooling in same wave → halt + user-ask, do NOT continue. |
| systemic? | YES — same pattern would recur in any pack that lacks Phase-0 toolchain probing. Hardening is at impl-lead policy level, complementing G-toolchain-probe at intake. |
| backpatch target | `.claude/agents/sdk-impl-lead.md` (escalation §); also referenced from a pack-overlay note. |

---

### PA-013 / FLOOR-BOUND-ORACLE — `PoolConfig.__init__` and `AcquiredResource.__aenter__` perf-budget oracle margins mechanically unreachable

| Field | Value |
|---|---|
| severity | HIGH (process; surfaced as G108 CALIBRATION-WARN at H8 — recoverable by perf-budget.md amendment) |
| introduced-at | Phase 1 / **D1** — sdk-perf-architect-python wrote `oracle.margin_multiplier × Go-reference-impl-p50` for both symbols without acknowledging Python language-floor for frozen+slotted dataclass machinery (~2µs floor for `__init__`) |
| actually-caught-at | Phase 3 / **T5** — `sdk-benchmark-devil-python` measured `PoolConfig.__init__: 2.337µs` vs Go×10 = 1µs; G108 surfaced CALIBRATION-WARN |
| should-have-been-caught-at | Phase 1 / D1 — perf-architect should have classified both symbols as `floor_type: language-floor` and set the oracle relative to **measured Python floor**, not Go × multiplier |
| gap-classification | **skill** (missing idiom) + **agent** prompt |
| gap detail | The perf-architect-python prompt has no notion of "floor-bound symbol." The retrospective proposes adding a `floor_type: {language-floor, hardware-floor, none}` enum to `perf-budget.md` and instructing perf-architect to detect language-floor patterns (frozen dataclass init, async ctx-mgr enter, single-attribute struct read) and set oracle accordingly. This is a NEW skill candidate: `python-floor-bound-perf-budget` (per retro Skill Gaps table). |
| systemic? | YES — the same class will surface in every Python pack run that wraps a stdlib runtime primitive (`frozen=True, slots=True` dataclass; `asyncio.Lock` ctx-mgr enter; `asyncio.Queue.get_nowait`) and every cross-language oracle declaration. Future Python adapter components hitting language-floor will produce the same calibration round-trip until perf-architect carries the idiom. |
| backpatch target | NEW skill `python-floor-bound-perf-budget` (proposed in `docs/PROPOSED-SKILLS.md`); `.claude/agents/sdk-perf-architect-python.md` to invoke the skill at D1. |

---

### PA-001 / PA-002 — `try_acquire` and `aclose` benches INCOMPLETE-by-harness (sync-fast-path-in-async, bulk-teardown shapes)

| Field | Value |
|---|---|
| severity | HIGH (perf-confidence; 2 of 8 §7 hot-path symbols never produced a measurable p50) |
| introduced-at | Phase 2 / **M3 green-phase** — bench stubs written without classifying harness shape; `try_acquire` (sync inside asyncio context) and `aclose` (bulk teardown) do not fit `pytest-benchmark`'s per-call timing model |
| actually-caught-at | Phase 2 / **M3.5** — sdk-profile-auditor-python could not instrument the stubs; emitted INCOMPLETE-by-harness for both |
| should-have-been-caught-at | Phase 2 / **M3 pre-flight** — impl-lead should classify each hot-path symbol as `per-call | sync-fast-path-in-async | bulk-teardown` and select a matching harness template before writing bench stubs |
| gap-classification | **skill** (missing) |
| gap detail | The python pack ships no `python-bench-harness-shapes` skill. Retro proposes the skill formalize three harness shapes with pytest-benchmark patterns. Adding a shapes-skill + an impl-lead pre-flight step at M3 closes this class. |
| systemic? | YES — every Python pack release that adds a new client with sync-fast-path or bulk-teardown methods will rediscover the same harness gap. |
| backpatch target | NEW skill `python-bench-harness-shapes`; `.claude/agents/sdk-impl-lead.md` python-overlay step at M3. |

---

### PA-012 / SAMPLER-STARVATION — soak sampler starved under hot asyncio worker loops (run-1 sampling defect)

| Field | Value |
|---|---|
| severity | HIGH (perf-confidence; identical-class bug already documented in Go pack) |
| introduced-at | Phase 3 / **T5.5 run-1** — sdk-soak-runner-python wrote a sampler in same event loop as workers without cooperative-yield, identical pattern to the Go-pack goroutine-scheduler-starves-soak-sampler bug |
| actually-caught-at | Phase 3 / T5.5 run-2 — re-run with patched sampler |
| should-have-been-caught-at | Phase 1 / D1 — the soak design should have warned about cooperative-yield starvation generically; OR Phase 2 / M3 — the soak driver template should have carried the warning |
| gap-classification | **skill** (cross-language carry-over gap) |
| gap detail | The Go-pack soak skill documents this bug as a Go-specific symptom. The Python pack rediscovered it because the skill abstraction did not lift the warning to a language-neutral "sampler-starvation under hot worker loops" rule. Retro proposes new cross-language skill `soak-sampler-cooperative-yield` covering both runtimes. |
| systemic? | YES — this is the **clearest example in the run** of insufficient skill-content abstraction across languages. Same root-cause class will resurface in every new language pack until the skill is hoisted. |
| backpatch target | NEW shared-core skill `soak-sampler-cooperative-yield`; cross-link from `python-asyncio-patterns` SKILL.md and existing Go soak skill. |

---

### G200-py / G32-py PHASE-HEADER-MISMATCH — guardrails fired at design phase for Mode A greenfield (pyproject.toml does not yet exist)

| Field | Value |
|---|---|
| severity | HIGH (process; cost = 1 lead waiver + 1 decision-log entry; would re-cost on every future Python Mode A run) |
| introduced-at | Pack-authoring time — guardrail headers `phase:` field set without `mode_skip` or `min_phase` predicate |
| actually-caught-at | Phase 1 / **D2** — guardrail-validator surfaced as FAIL → reclassified INCOMPLETE-deferred by lead waiver |
| should-have-been-caught-at | Pack-authoring time (one-time fix); or Phase 0 / I-RG if guardrail-validator rejected `phase: design + mode: A + needs-impl-artifact` combinations |
| gap-classification | **guardrail** (header schema gap) |
| gap detail | Guardrail header schema lacks `mode_skip: [A]` / `min_phase: impl` predicates. Mode A (greenfield) has no `pyproject.toml` until M3, so any guardrail keyed off the file at design phase BLOCKER-fires falsely. Retrospective proposes adding the predicate to header schema and patching G200-py + G32-py. |
| systemic? | YES — affects every greenfield Python adapter run. |
| backpatch target | `scripts/guardrails/G200-py.sh` + `scripts/guardrails/G32-py.sh` headers; guardrail header schema doc in `docs/PACKAGE-AUTHORING-GUIDE.md`. |

---

### STREAM-IDLE-MID-WAVE — agent stream killed after 75 tool uses on long-running M3 green-phase commit cycle (no mid-wave checkpoint)

| Field | Value |
|---|---|
| severity | HIGH (infra; cost = 1 user re-engagement + full sub-wave re-run from last checkpoint) |
| introduced-at | Phase 2 / **M3** — sdk-impl-lead long green-phase commit cycle exceeded the harness's 75-tool-use stream-idle ceiling; no mid-wave checkpointing protocol existed |
| actually-caught-at | Phase 2 / M3 — agent died |
| should-have-been-caught-at | Pack/agent design time — sdk-impl-lead should write `wave-checkpoint.json` after each M-wave commit so a resume protocol can skip completed sub-waves |
| gap-classification | **agent** (missing protocol) + **infra** |
| gap detail | Retrospective proposes `wave-checkpoint.json` after each M-sub-wave commit + resume protocol that reads it. This is the cheapest fix (single-file write per commit) and recovers from any mid-wave timeout — not just stream-idle, also user-cancel and OOM. |
| systemic? | PARTIAL — Python-specific frequency due to the 3-sub-run impl cycle, but mid-wave checkpointing is generally beneficial across all language packs. |
| backpatch target | `.claude/agents/sdk-impl-lead.md` (checkpointing §); resume protocol skill `wave-resume-protocol` (NEW or extend existing). |

---

## Summary table

| ID | introduced-at | actually-caught-at | should-have-been-caught-at | gap |
|---|---|---|---|---|
| CV-001 | P2/M3 | P2/M5b (mypy-strict) | P1/D3 (with new severity bucket) | agent + skill |
| TOOLCHAIN-ABSENCE | P0/H0 | P2/M9 | P0/H0 (G-toolchain-probe) | guardrail + infra |
| TOOLCHAIN-CASCADE | P2/run-2 | end of P2 | P2/M3.5 entry (impl-lead halt policy) | agent |
| PA-013 floor-bound oracle | P1/D1 | P3/T5 (G108) | P1/D1 (floor-bound idiom) | skill + agent |
| PA-001/002 bench-harness | P2/M3 | P2/M3.5 | P2/M3 pre-flight (shapes skill) | skill |
| PA-012 sampler-starvation | P3/T5.5 r1 | P3/T5.5 r1 | P1/D1 or P2/M3 (cross-lang skill) | skill (cross-language abstraction gap) |
| G200/G32-py phase-header | pack-authoring | P1/D2 | pack-authoring | guardrail header schema |
| STREAM-IDLE-MID-WAVE | P2/M3 | P2/M3 (death) | pack-authoring (checkpoint protocol) | agent + infra |

---

## Top systemic pattern (the one fix with highest leverage)

**Pattern: missing per-language preflight at H0.**

`TOOLCHAIN-ABSENCE` is the single-largest cost driver in this run (3 impl sub-runs, 2 user re-engagements, full M3.5/M5/M7/M9 INCOMPLETE cascade on the static pass). It is **not Python-specific** in essence: it is a pipeline-wide gap that the shared-core H0 contract checks only that the target is a git repo. The fix has the broadest reach:

> Add a shared-core guardrail `G-toolchain-probe.sh` that, at intake phase, reads `toolchain.<command>` from `active-packages.json`'s active language manifest and probes each declared command with `--version`. BLOCKER on any miss. The guardrail is shared-core; each new language pack inherits the check by declaring its toolchain commands in its manifest, not by authoring a sibling guardrail.

This single fix:

1. Eliminates the 3-sub-run impl cycle on first runs of any new language pack
2. Surfaces toolchain gaps before the user sees Phase 1 design output (saves $80-150 of pipeline cost on a missed-toolchain run)
3. Generalizes to every future language pack (Python Phase B, future Java/Rust packs) by manifest declaration alone
4. Composes cleanly with TOOLCHAIN-CASCADE (impl-lead halt policy) — preflight at intake reduces the surface area where the cascade can occur

Secondary high-leverage pattern: **`runtime-impact-unknown` severity bucket on language-pack convention devils** — would have caught CV-001 at design phase and is small to author (one severity-rubric edit per language convention-devil).

---

## Pointers

- Retrospective: `runs/sdk-resourcepool-py-pilot-v1/feedback/retrospective.md`
- Skill drift: `runs/sdk-resourcepool-py-pilot-v1/feedback/skill-drift.md`
- Phase summaries: `runs/sdk-resourcepool-py-pilot-v1/{intake,design,impl,testing}/phase-summary.md`
- Defect log: not present at trace authorship time (defect-analyzer ran in parallel)
