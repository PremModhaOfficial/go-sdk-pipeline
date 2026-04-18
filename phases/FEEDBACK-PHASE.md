# Phase 4: Feedback & Self-Learning

## Purpose

Close the loop. Collect telemetry, trace defects, detect drift, regress against golden corpus, apply safe improvements. Every run leaves the pipeline smarter.

**Core sequence ported verbatim from archive**:
`metrics-collector → phase-retrospector → root-cause-tracer → improvement-planner → learning-engine → baseline-manager`

New SDK agents plug in as INPUTS to `improvement-planner` — they don't replace the ported chain.

## Input

- `runs/<run-id>/decision-log.jsonl` (all 8 entry types)
- `runs/<run-id>/testing/*`
- `runs/<run-id>/impl/*`
- `runs/<run-id>/design/*`
- `runs/<run-id>/intake/*`
- `baselines/*.json` (previous)
- `golden-corpus/*` (canonical fixtures)
- `evolution/knowledge-base/*.jsonl`

## Waves

### Wave F1 — Metrics Collection
**Agent**: `metrics-collector`
- Computes per-agent `quality_score` (formula in CLAUDE.md)
- Per-phase metrics (duration, tokens, rework, devil-block-rate, skill-coverage-pct)
- Per-run metrics (pipeline_quality, coverage, bench-delta, vuln-count, leak-count, flake-rate, determinism-diff)
- Output: `runs/<run-id>/feedback/metrics.json` + `metrics-summary.md`

### Wave F2 — Phase Retrospectives
**Agent**: `phase-retrospector`
- For each phase (intake, design, impl, testing), produce `runs/<run-id>/feedback/retro-<phase>.md`
- What went well / recurring patterns / surprises / coordination issues
- Cross-phase pattern detection (if this is run ≥2)

### Wave F3 — Root-Cause Tracing (if defects)
**Agent**: `root-cause-tracer`
- For each HIGH/CRITICAL defect from testing phase, trace backward through phases
- Where was the defect introduced? Which phase should have caught it?
- Output: `runs/<run-id>/feedback/root-causes.md` + backpatch-log entries

### Wave F4 — SDK-Specific Drift + Coverage (NEW)
Parallel:

| Agent | Role |
|-------|------|
| `sdk-skill-drift-detector` | Compare what each invoked skill PRESCRIBED vs. what the code actually DOES. Example: `sdk-config-struct-pattern` says Config is immutable — code has exported mutable fields. Output: `feedback/skill-drift.md`. |
| `sdk-skill-coverage-reporter` | Which skills got invoked per phase? Which were expected-but-unused (based on TPRD tech signals)? Output: `feedback/skill-coverage.md`. |

### Wave F5 — Golden Regression
**Agent**: `sdk-golden-regression-runner`
- Re-run N most recent canonical additions from `golden-corpus/` against CURRENT agent + skill set
- Compare outputs with stored-golden (tolerance: pipeline-owned regions only; marker-preserved regions skipped)
- Output: `feedback/golden-regression.json` — PASS/FAIL per fixture
- If any FAIL: learning-engine HALTS auto-patch application; user must triage

### Wave F6 — Improvement Planning
**Agent**: `improvement-planner`
Reads: metrics, retros, root-causes, drift, coverage, golden-regression, knowledge-base
Outputs categorized improvements in `evolution/improvement-plan-<run-id>.md`:
- Prompt-patch candidates → `evolution/prompt-patches/<agent>.md` (draft)
- Existing-skill body-patch candidates → marked for `learning-engine` (auto-apply with minor bump + golden-regression gate)
- **New-skill proposals** → appended to `docs/PROPOSED-SKILLS.md` with `status: proposed`, source `run-id` (human-authored only; never drafted by pipeline)
- **New-guardrail proposals** → appended to `docs/PROPOSED-GUARDRAILS.md` (human-authored only)
- Process / threshold proposals (plan only, not auto-applied)
Confidence levels: high / medium / low.

### Wave F7 — Learning Engine (auto-apply safe; draft risky)
**Agent**: `learning-engine`
Safety gates (preserved from archive, narrowed post-Phase-1-removal):
- confidence=high required for auto-apply
- 2+ run recurrence (except CRITICAL)
- never deletes (append-only; `status: deprecated`)
- resets baselines every 5 runs
- caps per run: ≤10 prompt patches, ≤3 **existing-skill** body patches, **0 new skills / 0 new guardrails / 0 new agents** (all human-authored via PR)

**NEW delta** — halt auto-apply if Wave F5 golden regression FAILED. Never creates new `SKILL.md` files — only patches bodies of existing skills with a minor version bump.

Actions:
- Apply high-confidence prompt patches → `evolution/prompt-patches/<agent>.md` (append)
- Apply existing-skill body patches → bump minor version, append to `evolution-log.md`, re-run golden-corpus
- File new-skill proposals → `docs/PROPOSED-SKILLS.md` (status: proposed)
- File new-guardrail proposals → `docs/PROPOSED-GUARDRAILS.md` (status: proposed)
- Log applied patches in `evolution/knowledge-base/prompt-evolution-log.jsonl`

### Wave F8 — Baseline Manager
**Agent**: `baseline-manager`
- First-run: create baselines
- Subsequent: raise if improved by >10%, keep if regressed, reset every 5 runs
- Update `baselines/{quality,coverage,performance,skill-health}.json`
- Output: `baselines/regression-report-<run-id>.md`, `baseline-history.jsonl` append

### Wave F9 — HITL Gate H10 (merge rec)
**H10**: Final merge recommendation with run-summary. Major skill bumps and new-skill proposals are always human PR decisions (no runtime gate needed — pipeline cannot author them).

## Exit artifacts

- `runs/<run-id>/feedback/metrics.json`
- `runs/<run-id>/feedback/retro-<phase>.md` × 5
- `runs/<run-id>/feedback/root-causes.md` (if defects)
- `runs/<run-id>/feedback/skill-drift.md`
- `runs/<run-id>/feedback/skill-coverage.md`
- `runs/<run-id>/feedback/golden-regression.json`
- `evolution/improvement-plan-<run-id>.md`
- `evolution/evolution-reports/<run-id>.md` — summary of applied + drafted changes
- Updated `baselines/*.json`
- Updated `evolution/knowledge-base/*.jsonl`
- `runs/<run-id>/run-summary.md` — top-level roll-up for user

## Guardrails (exit gate)

G80 (evolution-report written), G81 (baselines updated or rationale), G82 (golden regression PASS), G83 (every patch logged in skill evolution-log.md with devil verdict), G84 (per-run safety caps respected).

## Metrics

- `learning_patches_applied`
- `learning_patches_drafted`
- `skills_evolved`
- `golden_regression_rate` (target 1.0)
- `baseline_improvements` / `baseline_regressions_caught`

## Pipeline-maturity signals

Longitudinal (across runs):
- `existing_skill_patch_accept_rate` (target ≥0.8 after 5 runs)
- `skill_stability` (patches per skill per run; target <0.3 after 10 runs)
- `manifest_miss_rate` (target 0 after library stabilizes)
- `mean_time_to_green` (trending down)
- `user_intervention_rate` (trending down)

## Typical durations

- First few runs: 30–60 min (drafts, baseline creation, many learnings)
- Mature runs: 10–20 min (stable, small deltas)
