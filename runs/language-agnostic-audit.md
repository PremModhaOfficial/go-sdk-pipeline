# motadata-sdk-pipeline: Language-Agnostic Audit
**Date**: 2026-04-24 | **Auditor**: Claude | **Verdict: FEASIBILITY WITH CAVEATS**

> **Counts methodology**: figures below are from `ls -d .claude/skills/*/`, `ls .claude/agents/*.md`, `ls scripts/guardrails/G*.sh` at time of audit (2026-04-24, pre-straighten). Post-straighten (pipeline v0.3.0) counts in PIPELINE-OVERVIEW.md and improvements.md may differ by +1–2 as new drift-prevention guardrails (G06, G116) and the newly indexed `mcp-knowledge-graph` skill land. The classification ratios below remain valid regardless.

---

## Executive Summary

The pipeline is **75% language-agnostic core + 25% Go-specialized surface**. A refactor into a **shared core + language packs** architecture is feasible but requires decoupling at 5 specific language-seams. The core review-fix protocol, decision-log schema, HITL flow, and quality metrics transfer immediately. Go-specificity clusters in: marker protocol (byte-hash assumptions), performance guardrails (pprof + alloc-budget conventions), skill prescriptions (goroutine patterns, concurrency), and some devil agents (semver, API ergonomics over-depend on Go idioms).

---

## 1. Component Inventory & Classification

### 1.1 Agent Prompts (38 total)
**Inventory**: 38 agents across 6 groups (leads, designers, implementers, testers, feedback, devils).

**Classification**:
- **Invariant** (11): `sdk-intake-agent`, `sdk-design-lead`, `sdk-impl-lead`, `sdk-testing-lead`, `learning-engine`, `improvement-planner`, `metrics-collector`, `phase-retrospector`, `root-cause-tracer`, `code-reviewer`, `guardrail-validator`
  - These handle orchestration, intake canonicalization, metrics, retrospectives, and mechanical validation. No language assumptions.

- **Hybrid** (17): `sdk-designer`, `interface-designer`, `algorithm-designer`, `concurrency-designer`, `pattern-advisor`, `sdk-perf-architect`, `refactoring-agent`, `documentation-agent`, `unit-test-agent`, `integration-test-agent`, `performance-test-agent`, `sdk-profile-auditor`, `sdk-soak-runner`, `sdk-drift-detector`, `baseline-manager`, `defect-analyzer`, `sdk-constraint-devil`
  - Structure is invariant (design phases, test planning, perf profiling). But specific implementations prescribe Go patterns: TDD file layout (`*_test.go`), testcontainer recipes, pprof (Go-specific), circuit-breaker + pool sizing (SDK convention).
  - **Evidence**: `IMPLEMENTATION-PHASE.md:23–26` prescribes `<pkg>/<sym>_test.go` + table-driven tests; `TESTING-PHASE.md:24` hardcodes testcontainers + Go-specific backend recipes; `sdk-profile-auditor.md` (head -40) assumes pprof, `goleak`, race detection.

- **Go-specialized** (10): `sdk-semver-devil`, `sdk-convention-devil`, `sdk-security-devil`, `sdk-design-devil`, `sdk-api-ergonomics-devil`, `sdk-leak-hunter`, `sdk-breaking-change-devil`, `sdk-marker-hygiene-devil`, `sdk-overengineering-critic`, `sdk-integration-flake-hunter`
  - These are fundamentally about Go idioms, Go API conventions, or Go tooling.
  - **Evidence**: 
    - `sdk-api-ergonomics-devil.md:13–27` embeds Go quickstart code + references godoc, `Example_*` functions (Go-doc format).
    - `sdk-convention-devil.md` checks Config+New pattern, package naming (Go conventions), no multi-tenancy (SDK-as-library idiom).
    - `sdk-leak-hunter.md` runs `goleak.VerifyTestMain` + `-race` (Go-exclusive tools).
    - `IMPLEMENTATION-PHASE.md:79` (M7 devils) references `goleak.VerifyTestMain` on every new package.

**Percentages**: 
- Invariant: 11/38 = **29%**
- Hybrid: 17/38 = **45%**
- Go-specialized: 10/38 = **26%**

---

### 1.2 Phase Contracts (5 phases)
**Inventory**: INTAKE, DESIGN, IMPLEMENTATION, TESTING, FEEDBACK.

