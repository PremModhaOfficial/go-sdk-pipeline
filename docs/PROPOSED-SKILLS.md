# Proposed Skills (Human-Review Backlog)

Entries from pipeline runs are auto-filed here as WARNINGs by `scripts/guardrails/G23.sh`. They never block a run.

Human-reviewed backlog of proposed new skills. **The pipeline never creates skills at runtime.** Entries appear here from two sources:

1. **TPRD intake** — `sdk-intake-agent` Wave I2 finds a required skill missing from `.claude/skills/skill-index.json` → emits a WARN (non-blocking), files an entry here, and the pipeline continues.
2. **Phase 4 learning-engine** — on repeated patterns that lack a backing skill (3+ runs) → files an entry here; never drafts the SKILL.md itself.

## Workflow

1. Entry lands here with `status: proposed` + motivation + consumer agents
2. Human author drafts `.claude/skills/<name>/SKILL.md` with `version: 1.0.0` offline (per `SKILL-CREATION-GUIDE.md`)
3. Human opens PR; reviewers include subject-matter owner + one devil-agent owner
4. On merge: entry in this file flipped to `status: promoted` with commit SHA + link to `SKILL.md`
5. `skill-index.json` updated manually in the same PR

## Existing proposals

| Priority | Skill | Motivation | Primary consumers | Status |
|---|---|---|---|---|
| MUST | `benchmark-regression-detection` | `benchstat` integration, delta thresholds, CI gating | `sdk-benchmark-devil`, `performance-test-agent` | proposed |
| MUST | `test-stability-verification` | `-race -count=5` pattern, flaky-test detection, seed-based repro | `sdk-integration-flake-hunter`, `unit-test-agent` | proposed |
| SHOULD | `pool-reuse-policy` | When to reuse SDK's `core/pool/` vs. create own; cleanup contracts | `sdk-designer`, `concurrency-designer` | proposed |
| SHOULD | `testcontainers-client-recipes` | Per-backend recipes: dragonfly, minio, localstack, kafka, rabbitmq | `integration-test-agent` | proposed (draft candidates under `evolution/skill-candidates/`) |

## Drafts awaiting human review

See `evolution/skill-candidates/` — 8 skill drafts from prior Dragonfly-class runs:

- `hash-field-ttl-hexpire`
- `k8s-secret-file-credential-loader`
- `lua-script-safety`
- `miniredis-testing-patterns`
- `pubsub-lifecycle`
- `redis-pipeline-tx-patterns`
- `sentinel-error-model-mapping`
- `testcontainers-dragonfly-recipe`

These are **not auto-promoted**. A human reviewer must (a) audit per `SKILL-CREATION-GUIDE.md`, (b) move to `.claude/skills/<name>/`, (c) update `skill-index.json`, (d) record the promotion in git.

## Meta-skills (observability over skill set)

| Skill | Role | Status |
|---|---|---|
| `sdk-skill-drift-detector-spec` | Detect skill-prescription vs. code-reality gaps | Agent exists (`sdk-skill-drift-detector`); skill body not yet authored |
| `sdk-skill-coverage-reporter-spec` | Which skills got invoked per run; unused-but-relevant flagging | Agent exists (`sdk-skill-coverage-reporter`); skill body not yet authored |

## Policy

- **No auto-synthesis.** Pipeline emits entries; does not write `SKILL.md` bodies.
- **No runtime promotion.** Moving a draft into `.claude/skills/` is a human PR action.
- **Devil-fleet gate on first use.** Newly promoted skills must pass the devil fleet on the next pipeline run before counting as stable (pipeline does not run golden-corpus full-replay regression).

---

## Auto-filed from run `preflight-dfly-XbvV` on 2026-04-18

- **MISSING** `redis-pipeline-tx-patterns` (≥1.0.0) — source run `preflight-dfly-XbvV`
- **MISSING** `hash-field-ttl-hexpire` (≥1.0.0) — source run `preflight-dfly-XbvV`
- **MISSING** `pubsub-lifecycle` (≥1.0.0) — source run `preflight-dfly-XbvV`
- **MISSING** `miniredis-testing-patterns` (≥1.0.0) — source run `preflight-dfly-XbvV`
- **MISSING** `lua-script-safety` (≥1.0.0) — source run `preflight-dfly-XbvV`
- **MISSING** `testcontainers-dragonfly-recipe` (≥1.0.0) — source run `preflight-dfly-XbvV`
- **MISSING** `k8s-secret-file-credential-loader` (≥1.0.0) — source run `preflight-dfly-XbvV`
- **MISSING** `sentinel-error-model-mapping` (≥1.0.0) — source run `preflight-dfly-XbvV`

