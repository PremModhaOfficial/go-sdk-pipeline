# C-Refactor Implementation Plan

> **Decision**: Option C — shared core + per-language packs
> **Rationale**: Language count is unpredictable; pay the structural cost once.
> **Target duration**: 24 weeks for P0–P3 + first language pack (P4); additional language packs at ~8–10 wk each after that.
> **Success definition**: Go pipeline still produces byte-equivalent output for the Dragonfly TPRD *and* Python (pilot) pipeline produces a working redis-py client from an equivalent Python TPRD.

---

## Architecture target

### Current (flat) layout
```
motadata-sdk-pipeline/
├── .claude/
│   ├── agents/        ← 38 agents, all Go-specialized or hybrid
│   └── skills/        ← 42 skills (18 Go-specific)
├── phases/            ← 5 phase contracts, Go-flavored
├── scripts/guardrails/← 51 guardrails, Go-tool-specific
├── commands/          ← 2 slash commands
├── CLAUDE.md          ← 33 rules, mix of invariant + Go-specific
└── runs/, baselines/, evolution/, docs/
```

### Target (core + packs) layout
```
motadata-sdk-pipeline/
├── core/                          ← NEW — language-neutral
│   ├── agents/                    ← invariant leads + learning-engine + meta-agents
│   │   ├── sdk-intake-agent.md
│   │   ├── learning-engine.md
│   │   ├── metrics-collector.md
│   │   ├── baseline-manager.md
│   │   ├── improvement-planner.md
│   │   ├── root-cause-tracer.md
│   │   ├── phase-retrospector.md
│   │   ├── defect-analyzer.md
│   │   ├── guardrail-validator.md
│   │   ├── sdk-marker-scanner.md       ← now pack-aware
│   │   ├── sdk-skill-drift-detector.md
│   │   ├── sdk-skill-coverage-reporter.md
│   │   ├── sdk-soak-runner.md          ← backend-pluggable
│   │   ├── sdk-drift-detector.md
│   │   └── sdk-perf-architect.md       ← metric-schema-aware
│   ├── skills/                    ← 10 meta-tagged skills from today
│   │   ├── decision-logging/
│   │   ├── review-fix-protocol/
│   │   ├── lifecycle-events/
│   │   ├── context-summary-writing/
│   │   ├── conflict-resolution/
│   │   ├── feedback-analysis/
│   │   ├── guardrail-validation/
│   │   ├── spec-driven-development/
│   │   ├── environment-prerequisites-check/
│   │   └── api-ergonomics-audit/
│   ├── phases/                    ← same 5 contracts, tool-free
│   ├── scripts/
│   │   ├── guardrails-meta/       ← G01, G04, G07, G20-G24, G30, G80-G93 (invariant)
│   │   └── ast-hash/              ← NEW — pluggable AST-hash tool (per-lang backends)
│   ├── CORE-CLAUDE.md             ← rules 1-5, 7-13, 17-18, 21-28, 30, 31 (invariant)
│   └── pack-manifest-schema.json  ← NEW — contract for packs
│
├── packs/                         ← per-language packs
│   ├── go/                        ← current content, repackaged
│   │   ├── pack-manifest.yaml
│   │   ├── agents/                ← sdk-design-lead, impl-lead, testing-lead (Go-flavored), 10 Go devils
│   │   ├── skills/                ← 32 Go/SDK-domain skills
│   │   ├── guardrails/            ← G32-G34, G60-G69, G95-G110 (Go-tool-specific)
│   │   ├── quality-standards.md   ← rule 6 content (godoc, no init(), context.Context first)
│   │   └── ast-hash-backend.go    ← Go-specific AST hasher
│   └── python/                    ← NEW, P4 deliverable
│       ├── pack-manifest.yaml
│       ├── agents/                ← design-lead-python, impl-lead-python, testing-lead-python, 10 Python devils
│       ├── skills/                ← ~20-22 Python-idiomatic skills
│       ├── guardrails/            ← pip-audit, coverage.py, mypy, ruff
│       ├── quality-standards.md   ← Python conventions (type hints, docstrings, PEP)
│       └── ast-hash-backend.py    ← Python-specific AST hasher
│
├── commands/                      ← unchanged (orchestrator commands)
├── runs/, baselines/, evolution/, docs/   ← unchanged
```

