<!-- Generated: 2026-04-18T15:20:00Z | Run: sdk-dragonfly-s2 | Agent: improvement-planner (Wave F6) -->
# Evolution Report — sdk-dragonfly-s2

## Run Outcome
- **Pipeline quality score:** 0.95
- **Defects:** 0
- **MAJOR skill drift:** 0
- **Root-cause backpatches:** 0 (F3 skipped — no defects)
- **Anomalies:** 5 (A1-A5, all MEDIUM or LOW)
- **HITL gates approved:** 5 (H1, H5, H6-conditional, H7, H8-waiver, H9). H10 still pending.

## F6 Improvement-Planner Output

### Drafted (for F7 learning-engine decision)
| Category | Count | Files |
|----------|------:|-------|
| Prompt patches | 4 | `evolution/prompt-patches/sdk-{intake-agent,design-lead,impl-lead,testing-lead}.md` |
| Existing-skill patch recommendations (cap 3) | 3 | Embedded in improvement-plan §F |
| Process change proposals | 5 | Embedded in improvement-plan §D |
| Threshold change proposals | 1 | Embedded in improvement-plan §E |

### Filed to human-review backlog
| Category | Count | Destination |
|----------|------:|------------|
| New-skill proposals (cap 0 → filed) | 3 | `docs/PROPOSED-SKILLS.md` §F6 |
| New-guardrail proposals (cap 0 → filed) | 7 | `docs/PROPOSED-GUARDRAILS.md` |

## Applied This Run

### F7 Learning-Engine — 2026-04-18T15:26:45Z

**Safety-cap consumption:** 4/10 prompt patches, 2/3 existing-skill patches, 0/0 new-skills, 0/0 new-guardrails, 0/0 new-agents.
**Safety halts:** None. Golden-corpus empty (advisory only — F5 N/A verdict does not halt F7). No MANUAL markers exist this run.
**Inter-service HTTP/gRPC scan on all patches:** CLEAN.

#### Prompt Patches APPLIED (4)

| # | Patch-ID | Target | Confidence | Status | Outcome |
|---|----------|--------|-----------|--------|---------|
| 1 | PP-01-intake | `.claude/agents/sdk-intake-agent.md` | HIGH | APPLIED | 2 Learned Patterns appended (TPRD §10 cross-check I3 + mode override formalization I1). |
| 2 | PP-02-design | `.claude/agents/sdk-design-lead.md` | HIGH | APPLIED | 2 Learned Patterns appended (MVS simulation at D2 + cross-SDK convention-deviation recording). |
| 3 | PP-03-impl | `.claude/agents/sdk-impl-lead.md` | HIGH | APPLIED | 2 Learned Patterns appended (Static OTel conformance test in M6 shift-left + M1 pre-flight MVS dry-run). |
| 4 | PP-04-testing | `.claude/agents/sdk-testing-lead.md` | MEDIUM | APPLIED | 2 Learned Patterns appended (CALIBRATION-WARN classification T5 + miniredis-family gap enumeration). Advisory until G66 guardrail is human-authored. |

All 4 patches are append-only under a `## Learned Patterns` heading with provenance comments (`<!-- Applied by learning-engine (F7) on run sdk-dragonfly-s2 | pipeline 0.2.0 | patch-id PP-NN-* -->`). Existing agent bodies were not modified.

#### Existing-Skill Patches APPLIED (2 patch-level bumps)

| # | Patch-ID | Skill | Prior Version | New Version | Bump Type | Change |
|---|----------|-------|--------------|------------|-----------|--------|
| 1 | SP-01-error-handling-triggers | `go-error-handling-patterns` | 1.0.0 | **1.0.1** | patch | Added `trigger-keywords` frontmatter: `mapErr`, `sentinel switch`, `precedence order`, `errors.Is`, `fmt.Errorf %w chain`. No body change. Evolution-log appended. |
| 2 | SP-02-example-function-triggers | `go-example-function-patterns` | 0.1.0 (draft) | **0.1.1 (draft)** | patch | Added `trigger-keywords` frontmatter: `ExampleCache_`, `godoc example`, `Example_ function`, `docs wave`. No body change; draft status preserved. Evolution-log appended. Plan named this v1.0.0→v1.0.1 but actual frontmatter was v0.1.0 — patch-level semantics preserved (no minor/major bump per F7 directive). |

Each skill now carries an `evolution-log.md` entry stamped with run_id, change-summary, devil verdict (`auto-accept-patch-level`), and pipeline version.

#### DEFERRED (2)

| # | Patch-ID | Target | Confidence | Reason | Re-evaluate When |
|---|----------|--------|-----------|--------|------------------|
| 1 | DEFERRED-body-split-error-handling | `go-error-handling-patterns` (v1.0.1 → v1.1.0 minor) | MEDIUM | Golden-corpus empty; F5 advises patch-only this run (no regression gate). | After human seeds `golden-corpus/dragonfly-v1/` from commit `a4d5d7f` post-H10. |
| 2 | DEFERRED-tdd-patterns-triggers | `.claude/skills/tdd-patterns/SKILL.md` trigger expansion | LOW | Scope broader than single-phase evidence warrants (improvement-plan §F rank 3). | If pattern recurs in future runs. |

#### NOT-APPLIED / REJECTED (0)

