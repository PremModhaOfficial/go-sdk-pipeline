# Provenance

Historical record of what was ported from `motadata-ai-pipeline-ARCHIVE/` and how. **All ported content is INLINED in this repo** — the pipeline has zero runtime dependency on the archive. Archive HEAD SHA at port time: `b245309811405b96ac6bb360ecb9831ae6530b1c` (branch `main`, short: `b2453098`).

## Porting policy

- **Ported verbatim** — archive body inlined byte-for-byte under frontmatter. `<!-- ported-from: <archive-path> @ b2453098 -->` marker added.
- **Ported with delta** — archive body inlined under `## Archive canonical body`; SDK-pipeline changes preserved as a preceding section (versioned via `version: X.Y.Z` frontmatter + `evolution-log.md`).
- **Inspired / rewritten** — archive was reference only; new file authored from scratch for SDK context.
- **NEW** — no archive counterpart; created for this pipeline.

## Runtime independence

- No agent or skill reads `$ARCHIVE_PATH` at runtime.
- `scripts/verify-provenance.sh` (maintenance-only) takes the archive path as an argument, runs `diff` between inlined files and their archive source, flags drift. Never invoked during a pipeline run.
- If the archive dir is deleted, the pipeline still functions end-to-end.

## Guides

| File | Status | Archive source | Delta |
|------|--------|----------------|-------|
| `SKILL-CREATION-GUIDE.md` | Ported with delta | `SKILL-CREATION-GUIDE.md` | Add `version:` frontmatter requirement; `evolution-log.md` sibling requirement; drop multi-tenancy-mandatory clause |
| `AGENT-CREATION-GUIDE.md` | Ported with delta | `AGENT-CREATION-GUIDE.md` | Same 9 required sections; drop frontend/NATS wave references |
| `CLAUDE.md` | Ported with delta | `CLAUDE.md` | Rules 1–13 verbatim, 6/14/16 rewritten, 15 dropped, 17–30 new |

## Agents (11 ported, all inlined)

Every file below is a full inline port: the archive body lives under `## Archive canonical body`, and any SDK-specific adaptations live under `## SDK-pipeline adaptations`.

| New path | Archive path | Status |
|---|---|---|
| `.claude/agents/learning-engine.md` | `.claude/agents/learning-engine.md` | Ported with delta (skill-version-bump responsibility, halt-on-golden-regression, path rebase) |
| `.claude/agents/improvement-planner.md` | same | Ported with delta (add skill-drift + coverage inputs) |
| `.claude/agents/baseline-manager.md` | same | Ported with delta (drop event-driven-compliance baseline; add skill-health dim) |
| `.claude/agents/metrics-collector.md` | same | Ported with delta (drop frontend-metrics branch) |
| `.claude/agents/phase-retrospector.md` | same | Ported verbatim |
| `.claude/agents/root-cause-tracer.md` | same | Ported verbatim |
| `.claude/agents/defect-analyzer.md` | same | Ported verbatim |
| `.claude/agents/refactoring-agent.md` | same | Ported verbatim |
| `.claude/agents/documentation-agent.md` | same | Ported verbatim |
| `.claude/agents/code-reviewer.md` | same | Ported verbatim |
| `.claude/agents/guardrail-validator.md` | same | Ported with delta (extended checks list to G01–G103) |

## Skills (21 ported, all inlined)