---

## Auto-filed from run `preflight-dfly-qIUq` on 2026-04-18

- **MISSING** `redis-pipeline-tx-patterns` (≥1.0.0) — source run `preflight-dfly-qIUq`
- **MISSING** `hash-field-ttl-hexpire` (≥1.0.0) — source run `preflight-dfly-qIUq`
- **MISSING** `pubsub-lifecycle` (≥1.0.0) — source run `preflight-dfly-qIUq`
- **MISSING** `miniredis-testing-patterns` (≥1.0.0) — source run `preflight-dfly-qIUq`
- **MISSING** `lua-script-safety` (≥1.0.0) — source run `preflight-dfly-qIUq`
- **MISSING** `testcontainers-dragonfly-recipe` (≥1.0.0) — source run `preflight-dfly-qIUq`
- **MISSING** `k8s-secret-file-credential-loader` (≥1.0.0) — source run `preflight-dfly-qIUq`
- **MISSING** `sentinel-error-model-mapping` (≥1.0.0) — source run `preflight-dfly-qIUq`

---

## Auto-filed from run `preflight-dfly-pl93` on 2026-04-18

- **MISSING** `redis-pipeline-tx-patterns` (≥1.0.0) — source run `preflight-dfly-pl93`
- **MISSING** `hash-field-ttl-hexpire` (≥1.0.0) — source run `preflight-dfly-pl93`
- **MISSING** `pubsub-lifecycle` (≥1.0.0) — source run `preflight-dfly-pl93`
- **MISSING** `miniredis-testing-patterns` (≥1.0.0) — source run `preflight-dfly-pl93`
- **MISSING** `lua-script-safety` (≥1.0.0) — source run `preflight-dfly-pl93`
- **MISSING** `testcontainers-dragonfly-recipe` (≥1.0.0) — source run `preflight-dfly-pl93`
- **MISSING** `k8s-secret-file-credential-loader` (≥1.0.0) — source run `preflight-dfly-pl93`
- **MISSING** `sentinel-error-model-mapping` (≥1.0.0) — source run `preflight-dfly-pl93`

---

## Auto-filed from run `preflight-dfly-7okH` on 2026-04-18

- **MISSING** `redis-pipeline-tx-patterns` (≥1.0.0) — source run `preflight-dfly-7okH`
- **MISSING** `hash-field-ttl-hexpire` (≥1.0.0) — source run `preflight-dfly-7okH`
- **MISSING** `pubsub-lifecycle` (≥1.0.0) — source run `preflight-dfly-7okH`
- **MISSING** `miniredis-testing-patterns` (≥1.0.0) — source run `preflight-dfly-7okH`
- **MISSING** `lua-script-safety` (≥1.0.0) — source run `preflight-dfly-7okH`
- **MISSING** `testcontainers-dragonfly-recipe` (≥1.0.0) — source run `preflight-dfly-7okH`
- **MISSING** `k8s-secret-file-credential-loader` (≥1.0.0) — source run `preflight-dfly-7okH`
- **MISSING** `sentinel-error-model-mapping` (≥1.0.0) — source run `preflight-dfly-7okH`

---

## Auto-filed from run `sdk-dragonfly-s2` on 2026-04-18

