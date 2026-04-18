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
- **Golden regression on first use.** Newly promoted skills must pass `sdk-golden-regression-runner` on the next pipeline run before counting as stable.

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
