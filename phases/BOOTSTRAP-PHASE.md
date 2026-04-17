# Phase -1: Bootstrap

## Purpose

Before real work starts, ensure skill library has everything needed for THIS request. Skills can be synthesized, evolved, and devil-reviewed here. Subsequent phases then operate on a sound foundation.

## Trigger rule

Evaluated by `sdk-bootstrap-lead`:
1. Parse input (NL or TPRD path) → extract tech signals (`Dragonfly` → redis-family, `S3` → aws+object-store, `Kafka` → stream-consumer, `NATS` → events-adjacent)
2. Load `.claude/skills/skill-index.json`; compare required tags vs. existing skill frontmatter tags
3. If all required skills present AND version ≥ required → **skip bootstrap** (proceed to intake)
4. Else → run bootstrap

## Input

- Raw request (NL string) OR partial TPRD path
- `.claude/skills/skill-index.json`
- `docs/MISSING-SKILLS-BACKLOG.md`
- `runs/<run-id>/state/run-manifest.json`

## Waves

### Wave B1 — Skill Audit
**Agent**: `sdk-skill-auditor`
**Output**: `runs/<run-id>/bootstrap/skill-gap-report.md`
Tech signals → required-skill-tags mapping → diff vs. existing.

### Wave B2 — Skill Synthesis (conditional)
**Agent**: `sdk-skill-synthesizer` (runs ONLY if Wave B1 found gaps)
**Output**: `evolution/skill-candidates/<skill-name>/SKILL.md` (draft)
**Skills can invoke**: Context7 / Exa for canonical docs. Authoring constraints:
- 3+ GOOD/BAD examples (≥1 sourced from target SDK if applicable)
- Target SDK Convention section
- `version: 1.0.0`, `status: draft`
- Frontmatter complete per SKILL-CREATION-GUIDE

### Wave B3 — Skill Convention Alignment
**Agent**: `sdk-skill-convention-aligner`
**Output**: patched drafts (same path) + `runs/<run-id>/bootstrap/convention-diff.md`
Reads target SDK tree; reconciles skill prescriptions with actual patterns (Config+New vs. functional options, otel/ wiring, pool/ usage, etc.).

### Wave B4 — Skill Devil Review
**Agent**: `sdk-skill-devil`
**Output**: `runs/<run-id>/bootstrap/reviews/skill-<name>.md` — verdict ACCEPT / NEEDS-FIX / REJECT
Reviews drafts for: vagueness, contradictions with target SDK, missing anti-patterns, missing GOOD/BAD examples, unverifiable claims, hidden multi-tenancy / HTTP assumptions.

### Wave B5 — Agent Synthesis (rarely triggered)
**Agent**: `sdk-agent-bootstrapper` → drafts new agent per AGENT-CREATION-GUIDE if a novel protocol demands it
**Review**: `sdk-agent-devil`
**Output**: `evolution/agent-candidates/<agent-name>.md`

### Wave B6 — Review-Fix Loop
If any wave B4/B5 review emitted `NEEDS-FIX`, route back to synthesizer. Max 5 iterations per finding (per `review-fix-protocol`).

### Wave B7 — User Gate (HITL H2 + H3)
**Lead**: `sdk-bootstrap-lead`
**Artifact**: `runs/<run-id>/bootstrap/bootstrap-summary.md` + skill/agent diffs
**Options**: Approve all / Approve subset / Reject all
**Default**: Reject (if timeout)
**Bypass**: `--auto-approve-bootstrap` (skills only, never agents)

### Wave B8 — Promotion
On user approval: move from `evolution/skill-candidates/<name>/` → `.claude/skills/<name>/`. Bump `skill-index.json`. Status: `draft` → `stable`. Initialize `evolution-log.md`.

## Exit artifacts

- `runs/<run-id>/bootstrap/skill-gap-report.md`
- `runs/<run-id>/bootstrap/skill-decisions.jsonl` (what was added/evolved/deferred)
- `runs/<run-id>/bootstrap/bootstrap-summary.md`
- `.claude/skills/<new-skill>/` (promoted skills, version 1.0.0)
- `.claude/agents/<new-agent>.md` (rarely; only if B5 triggered)
- Updated `.claude/skills/skill-index.json`

## Safety rails

- Max 5 new skills per run (user-gated; higher than learning-engine's ≤3 auto-apply cap)
- Max 2 new agents per run
- Every new skill MUST have: ≥3 GOOD/BAD examples, Target SDK Convention section, `sdk-skill-devil` ACCEPT verdict, user approval at H2
- No skill may require `encoding/json` for internal patterns
- No skill may require tenant_id / schema-per-tenant
- Skill drafts NEVER promoted without devil ACCEPT

## Metrics emitted (per wave)

- `bootstrap_gaps_found`
- `bootstrap_skills_drafted`
- `bootstrap_skills_approved`
- `bootstrap_devil_needs_fix_rate`
- `bootstrap_user_rejection_rate`

All feed `baselines/skill-health.json` via `metrics-collector`.

## Guardrails (run on phase exit)

G10, G11, G12, G13, G14, G15. See plan §Guardrails Catalog.

## Typical durations

- First run (greenfield library): ~10 new skills synthesized → 15–30 min + user review time
- Tenth run (mature library): 0 new skills, bootstrap skipped → <30 sec
