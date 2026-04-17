# Phase 0: Intake

## Purpose

Turn user input (NL request or partial TPRD) into a canonical, validated TPRD. Ask clarifying questions for every ambiguous field. Emit artifacts downstream phases consume.

## Trigger rule

Always runs unless `--spec <file>` points to a TPRD that passes `spec-completeness-guardrail` on first parse.

## Input

- Raw NL string OR `runs/<run-id>/tprd.md` (partial)
- Target SDK tree summary (read-only)
- Skill library (for tech-signal → skill mapping)

## Waves

### Wave I1 — Ingest
**Agent**: `sdk-intake-agent`
- If NL: create TPRD skeleton, fill what's inferable (e.g., "add S3 client" → §1 Request Type = New package; §2 Target package = `s3/` under `motadatagosdk/` or similar)
- If partial TPRD: copy in, identify missing/`[ambiguous]`/`TBD`/`?` fields

### Wave I2 — Clarification Loop
**Agent**: `sdk-intake-agent` (same; iterative)
For each ambiguous field:
- Emit `AskUserQuestion` with 2-4 options (each with description; add "Other" implicit)
- Record answer as `decision` entry in decision log with `alternatives` = option list, `choice` = user answer
- Max 7 questions total per session; exceeding = `ESCALATION: TPRD underspecified` + halt

Typical ambiguity triggers: package placement, config field types, dependency names, backend version, retry policy, observability metrics list, test backend (testcontainers image), semver bump intent (Mode C).

### Wave I3 — Mode Detection
Based on §1 Request Type, set `mode: A|B|C` in manifest. Mode B and C gate Phase 0.5.

### Wave I4 — Completeness Check
**Agent**: `sdk-intake-agent`
Runs `spec-completeness-guardrail` (G20 + G21):
- All 14 TPRD sections non-empty
- `[ambiguous]` / `TBD` / `?` count = 0
- §Non-Goals populated (scope discipline)
If FAIL: emit question + retry; else proceed.

### Wave I5 — HITL Gate H1 (TPRD Acceptance)
**Lead**: `sdk-intake-agent`
**Artifact**: canonical `runs/<run-id>/tprd.md`
**Options**: Approve / Revise / Cancel
**Default**: Revise (timeout 24h)
**Bypass**: `--auto-approve-tprd` (CI only)

## Exit artifacts

- `runs/<run-id>/tprd.md` — canonical, all sections non-empty
- `runs/<run-id>/intake/clarifications.jsonl` — every question + answer
- `runs/<run-id>/intake/mode.json` — `{ "mode": "A|B|C", "target_package": "...", "new_exports": [...] }`
- `runs/<run-id>/state/run-manifest.json` updated with intake completion

## Metrics

- `user_clarifications_asked` (target ≤5; >5 = spec-quality issue flagged to improvement-planner)
- `intake_duration_sec`
- `tprd_sections_filled_by_agent` vs. `filled_by_user`

## Guardrails

G20 (all 14 sections non-empty), G21 (§Non-Goals populated), G22 (clarifications ≤5 — info only).

## Example flows

### Flow 1: NL one-liner
Input: `"add S3 client"`
Intake questions:
- Package placement? (`core/objectstore/s3/` / `cloud/s3/` / Other)
- AWS SDK version? (v1 / v2 recommended)
- Bucket versioning support? (y / n / configurable)
- Server-side encryption? (AES256 / KMS / both / none)
- Retry policy? (default exp backoff / custom / none)

→ TPRD written with 14 sections; user approves; mode=A; proceed.

### Flow 2: Mode C incremental update
Input: `"tighten dragonfly retry — 3→5 attempts, 50ms→100ms backoff"`
Intake questions:
- Breaking change OK? (no → minor bump / yes → major bump)
- Update defaults only or add new Config fields? (defaults only / add fields)
- Bench must not regress? (y default)

→ TPRD with §12 Breaking-Change Risk populated; mode=C; triggers Phase 0.5 for existing-API snapshot.

### Flow 3: Complete TPRD submitted
Input: `--spec runs/my-s3-tprd.md`
Intake loads; runs completeness guardrail; all 14 sections pass; skips Wave I1–I3; jumps to I5 approval. Duration: <30s.