### Core ↔ pack contract (`pack-manifest.yaml`)
```yaml
pack:
  name: go
  version: 1.0.0
  language: go
  target_sdk_dir_env: SDK_TARGET_DIR
  file_extensions: [.go]
  test_file_suffix: _test.go
  bench_prefix: Benchmark
  fuzz_prefix: Fuzz
  example_prefix: Example

leads:
  design: agents/sdk-design-lead.md
  impl:   agents/sdk-impl-lead.md
  testing: agents/sdk-testing-lead.md

devils: [agents/sdk-design-devil.md, agents/sdk-security-devil.md, ...]

skills_registered:
  - {name: go-error-handling-patterns, version: 1.0.0}
  - ...

guardrails:
  mechanical_checks: [guardrails/G32.sh, guardrails/G60.sh, ...]
  marker_checks: [guardrails/G95.sh, ...]   # pack provides language-specific markers
  perf_checks:
    allocs_metric: allocs_per_op
    perf_tool: go test -bench
    profile_tool: pprof

ast_hash_backend: ast-hash-backend.go

perf_budget_schema: |
  Every §7 symbol requires:
    latency_p50_us, latency_p99_us, allocs_per_op, throughput_per_sec,
    hot_path (bool), reference_oracle_source, big_o_complexity

quality_standards_file: quality-standards.md
```

The core reads the active pack's manifest at pipeline start and binds all language-specific references through it. Agents in core reference skills/guardrails by *role* (e.g., `perf_checks.allocs_metric`); the pack maps role → concrete tool.

---

## Phase P0 — Extract invariant core (weeks 1–4)

### Goal
Separate the language-invariant ~34% of the pipeline into `core/`, leaving language-specific content in `packs/go/`. Existing Go pipeline runs must produce *byte-equivalent* output (rerun Dragonfly TPRD, diff).

### File inventory

**Moves to `core/agents/`** (14 agents — invariant or only-marginally-Go-flavored):
- sdk-intake-agent, learning-engine, metrics-collector, baseline-manager, improvement-planner, root-cause-tracer, phase-retrospector, defect-analyzer, guardrail-validator, sdk-marker-scanner (becomes pack-aware), sdk-skill-drift-detector, sdk-skill-coverage-reporter, sdk-soak-runner (backend-pluggable), sdk-drift-detector

**Moves to `core/skills/`** (10 meta-tagged skills):
- decision-logging, review-fix-protocol, lifecycle-events, context-summary-writing, conflict-resolution, feedback-analysis, guardrail-validation, spec-driven-development, environment-prerequisites-check, api-ergonomics-audit

**Moves to `packs/go/agents/`** (24 agents — Go-specialized):
- sdk-design-lead, sdk-impl-lead, sdk-testing-lead (Go hardcoded skill lists)
- All 10 devils (Go conventions baked in)
- sdk-existing-api-analyzer, sdk-merge-planner (Go-AST-coupled)
- sdk-profile-auditor, sdk-perf-architect (pprof-coupled — will split after P2)
- Others as the P0 audit subsection identifies

**Moves to `packs/go/skills/`** (32 skills): all go-* skills + all sdk-domain-but-Go-idiomatic skills (go-concurrency-patterns, goroutine-leak-prevention, sdk-config-struct-pattern, otel-instrumentation, etc.)

**Moves to `packs/go/guardrails/`**: G32 (govulncheck), G33 (osv-scanner), G34 (license), G60-G65 (Go coverage/bench), G69 (credential hygiene — Go-syntax sensitive), G95-G110 (markers + perf — Go-specific until P1/P2 refactor)

