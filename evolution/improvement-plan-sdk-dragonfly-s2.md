<!-- Generated: 2026-04-18T15:20:00Z | Run: sdk-dragonfly-s2 | Pipeline: 0.2.0 (manifest stamps 0.1.0 — inconsistency flagged in §E) -->
# Improvement Plan — sdk-dragonfly-s2 (Wave F6)

## Summary
- **Total improvements proposed:** 17 (≤ 20 cap)
- **By category:** 4 prompt patches, 3 existing-skill body patches (recommended, learning-engine decides), 3 new-skill proposals (filed to PROPOSED-SKILLS.md), 7 new-guardrail proposals (filed to PROPOSED-GUARDRAILS.md) — 17 total excluding process/threshold rows (5 additional, below).
- **By confidence:** 6 HIGH, 9 MEDIUM, 2 LOW.
- **Recurring from previous runs:** 0 (first end-to-end run on this target SDK; 4 preflight-dfly-* runs only produced intake WARN-absent skill entries already resolved in §Auto-filed history).
- **Safety caps respected:** prompt_patches ≤ 10 (drafted 4), existing_skill_patches ≤ 3 (recommended 3), new_skills_per_run = 0 (filed to PROPOSED-SKILLS.md only), new_guardrails_per_run = 0 (filed to PROPOSED-GUARDRAILS.md only), new_agents_per_run = 0.

## Source Evidence Index
- **RP** — retro patterns: RP1 TPRD perf constraint vs dep floor (SYSTEMIC-HIGH, both intake + testing retros); RP2 MVS-forced bumps at impl not design (SYSTEMIC-HIGH, both design + impl retros); RP3 mode selection ad-hoc (MEDIUM, retro-intake); RP4 OTel conformance test authored in testing not impl (MEDIUM, retro-impl + retro-testing); RP5 miniredis HPExpire family gap (LOW-MEDIUM, retro-testing).
- **A** — anomaly flags: A1 design tooling gap (govulncheck/osv-scanner PENDING); A2 dep MVS escalation; A3 §10 constraint floor mismatch; A4 mutation tooling gap; A5 BenchmarkHSet missing.
- **SKD** — skill drift: SKD-005 MODERATE (go-error-handling-patterns SDK-client branch missing).
- **COV** — skill coverage: 3 TRIGGERS-GAP + 2 lateral-transfer manifest gaps.

---

## A. High-Confidence Improvements (auto-applicable by learning-engine)

| # | Category | Target | Description | Source Evidence | Expected Impact |
|---|----------|--------|-------------|-----------------|-----------------|
| 1 | prompt-patch | `sdk-intake-agent` | Append §"TPRD §10 numeric-constraint vs dep-baseline cross-check (I3)" to Learned Patterns. Intake cross-references each TPRD §10 constraint against the pinned dep's known floor and emits CALIBRATION-WARN at H1. | RP1, A3 (SYSTEMIC-HIGH across intake + testing retros) | Converts a Phase-3 H8 waiver into an H1 annotation. Saves ~30 min of unplanned mid-run gate loop per future Dragonfly-class run. |
| 2 | prompt-patch | `sdk-design-lead` | Append §"MVS simulation against real target go.mod at D2" to Learned Patterns. D2 clones target go.mod, runs `go get` for every new dep, enumerates forced bumps, and escalates DEP-POLICY-CONFLICT-AT-DESIGN if any untouchable dep is touched. | RP2, A2 (SYSTEMIC-HIGH across design + impl retros) | Prevents the DEP-BUMP-UNAPPROVED impl halt. Saves ~45 min of H6 reopen + option-decision loop per future multi-dep run. |
| 3 | prompt-patch | `sdk-impl-lead` | Append §"Static OTel conformance test in M6 Docs wave" + §"M1 pre-flight MVS dry-run" to Learned Patterns. Shifts OTel conformance ownership from testing-lead to impl-lead; adds a belt-and-braces MVS check at M1 start. | RP4, RP2 | Stops observability_test.go from leaking into testing phase. Complements G44. |
| 4 | new-guardrail (filed) | G25 Perf-constraint dep-floor check | Intake-phase guardrail that compares TPRD §10 constraints against `baselines/performance-baselines.json`. | RP1, A3 | BLOCKER only when aspirational annotation is absent; otherwise WARN. Same impact class as Item 1. |
| 5 | new-guardrail (filed) | G36 MVS simulation vs real target go.mod | Design-phase guardrail implementing Item 2's check mechanically. | RP2, A2 | BLOCKER on DEP-POLICY-CONFLICT; WARN otherwise. Same impact class as Item 2. |
| 6 | existing-skill-patch (recommended) | `go-error-handling-patterns` v1.0.0 → **v1.0.1 (patch)** (NOT minor) | Patch-level: fix trigger keywords to include "mapErr", "sentinel switch", "precedence order", "errors.Is", "fmt.Errorf %w chain". Minor-level body split (add "SDK-client sentinel-only mode" branch alongside existing "service AppError" branch) is RECOMMENDED but **DEFERRED** until golden-corpus is seeded post-H10, per F5 advisory. | SKD-005, COV TRIGGERS-GAP | Enables trigger activation so mapErr-class work cites this skill in future runs. Avoids the SDK-client vs service-mode divergence being re-discovered. |

