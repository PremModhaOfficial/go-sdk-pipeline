# Improvements over the reference archive

What this NFR-driven pipeline adds on top of the original SaaS multi-agent fleet (the reference pipeline used as a starting point). Everything below is **new code, new files, or a new contract** — not a port. Ports (the 11 feedback-track agents and 21 generic Go/test skills) are intentionally not re-listed here.

---

## Concept-level additions (NEW)

| New thing | What it is | Why it matters |
|---|---|---|
| **TPRD as single contract** | Detailed spec with 14 sections + `§Skills-Manifest` + `§Guardrails-Manifest` | Pipeline contract is a file, not a chat |
| **Skills-Manifest validation** (Wave I2) | Intake-time check that declared skills exist at ≥ required version | Catches missing skills before design starts (WARN, non-blocking) |
| **Guardrails-Manifest validation** (Wave I3) | Intake-time check that declared G-id has executable script | Hard-blocks runs against unimplemented checks |
| **Code provenance markers** | `[traces-to:]`, `[constraint:]`, `[stable-since:]`, `[deprecated-in:]`, `[do-not-regenerate]`, `[owned-by:]` | Machine-readable lineage; enables Mode B/C |
| **Mode A / B / C** | Greenfield / extension / incremental update | Same pipeline, three intent shapes |
| **Marker-aware 3-way merge** | `sdk-merge-planner` preserves MANUAL regions byte-for-byte | Safe Mode C edits |
| **Target-dir discipline** | Writes only to `$SDK_TARGET_DIR` + `runs/` (G07) | Pipeline can't escape its sandbox |
| **Branch-based safety** | Always `sdk-pipeline/<run-id>` branch; never main; no force-push | No accidental prod commits |
| **Determinism rule** | Same TPRD + same `pipeline_version` + same `--seed` → byte-equivalent | Variance is a learning signal |
| **Dry-run mode** | `--dry-run` blocks all target writes; emits `preview.md` | Risk-free preview |
| **Golden-corpus regression** | `sdk-golden-regression-runner` re-runs canonical fixtures every Phase 4 | Halt auto-patch on regression |
| **NFR-driven framing** | TPRD §5 NFR + §10 Perf Targets + §11 Bench are first-class numeric gates | Quality is a contract, not afterthought |
| **Per-skill versioning** | `version: X.Y.Z` frontmatter + `evolution-log.md` sibling | Every skill change is auditable |
| **Human-only skill authorship** | `learning-engine` patches existing bodies only; never creates new SKILL.md | New skills require human PR |
| **Pipeline versioning** | `pipeline_version: 0.2.0` stamped on every log entry + run | Cross-run reproducibility anchor |
| **Supply-chain gate** | `govulncheck` + `osv-scanner` + license allowlist (G32–G34) | No vulnerable / unfree deps |
| **Two slash commands** | `/run-sdk-addition`, `/preflight-tprd` | Single entry point + risk-free check |

---

## Component count delta

| Item | Reference fleet (approx) | SDK pipeline | Δ |
|---|---:|---:|---:|
| Phases | 4 (architecture, detailed-design, implementation, testing) | **5** (intake + 0.5 + design + impl + testing + feedback) | +1 + intake/feedback re-scoped |
| Agents | 11 ported | **34** | **+23 new SDK-specific** |
| Skills | 21 ported | **40** + 8 candidates | **+19 new** |
| Guardrails | 28 checks | **38** scripts (G01–G103 catalog) | +10 implemented; catalog grew by ~75 |
| Slash commands | n/a (microservice flow) | **2** | +2 |
| HITL gates | broader, less explicit | **7** explicit (H0/H1/H5/H7/H7b/H9/H10) | restructured |
| Per-run scratch dirs | 1 | **6** (`intake/extension/design/impl/testing/feedback`) | structured |
| Baseline files | 3 (quality, coverage, perf) | **6** (+ skill-health, do-not-regenerate-hashes, stable-signatures) | +3 |

---

## NEW agents (23 SDK-specific, all written from scratch)

| Group | Agents | Count |
|---|---|---:|
| **Phase leads** | `sdk-intake-agent`, `sdk-design-lead`, `sdk-impl-lead`, `sdk-testing-lead` | 4 |
| **Design devils** | `sdk-design-devil`, `sdk-dep-vet-devil`, `sdk-semver-devil`, `sdk-convention-devil`, `sdk-security-devil`, `sdk-api-ergonomics-devil`, `sdk-overengineering-critic` | 7 |
| **Impl devils** | `sdk-marker-hygiene-devil`, `sdk-constraint-devil`, `sdk-leak-hunter` | 3 |
| **Testing devils** | `sdk-benchmark-devil`, `sdk-integration-flake-hunter` | 2 |
| **Feedback monitors** | `sdk-skill-drift-detector`, `sdk-skill-coverage-reporter`, `sdk-golden-regression-runner` | 3 |
| **Mode B/C helpers** | `sdk-existing-api-analyzer`, `sdk-marker-scanner`, `sdk-merge-planner`, `sdk-breaking-change-devil` | 4 |

(Reference-fleet ports retained: `learning-engine`, `improvement-planner`, `baseline-manager`, `metrics-collector`, `phase-retrospector`, `root-cause-tracer`, `defect-analyzer`, `refactoring-agent`, `documentation-agent`, `code-reviewer`, `guardrail-validator` — 11 ported.)