**Stays invariant in `core/scripts/guardrails-meta/`**: G01 (decision-log schema), G04 (MCP health), G07 (target-dir discipline), G20-G24 (TPRD structure + manifest), G30 (api.go.stub compiles — needs pack-parameterized "stub compiles" check), G80-G93 (learning-engine metadata)

### Migration strategy

1. **Parallel phase (week 1–2)** — copy files into the new structure; keep originals in place. Nothing breaks.
2. **Wire-up phase (week 2–3)** — update commands/run-sdk-addition to read the pack manifest + core references; dual-mode agents read from whichever path is present.
3. **Cutover (week 3)** — remove the original top-level `.claude/`, `phases/`, `CLAUDE.md`. Run Dragonfly TPRD end-to-end; diff artifacts against pre-cutover. Must be byte-equivalent.
4. **Cleanup (week 4)** — update LIFECYCLE.md, PIPELINE-OVERVIEW.md, AGENTS.md to reflect the new layout.

### Risks + mitigations

| Risk | Likelihood | Mitigation |
|---|---|---|
| Byte-diff on Dragonfly rerun | Medium | Parallel-phase first; binary diff before cutover |
| Agent name conflicts across core/pack | Low | Namespace agents (`core.sdk-intake-agent`, `go.sdk-design-lead`) |
| Slash commands break | Low | Update `commands/run-sdk-addition.md` first, test against existing run artifacts |
| Skill-index.json schema evolution | Medium | New `packs` top-level section; keep `ported_verbatim`/`sdk_native` for backward-compat one release |

### Entry criteria
- P1 design validated (AST-hash works on Go; guardrails pass)
- Git branch `c-refactor/p0-extract-core` created; main-branch freeze on pipeline repo

### Exit criteria
- Dragonfly TPRD rerun produces byte-equivalent artifacts
- All 51 guardrails PASS on Dragonfly rerun
- PIPELINE-OVERVIEW.md + LIFECYCLE.md updated

---

## Phase P1 — Marker protocol AST-hash refactor (weeks 1–2, parallel to P0 planning)

### Goal
Replace byte-range SHA256 with AST-node hashing so marker ownership is resilient to formatter changes and portable across languages.

### Current state (what we're replacing)

| Guardrail | Current mechanism | Failure mode |
|---|---|---|
| G95 marker ownership | SHA256 of `file[byte_start:byte_end]` | Fails if gofmt or comment tweaks the region; false-positive BLOCKERs |
| G96 byte-hash match | Same as G95 (belt-and-suspenders) | Same |
| G97 constraint proof | Looks for `BenchmarkX` by Go naming | Breaks for Python `test_constraint_x`, Rust `bench_xxx` |
| G99 traces-to marker on exported symbols | Regex `^(func ... \|type ...)` on Go syntax | Only matches Go |
| G100 do-not-regenerate | Regex comment scan | Only matches Go `//` comments |
| G101 stable-since | Regex comment scan | Only matches Go `//` comments |
| G102 deprecated-in | Regex comment scan | Only matches Go `//` comments |
| G103 no forged MANUAL | Regex comment scan | Only matches Go `//` comments |

### Target state

Introduce `core/scripts/ast-hash/ast-hash.sh` that dispatches to the pack's `ast-hash-backend.<ext>`:

```
ast-hash.sh <pack-name> <file> <symbol-name>
  ↓
  reads packs/<pack>/pack-manifest.yaml
  ↓
  invokes the pack's AST tool:
    go: packs/go/ast-hash-backend.go (compiled to scripts/ast-hash/go-backend)
    python: packs/python/ast-hash-backend.py
  ↓
  emits: {symbol, canonical_ast_sha256, start_line, end_line}
```

The canonical AST hash is computed over:
1. Parse the file with the language's AST parser.
2. Locate the named symbol.
3. Strip comments + whitespace + formatting-only differences.
4. Emit a canonical serialization (S-expression-like).
5. SHA256 that serialization.

This is resilient to formatter changes, insensitive to byte positions, and generalizes across languages.

### Backward compatibility