Source: `sdk-intake-agent` Wave I2 §Skills-Manifest validation (G23 WARN, non-blocking).
TPRD: `motadatagosdk/core/l2cache/dragonfly/TPRD.md` §Skills-Manifest (27 declared; 19 present; 8 missing, all WARN-expected per TPRD footnote).
Status: `proposed` (awaiting human PR authorship per rule #23).

- **MISSING** `redis-pipeline-tx-patterns` (≥1.0.0) — source run `sdk-dragonfly-s2`; TPRD reason: "§5.4 Pipeline + TxPipeline + Watch". Draft in `evolution/skill-candidates/`.
- **MISSING** `hash-field-ttl-hexpire` (≥1.0.0) — source run `sdk-dragonfly-s2`; TPRD reason: "§5.3 HEXPIRE/HPEXPIRE/HTTL/HPersist family". Draft in `evolution/skill-candidates/`.
- **MISSING** `pubsub-lifecycle` (≥1.0.0) — source run `sdk-dragonfly-s2`; TPRD reason: "§5.5 Subscribe/PSubscribe lifetime + cancellation". Draft in `evolution/skill-candidates/`.
- **MISSING** `miniredis-testing-patterns` (≥1.0.0) — source run `sdk-dragonfly-s2`; TPRD reason: "§11.1 miniredis fakes for unit tests". Draft in `evolution/skill-candidates/`.
- **MISSING** `lua-script-safety` (≥1.0.0) — source run `sdk-dragonfly-s2`; TPRD reason: "§5.6 Eval/EvalSha/ScriptLoad". Draft in `evolution/skill-candidates/`.
- **MISSING** `testcontainers-dragonfly-recipe` (≥1.0.0) — source run `sdk-dragonfly-s2`; TPRD reason: "§11.2 Dragonfly container image + readiness probe". Draft in `evolution/skill-candidates/`.
- **MISSING** `k8s-secret-file-credential-loader` (≥1.0.0) — source run `sdk-dragonfly-s2`; TPRD reason: "§9 `LoadCredsFromEnv` helper". Draft in `evolution/skill-candidates/`.
- **MISSING** `sentinel-error-model-mapping` (≥1.0.0) — source run `sdk-dragonfly-s2`; TPRD reason: "§7 `mapErr` switch + 30 sentinels". Draft in `evolution/skill-candidates/`.

---

## Auto-filed from run `sdk-dragonfly-s2` on 2026-04-18 (F6 improvement-planner)

Source: `improvement-planner` Wave F6, derived from retro patterns P1/P2/P5 (not intake manifest gaps).
Status: `proposed` (awaiting human PR authorship per rule #23). These are net-new proposals beyond the 8 intake-filed WARN-absent set.

| Priority | Skill | Motivation | Primary consumers | Source pattern |
|---|---|---|---|---|
| SHOULD | `miniredis-limitations-reference` | Documents which Redis commands miniredis v2 does/doesn't support (HEXPIRE family not supported; Lua subset; scripting edge cases). Bridges the TPRD §11.1 gap surfaced in sdk-dragonfly-s2. | `integration-test-agent`, `unit-test-agent`, `sdk-testing-lead` | P5 (retro-testing) |
| SHOULD | `bench-constraint-calibration` | Pattern for verifying TPRD §10 numeric constraints against dep-lib measured floors before declaring them acceptable. Methodology + lookup-table approach + CALIBRATION-WARN vs FAIL taxonomy. | `sdk-intake-agent`, `sdk-benchmark-devil`, `sdk-testing-lead` | P1 (retro-intake, retro-testing) |
| SHOULD | `mvs-forced-bump-preview` | Pattern for running Go MVS simulation against the live target `go.mod` (not a scratch module) to surface forced bumps of existing direct deps at design time, not impl time. | `sdk-dep-vet-devil`, `sdk-design-lead`, `sdk-impl-lead` | P2 (retro-design, retro-impl) |

Note: These are proposals only. Per CLAUDE.md Rule #23 skills are human-authored; the pipeline does NOT draft SKILL.md bodies for these entries. Related guardrails are proposed in `docs/PROPOSED-GUARDRAILS.md` (G25, G36, G66) — guardrails and skills reinforce each other but are independently PR-able.

---

## Auto-filed from run `sdk-dragonfly-p1-v1` on 2026-04-22

- **MISSING** `redis-pipeline-tx-patterns` (≥1.0.0) — source run `sdk-dragonfly-p1-v1`
- **MISSING** `go-iter-seq-patterns` (≥1.0.0) — source run `sdk-dragonfly-p1-v1`
- **MISSING** `redis-set-sortedset-semantics` (≥1.0.0) — source run `sdk-dragonfly-p1-v1`
- **MISSING** `generic-codec-helper-design` (≥1.0.0) — source run `sdk-dragonfly-p1-v1`

---

## Auto-filed from run `sdk-dragonfly-p1-v1` on 2026-04-23

- **MISSING** `redis-pipeline-tx-patterns` (≥1.0.0) — source run `sdk-dragonfly-p1-v1`
- **MISSING** `go-iter-seq-patterns` (≥1.0.0) — source run `sdk-dragonfly-p1-v1`
- **MISSING** `redis-set-sortedset-semantics` (≥1.0.0) — source run `sdk-dragonfly-p1-v1`
- **MISSING** `generic-codec-helper-design` (≥1.0.0) — source run `sdk-dragonfly-p1-v1`

---

## Auto-filed from run `sdk-dragonfly-p1-v1` on 2026-04-23

- **MISSING** `redis-pipeline-tx-patterns` (≥1.0.0) — source run `sdk-dragonfly-p1-v1`
- **MISSING** `go-iter-seq-patterns` (≥1.0.0) — source run `sdk-dragonfly-p1-v1`
- **MISSING** `redis-set-sortedset-semantics` (≥1.0.0) — source run `sdk-dragonfly-p1-v1`
- **MISSING** `generic-codec-helper-design` (≥1.0.0) — source run `sdk-dragonfly-p1-v1`

---

## Auto-filed from run `sdk-dragonfly-s2` on 2026-04-24

- **MISSING** `redis-pipeline-tx-patterns` (≥1.0.0) — source run `sdk-dragonfly-s2`
- **MISSING** `hash-field-ttl-hexpire` (≥1.0.0) — source run `sdk-dragonfly-s2`
- **MISSING** `pubsub-lifecycle` (≥1.0.0) — source run `sdk-dragonfly-s2`
- **MISSING** `miniredis-testing-patterns` (≥1.0.0) — source run `sdk-dragonfly-s2`
- **MISSING** `lua-script-safety` (≥1.0.0) — source run `sdk-dragonfly-s2`
- **MISSING** `testcontainers-dragonfly-recipe` (≥1.0.0) — source run `sdk-dragonfly-s2`
- **MISSING** `k8s-secret-file-credential-loader` (≥1.0.0) — source run `sdk-dragonfly-s2`
- **MISSING** `sentinel-error-model-mapping` (≥1.0.0) — source run `sdk-dragonfly-s2`

---

## Auto-filed from run `sdk-dragonfly-s2` on 2026-04-24

- **MISSING** `redis-pipeline-tx-patterns` (≥1.0.0) — source run `sdk-dragonfly-s2`
- **MISSING** `hash-field-ttl-hexpire` (≥1.0.0) — source run `sdk-dragonfly-s2`
- **MISSING** `pubsub-lifecycle` (≥1.0.0) — source run `sdk-dragonfly-s2`
- **MISSING** `miniredis-testing-patterns` (≥1.0.0) — source run `sdk-dragonfly-s2`
- **MISSING** `lua-script-safety` (≥1.0.0) — source run `sdk-dragonfly-s2`
- **MISSING** `testcontainers-dragonfly-recipe` (≥1.0.0) — source run `sdk-dragonfly-s2`
- **MISSING** `k8s-secret-file-credential-loader` (≥1.0.0) — source run `sdk-dragonfly-s2`
- **MISSING** `sentinel-error-model-mapping` (≥1.0.0) — source run `sdk-dragonfly-s2`

---

## Auto-filed from run `sdk-dragonfly-s2` on 2026-04-24

- **MISSING** `redis-pipeline-tx-patterns` (≥1.0.0) — source run `sdk-dragonfly-s2`
- **MISSING** `hash-field-ttl-hexpire` (≥1.0.0) — source run `sdk-dragonfly-s2`
- **MISSING** `pubsub-lifecycle` (≥1.0.0) — source run `sdk-dragonfly-s2`
- **MISSING** `miniredis-testing-patterns` (≥1.0.0) — source run `sdk-dragonfly-s2`
- **MISSING** `lua-script-safety` (≥1.0.0) — source run `sdk-dragonfly-s2`
- **MISSING** `testcontainers-dragonfly-recipe` (≥1.0.0) — source run `sdk-dragonfly-s2`
- **MISSING** `k8s-secret-file-credential-loader` (≥1.0.0) — source run `sdk-dragonfly-s2`
- **MISSING** `sentinel-error-model-mapping` (≥1.0.0) — source run `sdk-dragonfly-s2`
