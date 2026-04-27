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
| **Pipeline versioning** | `pipeline_version: 0.4.0` stamped on every log entry + run | Cross-run reproducibility anchor |
| **Supply-chain gate** | `govulncheck` + `osv-scanner` + license allowlist (G32–G34) | No vulnerable / unfree deps |
| **Two slash commands** | `/run-sdk-addition`, `/preflight-tprd` | Single entry point + risk-free check |

---

## Component count delta

| Item | Reference fleet (approx) | SDK pipeline | Δ |
|---|---:|---:|---:|
| Phases | 4 (architecture, detailed-design, implementation, testing) | **5** (intake + 0.5 + design + impl + testing + feedback) | +1 + intake/feedback re-scoped |
| Agents | 11 ported | **38** | **+27 new SDK-specific** (23 v0.2.0 + 5 v0.3.0 perf/drift) |
| Skills | 21 ported | **41** (20 SDK-native + 21 generic/meta/mcp) | **+20 new** |
| Guardrails | 28 checks | **52** scripts (G01–G116 catalog) | +24 implemented; catalog grew significantly |
| Slash commands | n/a (microservice flow) | **2** | +2 |
| HITL gates | broader, less explicit | **7** explicit (H0/H1/H5/H7/H7b/H9/H10) | restructured |
| Per-run scratch dirs | 1 | **6** (`intake/extension/design/impl/testing/feedback`) | structured |
| Baseline files | 3 (quality, coverage, perf) | **10** (+ skill-health, skill-health-baselines, do-not-regenerate-hashes, stable-signatures, output-shape-history, devil-verdict-history, baseline-history) | +7 |

---

## NEW agents (27 SDK-specific, all written from scratch)

| Group | Agents | Count |
|---|---|---:|
| **Phase leads** | `sdk-intake-agent`, `sdk-design-lead`, `sdk-impl-lead`, `sdk-testing-lead` | 4 |
| **Design devils** | `sdk-design-devil`, `sdk-dep-vet-devil`, `sdk-semver-devil`, `sdk-convention-devil`, `sdk-security-devil`, `sdk-api-ergonomics-devil`, `sdk-overengineering-critic` | 7 |
| **Impl devils** | `sdk-marker-hygiene-devil`, `sdk-constraint-devil`, `sdk-leak-hunter` | 3 |
| **Testing devils** | `sdk-benchmark-devil`, `sdk-integration-flake-hunter` | 2 |
| **Feedback monitors** | `sdk-skill-drift-detector`, `sdk-skill-coverage-reporter`, `sdk-golden-regression-runner` (retired; see DEPRECATED.md) | 2 active |
| **Mode B/C helpers** | `sdk-existing-api-analyzer`, `sdk-marker-scanner`, `sdk-merge-planner`, `sdk-breaking-change-devil` | 4 |
| **Perf / drift specialists (v0.3.0)** | `sdk-perf-architect`, `sdk-profile-auditor`, `sdk-complexity-devil`, `sdk-soak-runner`, `sdk-drift-detector` | 5 |

(Reference-fleet ports retained: `learning-engine`, `improvement-planner`, `baseline-manager`, `metrics-collector`, `phase-retrospector`, `root-cause-tracer`, `defect-analyzer`, `refactoring-agent`, `documentation-agent`, `code-reviewer`, `guardrail-validator` — 11 ported.)

---

## NEW skills (20 SDK-native written from scratch + 1 MCP integration)

All 19 `sdk_native` entries shipped as skeleton placeholders in v0.2.0 (frontmatter + "synthesize on Phase -1 use" body text). Phase -1 was removed in commit `b28405a` before those bodies were ever synthesized, leaving the skills as non-functional stubs that passed `G23` (skill-index name match) but contributed nothing at runtime. **v0.3.0 straighten authored the real body for all 19 in a single pass** (commit range listed in `evolution/evolution-reports/pipeline-v0.3.0.md`). Each is now `version: 1.0.0 status: stable authored-in: v0.3.0-straighten` with ≥3 GOOD + ≥3 BAD code examples drawn from the target SDK, decision criteria, cross-references, and guardrail hooks.

| Domain | Skills | Count |
|---|---|---:|
| **SDK conventions** | `sdk-config-struct-pattern`†, `sdk-otel-hook-integration`†, `sdk-marker-protocol`†, `sdk-semver-governance`† | 4 |
| **Client patterns** | `network-error-classification`†, `client-shutdown-lifecycle`†, `client-tls-configuration`†, `credential-provider-pattern`†, `client-rate-limiting`†, `client-mock-strategy`† | 6 |
| **Resilience** | `circuit-breaker-policy`†, `idempotent-retry-safety`†, `backpressure-flow-control`†, `context-deadline-patterns`† | 4 |
| **Pool / leak / perf** | `connection-pool-tuning`†, `goroutine-leak-prevention`† | 2 |
| **Supply chain / docs** | `go-dependency-vetting`†, `go-example-function-patterns`†, `api-ergonomics-audit`† | 3 |