`ownership-map.json` schema gets two fields added (both optional during transition):
```json
{
  "symbol": "Client.Get",
  "file": "core/dragonfly/client.go",
  "byte_start": 1234,      // DEPRECATED, kept for one release
  "byte_end": 1580,        // DEPRECATED
  "sha256": "...",         // DEPRECATED (byte-hash)
  "ast_hash": "...",       // NEW
  "language": "go"         // NEW (driven by pack)
}
```

G95/G96 check `ast_hash` if present, else fall back to `sha256` + byte range. After one release, byte fields are removed.

### Success criteria (non-negotiable)

1. `scripts/guardrails/G95.sh` on `runs/sdk-dragonfly-s2/` returns exit 0 **with AST-hash path active**.
2. `scripts/guardrails/G99.sh` continues to find the same set of missing markers on a deliberately-broken test fixture.
3. `ast-hash.sh` for Go produces identical hashes for `gofmt` vs. un-formatted equivalents of the same semantic code.
4. `ast-hash.sh` for Go produces *different* hashes when a symbol body is meaningfully changed.

### Deliverables
- `core/scripts/ast-hash/ast-hash.sh` (dispatcher)
- `packs/go/ast-hash-backend.go` (Go AST tool — small Go program using `go/parser` + `go/ast`)
- Updated G95/G96/G99/G100–G103 scripts reading `ast_hash` preferentially
- Unit tests in `tests/ast-hash/`
- Updated `sdk-marker-scanner.md` agent prompt

### Estimated effort
~2 weeks. Bulk of it is the Go AST tool (~3 days), guardrail updates (~3 days), testing + verification against Dragonfly (~4 days).

---

## Phase P2 — Perf-gate parameterization (week 5)

### Goal
Generalize the perf-confidence regime (rule 32) so each language pack supplies its own perf metrics and tools, while the core enforces the structural gates.

### perf-budget.md schema — generalization

Current (Go-specific):
```markdown
| symbol | p50 | p95 | p99 | allocs/op | throughput | hot_path | oracle | big_o |
```

Target (language-neutral with pack-supplied metric names):
```markdown
| symbol | p50_us | p95_us | p99_us | {pack.allocs_metric} | throughput_{pack.throughput_unit} | hot_path | oracle_ref | big_o |
```

Pack manifest supplies:
```yaml
perf_checks:
  allocs_metric: allocs_per_op     # Python: heap_bytes_per_call; Rust: instructions_per_call
  throughput_unit: op_per_sec
  profile_tool: pprof              # Python: py-spy; Rust: cargo flamegraph
  bench_tool: "go test -bench"     # Python: pytest-benchmark; Rust: cargo bench
  bench_name_pattern: "Benchmark*" # Python: "bench_*"; Rust: "bench_*"
```

### Guardrail updates

| Guardrail | Change |
|---|---|
| G104 allocs budget | Reads `pack.perf_checks.allocs_metric`; parses the right tool's output |
| G105 soak MMD | No change (structural) |
| G106 drift-detector | No change (structural) |
| G107 complexity scaling | Reads `pack.perf_checks.bench_tool` |
| G108 oracle margin | No change (structural) |
| G109 profile surprise | Reads `pack.perf_checks.profile_tool` |
| G110 perf-exception pairing | No change (structural) |

### Deliverables
- Updated `pack-manifest-schema.json` with `perf_checks` section
- Updated `core/agents/sdk-perf-architect.md` to emit pack-templated perf-budget.md
- Updated `core/agents/sdk-profile-auditor.md` to invoke pack-supplied profile tool
- Updated G104, G107, G109

### Estimated effort
~1 week.

---

## Phase P3 — Language-pack template + Go pack extraction (weeks 6–7)

### Goal
Ship `packs/go/` as the first concrete language pack. Validate the contract works end-to-end on the Go pipeline.

### Deliverables
- `core/pack-manifest-schema.json` — JSON Schema defining the contract (validated at pipeline start via G-new)
- `packs/go/pack-manifest.yaml` — full Go manifest
- `packs/go/README.md` — "how to author a language pack" guide (becomes the template for P4)
- Working end-to-end Dragonfly rerun using the new pack resolution