### Confidence rationale — HIGH (items 1-6)
- Item 1-2 evidence is SYSTEMIC (each cited across 2 retros + anomaly flags). Effects crossed phase boundaries.
- Items 4-5 are guardrail versions of Items 1-2; same evidence, complementary enforcement mechanism (guardrail = deterministic; prompt patch = heuristic).
- Item 3 is HIGH because the fix is specific (append a named conformance-test authoring step at M6) and the downstream-ownership gap is concrete (270-LOC observability_test.go authored at T9 by testing-lead).
- Item 6 is HIGH only at the patch level. The minor-level body patch carries split-behavior risk and is deferred per F5 "learning-engine patch-level only this run" advisory (golden-corpus empty, no regression gate).

---

## B. Medium-Confidence Improvements (require human review)

| # | Category | Target | Description | Source Evidence | Expected Impact |
|---|----------|--------|-------------|-----------------|-----------------|
| 7 | prompt-patch | `sdk-testing-lead` | Append §"CALIBRATION-WARN classification for dep-floor-unachievable constraints (T5)" + §"miniredis-family gap enumeration in TPRD §11.1" to Learned Patterns. | RP1 mitigation, RP5 | Pre-classifies H8 as CALIBRATION-WARN with Option A recommended; bubbles fake-client gaps back to TPRD. |
| 8 | existing-skill-patch (recommended, DEFERRED to post-H10 corpus) | `go-example-function-patterns` v1.0.0 trigger-keyword expansion | Add "ExampleCache_", "godoc example", "Example_ function", "docs wave" to triggers. | COV TRIGGERS-GAP | Docs-wave work activates the skill instead of being done skill-less. |
| 9 | existing-skill-patch (recommended, DEFERRED to post-H10 corpus) | `tdd-patterns` v1.0.0 trigger-keyword expansion | Add "coverage audit", "test-extension", "test phase". | COV TRIGGERS-GAP (testing phase partial) | Testing phase coverage-audit work activates the skill. |
| 10 | new-guardrail (filed) | G44 OTel static conformance | Impl-phase (M6/M9) guardrail enforcing Item 3. | RP4 | Catches span-cardinality / forbidden-attr / raw-otel-import drift mechanically. |
| 11 | new-guardrail (filed) | G66 Bench constraint calibration | Testing-phase (T5) guardrail reclassifying unachievable constraints as CALIBRATION-WARN. | RP1 mitigation | Pairs with G25; reduces reactive H8 friction. |
| 12 | new-guardrail (filed) | G35 Tool preflight | Pre-intake / H0 guardrail checking govulncheck, osv-scanner, benchstat, staticcheck, mutation-tool on PATH. | A1, A4 | Eliminates mid-run tool-install gates (D2/D3 PENDING verdicts). |
| 13 | new-skill (filed, PROPOSED-SKILLS.md) | `bench-constraint-calibration` | Methodology for cross-referencing TPRD §10 against dep floors. | RP1 | Codifies Item 1's procedure into a reusable skill rather than only embedded in the intake agent. |
| 14 | new-skill (filed, PROPOSED-SKILLS.md) | `mvs-forced-bump-preview` | Methodology for MVS simulation against the real target go.mod. | RP2 | Codifies Item 2's procedure. |
| 15 | new-skill (filed, PROPOSED-SKILLS.md) | `miniredis-limitations-reference` | Enumerates miniredis v2 unsupported commands (HEXPIRE family, Lua subset edges). | RP5 | Bridges the §11.1 coverage gap. |

