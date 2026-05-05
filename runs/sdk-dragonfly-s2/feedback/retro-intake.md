<!-- Generated: 2026-04-18T15:00:00Z | Run: sdk-dragonfly-s2 -->
# Phase Retrospective — Intake (Phase 0)

## What Went Well
- Zero ambiguity markers in the 477-line TPRD; zero clarification questions needed (G22 PASS with 0 questions).
- All 38 declared guardrail scripts present and executable (G24 PASS — BLOCKER gate cleared first try).
- TPRD §15 open questions each carried inline proposed answers; intake agent accepted them without escalation.
- Mode detection was fast: §16 inconsistency flagged, user directive applied, mode.json committed in a single wave.
- 8 missing skills filed to `docs/PROPOSED-SKILLS.md` rather than silently skipped; downstream agents had explicit fallback guidance.

## Recurring Patterns
| Pattern | Occurrences | Affected Agents | Severity |
|---------|------------|-----------------|----------|
| Mode declared in TPRD contradicted by user directive at run-time | 1 (this run) | sdk-intake-agent, run-sdk-addition | Medium — required mode.json override and §16 inconsistency flag; no downstream breakage but consumed coordination effort |
| Skills-Manifest WARN (missing skills) | 8 misses / 27 total | All downstream design agents | Low — non-blocking; agents synthesized from adjacent skills, outcomes acceptable |
| TPRD perf constraint unverified against dependency floor at intake | 1 (allocs ≤ 3) | sdk-intake-agent, sdk-testing-lead | High — surfaced only at Phase 3; see Surprises |

## Surprises
- The TPRD §10 `≤ 3 allocs per GET` constraint was accepted at intake without checking go-redis v9's known allocation floor (~25-30/call). Had intake run a "constraint feasibility" check against pinned dep versions, the H8 waiver path would have been triggered at H1, not Phase 3.
- TPRD §16 declared Mode B while the user simultaneously directed Mode A. The pipeline handled this gracefully, but the conflict was only resolved via an ad-hoc user message — no formal Mode-override mechanism existed in the TPRD or pipeline.

## Agent Coordination Issues
- No inter-agent communication entries logged during intake (single-agent phase — acceptable here).
- The mode.json produced at intake correctly propagated the Mode A override; all downstream agents consumed it without assumption flags.

## Communication Health
| Metric | Value |
|--------|-------|
| Total communications logged | 0 (single-agent phase) |
| Assumptions raised | 0 |
| Escalations sent | 0 |

## Failure & Recovery Summary
| Metric | Value |
|--------|-------|
| Total failures logged | 0 |
| Recovered (retry) | 0 |
| Unrecovered | 0 |

## Improvement Suggestions

### Agent Prompt Improvements
| Agent | Suggestion | Expected Impact | Source Pattern |
|-------|-----------|----------------|----------------|
| sdk-intake-agent | For each numeric perf constraint in TPRD §10, query the pinned dependency's known allocation/latency floor (e.g. from bench notes or dep docs) and flag if target is mechanically unreachable | Surfaces H8-class waivers at H1 rather than Phase 3 | allocs ≤ 3 vs go-redis v9 floor |
| sdk-intake-agent | When TPRD §16 mode declaration differs from run-driver mode directive, generate a formal `mode-override.md` artifact with diff + rationale, and explicitly ask run-driver to confirm before proceeding | Formalizes ad-hoc override; creates audit trail | Mode B vs Mode A conflict |

### Process Changes
| Change | Current State | Proposed State | Justification |
|--------|--------------|----------------|---------------|
| Mode selection | Determined by TPRD §16; can be overridden ad-hoc via user message | Add a `--mode` CLI flag or TPRD `§16-override` field that is checked before intake starts; any conflict between §16 and override requires explicit H1 annotation | Prevents silent mode mismatch; supports "Mode A/B/C selection as a TPRD §16-override flag" |
| Perf-constraint feasibility | Constraints accepted as stated in TPRD §10 | Intake agent cross-references each constraint against known dep floors (from `baselines/` or dep release notes); flags WARN if constraint appears unachievable without client swap | Would have caught allocs-per-GET issue 3 phases earlier |

### Guardrail Additions
| Guardrail | Check Logic | Phase | Rationale |
|-----------|------------|-------|-----------|
| G25 — Perf-constraint dep-floor check | For each numeric `[constraint: allocs/latency/throughput]` in TPRD §10, look up `baselines/performance-baselines.json` or dep changelog; emit WARN if measured floor exceeds target | Intake (I3) | Prevents aspirational constraints reaching bench phase without validation |

## Systemic Patterns
- No prior retrospectives exist for comparison. Patterns noted here become the baseline for future runs.
