# Phase 0: Intake

## Purpose

Turn the human-authored TPRD (detailed, including `§Skills-Manifest` and `§Guardrails-Manifest`) into a canonical, validated spec. Validate that every required skill + guardrail exists on disk **before** any design work starts. Ask clarifying questions only for unresolved ambiguities in functional/NFR sections.

This pipeline is **NFR-driven**: every run produces an API + tests that hits numeric targets declared in TPRD §5 NFR and §Benchmarks. Intake is the single pre-design contract check.

## Trigger rule

Always runs — there is no bootstrap phase. A complete `--spec <file>` may reduce clarifications to zero, but manifest validation (I2 + I3) always executes.

## Input

- `--spec <path>` or NL request → seeds `runs/<run-id>/tprd.md`
- `$SDK_TARGET_DIR` tree (read-only)
- `.claude/skills/skill-index.json` (static, human-curated)
- `scripts/guardrails/` directory listing (for guardrail existence check)

## Waves

### Wave I1 — Ingest
**Agent**: `sdk-intake-agent`
- NL input: drafts TPRD skeleton (14 sections + Skills-Manifest + Guardrails-Manifest), infers what it can
- `--spec`: loads file, flags missing sections / `[ambiguous]` / `TBD` / `?`
- Output: `runs/<run-id>/tprd.md`

### Wave I2 — §Skills-Manifest Validation (NEW)
**Agent**: `sdk-intake-agent`
**Severity**: WARN on miss — pipeline continues; misses filed to `docs/PROPOSED-SKILLS.md`
**Purpose**: Every skill declared in TPRD §Skills-Manifest should exist in `.claude/skills/skill-index.json` at version ≥ required. Missing / under-versioned skills produce a warning but NEVER halt the run — skill authorship is a human PR concern, not a pipeline blocker.

**Check**:
```
for entry in tprd.skills_manifest:
    if entry.name not in skill_index.skills: -> WARN (file to PROPOSED-SKILLS.md)
    if skill_index[entry.name].version < entry.min_version: -> WARN (file to PROPOSED-SKILLS.md)
```

**Output**: `runs/<run-id>/intake/skills-manifest-check.md`
- PASS: all present at required version → proceed
- WARN: list of missing / under-versioned skills → pipeline continues
  - Auto-files each miss to `docs/PROPOSED-SKILLS.md` with `status: proposed`, source = `run-id`
  - Human may author skill PR at leisure; run is not blocked

**No auto-synthesis.** Agent never writes `SKILL.md` bodies.

### Wave I3 — §Guardrails-Manifest Validation (NEW)
**Agent**: `sdk-intake-agent`
**Severity**: BLOCKER on miss — pipeline halts (exit 6)
**Purpose**: Every guardrail declared in TPRD §Guardrails-Manifest must have an executable script in `scripts/guardrails/`.

**Check**:
```
for g_id in tprd.guardrails_manifest:
    if not scripts/guardrails/<g_id>.sh exists and +x: -> BLOCKER
```

**Output**: `runs/<run-id>/intake/guardrails-manifest-check.md`
- PASS: proceed
- FAIL: list missing scripts → halt; file under `docs/PROPOSED-GUARDRAILS.md` for human authoring

### Wave I4 — Clarification Loop
**Agent**: `sdk-intake-agent` (iterative)

Only runs when I1 found residual ambiguity after the TPRD parse. For each ambiguous field:
- Emit `AskUserQuestion` with 2-4 options
- Record answer as `decision` entry in decision log
- Max **5** questions (down from 7 — the TPRD is expected to be detailed)
- Exceeding 5 = `ESCALATION: TPRD underspecified` + halt

Typical triggers (rare with detailed TPRD): package placement fine-tuning, open ambiguity flags (`[AMBIGUITY] OQ-*`) from TPRD §14.

### Wave I5 — Mode Detection
Based on §1 Request Type, set `mode: A|B|C` in manifest. Mode B and C gate Phase 0.5.

### Wave I6 — Completeness Check
**Agent**: `sdk-intake-agent`
Runs `spec-completeness-guardrail` (G20 + G21):
- All 14 TPRD sections non-empty
- §Skills-Manifest and §Guardrails-Manifest non-empty (NEW)
- `[ambiguous]` / `TBD` / `?` count = 0
- §Non-Goals populated

FAIL → back to I4; else → I7.

### Wave I7 — HITL Gate H1 (TPRD Acceptance)
**Lead**: `sdk-intake-agent`
**Artifact**: canonical `runs/<run-id>/tprd.md` + manifest-check reports
**Options**: Approve / Revise / Cancel
**Default**: Revise (timeout 24h)
**Bypass**: `--auto-approve-tprd` (CI only; still requires I2 + I3 PASS)

## Exit artifacts

- `runs/<run-id>/tprd.md` — canonical, all sections + both manifests non-empty
- `runs/<run-id>/intake/skills-manifest-check.md` — PASS or WARN verdict (never halts pipeline; misses filed to `docs/PROPOSED-SKILLS.md`)
- `runs/<run-id>/intake/guardrails-manifest-check.md` — PASS verdict (FAIL halts pipeline with exit 6)
- `runs/<run-id>/intake/clarifications.jsonl` — every Q + A (may be empty for detailed TPRDs)
- `runs/<run-id>/intake/mode.json` — `{ "mode": "A|B|C", "target_package": "...", "new_exports": [...] }`
- `runs/<run-id>/state/run-manifest.json` updated with intake completion

## Metrics

- `user_clarifications_asked` (target 0 with detailed TPRD; >3 = spec-quality issue → `improvement-planner`)
- `intake_duration_sec`
- `manifest_misses_skills`, `manifest_misses_guardrails` (both target 0)

## Guardrails

G20 (all 14 sections + 2 manifests non-empty), G21 (§Non-Goals populated), G22 (clarifications ≤3 — info only), **G23 (NEW: §Skills-Manifest validation, WARN)**, **G24 (NEW: §Guardrails-Manifest validation, BLOCKER)**.

## Example flows

### Flow 1: Detailed TPRD submitted (expected path)
Input: `--spec runs/nats-v1-tprd.md` (complete, with both manifests)
- I1: load TPRD; 14 sections + 2 manifests present
- I2: all 12 required skills present at version ≥ declared → PASS
- I3: all 9 guardrails scripts present → PASS
- I4: 0 clarifications (TPRD is detailed)
- I6: completeness PASS
- I7: H1 approve
- Duration: <20s

### Flow 2: TPRD missing a required skill (non-blocking)
Input: `--spec runs/redis-streams-tprd.md` (declares `redis-pipeline-tx-patterns` v1.0.0)
- I1: load
- I2: `redis-pipeline-tx-patterns` not in `skill-index.json` → WARN (non-blocking)
  - Auto-files entry to `docs/PROPOSED-SKILLS.md` with status `proposed` + reason
  - `runs/<run-id>/intake/skills-manifest-check.md` records `Status: WARN`
- I3: guardrails all present → PASS
- Pipeline proceeds through design / impl / testing / feedback
- Human may author skill + PR at leisure; future runs pick it up automatically. No re-run required for the current run to complete.

### Flow 3: NL one-liner (degenerate path, discouraged)
Input: `"add S3 client"` (no TPRD)
- I1: drafts TPRD skeleton; flags all sections as `TBD`
- I4: asks ~5 clarifying questions (placement, SDK version, encryption, retry, bench)
- Completeness FAIL → return to I4 up to cap
- If cap exceeded: halt with `ESCALATION: TPRD underspecified`
- **Recommended**: author detailed TPRD off-pipeline and re-submit via `--spec`.
