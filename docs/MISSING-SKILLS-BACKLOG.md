# Missing Skills Backlog

Seeded from recon gap analysis. Each entry is a skill `sdk-skill-synthesizer` may draft during Phase -1 Bootstrap when a run's TPRD requires it.

Priority: **MUST** = synthesize on first run requiring it · **SHOULD** = synthesize when a run's TPRD touches its domain · **COULD** = backlog, synthesize when organic need arises.

## MUST

| # | Skill | Why needed | Primary consumers |
|---|-------|-----------|-------------------|
| 1 | `go-dependency-vetting` | License / CVE / maintenance-status / supply-chain gate for every new `go get` | `sdk-dep-vet-devil`, `sdk-design-lead` |
| 2 | `sdk-semver-governance` | Public-API diff + breaking-change detection; Config default changes = minor; removals = major | `sdk-semver-devil`, `sdk-breaking-change-devil` |
| 3 | `network-error-classification` | Taxonomy: retryable / permanent / transient; wrap with host/op/attempt context | `algorithm-designer`, `sdk-implementor` |
| 4 | `context-deadline-patterns` | Deadline inheritance, cancellation safety, timeout arithmetic, goroutine scope | `concurrency-designer`, `sdk-leak-hunter` |
| 5 | `connection-pool-tuning` | Sizing heuristics using `core/pool/`; min/max/idle-timeout/eviction formulas | `sdk-designer`, `algorithm-designer` |
| 6 | `goroutine-leak-prevention` | goleak setup, -race discipline, graceful-close verification | `sdk-leak-hunter`, `unit-test-agent` |
| 7 | `client-shutdown-lifecycle` | Close()/Stop() contracts; in-flight drain; resource cleanup order | `sdk-designer`, `concurrency-designer` |
| 8 | `sdk-config-struct-pattern` | Target SDK convention: `Config` struct + `New(cfg)` vs. functional options — when to use which | `sdk-designer`, `sdk-convention-devil` |
| 9 | `sdk-otel-hook-integration` | Wire into `motadatagosdk/otel` package instead of raw OTel; span/metric attribute conventions | `sdk-designer`, `sdk-implementor` |

## SHOULD

| # | Skill | Why needed |
|---|-------|-----------|
| 10 | `idempotent-retry-safety` | Mark methods idempotent vs. mutation; guide retry policy per method |
| 11 | `client-tls-configuration` | Custom CA, mTLS, cert pinning, rotation lifecycle |
| 12 | `credential-provider-pattern` | Env / file / secrets-manager / chain-of-providers; no plaintext storage |
| 13 | `backpressure-flow-control` | Buffer sizing, block-vs-drop semantics, channel select patterns |
| 14 | `client-rate-limiting` | Token bucket, leaky bucket, distributed rate limits |
| 15 | `api-ergonomics-audit` | Consumer-POV usability: fluency, minimal boilerplate, type safety |
| 16 | `client-mock-strategy` | gomock vs. hand-rolled vs. counterfeiter; contract tests for SDK consumers |
| 17 | `go-example-function-patterns` | Runnable `Example_*` functions for godoc |
| 18 | `circuit-breaker-policy` | Consistent usage of `core/circuitbreaker/`; thresholds, fallback strategy |

## COULD

| # | Skill | Why needed |
|---|-------|-----------|
| 19 | `benchmark-regression-detection` | `benchstat` integration, delta thresholds, CI gating |
| 20 | `test-stability-verification` | `-race -count=5` pattern, flaky-test detection, seed-based repro |
| 21 | `pool-reuse-policy` | When to reuse SDK's `core/pool/` vs. create own; cleanup contracts |
| 22 | `testcontainers-client-recipes` | Per-backend container recipes: dragonfly, minio, localstack, kafka, rabbitmq |
| 23 | `sdk-marker-protocol` | `[traces-to:]` / `[constraint:]` / `[stable-since:]` markers — how to author, scope, and verify |

## Meta-skills

| # | Skill | Role |
|---|-------|------|
| M1 | `sdk-skill-drift-detector-spec` | How to detect skill-prescription vs. code-reality gaps |
| M2 | `sdk-skill-coverage-reporter-spec` | Which skills got invoked per run; unused-but-relevant flagging |
| M3 | `sdk-new-skill-synthesizer-spec` | When patterns appear 3+ times without backing skill → auto-draft |

## Process

1. During Phase -1, `sdk-skill-auditor` maps request tech signals to this backlog
2. `sdk-skill-synthesizer` drafts MUST-have missing skills in `evolution/skill-candidates/`
3. `sdk-skill-devil` reviews drafts — ACCEPT / NEEDS-FIX / REJECT
4. On ACCEPT + user approval at H2 → promoted to `.claude/skills/<name>/SKILL.md` with `version: 1.0.0`
5. Entry here marked `status: synthesized` with link to skill file
