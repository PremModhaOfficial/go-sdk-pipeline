<!-- Generated: 2026-04-28T13:30:00Z | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 | Agent: improvement-planner -->
# Improvement Plan — `sdk-resourcepool-py-pilot-v1`

First Python pilot (v0.5.0 Phase B). Mode A; Tier T1. Pipeline-quality 0.978; RULE 0 satisfied.
This plan synthesizes 10 input artifacts (4 retros + 4 metrics/coverage/drift reports +
python-pilot Q1–Q5 + run-retrospective) into 14 categorized, confidence-rated improvements
plus 4 PROPOSED-SKILLS additions, 5 PROPOSED-GUARDRAILS additions, and a generalization-debt
delta proposal. All changes honor `settings.json` safety caps and CLAUDE.md rule 23.

## Summary

- Total improvements: **14** (≤20 cap respected)
- Auto-applicable by learning-engine: **3 skill body patches + 4 prompt patches = 7**
  (under 3-skill / 10-prompt caps)
- Requires human PR: **4 PROPOSED-SKILLS + 5 PROPOSED-GUARDRAILS + 1 PROPOSED-CONVENTIONS**
- Process / threshold: **2 proposals** (in-body, no separate file exists)
- Backlog: **1 (idempotent-retry-safety body patch awaits Python retry TPRD)**
- Recurring from prior runs: **2 (surrogate-review pattern from sdk-dragonfly-s2;
  bench-harness correctness from sdk-dragonfly-s2 — elevated severity per
  design-retro and impl-retro Systemic Patterns)**
- Confidence breakdown: **5 HIGH, 6 MEDIUM, 3 LOW**

---

## Auto-Applicable by learning-engine (caps respected: ≤3 skill, ≤10 prompt)

These ship via existing-skill-body minor bumps (rule 23) or prompt patches. Each requires a
notification line in `learning-notifications.md` (G85). Confidence × Impact rating per item.

### Skill body patches (3 of 3 cap)

| # | Skill (vN → vN') | Diff intent | Source evidence | Confidence × Impact |
|---|---|---|---|---|
| A1 | `network-error-classification` 1.0.0 → 1.1.0 | Add Python "GOOD example" block: `PoolError` class hierarchy + `raise … from user_exc` as the `%w` analog; mark Go `errors.Is` / `net.Error` examples as Go-specific. Additive only. Closes shared-core.json `generalization_debt` entry once landed. | skill-drift §SKD-MINOR-3; skill-coverage §evolution-candidates HIGH; impl-retro M10 surprise note | **HIGH × HIGH** |
| A2 | `pytest-table-tests` 1.0.0 → 1.0.1 | Append "Pilot lessons: bare-list parametrize" subsection citing `test_construction.py:97` regression risk; reaffirm `pytest.param(..., id="…")` is mandatory for ≥2-tuple params. | skill-drift §SKD-001 MODERATE | **HIGH × MEDIUM** |
| A3 | `decision-logging` 1.1.0 → 1.1.1 | Append "Rework waves" subsection: per-wave caps reset on every rework wave OR a wave-level meta-entry rolls up sub-entries. Resolves the impl-lead 23-vs-15 cap breach without retroactively penalizing the M10/M11 wave. | skill-drift §SKD-003 MODERATE | **HIGH × MEDIUM** |

### Prompt patches (4 of 10 cap)

