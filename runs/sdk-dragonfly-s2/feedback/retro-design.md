<!-- Generated: 2026-04-18T15:00:00Z | Run: sdk-dragonfly-s2 -->
# Phase Retrospective — Design (Phase 1)

## What Went Well
- api.go.stub compiled clean against go-redis v9.18.0 in scratch module on the first attempt (G30 PASS, first try).
- Five design agents produced coherent, non-conflicting artifacts in a single D1 wave with no cross-agent conflicts.
- Review-fix loop completed in 1 iteration (2 NEEDS-FIX from D3, both resolved in D4 iter-1; no second round required).
- License allowlist (G34) cleared immediately; no restricted licenses in proposed dep set.
- Security devil found the credential-rotation Dialer gap (S-9) — a subtle correctness issue that would have caused a silent bug in production K8s rotation scenarios.

## Recurring Patterns
| Pattern | Occurrences | Affected Agents | Severity |
|---------|------------|-----------------|----------|
| Dep-vet tooling unavailable at design phase; G32/G33 punted to HITL | 2 gates (G32, G33) | guardrail-validator, sdk-dep-vet-devil | Medium — created PENDING verdicts and H6 dependency; tooling install mid-run is a process smell |
| New dep introducing forced MVS bumps of existing pinned deps | 1 (testcontainers-go → otel v1.39→v1.41) | sdk-dep-vet-devil, sdk-impl-lead | High — caused an impl-phase HALT and unplanned H6 escalation loop |
| First new package introducing a convention deviation (functional With* options) | 1 | pattern-advisor, sdk-convention-devil | Low — justified by TPRD; well documented; accepted. But no cross-SDK design standards doc exists |
| 8 of 27 skills missing; design agents synthesized from adjacent patterns | 8 skills | All D1 agents | Low severity (no output errors), but increases agent cognitive load and output variance risk |

## Surprises
- The dep-vet tooling (govulncheck, osv-scanner) was not pre-installed. This forced G32/G33 to remain PENDING through D2/D3 and be resolved at H6 — effectively a mid-run tooling-install gate. The pipeline had no pre-flight check for tool availability.
- The user directive "do not update deps if not touched by our code ever" was issued at H6 (AFTER design completed), not at H1. This retroactively constrained what impl-lead could do with MVS-forced bumps. The H6 verdict had to be revised within the same gate session.
- Dragonfly is the first target-SDK package to use functional `With*` options alongside `Config` struct, but no pipeline-level cross-SDK design standards document exists to record this as a deliberate precedent.

## Agent Coordination Issues
- guardrail-validator (D2) produced PENDING verdicts for G32/G33 that were accepted as-is and routed to H6 — this is a known workaround, but the conditional routing was implicit rather than documented in a PENDING-verdict protocol.
- The dep-untouchable list (`DO NOT UPDATE` directive) was formalized at H6 but was not available to sdk-design-lead or sdk-dep-vet-devil during D3. Those agents could only flag the risk; they could not apply the policy.

## Communication Health
| Metric | Value |
|--------|-------|
| Total communications logged | 0 formal inter-agent comms (all within lead orchestration) |
| Assumptions raised | 1 (D2 PENDING verdicts routed to H6 implicitly) |
| Escalations sent | 0 during design; 1 dep-escalation in subsequent impl |

## Failure & Recovery Summary
| Metric | Value |
|--------|-------|
| Total failures logged | 0 agent failures |
| G32/G33 PENDING (tool install) | 2 — recovered via H6 gate |
| NEEDS-FIX findings | 2 (F-D3, S-9) — resolved in D4 iter-1, 0 remaining |
| Refactors (D4 iter-1) | 2 design doc amendments (concurrency.md §G1, patterns.md §P5a) |

## Refactor Summary
| Metric | Value |
|--------|-------|
| Total refactors | 2 design artifact amendments |
| Trigger: review-finding | 2 (sdk-design-devil F-D3, sdk-security-devil S-9) |
| High regression risk | 0 |
| Refactor ratio (2 doc edits / 8 design files) | 25% |

## Improvement Suggestions

### Agent Prompt Improvements
| Agent | Suggestion | Expected Impact | Source Pattern |
|-------|-----------|----------------|----------------|
| sdk-dep-vet-devil | Before rendering a CONDITIONAL verdict, simulate MVS resolution for the proposed new dep against the live go.mod and list every existing dep that would be bumped; include this in the verdict | Would have surfaced the otel bump requirement at D3, not during impl | testcontainers-go MVS cascade |
| guardrail-validator | At D2 startup, check if govulncheck and osv-scanner are available on PATH; if not, emit an ESCALATION immediately so run-driver can install tools before D3 devil wave | Eliminates mid-run tooling-install gates | G32/G33 PENDING at D2 |

### Process Changes
| Change | Current State | Proposed State | Justification |
|--------|--------------|----------------|---------------|
| H6 dep-untouchable policy | Issued by user at H6 after design completes | Solicit dep-policy constraints at H1 (alongside TPRD approval) — add "dep-policy" section to H1 checklist | Late policy constraints force retro-active re-scoping of already-completed verdicts |
| H6 MVS bump proactive disclosure | H6 asks user to confirm pinned versions; MVS-forced bumps discovered at impl | H6 guardrail-validator runs `go get <new-dep> && go mod tidy -json` in scratch module and lists all bumped existing deps for user approval before H6 closes | Prevents DEP-BUMP-UNAPPROVED HALT at impl phase |
| Cross-SDK design standards | No document exists | Phase 4 feedback improvement-planner to create `docs/design-standards.md` whenever a convention deviation (ACCEPT-WITH-NOTE from convention-devil) is logged | Prevents similar deviations going unrecorded in future runs |

### Guardrail Additions
| Guardrail | Check Logic | Phase | Rationale |
|-----------|------------|-------|-----------|
| G35 — Tool preflight | Check govulncheck, osv-scanner, benchstat, staticcheck on PATH at pipeline start; block design phase if missing | Pre-intake / H0 | Eliminates PENDING verdicts caused by tool absence |
| G36 — MVS simulation | For each proposed new dep in dependencies.md, run `go get <dep>@<ver> && go mod tidy -json` in scratch module; list forced bumps; require explicit approval for any bump of an existing direct dep | Design D2 | Surfaces forced dep bumps before impl phase |

## Systemic Patterns
- No prior retrospectives; patterns established here as baseline. MVS-forced-bump discovery gap and dep-policy-late-arrival are candidates to watch in future runs.