### Confidence rationale — MEDIUM (items 7-15)
- Item 7 depends on G66 (item 11) being available; classification is a behavior change not a pure additive patch.
- Items 8-9 are trigger-keyword expansions that are inherently low-risk, but F5 advises patch-level only while corpus is empty. If learning-engine wants to apply without a corpus guard, risk is low (keyword string edits) — but human review is the safer path.
- Items 10-12 are proposed guardrails; MEDIUM because they require script authorship + subject-matter review.
- Items 13-15 are new-skill proposals; MEDIUM because skill authorship is non-trivial and each requires SME review.

---

## C. Low-Confidence Improvements (proposals only)

| # | Category | Target | Description | Source Evidence | Expected Impact |
|---|----------|--------|-------------|-----------------|-----------------|
| 16 | new-guardrail (filed) | G67 Integration matrix completeness | Parse TPRD §11.2 matrix; WARN if any cell has zero tests. | RP5 (retro-testing) | Surfaces integration-coverage gaps against TPRD spec. |
| 17 | new-guardrail (filed) | G68 TPRD §11.1 fake-client-exclusion enumeration | Require TPRD §11.1 to list commands not covered by the declared fake-client. | RP5 | Prevents surprise skips during Phase 3. |

### Confidence rationale — LOW (items 16-17)
- Evidence: single occurrence in one phase (testing); not yet a systemic pattern.
- Scope uncertainty: TPRD authoring discipline changes have broader impact than a single run justifies.

---

## D. Process Change Proposals (not auto-applied — human decision)

### D1. Add `--mode {A,B,C}` CLI flag + TPRD §16-override field (LOW-MEDIUM confidence)
- **Current state:** Mode is declared in TPRD §16 only; run-driver overrides via ad-hoc user message (as happened on 2026-04-18 when TPRD-B was overridden to pipeline-A).
- **Proposed state:** `/run-sdk-addition --mode A` flag that ties into a formal `§16-override:` field in the TPRD. Conflict between §16 and override requires explicit H1 annotation.
- **Justification:** Run-manifest `mode_rationale` already captures the override rationale in free-form text. Formalizing prevents silent mode mismatches and creates an audit trail.
- **Source:** retro-intake RP3.

### D2. Move dep-policy declaration to pre-H1 (MEDIUM confidence)
- **Current state:** User directive "do not update deps if not touched by our code ever" was issued at H6, after design completed.
- **Proposed state:** Add a "dep-policy" section to the H1 checklist — solicit dep-untouchable list at the same time as TPRD approval.
- **Justification:** Late policy forced retro-active re-scoping of already-completed design verdicts (H6 revision loop).
- **Source:** retro-design §Surprises.

### D3. `pipeline_version` normalization (LOW confidence)
- **Current state:** `settings.json` declares `pipeline_version: "0.1.0"`; multiple feedback agents stamp `pipeline_version: "0.2.0"` in decision-log entries (e.g. seq 100-109 skill-coverage, seq 110-114 golden-regression). Run-manifest stamps 0.1.0 but skill-drift.md stamps 0.2.0.
- **Proposed state:** Normalize to a single authoritative version string. Either bump settings.json to 0.2.0 (matching plan.md pipeline versioning notes) or normalize downstream agents back to 0.1.0 — pick one per Rule #12 "Every log entry stamps pipeline_version" requires a single source of truth.
- **Justification:** Cross-run trend analysis (knowledge-base/agent-performance.jsonl) becomes ambiguous if version strings drift within a single run.
- **Source:** observed in sdk-dragonfly-s2 decision-log seq drift between 0.1.0 and 0.2.0 stamps.

### D4. Promote 10 draft seed-stub skills (v0.1.0 → v1.0.0) post-H10 (MEDIUM confidence, HUMAN-GATED)
- **Current state:** 8 draft seed-stubs (sdk-config-struct-pattern, sdk-otel-hook-integration, network-error-classification, goroutine-leak-prevention, client-shutdown-lifecycle, client-tls-configuration, connection-pool-tuning, credential-provider-pattern) plus sdk-marker-protocol and sdk-semver-governance are at v0.1.0 draft status. All 10 were invoked and the resulting code passed all reviews.
- **Proposed state:** Human-authored PRs promoting each to v1.0.0 stable, using the dragonfly run's implementation as the reference example in each skill body.
- **Justification:** Dragonfly provides a clean worked reference for all 10 patterns (see skill-drift.md SKD-001 through SKD-019 NONE/MINOR findings). Promotion raises skill maturity from "draft" to "stable" and reduces future agent cognitive load.
- **Source:** skill-drift.md §Summary.
- **Note:** This is HUMAN work per CLAUDE.md Rule #23 — pipeline cannot promote.