| # | Agent | Diff intent | Source evidence | Confidence × Impact |
|---|---|---|---|---|
| A4 | `sdk-perf-architect` | Add a `cross_language_oracle_caveats` template section to `perf-budget.md` output spec: when oracle is "N× <other-language>", flag the underlying primitive cost-model assumption (asyncio.Lock ≠ Go chan; ~10× factor). | impl-retro M10 Fix 2 root cause; run-retrospective "Cross-language oracle derivation" | **HIGH × HIGH** |
| A5 | `sdk-impl-lead` | Document counter-mode bench-harness pattern for sub-µs sync ops in async test suites. Mandate isolation of timed window from async-release overhead. Cite `bench_try_acquire` 7.2 µs → 71 ns lesson. | impl-retro M10 Fix 1; run-retrospective Top-3 Surprise #2; sdk-dragonfly-s2 prior recurrence | **HIGH × HIGH** |
| A6 | `sdk-testing-lead` | Mandate thread-based soak poller for asyncio workloads (no asyncio-poller); add to soak harness template/checklist. | testing-retro Soak harness v1 → v2; run-retrospective "What Didn't Work" | **MEDIUM × HIGH** |
| A7 | `sdk-design-devil` | Add note: `__slots__` field count is budget-by-profile, not heuristic; ≤8 is a Go/C-struct idiom, not a Python limit. (Companion to A8 PROPOSED-CONVENTIONS entry.) | skill-coverage §D6 (DD-001); python-pilot Q2 | **MEDIUM × MEDIUM** |

---

## Requires Human PR

### PROPOSED-SKILLS additions (4 entries) — filed to `docs/PROPOSED-SKILLS.md`

| # | Skill | Motivation | Primary consumers | Confidence × Impact |
|---|---|---|---|---|
| P1 | `python-asyncio-lock-free-patterns` (v1.0.0) | Required by v1.1.0 perf-improvement TPRD draft (`runs/sdk-resourcepool-py-pilot-v1/feedback/v1.1.0-perf-improvement-tprd-draft.md §11`). asyncio.Lock+Condition imposes ~2 µs/cycle floor; v1.1.0 targets ≥1M acq/sec (≥2× current). Skill must encode lock-free / sharded / queue-based patterns appropriate for Python asyncio. **MUST be authored before v1.1.0 run begins.** | sdk-perf-architect, sdk-impl-lead, concurrency, algorithm | **HIGH × HIGH** |
| P2 | `asyncio-soak-thread-poller` (v1.0.0) | Codifies the rule: soak harnesses for asyncio workloads MUST poll from a dedicated OS thread (not the event loop) to avoid loop starvation. Surfaced from soak harness v1 → v2 rewrite this run. Companion to A6 prompt patch (skill body provides the Python implementation; prompt mandates the rule). | sdk-testing-lead, sdk-soak-runner | **MEDIUM × MEDIUM** |
| P3 | `python-bench-counter-mode-harness` (v1.0.0) | Codifies counter-mode / batch-mode harness patterns for sub-µs sync ops in async test suites. Surfaced from `bench_try_acquire` 100× error this run. Companion to A5. | sdk-impl-lead, sdk-benchmark-devil | **MEDIUM × MEDIUM** |
| P4 | `python-asyncio-task-leak-fixture` (v1.0.0) | Codifies the policy-free `assert_no_leaked_tasks` fixture pattern (snap `asyncio.all_tasks()` before/after; reusable across any asyncio package). Confirmed working in this pilot (Q4 verdict). Lifts the pattern out of the resourcepool tests so the next Python pilot inherits it. | sdk-leak-hunter, sdk-testing-lead | **MEDIUM × LOW** |

### PROPOSED-CONVENTIONS additions (4 entries)

`docs/PROPOSED-CONVENTIONS.md` does not yet exist. Filing the proposal in plan body (this
section) for human triage; the human creates the file + authors `python/conventions.yaml`
entries per pipeline rule 23.

Verbatim entries from python-pilot Q2 (already drafted by retrospector):