| New path | Status | Frontmatter version | Delta summary |
|---|---|---|---|
| `go-concurrency-patterns` | Ported verbatim | 1.0.0 | — |
| `go-error-handling-patterns` | Ported verbatim | 1.0.0 | — |
| `go-struct-interface-design` | Ported verbatim | 1.0.0 | — |
| `mock-patterns` | Ported verbatim | 1.0.0 | — |
| `otel-instrumentation` | Ported verbatim | 1.0.0 | — |
| `testcontainers-setup` | Ported verbatim | 1.0.0 | — |
| `testing-patterns` | Ported verbatim | 1.0.0 | — |
| `table-driven-tests` | Ported verbatim | 1.0.0 | — |
| `tdd-patterns` | Ported verbatim | 1.0.0 | — |
| `fuzz-patterns` | Ported verbatim | 1.0.0 | — |
| `go-hexagonal-architecture` | Ported verbatim | 1.0.0 | — |
| `go-module-paths` | Ported verbatim | 1.0.0 | — |
| `review-fix-protocol` | Ported verbatim | 1.0.0 | — |
| `lifecycle-events` | Ported verbatim | 1.0.0 | — |
| `context-summary-writing` | Ported verbatim | 1.0.0 | — |
| `conflict-resolution` | Ported verbatim | 1.0.0 | SDK phase-lead role mapping note added |
| `feedback-analysis` | Ported verbatim | 1.0.0 | New input streams: `skill-evolution`, `budget` |
| `environment-prerequisites-check` | Ported verbatim | 1.0.0 | SDK tool additions (govulncheck, osv-scanner, staticcheck, benchstat, Docker, jq, git) |
| `spec-driven-development` | Ported verbatim | 1.0.0 | TPRD re-scope (stories → FRs, symbol-traceability markers) |
| `decision-logging` | Ported with delta | 1.1.0 | New types: `skill-evolution`, `budget`; new required envelope fields `pipeline_version`, `skill_version_snapshot` |
| `guardrail-validation` | Ported with delta | 1.1.0 | Extended 28-check catalog to G01–G103; inverted multi-tenancy checks; dropped SQL/migration/inter-service checks; added supply-chain, bench, marker guardrails |

## Skills to synthesize on first use (Phase -1)

Skeletons live under `.claude/skills/<name>/SKILL.md` with `status: draft`. First Phase -1 that touches the domain fleshes them out.

**MUST** (synthesized before first real run): `go-dependency-vetting`, `sdk-semver-governance`, `network-error-classification`, `context-deadline-patterns`, `connection-pool-tuning`, `goroutine-leak-prevention`, `client-shutdown-lifecycle`, `sdk-config-struct-pattern`, `sdk-otel-hook-integration`, `sdk-marker-protocol`.

**SHOULD** (synthesized per-request when applicable): `idempotent-retry-safety`, `client-tls-configuration`, `credential-provider-pattern`, `backpressure-flow-control`, `client-rate-limiting`, `api-ergonomics-audit`, `client-mock-strategy`, `go-example-function-patterns`, `circuit-breaker-policy`.

## NEW (no archive counterpart)

- `phases/BOOTSTRAP-PHASE.md` — Phase -1 (skill-bootstrap)
- `phases/INTAKE-PHASE.md` — TPRD canonicalization
- `phases/DESIGN-PHASE.md` — Design + devil review
- `phases/IMPLEMENTATION-PHASE.md` — TDD + marker-aware merge
- `phases/TESTING-PHASE.md` — Unit/integration/bench/leak
- `phases/FEEDBACK-PHASE.md` — Drift + golden + evolution
- `commands/run-sdk-addition.md` — Slash command
- `docs/MISSING-SKILLS-BACKLOG.md` — 23 gaps seeded from recon
- `docs/verify-provenance.md` — Maintainer spec
- `golden-corpus/README.md`
- `evolution/README.md`
- `baselines/*.json` (quality / coverage / performance / skill-health)
- `scripts/guardrails/*.sh` (mechanical checks G01–G103)
- `scripts/verify-provenance.sh` (maintainer provenance diff)
- All `sdk-*` agents: bootstrap-lead, intake-agent, skill-auditor, skill-synthesizer, skill-devil, skill-convention-aligner, agent-bootstrapper, agent-devil, design-lead, design-devil, dep-vet-devil, semver-devil, convention-devil, security-devil, overengineering-critic, leak-hunter, api-ergonomics-devil, impl-lead, testing-lead, integration-flake-hunter, benchmark-devil, skill-drift-detector, skill-coverage-reporter, golden-regression-runner, existing-api-analyzer, breaking-change-devil, marker-scanner, constraint-devil, merge-planner, marker-hygiene-devil

## Porting decision rationale

**Why inline instead of reference-at-runtime?**

- Pipeline independence: no coupling to a repo that may be deleted, renamed, or version-drifted
- Reproducibility: every run at `pipeline_version: X.Y.Z` has a frozen snapshot of every prescription
- Auditability: a single-file read tells the whole story of what an agent / skill says
- Evolution: learning-engine patches touch inline content under `## SDK-pipeline adaptations` (or skill bodies) — no back-reference required
- Tradeoff: archive updates no longer auto-propagate. Mitigation: `scripts/verify-provenance.sh <archive-path>` run manually before cutting a new `pipeline_version`