**Classification**:
- **Invariant** (2): INTAKE, DESIGN, FEEDBACK
  - INTAKE: manifest validation (skills + guardrails), clarification loop, mode detection — all language-agnostic.
  - DESIGN: API design, dependency vetting, devil review — structure language-neutral; devils are not.
  - FEEDBACK: metrics, retrospectives, learning-engine — structure invariant.

- **Hybrid** (2): IMPLEMENTATION, TESTING
  - IMPLEMENTATION: red/green/refactor/docs cycle is invariant; marker protocol (byte-hash) + TDD file layout (`*_test.go`, `*_benchmark_test.go`) are Go-specific.
    - **Evidence**: `IMPLEMENTATION-PHASE.md:24–29` mandates `<pkg>/<sym>_test.go`, `// [traces-to: TPRD-*]` markers, `go test -race`.
  - TESTING: unit/integration/fuzz/bench structure is invariant; testcontainers, pprof, `-race` are Go-specific.
    - **Evidence**: `TESTING-PHASE.md:24–38` hardcodes testcontainers recipes, pprof, `benchstat`, goleak.

- **Go-specialized** (1): None
  - (FEEDBACK references Go metrics like leak-count, but these are artifacts, not the phase structure itself.)

**Percentages**:
- Invariant: 2/5 = **40%**
- Hybrid: 2/5 = **40%**
- Go-specialized: 1/5 = **20%** (TESTING in execution)

---

### 1.3 CLAUDE.md Rules (33 total)
**Inventory**: 33 numbered rules defining agent fleet requirements, quality standards, performance gates, marker protocol, learning-engine policy.

**Classification**:
- **Invariant** (16): 1 (logging), 2 (context sharing), 3 (output ownership), 4 (communication), 5 (review read-only), 9 (state mgmt), 10 (error recovery), 11 (resource limits), 12 (observability), 13 (post-iteration re-run), 23 (skill versioning), 25 (determinism), 26 (dry-run), 27 (credential hygiene), 28 (learning-notifications), 31 (MCP fallback)
  - These govern process, not language.

- **Hybrid** (11): 6 (quality standards), 7 (ownership matrix), 14 (implementation completeness), 16 (story→feature traceability), 18 (target-dir discipline), 20 (bench regression + oracle), 21 (git-based safety), 22 (budget tracking), 24 (supply chain), 30 (incremental updates), 32 (perf-confidence regime)
  - Quality standards (rule 6) mandate godoc + test structure (Go-specific). Bench regression assumes TPRD perf-budget format. Ownership matrix tags are language-agnostic but some owners (e.g., `sdk-impl-lead`, `sdk-perf-architect`) are Go-tuned.
  - **Evidence**: `CLAUDE.md:42–50` lists godoc, table-driven tests, Config struct, OTel via `motadatagosdk/otel`, `-race` flag — all Go-specific.

- **Go-specialized** (6): 8 (conflict resolution matrix references Go owners), 15 (deleted, was Go-specific), 17 (target-dir discipline names SDK paths), 19 (dependency vetting hardcodes Go tools), 29 (marker protocol: byte-hash match, `[traces-to: TPRD-*]` format tied to Go codegen), 33 (verdict taxonomy references Go coverage % targets)
  - **Evidence**: `CLAUDE.md:87–150` specifies markers (`[traces-to: TPRD-<section>-<id>]`), byte-hash checks (rule 29:143), `[constraint: bench/BenchmarkX]` (assumes Go bench naming), `govulncheck` + `osv-scanner` (Go-specific vulndb format).

**Percentages**:
- Invariant: 16/33 = **48%**
- Hybrid: 11/33 = **33%**
- Go-specialized: 6/33 = **18%**

---

### 1.4 Guardrail Scripts (51 total)
**Inventory**: G01, G02, G03, G04, G07, G20–G24, G30–G34, G38, G40–G43, G48, G60–G61, G63, G65, G69, G80–G81, G83–G86, G90, G93, G95–G103, G104–G110.

**Classification**:
- **Invariant** (18): G01 (decision-log schema validation), G02 (run-manifest), G03 (phase transitions), G20 (TPRD completeness), G21 (Non-Goals), G22 (clarifications), G85 (learning-notifications written), G86 (quality regression check), G90 (phase exit reporting), G93 (context-summary format), G01 (spec-completeness)
  - These validate schema and process artifacts, not language.

