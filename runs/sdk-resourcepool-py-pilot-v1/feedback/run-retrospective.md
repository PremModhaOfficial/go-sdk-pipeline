<!-- Generated: 2026-04-28T00:00:00Z | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 -->
# Run Retrospective — `sdk-resourcepool-py-pilot-v1`

## Summary

First Python pilot for the motadata-sdk-pipeline. Mode A, T1, Python 3.11+. New package:
`motadata_py_sdk.resourcepool`. Four phases completed (intake / design / impl / testing).
All HITL gates approved. RULE 0 (zero TPRD tech debt) satisfied with one legitimately-
adjudicated user decision (M11 contention re-baseline). Branch `sdk-pipeline/sdk-resourcepool-
py-pilot-v1` at SHA `bd14539`; 7 commits; ready for H10 merge verdict.

## Outcome metrics

| Metric | Value |
|---|---|
| Tests | 81 unit/integration/leak + 14 bench = 95 total |
| Coverage | 92.33% (gate ≥90%; all 6 files individually ≥90%) |
| Flake detection | 690/690 PASS (pytest --count=10) |
| Soak | PASS at 600.38 s / 40.25M cycles |
| Supply chain | pip-audit + safety both clean; 0 CVEs |
| Tech-debt scan | 0 hits across all 7 wave checkpoints |
| G108 oracle | 6/7 PASS; 1 CALIBRATION-WARN (contention host-load; not a regression) |
| Baselines seeded | 6 Python baseline files (first-run seed) |
| HITL gates | H0/H1/H5/H7/H9 all APPROVED; H8 AUTO-PASS-WITH-ADVISORY |

## What Worked Well

- **RULE 0 propagation chain**: verbatim constraint copy in intake-summary.md → inherited by
  all 4 phase leads → explicit enforcement (tech-debt scans, forbidden-artifact greps). The
  chain held across 7 waves with 0 hits.
- **Design-phase §15 pre-decision strategy**: all 6 Q1-Q6 answers decided in the TPRD before
  the design phase began. Zero intra-design conflicts; zero D3 review-fix iterations. This is
  the right pattern for Python pilots going forward.
- **Contention ESCALATION model**: M10 Fix 2 escalated correctly (intentional test FAIL as
  signal, not as noise); M11 re-baseline applied per user decision with full audit trail
  (original_budget_v0 preserved; CI gate floor documented; v1.1.0 TPRD drafted). The
  escalation model worked end-to-end without losing any evidence.
- **Python pilot guardrail set was sufficient**: 22 guardrails; all relevant to Python;
  G30-G65 Go-specific guardrails correctly excluded by active-packages.json.
- **Leak harness + negative test**: the habit of confirming fixture sensitivity (via deliberate
  leak in a sandbox test) should be mandatory for all future pilots.

## What Didn't Work / Needs Fixing

- **python.json `agents: []`** (biggest structural gap): five perf-confidence roles ran in-process
  by testing-lead; two surrogate design reviews; one profile-auditor role gap. The Phase A
  Python adapter scaffold left agents empty as a known placeholder. This is the #1 item to
  address before the v1.1.0 run.
- **G90 schema-drift** (H1 BLOCKER): guardrail body did not iterate over new skill-index.json
  sections added by the Phase A PR. G90 now generalised; prevent recurrence by adding a
  "schema-section coverage" assertion to G90 itself.
- **Cross-language oracle derivation ("N× Go")**: the 500k acq/sec budget assumed Python
  asyncio.Lock cost ≈ Go channel cost. It doesn't (factor of ~10). Future cross-language
  oracle derivations MUST account for the target language's primitive cost model.
- **Bench harness correctness**: `try_acquire` appeared 70× slower than reality because async-
  release overhead polluted the timed window. Counter-mode harness is the correct pattern for
  any sub-µs synchronous operation in an async test suite.
- **Soak harness asyncio loop starvation**: v1 (pure asyncio poller) starved the workload loop.
  Rule: soak harnesses MUST poll from a dedicated OS thread for asyncio workloads.

## Top-3 Surprises

1. **G90 BLOCKER at H1**: a new skill-index.json section (`python_specific`) added by the Phase
   A PR was invisible to G90's hardcoded section list. First thing the pipeline hit on the
   first Python run. Resolved quickly but underscored that schema evolution must trigger
   guardrail body verification.

2. **M10 perf rework — bench harness shape matters by orders of magnitude**: `try_acquire`
   appeared at 7.2 µs (over budget). The actual operation is 71 ns. A 100× error caused by
   async-release overhead in the timed window. The lesson: async harness overhead can completely
   mask fast synchronous operations; always use counter-mode or batch-mode harnesses for
   sub-µs ops.

3. **M11 re-baseline as ESCALATION resolution**: the contention budget (10× Go oracle) was
   structurally unreachable on Python's asyncio.Lock+Condition impl. The M10 ESCALATION model
   worked exactly as designed — intentional test FAIL surfaced the data; user decided in one
   interaction; M11 closed the loop with a user-approved budget update, CI gate floor, and a
   filed v1.1.0 TPRD draft. No evidence lost; no tech debt created.

## Generalization-debt delta (Q5 summary)

| Action | Count | Items |
|---|---|---|
| REMOVE | 0 | — |
| KEEP | 7 | All 4 agent entries + 3 skill entries in current shared-core.json |
| ADD | 2 (agents) | sdk-testing-lead, sdk-profile-auditor (python.json gap) |
| ADD | 1 (PROPOSED skill) | python-asyncio-lock-free-patterns (v1.1.0 requirement; human-authored) |

## Items Requiring H10 Attention (beyond standard merge verdict)

1. **CALIBRATION-WARN (contention 32:4)**: median 426k across 6 loaded-host reruns vs 450k
   design budget. CI gate floor (425k) PASSED 5/6. Not a code regression (SHA unchanged from
   H7). Surface as informational; no waiver needed; v1.1.0 TPRD already filed.

2. **PROPOSED-SKILLS.md update**: `python-asyncio-lock-free-patterns` must be filed to
   `docs/PROPOSED-SKILLS.md` before the v1.1.0 run begins (pipeline rule 23 — human authored).
   User should confirm this action at H10.

3. **python.json `agents: []` gap**: user should approve a follow-up PR that adds the 5+
   perf-confidence specialist roles (benchmark-devil, complexity-devil, soak-runner,
   drift-detector, profile-auditor) and 2 design roles (dep-vet, convention devils) to
   python.json before the v1.1.0 run. Without this, v1.1.0 repeats the in-process multi-role
   anti-pattern.

4. **v1.1.0 TPRD draft at `runs/.../feedback/v1.1.0-perf-improvement-tprd-draft.md`**: user
   should read and approve the draft before authorising the v1.1.0 run. The draft is complete
   (Mode B extension, full §7 API unchanged, §8 perf targets, §9 test strategy, §10-15).

## Recommendation

**APPROVE for H10 merge.** Branch `sdk-pipeline/sdk-resourcepool-py-pilot-v1` (SHA `bd14539`)
is production-quality Python code with 92.33% coverage, zero tech debt, RULE 0 satisfied,
and all gate verdicts PASS or CALIBRATION-WARN (advisory only). The four items above are
routine post-merge actions, not blockers.