None. No proposed patch introduced HTTP/gRPC inter-service comm; no MANUAL-marker violations; all HIGH-confidence items fit in caps. The 3 new-skill proposals (§F6 of improvement-plan) and 7 new-guardrail proposals remain in `docs/PROPOSED-SKILLS.md` / `docs/PROPOSED-GUARDRAILS.md` for human PR authorship — runtime caps are 0 per CLAUDE.md Rule #23.

#### Cap Consumption Summary

| Cap | Limit | Used | Remaining | Status |
|-----|-------|------|----------|--------|
| prompt_patches_per_run | 10 | 4 | 6 | OK |
| existing_skill_patches_per_run | 3 | 2 | 1 | OK |
| new_skills_per_run | 0 | 0 | 0 | OK (3 filed to PROPOSED-SKILLS.md) |
| new_guardrails_per_run | 0 | 0 | 0 | OK (7 filed to PROPOSED-GUARDRAILS.md) |
| new_agents_per_run | 0 | 0 | 0 | OK |

#### Artifacts Written by F7

- `.claude/agents/sdk-intake-agent.md` — appended `## Learned Patterns` section (2 subsections)
- `.claude/agents/sdk-design-lead.md` — appended `## Learned Patterns` section (2 subsections)
- `.claude/agents/sdk-impl-lead.md` — appended `## Learned Patterns` section (2 subsections)
- `.claude/agents/sdk-testing-lead.md` — appended `## Learned Patterns` section (2 subsections)
- `.claude/skills/go-error-handling-patterns/SKILL.md` — frontmatter `version: 1.0.1` + `trigger-keywords` field
- `.claude/skills/go-error-handling-patterns/evolution-log.md` — v1.0.1 entry
- `.claude/skills/go-example-function-patterns/SKILL.md` — frontmatter `version: 0.1.1` + `trigger-keywords` field
- `.claude/skills/go-example-function-patterns/evolution-log.md` — v0.1.1 entry
- `evolution/knowledge-base/prompt-evolution-log.jsonl` — NEW file, 8 entries (6 applied + 2 deferred)
- `runs/sdk-dragonfly-s2/feedback/context/learning-engine-summary.md` — F7 context summary
- `runs/sdk-dragonfly-s2/decision-log.jsonl` — 11 entries (seq 144-154)

## Recommended Applications (F7 directives)

### Apply NOW (this run)
1. Prompt patches A1-A3 (HIGH confidence): sdk-intake-agent, sdk-design-lead, sdk-impl-lead.
2. Optional: Prompt patch A4 (MEDIUM): sdk-testing-lead.
3. Existing-skill PATCH bumps (patch level only — v1.0.0 → v1.0.1):
   - `go-error-handling-patterns` — trigger keywords only.
   - `go-example-function-patterns` — trigger keywords only.

### Do NOT apply this run
- Minor-version bump of `go-error-handling-patterns` (body split): wait for `golden-corpus/dragonfly-v1/` seed post-H10.
- `tdd-patterns` trigger expansion (LOW confidence).
- Any new guardrail or new skill (runtime caps enforce HUMAN-only creation).

## Baseline-Manager Handoff
- `baselines/performance-baselines.json` already updated by F1 with dragonfly bench baseline (see metrics-summary §Benchmark Baseline).
- No additional baseline write needed by F7 beyond prompt-evolution-log updates.

## Human Post-H10 Actions (NOT pipeline work)
1. **Promote 10 draft seed-stub skills** v0.1.0 → v1.0.0 via PRs (see improvement-plan §D4).
2. **Seed `golden-corpus/dragonfly-v1/`** from commit `a4d5d7f` (see improvement-plan §D5). This unlocks future minor-version skill bumps.
3. **Author 7 proposed guardrails** as scripts under `scripts/guardrails/` (see `docs/PROPOSED-GUARDRAILS.md`).
4. **Author 3 new proposed skills** (bench-constraint-calibration, mvs-forced-bump-preview, miniredis-limitations-reference) under `.claude/skills/` (see `docs/PROPOSED-SKILLS.md`).
5. **Author 2 new skills from the intake WARN-absent backlog** that are highest priority:
   - `sentinel-error-model-mapping` (highest reuse).
   - `pubsub-lifecycle` (subtle recurring caller-owns-Close pattern).

## Safety Caps Compliance
| Cap | Limit | Used | Status |
|-----|-------|------|--------|
| prompt_patches_per_run | 10 | 4 | OK |
| existing_skill_patches_per_run | 3 | 3 | OK (at cap) |
| new_skills_per_run | 0 | 0 (3 filed to PROPOSED-*) | OK |
| new_guardrails_per_run | 0 | 0 (7 filed to PROPOSED-*) | OK |
| new_agents_per_run | 0 | 0 | OK |
| Total improvements per plan | 20 | 17 | OK |
| Plan line count | 500 | ~290 | OK |

## Trend (vs prior runs)
This is the first end-to-end completed run. Four prior `preflight-dfly-*` runs reached only intake WARN-absent reporting; they did not exercise design/impl/testing. No regression or improvement trend can be computed.

## Signals to Next Run
- If sdk-dragonfly-s2 merges at H10 and `dragonfly-v1` becomes the canonical golden fixture, the next end-to-end run MUST pass golden-regression against this run's outputs (tolerance bands per corpus README).
- The proposed prompt-patch additions to the four leads should take effect on the next run after F7 applies them — expect shift-left catches of RP1/RP2 patterns at intake and design rather than at impl/testing.