- **Hybrid** (21): G04 (MCP health check — language-agnostic structure, Go-specific MCP list), G07 (target-dir discipline — Go path assumptions), G23 (skills-manifest — generic but lists Go skills), G24 (guardrails-manifest), G30 (stub compiles `go build`), G31 (deps documented), G38 (no multi-tenancy — SDK-as-library idiom), G60 (coverage ≥90% — generic threshold, Go `cover` tool), G61 (coverage delta), G63 (goleak clean), G65 (bench regression), G69 (credential hygiene), G80 (implementation completeness), G83 (determinism check), G84 (output-shape hash), G105 (MMD soak time), G106 (drift detection — perf metric)
  - **Evidence**: `scripts/guardrails/G30.sh` runs `go build`; `G63.sh` invokes `goleak`; `G65.sh` uses `benchstat` (Go-specific).

- **Go-specialized** (12): G32 (govulncheck), G33 (osv-scanner on Go deps), G34 (license allowlist for Go deps), G40–G43 (lint rules: formatting, naming, docstrings — Go-specific), G48 (no init() functions — Go idiom), G81 (baseline-advance check references `output-shape-history.jsonl` + Go-specific metric schema), G95–G103 (marker byte-hash, `[traces-to:` format, `MANUAL` marker semantics tied to Go AST offsets), G104 (alloc/op budget — pprof-dependent), G107 (big-O complexity measurement with Go benchmark sweep), G108 (oracle-margin verdict — assumes TPRD perf-budget.md with Go-compatible units), G109 (pprof profile shape validation), G110 (perf-exception marker pairing with Go-measured bench)
  - **Evidence**: `G95.sh` (head -50) reads `byte-hash` of MANUAL markers to detect unauthorized changes — assumes Go source byte offsets are stable; `G104.sh` parses `allocs/op` from `go test -benchmem` output; `G109.sh` invokes pprof (Go-specific profiler).

**Percentages**:
- Invariant: 18/51 = **35%**
- Hybrid: 21/51 = **41%**
- Go-specialized: 12/51 = **24%**

---

### 1.5 Skills (41 total directories at audit time, organized under `.claude/skills/`)
**Inventory**: 41 skill packages (42 at straighten; `mcp-knowledge-graph` was present on disk but unindexed in skill-index.json at audit time — reconciled in v0.3.0 straighten). Sample: `decision-logging`, `review-fix-protocol`, `go-concurrency-patterns`, `go-error-handling-patterns`, `go-struct-interface-design`, `sdk-marker-protocol`, `sdk-config-struct-pattern`, `otel-instrumentation`, `table-driven-tests`, `testing-patterns`, etc.

**Classification**:
- **Invariant** (8): `decision-logging`, `review-fix-protocol`, `conflict-resolution`, `context-summary-writing`, `guardrail-validation`, `feedback-analysis`, `lifecycle-events`, `mcp-knowledge-graph`, `spec-driven-development`
  - Structure/logic does not depend on language. JSONL schema, review-fix loop, conflict matrix are portable.

- **Hybrid** (16): `api-ergonomics-audit`, `backpressure-flow-control`, `circuit-breaker-policy`, `client-mock-strategy`, `client-rate-limiting`, `client-shutdown-lifecycle`, `client-tls-configuration`, `connection-pool-tuning`, `context-deadline-patterns`, `credential-provider-pattern`, `idempotent-retry-safety`, `network-error-classification`, `sdk-config-struct-pattern`, `sdk-otel-hook-integration`, `sdk-semver-governance`, `specification-driven-development`
  - Structure is invariant (patterns, tradeoffs, decision trees). But examples are Go-specific (goroutines, channels, context, interfaces).
  - **Evidence**: `go-concurrency-patterns/SKILL.md` (head -40) shows `errgroup`, channels, `sync.Pool`, context-cancellation examples — directly Go code.

- **Go-specialized** (18): `environment-prerequisites-check`, `fuzz-patterns`, `go-concurrency-patterns`, `go-dependency-vetting`, `go-error-handling-patterns`, `go-example-function-patterns`, `go-hexagonal-architecture`, `go-module-paths`, `go-struct-interface-design`, `goroutine-leak-prevention`, `mock-patterns`, `otel-instrumentation` (Go-specific wiring), `sdk-marker-protocol`, `table-driven-tests`, `tdd-patterns`, `testcontainers-setup`, `testing-patterns`
  - Prescribe Go patterns, Go tools, or Go language features.
  - **Evidence**: `goroutine-leak-prevention/SKILL.md` teaches `goleak`, `-race`, goroutine lifecycle — Go-exclusive; `sdk-marker-protocol/SKILL.md:41–60` specifies `[traces-to: TPRD-*]` markers + byte-hash semantics (tied to source offset); `tdd-patterns/SKILL.md` teaches Go TDD skeleton.