### D5. Seed `golden-corpus/dragonfly-v1/` from this run's commit `a4d5d7f` post-H10 merge (MEDIUM confidence, HUMAN-GATED)
- **Current state:** `golden-corpus/` is empty (README-only). Golden regression N/A this run per F5.
- **Proposed state:** After H10 approves merge, capture `golden-corpus/dragonfly-v1/` per README.md layout (tprd.md + gate-answers.yaml + expected/ + metadata.json) from commit `a4d5d7f`. Unlocks future golden-regression gating for skill minor bumps.
- **Justification:** Item 6 (and B items 8-9) are currently blocked from minor-bump application because F5 advises patch-only until corpus is seeded.
- **Source:** feedback/golden-regression.json §seed_candidacy.

---

## E. Threshold Change Proposals (not auto-applied — human decision)

### E1. Bench regression gate — keep at 5%/10%, but add a CALIBRATION-WARN bypass
- **Current value:** `settings.json § regression_gates.bench_hot_path_pct = 5`, `bench_shared_pct = 10`.
- **Proposed value:** Unchanged; add a CALIBRATION-WARN taxonomy (via G66) so `allocs ≤ 3` vs `allocs ≈ 32` is not falsely classified as a 5%-gate violation — it's a calibration miss, not a regression.
- **Data justification:** sdk-dragonfly-s2 had zero real regressions but one calibration miss; merging the two into a single gate produces false positives.
- **Source:** retro-testing RP1.

---

## F. Existing-Skill Body-Patch Recommendations (cap: 3, pick top 3 by confidence)

**Cap respected**: `settings.json § existing_skill_patches_per_run = 3`.

| Rank | Skill | Patch | Version Bump | Confidence | Apply Now? |
|------|-------|-------|--------------|-----------|-----------|
| 1 | `go-error-handling-patterns` | Fix trigger keywords (add "mapErr", "sentinel switch", "precedence order", "errors.Is", "fmt.Errorf %w chain") | **v1.0.0 → v1.0.1 (PATCH)** | HIGH | YES — patch-level only, safe per F5 advisory |
| 1 (deferred) | `go-error-handling-patterns` | Body split: add "SDK-client sentinel-only mode" branch | v1.0.0 → v1.1.0 (MINOR) | MEDIUM | NO — defer until `golden-corpus/dragonfly-v1/` is seeded post-H10 |
| 2 | `go-example-function-patterns` | Trigger expansion ("ExampleCache_", "godoc example", "Example_ function", "docs wave") | **v1.0.0 → v1.0.1 (PATCH)** | MEDIUM | YES — patch-level only |
| 3 | `tdd-patterns` | Trigger expansion ("coverage audit", "test-extension", "test phase") | **v1.0.0 → v1.0.1 (PATCH)** | LOW | PREFERRED-NO — trigger is broader than evidence warrants; defer |

**learning-engine directive**: apply ranks 1 (patch-level only, NOT minor) and 2. Do NOT apply rank 3 this run (LOW confidence). Do NOT apply the deferred minor bump on rank 1 until corpus seeds.

---

## G. Communication & Failure Pattern Analysis

### Communication Gaps
Per decision-log mining: only 1 formal inter-agent communication (seq 107, sdk-skill-coverage-reporter → improvement-planner) and 1 formal ESCALATION (impl-phase DEP-BUMP-UNAPPROVED, seq 38). Design phase had 0 formal communications, which matches retro-design's "no coordination issues within design" observation. No gap pattern to record this run.

### Failure Recovery Gaps
| Agent | Failure Type | Recovery Method | Occurrences | Suggested Fix |
|-------|-------------|-----------------|-------------|---------------|
| sdk-impl-lead | dep-policy-violation (MVS-forced bump of untouched deps) | HITL escalation → Option A approved | 1 | Item 2 + Item 5 prevent recurrence. |
| sdk-testing-lead | soft-gate fail (allocs_per_GET vs dep floor) | H8 Option A waiver | 1 | Items 1 + 4 + 7 + 11 prevent recurrence. |
| sdk-testing-lead | T10 skip (mutation tool absent) | Skip + Phase-4 backlog | 1 | Item 12 (G35 tool preflight) prevents recurrence. |

### Agents with High Refactor Ratio (>30%)
| Agent | Output Files | Refactors | Ratio | Primary Trigger | Suggested Fix |
|-------|-------------|-----------|-------|----------------|---------------|
| sdk-design-lead | 8 artifacts | 2 amendments | 25% | review-finding (D3 F-D3, S-9) | No fix needed — threshold not crossed; 1-iteration review-fix loop is healthy. |