† All 19 authored in v0.3.0 straighten (2026-04-24). Prior to that, each file contained only the bootstrap-seed skeleton "will be synthesized on first Phase -1 use" — drift since Phase -1 removal in commit `b28405a`. The straighten pass replaced each skeleton with a real body backed by code read from `motadata-go-sdk/src/motadatagosdk/`.

### v0.3.0 skill additions

| Domain | Skills | Count |
|---|---|---:|
| **MCP integration (v0.3.0)** | `mcp-knowledge-graph` | 1 |
| **Updated for v0.3.0** | `environment-prerequisites-check` (v1.0.0 → v1.1.0 — MCP reachability probe) | 1 |

---

## NEW guardrails (23 implemented + ~75 catalog entries new)

| ID | Phase | What it checks |
|---|---|---|
| G02 | universal | decision-log entry-limit |
| G03 | universal | run-manifest schema |
| **G04** | universal | MCP health check (WARN-only; writes `mcp-health.md`) (v0.3.0) |
| **G06** | intake | `pipeline_version` consistency across repo (v0.3.0 straighten) |
| G07 | impl | target-dir discipline |
| G20–G24 | intake | TPRD completeness, Non-Goals, clarification info, **Skills-Manifest**, **Guardrails-Manifest** |
| G32, G33, G34 | design | govulncheck, osv-scanner, license allowlist |
| G38 | design | sentinel-only error model |
| G48 | impl | no `ErrNotImplemented` / `TODO` |
| G63 | testing | `goleak.VerifyTestMain` clean |
| G65 | testing | bench regression (>5% hot / >10% shared) |
| G69 | testing | credential hygiene |
| G82 | feedback | golden-corpus regression PASS (retired in v0.3.0; see DEPRECATED.md) |
| **G85** | feedback | `learning-notifications.md` written on any patch (v0.3.0) |
| **G86** | feedback | quality regression BLOCKER at 5% once ≥3 prior runs (v0.3.0) |
| G90 | meta | skill-index ↔ filesystem **strict equality** (tightened v0.3.0) |
| G93 | meta | settings.json schema |
| **G95–G103** | impl | **complete marker-protocol enforcement** (9 checks) |
| **G104** | testing | alloc budget — measured `allocs/op` ≤ declared (v0.3.0) |
| **G105** | testing | soak MMD — `actual_duration_s ≥ mmd_seconds` or INCOMPLETE (v0.3.0) |
| **G106** | testing | drift fail-fast — no positive trend on declared signals (v0.3.0) |
| **G107** | testing | big-O scaling match at N ∈ {10, 100, 1k, 10k} (v0.3.0) |
| **G108** | testing | oracle margin — p50 ≤ `margin × reference impl`; not waivable (v0.3.0) |
| **G109** | impl | profile-shape — top-10 CPU samples ≥ 0.8 match hot paths (v0.3.0) |
| **G110** | impl | `[perf-exception:]` marker ↔ `perf-exceptions.md` pairing (v0.3.0) |
| **G116** | intake | retired-term scanner — DEPRECATED.md terms absent from live docs (v0.3.0 straighten) |

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
| `baselines/shared/skill-health.json` | NEW pipeline-maturity dimension |
| `baselines/go/do-not-regenerate-hashes.json` | NEW (G100 backing store) |
| `baselines/go/stable-signatures.json` | NEW (G101 backing store) |
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

---

## MCP Integration (v0.3.0 — in progress on `mcp-enhanced-graph` branch)

Cross-run state moves from flat JSONL under `evolution/knowledge-base/` to a queryable Neo4j graph via `mcp__neo4j-memory__*`. JSONL remains authoritative fallback; pipeline never halts on MCP failure.

### What changed

| Item | Kind | Detail |
|---|---|---|
| `mcp-knowledge-graph` | **NEW skill (v1.0.0)** | Canonical read/write + fallback pattern for all MCP-aware agents |
| `environment-prerequisites-check` | **Updated skill** | v1.0.0 → v1.1.0 (adds MCP reachability probe) |
| `learning-engine`, `improvement-planner`, `root-cause-tracer`, `metrics-collector`, `baseline-manager` | **5 agents updated** | MCP-aware sections appended; JSONL fallback preserved |
| **G04** | **NEW guardrail** | MCP health check at phase start (WARN-only; writes `runs/<id>/<phase>/mcp-health.md`) |
| `docs/MCP-INTEGRATION-PROPOSAL.md` | **NEW doc** | Scope + rollout (0.3.0 → 0.5.0) |
| `docs/NEO4J-KNOWLEDGE-GRAPH.md` | **NEW doc** | Graph schema + canonical Cypher |
| `scripts/migrate-jsonl-to-neo4j.py` | **NEW script** | Backfills graph from JSONL on next healthy run |
| `CLAUDE.md` rule 31 | **NEW rule** | MCP Fallback Policy |
| `AGENTS.md` | **Updated** | New **MCPs used** column in Ownership Matrix |

### Fallback guarantee

Every MCP is an enhancement, not a correctness dependency. On `mcp__neo4j-memory__*` (or any MCP) unavailability, agents degrade to JSONL / Grep / text-based paths with a WARN log entry. Pipeline never halts. Golden-corpus gate unaffected. See `CLAUDE.md` rule 31.