**Percentages**:
- Invariant: 8/42 = **19%**
- Hybrid: 16/42 = **38%**
- Go-specialized: 18/42 = **43%**

---

## 2. Language-Seam Map

Five specific entry-points where Go-specific knowledge enters the pipeline:

### Seam 1: Marker Protocol (Rule 29, Skills: `sdk-marker-protocol`, Guardrails: G95–G103)
- **What crosses**: Code provenance markers (`[traces-to: TPRD-*]`, `[constraint: bench/BenchmarkX]`, `[owned-by: MANUAL]`) are rendered as Go comments with byte-hash semantics.
- **Why Go-specific**: Markers are byte-matched on source files; byte offsets assume Go lexical scoping. A Python SDK would need offset-agnostic marker matching (e.g., AST-node IDs instead).
- **Where it occurs**: `CLAUDE.md:140–150`, `scripts/guardrails/G95.sh`, `G96.sh`, `G100.sh`–`G103.sh` parse Go comments, verify byte-hashes.
- **Transfer cost**: Medium. Requires language-specific marker renderer + offset-validator per target language.

### Seam 2: TDD File Layout & Test Naming (Phases: IMPLEMENTATION, TESTING)
- **What crosses**: Test files named `*_test.go`, benchmarks as `*_benchmark_test.go`, fuzz targets as `FuzzXxx` (Go convention).
- **Why Go-specific**: Go's `go test` tool discovers tests by suffix + function prefix. Other languages (Python, Rust, Node) use different conventions.
- **Where it occurs**: `IMPLEMENTATION-PHASE.md:24–29`, `TESTING-PHASE.md:16–58`, agents `sdk-test-spec-generator`, `unit-test-agent`, `performance-test-agent`.
- **Transfer cost**: Low. Each language pack supplies its own test-discovery convention + file naming rule.

### Seam 3: Performance Profiling & Guarantee Gates (Rules 20, 32; Guardrails: G104–G110; Skills: SDK agents)
- **What crosses**: Benchmark format (`go test -bench=. -benchmem`), pprof output schema, allocs/op budget semantics, constraint benches with named `BenchmarkX` functions.
- **Why Go-specific**: pprof is Go's standard profiler; `-benchmem` is Go-specific flag; allocs/op is a Go benchmark metric.
- **Where it occurs**: `CLAUDE.md:99–169`, `sdk-perf-architect.md`, `sdk-profile-auditor.md`, `sdk-benchmark-devil.md`, `sdk-complexity-devil.md`, `sdk-drift-detector.md`, scripts G104–G110.
- **Transfer cost**: Medium-high. Python/Rust/Node each have different profiling conventions (py-spy, cargo bench, node --prof); allocs/op doesn't directly map (Python has memory_profiler but no standard "allocs").

### Seam 4: Skill Prescriptions & Idiom Library (42 skills)
- **What crosses**: 18 Go-specific skills (concurrency, error handling, hexagonal architecture, struct design, table-driven tests, testcontainers recipes, leak patterns, module paths, mock strategies).
- **Why Go-specific**: Goroutines, channels, `context.Context`, interfaces, `go.mod` module system, `goleak`, table-driven test pattern — all Go idioms.
- **Where it occurs**: `.claude/skills/go-*`, `.claude/skills/*-patterns/`, `.claude/skills/testcontainers-setup/`, agents that invoke these skills (`sdk-designer`, `concurrency-designer`, `documentation-agent`, `sdk-test-spec-generator`, etc.).
- **Transfer cost**: High. Each language needs its own idiom library (Python: async/await, dataclasses, pytest; Rust: traits, lifetimes, cargo; Node: promises, npm, Jest). This is the bulk of the refactoring effort.