All other agents are well below 30% refactor ratio. No prompt-improvement needed on this axis.

---

## H. Recurring Improvements (not addressed from previous runs)

Previous `preflight-dfly-*` runs only reached intake WARN-absent skill entries (all 4 runs identically filed the same 8 missing skills). This run inherits those as proposals, already filed to `docs/PROPOSED-SKILLS.md`. No other recurrence pattern exists (this is the first end-to-end completed run on this target SDK).

---

## I. Evolution Artifacts Written

### Prompt patches (4 files, ≤ 10 cap)
- `evolution/prompt-patches/sdk-intake-agent.md` — TPRD §10 cross-check + mode-override formalization (HIGH).
- `evolution/prompt-patches/sdk-design-lead.md` — D2 MVS simulation + convention-deviation recording (HIGH).
- `evolution/prompt-patches/sdk-impl-lead.md` — Static OTel conformance test in M6 + M1 MVS pre-flight (HIGH).
- `evolution/prompt-patches/sdk-testing-lead.md` — CALIBRATION-WARN classification + miniredis-family gap enumeration (MEDIUM).

### Existing-skill body-patch recommendations (3 items, ≤ 3 cap — learning-engine F7 applies)
- `go-error-handling-patterns` — patch-level trigger keywords (HIGH).
- `go-example-function-patterns` — patch-level trigger keywords (MEDIUM).
- `tdd-patterns` — patch-level trigger keywords (LOW — recommend DEFER).

### New-skill proposals (3 entries, `new_skills_per_run = 0` → PROPOSED-SKILLS.md only)
- `miniredis-limitations-reference` — MEDIUM.
- `bench-constraint-calibration` — MEDIUM.
- `mvs-forced-bump-preview` — MEDIUM.

### New-guardrail proposals (7 entries, `new_guardrails_per_run = 0` → PROPOSED-GUARDRAILS.md only)
- G25 Perf-constraint dep-floor check — HIGH.
- G35 Tool preflight — MEDIUM.
- G36 MVS simulation vs real target go.mod — HIGH.
- G44 OTel static conformance — MEDIUM.
- G66 Bench constraint calibration — MEDIUM.
- G67 Integration matrix completeness — LOW.
- G68 TPRD §11.1 fake-client-exclusion enumeration — LOW.

### Evolution report
- `evolution/evolution-reports/sdk-dragonfly-s2.md` — summary of applied + drafted improvements (for baseline-manager and H10 consumers).

### Context summary
- `runs/sdk-dragonfly-s2/feedback/context/improvement-planner-summary.md` — ≤ 200 lines, for downstream F7 learning-engine.

---

## J. Directive to learning-engine (F7)

1. **No safety halts triggered this run.**
   - Golden regression: N/A (empty corpus); learning-engine is NOT blocked by F5 advisory.
   - Zero defects; zero root-cause backpatches; skill-drift MAJOR count = 0.
   - Prompt-patch cap 10: 4 drafted (safe).
   - Existing-skill-patch cap 3: 3 recommended (safe — top 3 by confidence).
   - New-skill cap 0: 3 proposals filed (no runtime create).
   - New-guardrail cap 0: 7 proposals filed (no runtime create).

2. **Apply these patches now (this run):**
   - Prompt patches A1, A2, A3 (sdk-intake-agent, sdk-design-lead, sdk-impl-lead — all HIGH confidence).
   - Optional: Prompt patch A7 (sdk-testing-lead, MEDIUM) — safe to apply; depends on G66 being filed (it is).
   - Existing-skill PATCH-level bumps for `go-error-handling-patterns` and `go-example-function-patterns` (trigger-keyword additions only; v1.0.0 → v1.0.1).

3. **Do NOT apply this run:**
   - Minor-version bump of `go-error-handling-patterns` to v1.1.0 (SDK-client mode branch). Reason: golden-corpus empty; F5 advises patch-only.
   - Trigger expansion for `tdd-patterns` (LOW confidence; defer).
   - Any new guardrail or new skill (runtime caps are 0 by policy).

4. **Handoff for human action post-H10:**
   - Promote 10 draft seed-stub skills v0.1.0 → v1.0.0 (Process D4).
   - Seed `golden-corpus/dragonfly-v1/` from commit `a4d5d7f` (Process D5).
   - Author 7 proposed guardrails and 3 proposed skills as separate PRs.

---

<!-- End of plan. Line count ≈ 290 / 500 cap. -->
