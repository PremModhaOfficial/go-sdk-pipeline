<!-- Generated: 2026-04-29T18:10:00Z | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 -->

# Per-Agent Quality Scorecard — sdk-resourcepool-py-pilot-v1

Run: Python adapter pilot · Mode A · Tier T1 · 22 agents scored across 4 phases

## Phase 0 — Intake

| Agent | Status | Q-Score | Completeness | Guardrail | Rework | Comm | Notes |
|---|---|---|---|---|---|---|---|
| sdk-intake-agent | completed | **1.00** | 1.0 | 1.0 | 1.0 | 1.0 | 12/12 RAN-PASS; 0 clarifications; all manifests clean |

**Phase aggregate: 1.00**

---

## Phase 1 — Design

| Agent | Status | Q-Score | Completeness | Rev-Severity | Guardrail | Rework | Notes |
|---|---|---|---|---|---|---|---|
| sdk-design-lead | completed | **0.93** | 1.0 | 1.0 | 0.67 | 1.0 | 2 INCOMPLETE-deferred guardrails; waiver justified (Mode A greenfield) |
| sdk-perf-architect-python | completed | **0.90** | 1.0 | 1.0 | 1.0 | 1.0 | PA-003 downstream assumption (stub IDs) |
| sdk-design-devil | completed | **1.00** | 1.0 | 1.0 | 1.0 | 1.0 | DD-005 LOW only; ACCEPT-WITH-NOTE |
| sdk-convention-devil-python | completed | **0.975** | 1.0 | 1.0 | 1.0 | 1.0 | CV-001 was real bug; caught at design |
| sdk-dep-vet-devil-python | completed | **1.00** | 1.0 | 1.0 | 1.0 | 1.0 | 11/11 deps ACCEPT; H6 auto-pass |
| sdk-semver-devil | completed | **1.00** | 1.0 | 1.0 | 1.0 | 1.0 | Mode A v1.0.0; clean ACCEPT |
| sdk-security-devil | completed | **1.00** | 1.0 | 1.0 | 1.0 | 1.0 | 0 findings; threat model clean |
| sdk-packaging-devil-python | completed | **0.975** | 1.0 | 1.0 | 1.0 | 1.0 | PK-001/002 LOW deferred to impl |
| guardrail-validator (D2) | completed | **0.90** | 1.0 | 1.0 | 1.0 | 1.0 | Scored in multi-phase entry below |

**Phase aggregate: 0.969** (mean of 7 primary design agents)

---

## Phase 2 — Implementation

| Agent | Status | Q-Score | Completeness | Rev-Severity | Guardrail | Rework | Notes |
|---|---|---|---|---|---|---|---|
| sdk-impl-lead | completed | **0.78** | 1.0 | 0.8 | 0.86 | 0.5 | G43-py INCOMPLETE; M5b rework; PA-001..006; 1 retry needed |
| code-reviewer-python | completed | **1.00** | 1.0 | 1.0 | 1.0 | 1.0 | CR-001 closed; CR-002/003 INFO/LOW deferred |
| sdk-api-ergonomics-devil-python | completed | **1.00** | 1.0 | 1.0 | 1.0 | 1.0 | ACCEPT; 0 findings |
| sdk-overengineering-critic | completed | **1.00** | 1.0 | 1.0 | 1.0 | 1.0 | OE-005/006 INFO; ACCEPT |
| sdk-marker-hygiene-devil | completed | **1.00** | 1.0 | 1.0 | 1.0 | 1.0 | G99/G103/G110 PASS; 100% traces-to coverage |
| sdk-profile-auditor-python | completed | **0.79** | 0.5 | 1.0 | 0.75 | 1.0 | 6/8 symbols PASS; 2 INCOMPLETE-by-harness (PA-001/002) |
| guardrail-validator (M9) | — | (scored combined) | — | — | — | — | See multi-phase entry |

**Phase aggregate: 0.877** (6 primary impl agents; guardrail-validator scored combined)

---

## Phase 3 — Testing