### Success criteria
- G04 (MCP health) + new G-pack-manifest-valid guardrail both pass
- Dragonfly TPRD runs through the pack-based pipeline and produces equivalent artifacts

### Estimated effort
~1–2 weeks.

---

## Phase P4 — First non-Go pack pilot (weeks 8–24)

### Language choice: Python (recommended) or Rust

| Criterion | Python | Rust |
|---|---|---|
| Tooling symmetry with Go | High (`pip-audit` ≈ `govulncheck`, `coverage.py` ≈ `go test -cover`) | Medium (`cargo-audit`, `tarpaulin`) |
| User grading feasibility | High (assume team Python fluency) | Low (requires Rust expert) |
| Ecosystem overlap with Go SDKs | High (all 8 backends have Python clients) | Medium |
| Cognitive overhead | Low (no ownership/lifetimes) | High |
| Pilot TPRD viability | High (redis-py is well-scoped) | Medium |

**Default choice: Python.** Flag for Rust if perf-critical backends are the priority.

### Deliverables
- `packs/python/pack-manifest.yaml`
- 20–22 Python skills (async/await, type hints, pytest patterns, dataclass design, pyproject.toml layout, pip-audit, coverage.py, mypy strict, ruff, sphinx docstrings, …)
- 10 Python devils (mirroring Go devil structure)
- ~20 Python guardrails (replace Go-specific ones)
- `packs/python/quality-standards.md` (PEP 8, PEP 484, docstring conventions, async conventions)
- `packs/python/ast-hash-backend.py` (uses `ast` module)
- Pilot TPRD: `redis-py` client wrapper, Mode A
- End-to-end run successful

### Estimated effort
~8–10 weeks. Breakdown:
- Weeks 8–9: skills authoring (heaviest content work)
- Weeks 10–11: devils + leads
- Weeks 12: guardrails + AST-hash backend
- Week 13: quality-standards + pack-manifest
- Weeks 14–15: pilot TPRD authoring + first run + iterate
- Weeks 16–17: review-fix, gap skills, refinement

---

## Cross-cutting concerns

### Git strategy
**Monorepo with `core/` and `packs/` as siblings** (default). Single PR per phase; each phase on a feature branch (`c-refactor/p0`, `c-refactor/p1`, …). Rationale: easier atomic rollback, shared history, lower coordination overhead than multi-repo.

Alternative: split `core/` into a separate repo once P4 is green. Defer decision to post-P4.

### TPRD schema versioning
Every TPRD declares `pipeline_version: ` and now a `pack: ` field (new). Existing TPRDs default to `pack: go` for backward compat.

### Backward compatibility for existing runs
- `runs/sdk-dragonfly-*` artifacts remain readable.
- `ownership-map.json` with byte-hash fields still works (G95/G96 fall back).
- Skill-index schema gets `schema_version: 1.2.0` with a `packs` section; old `ported_verbatim`/`sdk_native` kept.

### Pipeline version bumps
- After P1: bump to 0.3.0 (marker protocol changed)
- After P3: bump to 0.4.0 (pack architecture live)
- After P4: bump to 1.0.0 (first non-Go pack shipped — architecture proven)

---

## Week-by-week schedule