```yaml
suppress_go_noise:
  - agent: sdk-overengineering-critic
    pattern: "Go interface unused abstraction"
    python_replacement: >
      Flag @abstractmethod ABC with zero concrete subclasses OR Protocol with only one
      structural-duck-typing user as potential over-abstraction. Single-impl concrete
      classes are normal in Python.

  - agent: sdk-dep-vet-devil
    pattern: "govulncheck / go get / go.sum"
    python_replacement: >
      Use pip-audit for vulnerability scanning; safety check --full-report for CVE
      cross-reference; pyproject.toml [project.dependencies] for direct dep declaration.

  - agent: sdk-security-devil
    pattern: "tls.Config / crypto/tls examples"
    python_replacement: >
      Python TLS is handled via ssl.SSLContext or httpx/aiohttp transport; for
      in-process asyncio pools with no network I/O, TLS findings are N/A.

  - agent: sdk-design-devil  # corresponds to A7 prompt patch
    pattern: "__slots__ field count ≤8 heuristic"
    python_replacement: >
      __slots__ field count is budget-by-profile, not by heuristic; the ≤8 idiom comes
      from Go/C-struct conventions and does not apply to Python.
```

Confidence × Impact: **MEDIUM × MEDIUM** (pattern observed once; mitigation correctly
identified; D6=Split not yet justified — `python/conventions.yaml` is the right
intermediate vehicle per skill-coverage §D6 verdict).

### PROPOSED-GUARDRAILS additions (5 entries) — filed to `docs/PROPOSED-GUARDRAILS.md`

| # | Guardrail | Phase | Severity | Source evidence | Confidence × Impact |
|---|---|---|---|---|---|
| G1 | G-SCHEMA-SECTION-COVERAGE | Intake (I0/H1 preflight) | BLOCKER | G90 BLOCKER at H1 caused by hardcoded section list missing the new `python_specific` skill-index.json section (Phase A schema 1.1.0). Generalization at runtime fixed it; preventive guardrail asserts every `skills.*` schema section is iterated by every guardrail that walks the index. | intake-retro G90 BLOCKER; run-retrospective Top-3 Surprise #1 | **HIGH × HIGH** |
| G2 | G-PY-SPY-INSTALLED | Impl (M3.5 preflight) | BLOCKER (gated on G109 in active-packages) | py-spy was not pre-installed in the venv; G109 reverted to "INCOMPLETE for strict surprise-hotspot" at M3.5; resolved ad-hoc in M10. Preflight removes the round-trip. | impl-retro M10 Fix 3; testing-retro Phase B carryover | **HIGH × MEDIUM** |
| G3 | G-DRIFT-MAGNITUDE | Testing (T5.5 drift) | WARN-only | sdk-drift-detector triggered statistically-significant positive trend on `heap_bytes` (\|t\|=14.97) at magnitude 0.07 bytes / million ops — operationally negligible GC oscillation. Add `magnitude_floor` to drift verdict so trivial slopes do not fire. | testing-retro CALIBRATION-WARN heap_bytes | **MEDIUM × MEDIUM** |
| G4 | G-HARNESS-SHAPE | Impl (M3.5/M7 bench review) | WARN | Asserts: a benchmark function does NOT `await` a non-timed async operation inside the timed window. Catches `bench_try_acquire`-class harness inflation pre-devil-review. | impl-retro Fix 1; run-retrospective Top-3 Surprise #2 | **MEDIUM × MEDIUM** |
| G5 | G-SKILLMD-VERSION | Intake (I2 §Skills-Manifest) | WARN | Asserts every SKILL.md frontmatter has a `version:` field. `feedback-analysis` was discovered missing this; index-recorded version was 1.0.0 but SKILL.md frontmatter was bare. Defense-in-depth on rule 23. | intake-retro G23 WARN | **LOW × LOW** |

### PROPOSED-AGENTS

`docs/PROPOSED-AGENTS.md` does not exist in the repo. Filing the proposal in plan body for
human triage; the human creates the file (or extends `docs/PROPOSED-SKILLS.md` workflow) and
authors agent prompts per CLAUDE.md rule 23 (no agent body authorship by pipeline).

Per python-pilot Q5 + design-retro + testing-retro, the dominant structural debt is
`python.json` `agents: []`. Five+ specialist roles ran in-process (testing-lead) and three
surrogate reviews were authored at design-lead. The agents themselves are language-neutral —
they are `shared-core` agents — so the action is **add them to `shared-core.json`'s
`agents[]` array** (a manifest edit; human-only per rule 34 / CLAUDE.md). Specifically:

| # | Agent | Currently | Proposed | Rationale |
|---|---|---|---|---|
| Ag1 | sdk-dep-vet-devil | absent from active-packages.json | add to `shared-core.json` agents[] | Surrogate review at design (entry 65); language-neutral role |
| Ag2 | sdk-convention-devil | absent | add to `shared-core.json` agents[] | Surrogate review at design |
| Ag3 | sdk-constraint-devil | absent | add to `shared-core.json` agents[] | Surrogate review at design |
| Ag4 | sdk-profile-auditor | absent | add to `shared-core.json` agents[] (with Python toolchain note) | Caused G109 INCOMPLETE at M3.5; testing-lead substitution |
| Ag5 | sdk-benchmark-devil, sdk-complexity-devil, sdk-soak-runner, sdk-drift-detector, sdk-leak-hunter, sdk-integration-flake-hunter | absent | add to `shared-core.json` agents[] OR `python.json` agents[] | testing-retro identified all 5 as in-process anti-pattern |

Confidence × Impact: **HIGH × HIGH**. **Required before v1.1.0 run begins** per
run-retrospective H10 attention item #3.

---

## Process & Threshold Proposals

### Process change Pr1 — Bench-harness correctness review at M3.5

- **Current state**: bench harnesses authored by sdk-impl-lead and reviewed only at M7
  by overengineering-critic + code-reviewer. Counter-mode/batch-mode shape correctness
  is not a deliberate review item; bench-harness shape errors recur (sdk-dragonfly-s2 +
  this run = 2 of 2 first-package pilots affected).
- **Proposed state**: insert a "bench-harness shape" checkpoint at M3.5 (alongside G109
  profile audit). Reuses A5 prompt patch + G4 PROPOSED-GUARDRAIL as enforcement vehicles.
- **Justification**: 2 of 2 pilots (sdk-dragonfly-s2 Go + sdk-resourcepool-py Python)
  required late-stage bench harness rework. Systemic per impl-retro and run-retrospective.
- **Confidence × Impact**: **HIGH × HIGH**.

### Threshold change Th1 — Drift-detector magnitude floor

- **Current value**: drift verdict fires on any statistically-significant positive slope
  (p<0.01) regardless of magnitude.
- **Proposed value**: add configurable `magnitude_floor` (e.g. 0.001 bytes/op for heap;
  0.001 µs/op for latency); ignore positive slopes below the floor.
- **Data justification**: `heap_bytes` slope 0.07 bytes / million ops triggered drift
  alarm but is operationally negligible (= 70 bytes over 1B ops = ~70 ns of GC noise).
  Controlling signals (Gen1, Gen2) flat. Annotated PASS in-phase but the alarm consumed
  reviewer attention.
- **Confidence × Impact**: **MEDIUM × MEDIUM**.

---

## Backlog (lower confidence; revisit after more data)

| # | Improvement | Why backlogged |
|---|---|---|
| BL1 | `idempotent-retry-safety` body patch (Python GOOD example) | Skill not invoked this run (TPRD §3 Non-Goal). No Python retry-primitive evidence to draft against. **Revisit when a Python TPRD declares retry semantics.** |

### Skill-evolution backlog (SDK-specific)

Per skill-drift §7 candidates list, the following are explicitly tagged for future
learning-engine evaluation:

| # | Skill | Evolution intent | Trigger |
|---|---|---|---|
| BL2 | `python-class-design` 1.0.0 → 1.0.1 | Append "Construction-locus" caveat: factory function is optional when `__init__` already holds derived state (cached-flag pattern). | Already drafted in skill-drift §SKD-MINOR-1/2; not in 3-skill cap this run; ship next Python run. |
| BL3 | `tdd-patterns` body restructure | Demote to "advisory" OR split impl-lead into red/green sub-agents. Fleet-topology question, not body patch. | skill-drift §SKD-002 MODERATE drift; not a learning-engine candidate (rule 23). File as v0.6.0 design proposal. |

