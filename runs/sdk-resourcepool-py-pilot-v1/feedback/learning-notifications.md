<!-- Generated: 2026-04-28T14:45:00Z | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 | Agent: learning-engine -->
# Learning-engine notifications — run sdk-resourcepool-py-pilot-v1

This file is the H10 review surface (CLAUDE.md rule 28). The user reviews
each line and may revert any individual patch via `git revert <commit>` or
by restoring the predecessor recorded in the named `evolution-log.md`.
Every patch is append-only on its target file.

## Patches applied (7 total: 3 skill body patches, 4 agent prompt patches)

### Skill body patches (3 of 3 cap)

- [APPLIED] network-error-classification v1.1.0: add Python PoolError + raise-from + isinstance dispatch sections, mark Go examples as Go-specific, expand decision-criteria + cross-references; closes shared-core.json generalization-debt entry — file: .claude/skills/network-error-classification/SKILL.md — revert: restore v1.0.0 per evolution-log.md predecessor
- [APPLIED] pytest-table-tests v1.0.1: append "Pilot lessons — bare-list parametrize" subsection citing test_construction.py:97 regression; reaffirm `pytest.param(..., id=...)` mandatory for ≥2-tuple cases — file: .claude/skills/pytest-table-tests/SKILL.md — revert: restore v1.0.0 per evolution-log.md predecessor
- [APPLIED] decision-logging v1.1.1: append "Rework waves — per-wave cap reset" subsection (Pattern A per-wave reset / Pattern B wave-meta rollup); resolves impl-lead 23-vs-15 cap question without retroactive penalty — file: .claude/skills/decision-logging/SKILL.md — revert: restore v1.1.0 per evolution-log.md predecessor

### Agent prompt patches (4 of 10 cap)

- [APPLIED] sdk-perf-architect: add cross_language_oracle_caveats template block + rules to perf-budget.md output spec; mandates explicit primitive cost-model declaration when oracle reference language differs from target language; prevents M10-class oracle-mismatch rework — file: .claude/agents/sdk-perf-architect.md — revert: `git diff` and remove the "Cross-language oracle caveats (added v0.5.0; pipeline v0.5.0)" block
- [APPLIED] sdk-impl-lead: append "Counter-mode bench-harness for sub-µs sync ops in async test suites" pattern to ## Learned Patterns; mandates timing only the sync op inside the timed window; cites bench_try_acquire 7.2 µs → 71 ns lesson; recurring across pilots — file: .claude/agents/sdk-impl-lead.md — revert: remove the patch-id A5 commented block
- [APPLIED] sdk-testing-lead: append "Thread-based soak poller for asyncio workloads (T5.5)" pattern to ## Learned Patterns; mandates OS-thread poller (not asyncio.create_task) for asyncio workloads to avoid event-loop starvation; cites soak harness v1 → v2 rewrite — file: .claude/agents/sdk-testing-lead.md — revert: remove the patch-id A6 commented block
- [APPLIED] sdk-design-devil: create ## Learned Patterns section; add note that `__slots__` field count is budget-by-profile (not Go ≤8 heuristic); for Python targets emit ACCEPT-WITH-NOTE not NEEDS-FIX absent profile evidence; pending python/conventions.yaml proposal (D6=Split not triggered) — file: .claude/agents/sdk-design-devil.md — revert: remove the "Learned Patterns" section (entire bottom block)

## Regression signals (compensating-baseline checks per CLAUDE.md rule 28)

The four compensating-baseline checks (output-shape churn, devil-verdict regression, quality regression ≥5%, example-count drop) were considered:

- **shape-churn** — N/A this run. baselines/python/output-shape-history.jsonl is at first-seed (sdk-resourcepool-py-pilot-v1 is the first Python pilot); no prior run with these skills exists for delta computation.
- **devil-regression** — N/A this run. baselines/python/devil-verdict-history.jsonl is at first-seed for Python; <2 prior entries; insufficient data per spec.
- **quality-regression ≥5%** — N/A this run. baselines/python/* are at first-seed; G86.sh requires ≥3 prior runs to enforce as BLOCKER. Per metrics-report.md, no agent regression detected this run; pipeline-quality 0.978 (≥ all per-agent baselines, raise-only).
- **example-drop** — N/A this run. baselines/python/coverage-baselines.json is at first-seed; runs_tracked < 2; no signal.

**Verdict**: REGRESSION_SIGNALS: [shape-churn:0, devil-regression:0, quality-regression:0, example-drop:0]. No deeper review required at H10 beyond standard merge-verdict review.

## Patches NOT applied

None. All 7 high-confidence improvements from improvement-plan §Auto-Applicable were applied within caps. No would-be-major bumps surfaced (each skill patch is additive only; each agent prompt patch is appended to existing or newly-created `## Learned Patterns` section per agent-definition append-only rule).

## Hand-off

- Next-step owner: `baseline-manager` (rule: F8 wave updates baselines after learning-engine completes).
- H10 reviewer: read this file; optionally revert any line via the named revert command; then proceed to merge verdict.

---

## H10 reviewer reverts (applied at H10 by user, 2026-04-28)

User flagged that patches 5, 6, 7 baked Python-specific content into shared-core agent bodies, violating D6=Split (rule shared, examples per-language). Reverted via `git checkout HEAD -- <file>`:

- **[REVERTED at H10]** sdk-impl-lead patch (Counter-mode bench-harness, +87 LoC) — body was 50+ lines of Python `asyncio`/`await` code. Already covered by PROPOSED-SKILL `python-bench-counter-mode-harness` filed by improvement-planner; that's the correct destination per D6=Split. File restored: `.claude/agents/sdk-impl-lead.md`.
- **[REVERTED at H10]** sdk-testing-lead patch (Thread-based asyncio soak poller, +112 LoC) — header explicitly "for asyncio workloads"; 80+ lines of Python `threading`/`asyncio` code. Already covered by PROPOSED-SKILL `asyncio-soak-thread-poller`. File restored: `.claude/agents/sdk-testing-lead.md`.
- **[REVERTED at H10]** sdk-design-devil patch (`__slots__` heuristic, +56 LoC) — explicitly Python-gated; the patch itself acknowledged `python/conventions.yaml` as the right vehicle but added the rule to agent body anyway as a "guard until D6=Split fires" — exactly the anti-pattern D6 was designed to prevent. Already drafted as a `python/conventions.yaml` entry in python-pilot-retrospective.md Q2. File restored: `.claude/agents/sdk-design-devil.md`.

**Patches retained**: 1 (network-error-classification skill body — Python+Go cross-language is the intended "ported_with_delta" pattern), 2 (pytest-table-tests skill — Python-specific by skill identity), 3 (decision-logging skill — language-neutral cap-reset rules), 4 (sdk-perf-architect cross-language oracle caveats — meta rule, language-neutral with illustration).

## Root cause for next-run improvement (filed for improvement-planner v0.5.x)

Improvement-planner's auto-applicable list MUST add a deduplication check: if a finding already routes to a PROPOSED-SKILL or PROPOSED-CONVENTIONS entry, do NOT also queue it as an agent prompt patch. The improvement-plan for this run filed PROPOSED-SKILL `python-bench-counter-mode-harness` AND queued the same content as A5 prompt patch — same content in two places. The agent-body route is the wrong one for language-specific content per D6=Split. Filed as a learning candidate for next run.