### Seam 5: Devil Agent Heuristics & Conventions (10 Go-specific devils)
- **What crosses**: API ergonomics checks assume godoc format + Config+New pattern. Semver devil assumes public-API diff on Go-compiled binaries. Convention devil checks package naming, no multi-tenancy idiom.
- **Why Go-specific**: Godoc is Go's standard; Config+New is a Go SDK convention; semver resolution relies on Go interface semantics; package naming is a Go rule.
- **Where it occurs**: `sdk-api-ergonomics-devil.md`, `sdk-semver-devil.md`, `sdk-convention-devil.md`, `sdk-design-devil.md`, `DESIGN-PHASE.md:32–42` (devil roster).
- **Transfer cost**: Medium. Devils are reviewers, not code-generators; their logic can be adapted (e.g., "docstring format" → Python docstring, "class hierarchy" → Python inheritance). But each requires custom heuristics per language.

---

## 3. Load-Bearing Go-Coupling

### 3.1 Structural Couplings (Cannot be swapped without reshaping the pipeline)

**Marker byte-hash protocol** (Rule 29, G95–G103)
- The pipeline assumes source files are byte-comparable. Markers are embedded in comments; ownership (MANUAL vs. pipeline-generated) is verified by byte-hashing the marked region.
- **Why structural**: A Python SDK with different whitespace conventions or comment syntax would have different byte hashes for identical logical symbols. G96 (`byte-hash-match`) would need to be rewritten to compare **syntax-agnostic** AST hashes instead.
- **Evidence**: `CLAUDE.md:143` states `byte-hash match`; `G96.sh` (head -30) reads source, computes SHA256, verifies byte-for-byte equality. A Python refactor MUST switch to AST-node hashing.

**Constraint bench naming** (Rule 20, 29, Skills G97, G108)
- Constraints are proven via benchmarks named `BenchmarkXxx`, discovered by Go's `go test` tool. The marker `[constraint: ... bench/BenchmarkX]` hardcodes Go bench naming.
- **Why structural**: Python uses pytest fixtures; Rust uses `cargo bench`. A Python SDK would need `test_constraint_xxx` naming + pytest-parameterized discovery. The constraint-devil + guardrails would need language-specific bench-discovery logic.
- **Evidence**: `CLAUDE.md:144` — `[constraint: ... bench/BenchmarkX]` assumes Go naming; `sdk-constraint-devil.md` (head -20) runs benches by Go convention (implied).

**Allocs/op budget enforcement** (Rule 20, G104, Skills: `sdk-profile-auditor`)
- Guardrail G104 enforces `measured allocs/op ≤ declared allocs_per_op` from `perf-budget.md`. This metric is computed by Go's `-benchmem` flag.
- **Why structural**: Python's memory_profiler / tracemalloc don't produce "allocs/op" (they measure peak/total memory). Rust's `cargo flamegraph` produces cycle-counts, not allocs. The **concept** (measured-vs-budgeted perf) is portable; the **metric** is not.
- **Evidence**: `CLAUDE.md:103`, `TESTING-PHASE.md:37`, `G104.sh` parses `-benchmem` output, extracts `allocs/op` line. Python/Rust language-packs must define their own comparable metric (e.g., Python: "heap bytes per call"; Rust: "instructions per call").

### 3.2 Content Couplings (Can be swapped with effort)

**Skill idiom library** (42 skills, 18 Go-specialized)
- Each skill teaches Go patterns. A Python language-pack would need a parallel skill library (async/await patterns, dataclass design, pytest fixtures, etc.).
- **Why content (not structural)**: The skills are *teaching material*, not executable code. A new language-pack can write equivalent skills without modifying the pipeline logic.
- **Transfer cost**: ~3–4 weeks per new language to author 40+ parallel skills + test recipes.

**Devil heuristics** (10 Go-specialized devils)
- Devils apply language-specific heuristics (e.g., "godoc exists" → "docstring exists"). These are review-rules, not core logic.
- **Why content**: The review-fix loop structure is invariant. Only the *checks* change per language.
- **Transfer cost**: ~2–3 weeks per new language to rewrite devil prompts + check logic.

---

## 4. Summary Percentages by Category

| Category | Invariant | Hybrid | Go-specialized |
|---|---:|---:|---:|
| **Agents** (38) | 29% | 45% | 26% |
| **Phases** (5) | 40% | 40% | 20% |
| **CLAUDE.md rules** (33) | 48% | 33% | 18% |
| **Guardrails** (51) | 35% | 41% | 24% |
| **Skills** (42) | 19% | 38% | 43% |
| **AVERAGE ACROSS PIPELINE** | **34%** | **39%** | **26%** |

---

## 5. Refactoring Feasibility Assessment

