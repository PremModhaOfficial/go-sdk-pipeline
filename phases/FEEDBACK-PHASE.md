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
- `runs/<run-id>/bootstrap/*`
- `baselines/*.json` (previous)
- `golden-corpus/*` (canonical fixtures)
- `evolution/knowledge-base/*.jsonl`

## Waves

### Wave F1 — Metrics Collection
**Agent**: `metrics-collector` (ported with delta)
- Computes per-agent `quality_score` (formula in CLAUDE.md)
- Per-phase metrics (duration, tokens, rework, devil-block-rate, skill-coverage-pct)
- Per-run metrics (pipeline_quality, coverage, bench-delta, vuln-count, leak-count, flake-rate, determinism-diff)
- Output: `runs/<run-id>/feedback/metrics.json` + `metrics-summary.md`

### Wave F2 — Phase Retrospectives
**Agent**: `phase-retrospector` (ported)
- For each phase (bootstrap, intake, design, impl, testing), produce `runs/<run-id>/feedback/retro-<phase>.md`
- What went well / recurring patterns / surprises / coordination issues
- Cross-phase pattern detection (if this is run ≥2)

### Wave F3 — Root-Cause Tracing (if defects)
**Agent**: `root-cause-tracer` (ported)
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
**Agent**: `improvement-planner` (ported with delta)
Reads: metrics, retros, root-causes, drift, coverage, golden-regression, knowledge-base
Outputs categorized improvements in `evolution/improvement-plan-<run-id>.md`:
- Prompt-patch candidates → `evolution/prompt-patches/<agent>.md` (draft)
- Skill candidates → `evolution/skill-candidates/<name>.json` (next-run bootstrap consumer)
- Guardrail candidates → `evolution/guardrail-candidates/<name>.json`
- Process / threshold proposals (plan only, not auto-applied)
Confidence levels: high / medium / low.

### Wave F7 — Learning Engine (auto-apply safe; draft risky)
**Agent**: `learning-engine` (ported with delta)
Safety gates (preserved from archive):
- confidence=high required for auto-apply
- 2+ run recurrence (except CRITICAL)
- never deletes (append-only; `status: deprecated`)
- resets baselines every 5 runs
- caps per run: ≤10 prompt patches, ≤3 new skills (non-bootstrap), ≤2 new guardrails, ≤2 new agents

**NEW delta** — halt auto-apply if Wave F5 golden regression FAILED.

Actions:
- Apply high-confidence prompt patches → `evolution/prompt-patches/<agent>.md` (append, bump skill version if affects skill)
- Draft risky patches for user review at H9
- Log applied patches in `evolution/knowledge-base/prompt-evolution-log.jsonl`

### Wave F8 — Baseline Manager
**Agent**: `baseline-manager` (ported with delta)
- First-run: create baselines
- Subsequent: raise if improved by >10%, keep if regressed, reset every 5 runs
- Update `baselines/{quality,coverage,performance,skill-health}.json`
- Output: `baselines/regression-report-<run-id>.md`, `baseline-history.jsonl` append

### Wave F9 — HITL Gate H9 (major skill bumps) + H10 (merge rec)
**H9**: If Wave F6 proposed a MAJOR skill version bump → user approves + golden-corpus re-run
**H10**: Final merge recommendation with run-summary

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
- `bootstrap_success_rate` (target ≥0.8 after 5 runs)
- `skill_stability` (patches per skill per run; target <0.3 after 10 runs)
- `mean_time_to_green` (trending down)
- `user_intervention_rate` (trending down)

## Typical durations

- First few runs: 30–60 min (drafts, baseline creation, many learnings)
- Mature runs: 10–20 min (stable, small deltas)