| Agent | Status | Q-Score | Completeness | Rev-Severity | Guardrail | Rework | Notes |
|---|---|---|---|---|---|---|---|
| sdk-testing-lead | completed | **0.96** | 1.0 | 1.0 | 0.89 | 1.0 | 8/9 guardrails PASS; G32-py INCOMPLETE; 13-item backlog |
| sdk-benchmark-devil-python | completed | **1.00** | 1.0 | 1.0 | 1.0 | 1.0 | G108 4 PASS / 2 CALIBRATION-WARN (floor-bound) |
| sdk-complexity-devil-python | completed | **1.00** | 1.0 | 1.0 | 1.0 | 1.0 | G107 PASS; O(1) confirmed; slope −0.0585 |
| sdk-asyncio-leak-hunter-python | completed | **1.00** | 1.0 | 1.0 | 1.0 | 1.0 | 15/15 PASS; 0 leaks |
| sdk-integration-flake-hunter-python | completed | **1.00** | 1.0 | 1.0 | 1.0 | 1.0 | 28 invocations; 0 flakes |
| sdk-soak-runner-python | completed | **0.93** | 1.0 | 1.0 | 1.0 | 0.5 | run-1 sampler defect; run-2 canonical; 131k ops/sec |
| sdk-drift-detector | completed | **1.00** | 1.0 | 1.0 | 1.0 | 1.0 | G106 PASS; 6/6 signals clean |

**Phase aggregate: 0.984** (7 testing agents)

---

## Multi-Phase Agent

| Agent | Phases | Q-Score | Notes |
|---|---|---|---|
| guardrail-validator | D2 + M9 + T-GR | **0.90** | 18/21 PASS; 3 INCOMPLETE-deferred (all Rule 33 justified); improvement-planner candidate |

---

## Run-Level Summary

| Metric | Value |
|---|---|
| Total agents scored | 22 |
| Completed | 22 / 0 failed / 0 degraded |
| Pipeline quality score | **0.959** |
| Mean quality score | 0.959 |
| Median quality score | 1.00 |
| Min quality score | 0.78 (sdk-impl-lead) |
| Max quality score | 1.00 (10 agents tied) |

---

## Top 5 Agents by Quality Score (ties broken alphabetically)

1. sdk-asyncio-leak-hunter-python — **1.00**
2. sdk-benchmark-devil-python — **1.00**
3. sdk-complexity-devil-python — **1.00**
4. sdk-dep-vet-devil-python — **1.00**
5. sdk-design-devil — **1.00**

(also 1.00: sdk-drift-detector, sdk-integration-flake-hunter-python, sdk-marker-hygiene-devil, sdk-semver-devil, sdk-security-devil)

---

## Agents Needing Attention (quality_score < 0.85)

| Agent | Score | Primary Reason |
|---|---|---|
| sdk-impl-lead | **0.78** | G43-py INCOMPLETE (tooling mismatch); 1 resume+retry; M5b rework iteration; 6 downstream PA items |
| sdk-profile-auditor-python | **0.79** | 2/8 bench harnesses INCOMPLETE (PA-001/002); failure_recovery partial |

---

## D2 Cross-Language Analytics (vs Go baseline sdk-dragonfly-s2)

| Agent | Go baseline | Python score | Delta | Divergence (≥3pp = WARN) |
|---|---|---|---|---|
| sdk-intake-agent | 1.00 | 1.00 | 0.00pp | NONE |
| sdk-design-lead | 0.85 | 0.93 | +8pp | WARN-progressive: +8pp improvement (positive; no flip required per D2 lenient — positive divergence is not a debt signal) |
| sdk-impl-lead | 0.975 | 0.78 | −19.5pp | **WARN-progressive-trigger: −19.5pp debt** — exceeds 3pp threshold. Language-specific tooling gap (Python adapter pilot). D2 lenient: log WARN, do NOT block. Candidate for per-language partition if gap persists over rolling-3. |
| sdk-testing-lead | 0.975 | 0.96 | −1.5pp | NONE (within 3pp) |

---

## G86 Regression Gate

**Status: no-op-first-python-run-precondition-unmet**

G86 requires ≥3 prior runs before the 5% regression BLOCKER activates. This is run 2 in the shared quality.json history (first Python entry). Gate is advisory-only this run.

---

## Baseline Operations This Run

- `baselines/shared/quality-baselines.json` — updated with Python entries for 4 primary agents
- `baselines/shared/baseline-history.jsonl` — run-level entry appended
- `baselines/python/devil-verdict-history.jsonl` — SEEDED (first Python run)

---

## Pointers

- Machine-readable: `runs/sdk-resourcepool-py-pilot-v1/feedback/metrics.json`
- Decision log: `runs/sdk-resourcepool-py-pilot-v1/decision-log.jsonl`
- Phase summaries: `runs/.../intake/phase-summary.md` · `design/phase-summary.md` · `impl/phase-summary.md` · `testing/phase-summary.md`
- Baselines: `baselines/shared/quality-baselines.json` · `baselines/shared/baseline-history.jsonl` · `baselines/python/devil-verdict-history.jsonl`