---

## NEW skills (19 SDK-native, all written from scratch)

| Domain | Skills | Count |
|---|---|---:|
| **SDK conventions** | `sdk-config-struct-pattern`, `sdk-otel-hook-integration`, `sdk-marker-protocol`, `sdk-semver-governance` | 4 |
| **Client patterns** | `network-error-classification`, `client-shutdown-lifecycle`, `client-tls-configuration`, `credential-provider-pattern`, `client-rate-limiting`, `client-mock-strategy` | 6 |
| **Resilience** | `circuit-breaker-policy`, `idempotent-retry-safety`, `backpressure-flow-control`, `context-deadline-patterns` | 4 |
| **Pool / leak / perf** | `connection-pool-tuning`, `goroutine-leak-prevention` | 2 |
| **Supply chain / docs** | `go-dependency-vetting`, `go-example-function-patterns`, `api-ergonomics-audit` | 3 |

---

## NEW guardrails (10 implemented + ~75 catalog entries new)

| ID | Phase | What it checks |
|---|---|---|
| G02 | universal | decision-log entry-limit |
| G03 | universal | run-manifest schema |
| G07 | impl | target-dir discipline |
| G20–G24 | intake | TPRD completeness, Non-Goals, clarification info, **Skills-Manifest**, **Guardrails-Manifest** |
| G32, G33, G34 | design | govulncheck, osv-scanner, license allowlist |
| G38 | design | sentinel-only error model |
| G48 | impl | no `ErrNotImplemented` / `TODO` |
| G63 | testing | `goleak.VerifyTestMain` clean |
| G65 | testing | bench regression (>5% hot / >10% shared) |
| G69 | testing | credential hygiene |
| G82 | feedback | golden-corpus regression PASS |
| G90 | meta | skill-index ↔ filesystem consistency |
| G93 | meta | settings.json schema |
| **G95–G103** | impl | **complete marker-protocol enforcement** (9 checks) |

---

## NEW infrastructure files (none of these existed in the reference fleet)

| File | Purpose |
|---|---|
| `phases/INTAKE-PHASE.md` | 7-wave intake with manifest validation |
| `phases/DESIGN-PHASE.md` | Devil-driven design |
| `phases/IMPLEMENTATION-PHASE.md` | TDD + marker-aware merge |
| `phases/TESTING-PHASE.md` | Unit+integration+bench+leak+fuzz |
| `phases/FEEDBACK-PHASE.md` | 9 waves; learning-engine narrowed |
| `commands/run-sdk-addition.md` | Slash command |
| `commands/preflight-tprd.md` | Risk-free TPRD check |
| `LIFECYCLE.md` | Operator manual |
| `docs/PROPOSED-SKILLS.md` | Human-review backlog |
| `evolution/skill-candidates/` | Inbox for human-promote |
| `golden-corpus/` | Per-skill canonical fixtures |
| `baselines/skill-health.json` | NEW pipeline-maturity dimension |
| `baselines/do-not-regenerate-hashes.json` | NEW (G100 backing store) |
| `baselines/stable-signatures.json` | NEW (G101 backing store) |
| `state/ownership-cache.json` | Target-SDK marker ownership map |

---

## Self-evolution rules tightened vs. reference

| Cap | Reference fleet | SDK pipeline |
|---|---:|---:|
| New skills per run (auto) | ≤ 3 | **0** (human PR only) |
| New guardrails per run (auto) | ≤ 2 | **0** |
| New agents per run (auto) | ≤ 2 | **0** |
| Existing-skill body patches per run | n/a | **≤ 3** (golden-gated) |
| Prompt patches per run | ≤ 10 | **≤ 10** (unchanged) |
| Golden-corpus gate | n/a | **REQUIRED** before any patch sticks |

---

## What we DROPPED from the reference (re-scope)

| Dropped | Why |
|---|---|
| Frontend / full-stack waves | SDK is a Go library, no UI |
| Microservice decomposition | Single SDK, no services |
| Inter-service NATS/HTTP enforcement | SDK is the library, not the broker |
| Multi-tenancy mandates (`tenant_id` columns, schema-per-tenant) | Tenant context is caller-supplied |
| SQL / database-architect agents | No DB layer in SDK |
| API Gateway / OpenAPI specs | No gateway |
| Bootstrap phase (Phase -1) | Skills/agents now human-authored statically |
| 7 bootstrap agents (sdk-bootstrap-lead, skill-{auditor,synthesizer,convention-aligner,devil}, agent-{bootstrapper,devil}) | Same |
| HITL gates H2 + H3 (skill / agent approval) | Same |
| `--auto-approve-bootstrap` CLI flag | Same |

---

## TL;DR

**+23 agents · +19 skills · +10 implemented guardrails (catalog grew ~75 entries) · +2 commands · +1 phase (Intake re-scoped) · all marker-protocol mechanics · all manifest validation · NFR-as-contract framing · golden-corpus gate · branch safety · determinism rule · human-only skill governance.**

The reference provided 11 feedback-track agents + 21 generic Go/test skills. Everything SDK-specific (Mode B/C, markers, manifests, devils, NFR gates, intake, leads) is **new**.