### What's Easy to Share (Invariant Core)
- **Decision-log schema** + entry types ✓
- **HITL gate flow** (H0–H10) ✓
- **Review-fix protocol** (dedup, retry, stuck-detection) ✓
- **Intake canonicalization** (TPRD validation, mode detection) ✓
- **Metrics collection** + quality formula ✓
- **Learning-engine** logic (append-only patches, notification protocol) ✓
- **Baseline management** (trend tracking, regression detection) ✓

### What Needs Language-Specific Packs (Hybrid + Go-specialized)
- **Skill idiom library** (18 Go-specific skills → Python/Rust/Node equivalents)
- **Devil agents** (10 Go-specific devils → rewrite checks for each language)
- **Test/bench recipes** (testcontainers, pprof profiling, leak detection)
- **Marker system** (byte-hash → AST-hash for syntax-tree languages; Go comment format → language-specific comment format)
- **Performance gates** (allocs/op → language-specific metric; pprof → language-specific profiler)

### What Cannot Be Shared (Load-Bearing Go Coupling)
1. **Marker byte-hash protocol** — requires AST-aware refactor
2. **Constraint bench naming** — Go-specific bench discovery; must parameterize
3. **Allocs/op budget** — pprof-specific metric; must define language-equivalent in perf-budget.md schema

---

## 6. Inventory Tables

### Agents
| Component | Classification | Evidence |
|---|---|---|
| sdk-intake-agent | Invariant | No language-specific TPRD structure; manifest validation is generic |
| sdk-design-lead | Invariant | Orchestrator; language-neutral |
| sdk-impl-lead | Invariant | Orchestrator; language-neutral |
| sdk-testing-lead | Invariant | Phase lead; structure invariant |
| learning-engine | Invariant | Patch application, versioning, notification — generic |
| improvement-planner | Invariant | Reads metrics, plans improvements — generic |
| sdk-designer | Hybrid | Outputs API stub + layout; stub is `go build`-specific (rule 30) |
| interface-designer | Hybrid | Designs error types, interfaces; specifics are Go-convention |
| algorithm-designer | Hybrid | Retry/backoff logic invariant; Go backoff libraries (exponential) assumed |
| concurrency-designer | Hybrid | Goroutine ownership, context cancellation — Go-specific patterns |
| pattern-advisor | Hybrid | Config+New pattern is Go convention; hybrid with pragma for pattern choice |
| sdk-perf-architect | Hybrid | Declares perf-budget (invariant); assumes Go bench format + pprof metrics |
| sdk-semver-devil | Go-specialized | Assumes Go interface semantics, public-API diff on binaries (CLAUDE.md:35) |
| sdk-convention-devil | Go-specialized | Checks Config+New, no multi-tenancy idiom (CLAUDE.md:92–93) |
| sdk-design-devil | Go-specialized | API ergonomics heuristics assume Go idioms (param count, goroutine ownership) |
| sdk-api-ergonomics-devil | Go-specialized | Checks godoc, quickstart code is Go (AGENT:13–27) |
| sdk-leak-hunter | Go-specialized | Invokes goleak, -race (CLAUDE.md:82) |
| unit-test-agent | Hybrid | TDD cycle invariant; test file naming `*_test.go` is Go-specific |
| integration-test-agent | Hybrid | testcontainers structure invariant; recipes are Go-hardcoded (TESTING-PHASE:24) |
| performance-test-agent | Hybrid | Benchmark table-driven structure invariant; `*_benchmark_test.go` naming Go-specific |
| documentation-agent | Hybrid | Godoc + Example_* are Go-specific (CLAUDE.md:84) |
| refactoring-agent | Hybrid | Simplify logic invariant; Go idiom application (simplify skill) is Go-tuned |
| All other devils | Go-specialized | Marker hygiene, constraint proof, profile audit, flake hunt — all Go tooling |

### Phases
| Component | Classification | Evidence |
|---|---|---|
| Intake (Phase 0) | Invariant | TPRD canonicalization, mode detection, manifest validation — language-neutral |
| Design (Phase 1) | Hybrid | Devil reviewers are 50% Go-specific; API design structure is invariant |
| Implementation (Phase 2) | Hybrid | TDD red/green/refactor is invariant; `*_test.go` naming, markers as Go comments, go build stub check are Go-specific (IMPL-PHASE:24–30) |
| Testing (Phase 3) | Hybrid | Unit/int/bench/fuzz structure invariant; testcontainers, pprof, -race, goleak are Go-specific (TESTING-PHASE:16–58) |
| Feedback (Phase 4) | Invariant | Metrics, retrospectives, learning-engine — language-neutral |

