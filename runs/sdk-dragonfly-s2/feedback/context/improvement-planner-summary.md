<!-- Generated: 2026-04-18T15:20:00Z | Run: sdk-dragonfly-s2 | Agent: improvement-planner (Wave F6) -->
# improvement-planner — Context Summary for Wave F7 (learning-engine)

## Inputs consumed
- `runs/sdk-dragonfly-s2/feedback/metrics.json` + `metrics-summary.md` (F1)
- `runs/sdk-dragonfly-s2/feedback/retro-{intake,design,impl,testing}.md` (F2)
- `runs/sdk-dragonfly-s2/feedback/skill-drift.md` (F4a)
- `runs/sdk-dragonfly-s2/feedback/skill-coverage.md` (F4b)
- `runs/sdk-dragonfly-s2/feedback/golden-regression.json` (F5)
- `runs/sdk-dragonfly-s2/decision-log.jsonl` seq 1–121
- `evolution/knowledge-base/agent-performance.jsonl` (F1 update — first-run baselines)
- `docs/PROPOSED-SKILLS.md`, `.claude/settings.json` (safety caps)

## Output artifacts (produced by F6)
- `evolution/improvement-plan-sdk-dragonfly-s2.md` (290 lines, 17 items, ≤ 20 cap, ≤ 500 lines)
- `evolution/prompt-patches/sdk-{intake-agent,design-lead,impl-lead,testing-lead}.md` (4 drafts)
- `evolution/evolution-reports/sdk-dragonfly-s2.md` (F7 + baseline-manager input)
- `docs/PROPOSED-GUARDRAILS.md` (new file, 7 entries from this run)
- `docs/PROPOSED-SKILLS.md` (appended 3 new net-new skill proposals under §F6 section)

## Counts (concise)
- **Prompt patches drafted:** 4 (3 HIGH + 1 MEDIUM). Cap 10. OK.
- **Existing-skill patches recommended:** 3 (1 HIGH + 1 MEDIUM + 1 LOW defer). Cap 3. OK.
- **New-skill proposals filed:** 3 (all MEDIUM). Runtime cap 0 enforced (filed to PROPOSED-SKILLS.md).
- **New-guardrail proposals filed:** 7 (2 HIGH + 3 MEDIUM + 2 LOW). Runtime cap 0 enforced (filed to PROPOSED-GUARDRAILS.md).
- **Process change proposals:** 5 (all HUMAN-GATED).
- **Threshold change proposals:** 1 (keep current threshold; add CALIBRATION-WARN bypass).

## Root evidence map (top 5 patterns)
| Retro Pattern | Severity | Cross-phase? | Fix tier |
|---|---|---|---|
| RP1 TPRD §10 constraint vs dep-floor | SYSTEMIC-HIGH | intake + testing | Prompt patches 1 + 7 + Guardrail G25 + G66 + Skill `bench-constraint-calibration` |
| RP2 MVS-forced bumps at impl not design | SYSTEMIC-HIGH | design + impl | Prompt patches 2 + 3 + Guardrail G36 + Skill `mvs-forced-bump-preview` |
| RP3 Mode selection ad-hoc | MEDIUM | intake | Process D1 (--mode flag + §16-override field) |
| RP4 OTel conformance test authored in testing | MEDIUM | impl + testing | Prompt patch 3 + Guardrail G44 |
| RP5 miniredis HPExpire-family gap | LOW-MEDIUM | testing | Prompt patch 7 + Guardrail G67/G68 + Skill `miniredis-limitations-reference` |

## Safety halts
**None.** Golden regression N/A (empty corpus; F5 ruled NOT-BLOCKED-BY-GOLDEN). Zero defects. Zero MAJOR drift. All improvements respect per-run caps.

## Directive to F7 (learning-engine)

### Apply NOW (this run)
1. Prompt patches to sdk-intake-agent, sdk-design-lead, sdk-impl-lead (all HIGH).
2. Optional prompt patch to sdk-testing-lead (MEDIUM; depends on G66 file existing — it does).
3. Existing-skill PATCH bumps (v1.0.0 → v1.0.1): `go-error-handling-patterns` (trigger keywords only) and `go-example-function-patterns` (trigger keywords only).

### Do NOT apply (this run)
- Minor-version bump of `go-error-handling-patterns` body-split. Wait for golden-corpus seed post-H10.
- `tdd-patterns` trigger expansion (LOW confidence).
- Any new skill / guardrail / agent (runtime caps enforce HUMAN-only creation).

## Decision log entries appended
Seq 130–143 (14 entries; within the 15-entry-per-agent cap). See decision-log.jsonl.

## Handoff
F7 (learning-engine) is the next wave. It reads this summary + the improvement plan, applies safe patches per directive above, updates `evolution/knowledge-base/prompt-evolution-log.jsonl`, and hands off to F8 (baseline-manager).

## Inter-agent communications this wave
- 1 formal communication logged: decision-log seq 142, improvement-planner → learning-engine, "F6 complete; 17 improvements; 0 safety halts; apply directive in §J of plan."

## Notes
- No refactor-pattern analysis needed; the single refactor observed (sdk-design-lead 2 amendments / 8 artifacts = 25%) is below the 30% threshold.
- No failure-pattern analysis needed; 1 soft-gate fail + 1 dep-escalation both had clean recovery and are addressed by proposed fixes.
- One data-quality note: `pipeline_version` stamps drift between 0.1.0 and 0.2.0 within this run; filed as process D3 for normalization.