| Week | Phase | Deliverable |
|---:|---|---|
| 1 | P1 | AST-hash protocol design + Go backend proof-of-concept |
| 2 | P1 | AST-hash integrated into G95/G96/G99; Dragonfly verification |
| 3 | P0 | Parallel file copy into core/ + packs/go/ |
| 4 | P0 | Wire-up phase; dual-mode agents |
| 5 | P0 + P2 | Cutover + perf-gate parameterization |
| 6 | P3 | pack-manifest.yaml contract + schema guardrail |
| 7 | P3 | Dragonfly end-to-end on new pack system |
| 8 | P4 | Language choice confirmed; skills authoring begins |
| 9–11 | P4 | Python skills (20–22) |
| 12 | P4 | Python devils + leads |
| 13 | P4 | Python guardrails + AST-hash backend |
| 14 | P4 | quality-standards + pack manifest |
| 15 | P4 | Pilot TPRD authored (redis-py client) |
| 16 | P4 | First pilot run — Phase 0-2 |
| 17 | P4 | Pilot run — Phase 3-4 + review-fix |
| 18–20 | P4 | Gap-filling, refinement, second TPRD |
| 21–22 | P4 | Documentation (lifecycle, agents, operator manual) |
| 23 | Cleanup | Remove deprecated byte-hash path; 1.0.0 release |
| 24 | Buffer | Risks / slippage / post-mortem |

---

## Risks register

| # | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| 1 | AST-hash refactor introduces byte-diff on Dragonfly rerun | Medium | High | Backward-compat byte-hash path kept for 1 release; cross-verify on fixture tests |
| 2 | Go AST tool fails on generic type constraints or unusual syntax | Medium | Medium | Use stdlib `go/parser`; test against the full Dragonfly codebase |
| 3 | Pack-manifest.yaml schema churn after P3 | Medium | Medium | Lock schema at end of P3; version it (`schema_version: 1.0.0`) |
| 4 | Python skill authoring takes longer than 3 weeks | High | Medium | Prioritize 10 core skills; defer the "nice-to-have" 10; iterate over pilot runs |
| 5 | Pilot TPRD reveals missed abstraction in core | Medium | High | Week 17 buffer; prepared to cycle back to P0/P1 if necessary |
| 6 | Team capacity (if single-threaded through one engineer) | Unknown | High | Clarify staffing with user before starting P0 |
| 7 | Learning-engine patches core during refactor, bypassing pack | Low | High | Freeze learning-engine writes during refactor; re-enable in P3 |
| 8 | `sdk-designer` / sub-agent inline prompts embed pack-specific knowledge I didn't audit | Medium | Medium | Do a targeted sub-agent prompt audit during P0 week 3 |

---

## Open questions — require user answer before P0 execution

1. **Python or Rust for P4?** (Recommend Python.)
2. **Monorepo or multi-repo for core vs. packs?** (Recommend monorepo for now; split post-P4.)
3. **Team staffing**: who executes? Is this sequential-single-engineer or parallelized?
4. **Start timing**: when does Week 1 begin?
5. **Freeze policy**: can we freeze new-feature merges to the pipeline during the refactor? (Strongly recommended — makes diffing much cleaner.)
6. **Existing Dragonfly run**: keep as golden baseline, or author a second TPRD for cross-validation?

---

## Entry criteria (for this plan to execute)

- User approves the architecture target (core/ + packs/ layout)
- User approves the monorepo git strategy (or proposes alternative)
- User answers the 6 open questions above
- Repo is in a clean git state (no uncommitted work on main)

---

## Exit criteria (for the full 24-week plan)

- `packs/go/` produces the same Dragonfly output as today's flat layout (byte-equivalent)
- `packs/python/` produces a working redis-py SDK client from a Python-adapted TPRD
- All 7 HITL gates fire correctly under both packs
- Pipeline version 1.0.0 is tagged
- PIPELINE-OVERVIEW.md, LIFECYCLE.md, AGENTS.md reflect the new architecture
- Two more SDK additions can be started without any core changes

---

## What happens IF we stop after each phase

| Stop after | What you have | What's missing |
|---|---|---|
| P1 only | AST-hash, formatter-resilient markers. Defensible on its own. | Still flat layout; no language packs |
| P1 + P2 | Generalized perf gates. Defensible on its own. | Still flat layout |
| P1 + P2 + P0 + P3 | Pack architecture live for Go. 100% ready for P4. | No non-Go language shipped yet |
| Full (through P4) | Proven multi-language pipeline. Additional languages cost ~8 wk each. | n/a |

Every phase through P3 is valuable even if the project is paused. Only P4 (non-Go pack) is strictly dependent on the full commitment.