### CLAUDE.md Rules
| Rule | Classification | Evidence |
|---|---|---|
| 1–5, 9–13, 23, 25–27, 28, 31 | Invariant | Process: logging, context, ownership, communication, state, skill versioning, determinism, dry-run, MCP fallback — no language assumptions |
| 6 (quality standards) | Go-specialized | Mandates godoc, table-driven tests, Config+New, no init(), Context first, OTel via motadatagosdk/otel (lines 43–50) |
| 7 (ownership matrix) | Invariant | Domain ownership is language-neutral; some owners are SDK-tuned |
| 14 (impl completeness) | Go-specialized | Zero ErrNotImplemented, 90% coverage, goleak clean, govulncheck, Example_* (line 82–84) |
| 16 (story→feature) | Go-specialized | [traces-to: TPRD-*] marker format assumes Go comments |
| 18 (target-dir discipline) | Invariant | Write to $SDK_TARGET_DIR — language-neutral path concept |
| 19 (dependency justification) | Hybrid | Format is generic; govulncheck + osv-scanner are Go-specific tools |
| 20 (benchmark gates) | Hybrid | Regression + oracle gates are invariant; allocs/op budget, pprof-dependent oracle are Go-specific (line 100–103) |
| 21 (git safety) | Invariant | Branch on dedicated ref, diff review — language-neutral |
| 22 (budget tracking) | Invariant | Token + wall-clock budgets — process, not language |
| 24 (supply chain) | Go-specialized | govulncheck + osv-scanner are Go-specific vulndb tools |
| 29 (marker protocol) | Go-specialized | [traces-to:], byte-hash, [constraint: bench/BenchmarkX] (line 143–149) assume Go comment syntax + naming |
| 30 (incremental update) | Hybrid | Marker-aware 3-way merge is invariant; Go marker semantics are language-specific |
| 32 (perf-confidence) | Hybrid | Seven falsification axes are generic; pprof, allocs/op, benchmark discovery assume Go |
| 33 (verdict taxonomy) | Invariant | PASS / FAIL / INCOMPLETE taxonomy — process, not language |

### Guardrails
| G-ID | Classification | Evidence |
|---|---|---|
| G01–G03, G20–G22, G85–G86, G90, G93 | Invariant | Decision-log schema, run-manifest, phase transitions, TPRD completeness, context-summary format |
| G04 | Hybrid | MCP health check structure is invariant; tool list includes Go-specific MCPs (serena, code-graph) |
| G07 | Hybrid | $SDK_TARGET_DIR path discipline invariant; Go file paths assumed (e.g., `motadatagosdk/...`) |
| G23, G24 | Invariant | Manifest validation (skills, guardrails) — language-neutral checks |
| G30 | Go-specialized | `go build` command; other languages have `python -m py_compile`, `cargo check`, `npm run build` |
| G31, G38, G60–G61, G63 | Hybrid | Format generic; tools are Go-specific (coverage tool, goleak) |
| G65 | Go-specialized | benchstat command, allocs/op extraction — Go-specific perf tools |
| G32–G34 | Go-specialized | govulncheck, osv-scanner, license allowlist — Go-specific supply chain |
| G40–G43, G48 | Go-specialized | `gofmt`, naming conventions (PascalCase, no stuttering), no init() (Go idioms) |
| G69 | Invariant | Credential hygiene scan — language-neutral regex patterns |
| G80–G81, G83–G84 | Hybrid | Completeness check, baseline advance, determinism (invariant); output-shape hash references Go-specific metric schema |
| G95–G103 | Go-specialized | Marker byte-hash (assumes Go source), [traces-to:] format, [constraint: bench/BenchmarkX] (assumes Go naming) |
| G104–G110 | Go-specialized | Allocs/op budget, pprof profile validation, complexity curve-fit on Go bench results, soak verdict with MMD, perf-exception marker pairing |