---

## Generalization-debt update (Q5 verdict propagation)

`.claude/package-manifests/shared-core.json` `generalization_debt` array is human-edited
(rule 23 / rule 34). Filing the proposed edits in plan body for human triage:

**REMOVE: 0 entries**
**KEEP: 7 entries** (4 agents + 3 skills, all per Q5 table)
**ADD: 3 entries**

```json
{
  "agents": [
    {"name": "sdk-testing-lead", "debt": "python.json agents:[] forces 5+ specialist perf-confidence roles to execute in-process. Multi-role anti-pattern arose from Phase A scaffold leaving agents empty. Resolve by populating shared-core.json or python.json agents[] (see PROPOSED-AGENTS Ag5).", "source_run": "sdk-resourcepool-py-pilot-v1"},
    {"name": "sdk-profile-auditor", "debt": "Absent from python.json; G109 INCOMPLETE for strict surprise-hotspot at M3.5; resolved ad-hoc via py-spy install in M10. List in shared-core.json with py-spy adapter command for next Python run.", "source_run": "sdk-resourcepool-py-pilot-v1"}
  ],
  "skills": [
    {"name": "python-asyncio-lock-free-patterns", "debt": "PROPOSED but not yet authored. Required by v1.1.0 perf-improvement TPRD. Human author + PR-merge before v1.1.0 run begins (rule 23).", "source_run": "sdk-resourcepool-py-pilot-v1"}
  ]
}
```

Annotation update for existing `sdk-overengineering-critic` debt entry per Q5:
add note "ME-001 advisory in M10 showed implicit Go-test-visibility reasoning; Python
overengineering critique needs duck-typing + Protocol concerns examples section."

`docs/PROPOSED-GENERALIZATION-DEBT.md` does not exist; the human may either author it or
apply the edits directly to `shared-core.json`.

---

## D2 Verdict Propagation — HOLD Lenient

**Decision**: D2 holds Lenient. **No action this run.**

**Rationale** (per python-pilot Q1 + metrics-report §D2):

- sdk-design-devil quality_score Python: **0.91**
- sdk-design-devil quality_score Go baseline (sdk-dragonfly-s2): **0.85**
- Delta: **+6pp** (POSITIVE)
- Lenient regime triggers per-language partition only on ≥3pp **NEGATIVE** divergence.
- A POSITIVE divergence is evidence the agent's review heuristics transfer well.
- D6=Split is NOT triggered. Per-language partition is NOT triggered. Skill stays shared.

Baseline raise: per raise-only policy, the next Go run will raise sdk-design-devil's
shared baseline 0.85 → 0.91 (+7.1% > 10% threshold not actually met; raise condition
re-checked at next Go run). This run only seeds the Python baseline (0.91, recorded as
`python_pilot_seed`).

---

## D6 Verdict Propagation — NOT YET (continue Lenient)

**Decision**: D6 does NOT split. **No agent prompt is partitioned per-language this run.**

**Rationale** (per skill-coverage §D6 + python-pilot Q2):

- One Go-flavored heuristic leak observed: `sdk-design-devil` DD-001 `__slots__` field
  count ≤8 heuristic.
- Impact: ACCEPT-WITH-NOTE (not a blocker).
- D6=Split threshold per docs/LANGUAGE-AGNOSTIC-DECISIONS.md: **2+ confirmed cases of
  Go-derived heuristic producing wrong findings**. Single observation does not cross.
- Mitigation vehicle: `python/conventions.yaml` (4 draft entries, see PROPOSED-CONVENTIONS).
  This is the documented intermediate per Decision D6 (Split is a last resort).
- Re-evaluate D6 at next Python run: if a second instance of Go-flavored heuristic leak
  occurs, escalate to D6=Split for that specific agent.

---