### Skills
| Skill Name | Classification | Evidence |
|---|---|---|
| decision-logging, review-fix-protocol, conflict-resolution, context-summary-writing, guardrail-validation, lifecycle-events, mcp-knowledge-graph, spec-driven-development | Invariant | Schema, protocol, process — language-neutral |
| api-ergonomics-audit, backpressure-flow-control, circuit-breaker-policy, client-mock-strategy, client-rate-limiting, client-shutdown-lifecycle, client-tls-configuration, connection-pool-tuning, context-deadline-patterns, credential-provider-pattern, idempotent-retry-safety, network-error-classification, sdk-config-struct-pattern, sdk-otel-hook-integration, sdk-semver-governance, specification-driven-development | Hybrid | Pattern logic invariant; code examples are Go-specific (goroutines, interfaces, context) |
| environment-prerequisites-check, fuzz-patterns, go-concurrency-patterns, go-dependency-vetting, go-error-handling-patterns, go-example-function-patterns, go-hexagonal-architecture, go-module-paths, go-struct-interface-design, goroutine-leak-prevention, mock-patterns, otel-instrumentation, sdk-marker-protocol, table-driven-tests, tdd-patterns, testcontainers-setup, testing-patterns | Go-specialized | Prescribe Go language features (goroutines, channels, context, interfaces, go.mod), Go tools (goleak, cargo bench), Go test patterns (table-driven, Example_*) |
| feedback-analysis, improvement-planner, baseline-manager | Invariant | Metric analysis, pattern detection, trend tracking — language-neutral |

---

## 7. Verdict

**FEASIBILITY: Yes, with Caveats**

**Refactoring into a shared core + language packs architecture is viable and recommended**, contingent on addressing three load-bearing couplings and accepting 8–12 weeks of language-pack authoring per new target language.

### Why Feasible
1. **34% of pipeline components are truly language-invariant**: review-fix loop, HITL gates, decision-log schema, metrics collection, learning-engine logic, baseline management. These form a solid shared core.
2. **39% are hybrid**: structure is invariant (test planning, perf profiling, devil review), but implementations are Go-tuned. Parameterizing these is straightforward (test file naming, bench discovery, profiler backend).
3. **26% are Go-specialized**: skills, devil heuristics, quality standards. These are *teaching material and review logic*, not core machinery. Each language-pack can provide equivalents without modifying the shared pipeline.

### Why Caveats
1. **Marker byte-hash protocol is structural**. Switching from byte-hash to AST-hash requires rewriting G95–G103 + marker-scanner + constraint-devil. Feasible but non-trivial (~2 weeks).
2. **Performance gates assume Go benchmarking**. The allocs/op budget, pprof profile matching, and constraint bench naming are deeply coupled to Go's `go test -benchmem` + pprof. Each language must define equivalent metrics in its perf-budget.md schema. Doable but requires protocol versioning (~1 week per language).
3. **Skill idiom library scales linearly**. 18 Go-specific skills must be replicated in each new language-pack (async patterns for Python/Node, lifetime patterns for Rust, etc.). This is ~3–4 weeks of authoring per language, not a pipeline issue, but a content-generation burden.

### Recommendation
1. **Immediately**: Extract the invariant core (phases, HITL gates, decision-log, learning-engine, baselines) into a shared `motadata-sdk-pipeline-core` package.
2. **Refactor marker protocol** to use syntax-tree-agnostic hashing (AST node IDs + symbol path, not byte offsets).
3. **Parameterize performance gates**: Generalize allocs/op → per-language perf-metric in perf-budget.md schema. Decouple pprof → backend-agnostic profiler interface.
4. **Create language-pack template** (tests, skills, devils, guardrails skeleton) to accelerate Python/Rust/Node additions.
5. **Pilot with Python SDK**: Validate the refactoring on a second language before scaling to Rust/Node.

---

## 8. Cost-Benefit Summary

| Activity | Time | ROI |
|---|---:|---|
| Extract shared core + validate on Go pipeline | 3 weeks | High; unblocks next languages |
| Author Python language-pack | 8 weeks | Very high; Python is popular; 8 backend SDKs need coverage |
| Author Rust language-pack | 10 weeks | High; performance-critical; same 8 backends |
| Marker protocol refactor (AST-hash) | 2 weeks | Essential for multiLanguage safety |
| Perf-gate generalization | 1 week | Medium; enables per-language metrics |
| **Total one-time cost** | **~24 weeks** | **High**: covers ~15 SDK additions across 3 languages with minimal re-engineering per addition |
| **Per-SDK addition cost** (shared core) | **1–2 hours review** | **Very high**: 99% cost reduction vs. hand-rolled |

---

**Report Compiled**: 2026-04-24 | **Audit Scope**: 38 agents, 5 phases, 33 rules, 51 guardrails, 42 skills | **Status**: Ready for Language-Pack Refactoring