## v1.1.0 TPRD Followup Status

`runs/sdk-resourcepool-py-pilot-v1/feedback/v1.1.0-perf-improvement-tprd-draft.md` was
filed during impl M11. **Owner handoff**:

| Item | Owner | Action |
|---|---|---|
| TPRD draft review + sign-off | User (H10 attention) | Read draft; approve to authorize v1.1.0 run |
| `python-asyncio-lock-free-patterns` SKILL.md authorship | Human (rule 23) | Required BEFORE v1.1.0 run begins; tracked in PROPOSED-SKILLS P1 |
| python.json agents[] population | Human (rule 23 / rule 34) | Required BEFORE v1.1.0 run; see PROPOSED-AGENTS Ag1-Ag5 |
| v1.1.0 run kickoff | Pipeline orchestrator | After all three above complete |

---

## RULE 0 / RULE 23 Compliance

- **No improvement re-introduces TPRD tech debt.** Specifically:
  - Contention CI gate floor remains at **425k** (no proposal to lower).
  - RULE 0 enforcement remains intact (no proposal to loosen forbidden-artifacts).
  - All 5 Appendix C retrospective questions answered with concrete data; nothing
    deferred to next run.
- **No new SKILL.md / AGENT.md / G-script files created at runtime.** All such items
  routed to PROPOSED-* files for human PR (rule 23).
- **Auto-applicable items respect safety caps**: 3 skill body patches (cap 3); 4 prompt
  patches (cap 10); 0 new skills/agents/guardrails by pipeline (cap 0).
- **Each auto-patch will be notified** in `learning-notifications.md` per G85 (handoff
  to learning-engine).

---

## Top-3 HIGH × HIGH (priority for learning-engine)

1. **A1**: `network-error-classification` v1.0.0 → v1.1.0 — add Python `PoolError`
   GOOD example block (closes a generalization-debt entry).
2. **A4**: `sdk-perf-architect` prompt patch — add `cross_language_oracle_caveats` to
   perf-budget.md template (prevents M10-class oracle-mismatch rework).
3. **A5**: `sdk-impl-lead` prompt patch — codify counter-mode bench-harness pattern for
   sub-µs sync ops (prevents bench-harness-shape rework; recurring across pilots).

PROPOSED-* HIGH×HIGH items for human triage:
- **P1**: `python-asyncio-lock-free-patterns` skill — required by v1.1.0 TPRD.
- **G1**: G-SCHEMA-SECTION-COVERAGE guardrail — prevents G90-class schema-drift recurrence.
- **Ag1-Ag5**: populate `shared-core.json` / `python.json` agents[] — eliminates surrogate
  review + in-process multi-role anti-pattern (#1 structural debt of Phase A).

---

## Items Requiring H10 Attention (beyond merge verdict)

(Cross-references run-retrospective Items §H10 list and adds improvement-planner findings.)

1. **PROPOSED-SKILLS.md updates** (4 entries: P1 P2 P3 P4) — read + decide which to PR.
2. **PROPOSED-GUARDRAILS.md updates** (5 entries: G1–G5) — read + decide which to PR.
3. **PROPOSED-CONVENTIONS** (4 entries inline) — author `docs/PROPOSED-CONVENTIONS.md`
   OR apply directly to `python/conventions.yaml` (when authored).
4. **`shared-core.json` / `python.json` agents[] population** (PROPOSED-AGENTS Ag1–Ag5)
   — required before v1.1.0 run begins.
5. **v1.1.0 TPRD draft** at `runs/.../feedback/v1.1.0-perf-improvement-tprd-draft.md` —
   approve before v1.1.0 run.
6. **Generalization-debt update to `shared-core.json`** — REMOVE 0 / KEEP 7 / ADD 3 per
   Q5 verdict; manifest edit is human-only (rule 34).
7. **CALIBRATION-WARN (contention)** — informational only, advisory carryover from H9.
   No waiver needed; v1.1.0 TPRD already filed to address.
