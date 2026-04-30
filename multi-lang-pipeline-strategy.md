# Multi-Language SDK Pipeline — Architecture Strategy (Revised)

> **Context**: The current pipeline (v0.2.0) is Go-only. This document covers:
> 1. How to achieve multi-language support (Rust, Java, C++)
> 2. How to manage skills across languages without agent explosion
> 3. How skill growth affects pipeline performance
> 4. How to handle that impact

---

## 1. The Core Principle: Skills Are the Language Adapters

> **Agents stay generic. Language-specific knowledge (build commands, test tooling, idioms, perf tools) lives entirely inside skills. The TPRD `§Skills-Manifest` is the router.**

This means:
- **Zero new agent files** to add a new language
- **Zero if/else language branching** inside agent prompts
- Adding Rust = authoring ~12 Rust skills + their guardrails. That's it.

### Before vs After

```
BEFORE (Go-coupled agents):
  sdk-impl-lead → hard-codes: go build, go test -race, goleak, govulncheck

AFTER (generic agents):
  sdk-impl-lead → reads §Skills-Manifest → follows "build-and-test" skill
  skill says: cargo build / cargo test / cargo audit   ← Rust TPRD
  skill says: go build / go test -race / govulncheck   ← Go TPRD
```

The agent is a **contract executor**. The skill is the **language expert**.

---

## 2. What Changes in Agents (Minimal)

Agents need only **two edits** to become generic:

### Edit 1 — Remove hard-coded toolchain commands from agent prompts

Every place an agent currently says:
- `go build`, `go test -race`, `goleak.VerifyTestMain`, `govulncheck`, `gofmt`, `go vet`
- `motadatagosdk/otel`, `Config struct + New()`, `Godoc on every exported symbol`

...replace with:

```markdown
## Toolchain
Follow the build, test, lint, audit, and coverage instructions in the
`<lang>-build-test` skill loaded for this run. Do not assume any specific
toolchain. If no `<lang>-build-test` skill is declared in §Skills-Manifest,
escalate as BLOCKER at Phase 0.
```

### Edit 2 — Add a generic quality standards header

Replace the current Go-specific quality standards block (Godoc, `context.Context`, etc.) with:

```markdown
## Quality Standards
Apply the language idiom, error-handling, interface-design, and documentation
standards declared in the skills loaded from §Skills-Manifest. Each skill
documents exactly which rules apply and how to verify them.
```

That's the full agent change — two paragraph replacements per agent.

---

## 3. What Skills Must Contain (The New Contract)

For multi-language to work, every language-specific skill must be **self-contained**. Each skill becomes the single source of truth for everything an agent needs to do its job in that language.

### Required skill sections (for language-typed skills)

```markdown
---
name: rust-build-test
version: 1.0.0
language: rust
tags: [build, test, coverage, lint]
---

## Build
cargo build --release 2>&1

## Lint
cargo clippy -- -D warnings

## Test
cargo test -- --nocapture

## Coverage gate (maps to G60 equivalent)
cargo tarpaulin --min-coverage 90

## Leak / safety check
cargo +nightly miri test   # or valgrind for integration tests

## Supply-chain audit (maps to G32 equivalent)
cargo audit
cargo deny check

## Performance benchmarking
cargo bench (criterion)   # report allocs via criterion's measurement

## Documentation standard
/// doc-comments on every pub item; no bare pub structs without doc
```

### Skill taxonomy (proposed structure)

```
.claude/skills/
├── _shared/                         ← Pure concepts, no toolchain
│   ├── tdd-patterns/
│   ├── circuit-breaker-policy/
│   ├── review-fix-protocol/
│   ├── decision-logging/
│   ├── api-ergonomics-audit/
│   └── otel-instrumentation/        ← concept only; impl in lang skills
│
├── go/                              ← current skills, renamed
│   ├── go-build-test/               ← NEW: consolidates go build/test/cover/lint
│   ├── go-concurrency-patterns/
│   ├── go-error-handling-patterns/
│   ├── goroutine-leak-prevention/
│   └── ...
│
├── rust/
│   ├── rust-build-test/             ← cargo build/test/clippy/tarpaulin/audit
│   ├── rust-ownership-patterns/     ← lifetimes, Send+Sync, Arc/Mutex
│   ├── rust-async-tokio/            ← tokio runtime, async SDK patterns
│   ├── rust-error-handling/         ← Result<T,E>, thiserror, anyhow
│   ├── rust-trait-design/           ← trait objects, generics
│   └── rust-otel-instrumentation/   ← opentelemetry-rust specifics
│
├── java/
│   ├── java-build-test/             ← mvn/gradle, JaCoCo, SpotBugs, OWASP dep-check
│   ├── java-concurrency-patterns/   ← CompletableFuture, virtual threads
│   ├── java-error-handling/
│   ├── java-interface-design/       ← Builder, fluent API
│   └── java-otel-instrumentation/
│
└── cpp/
    ├── cpp-build-test/              ← cmake, ctest, gcov, AddressSanitizer, CVE scan
    ├── cpp-raii-patterns/
    ├── cpp-concurrency-patterns/    ← std::thread, std::atomic
    ├── cpp-error-handling/
    └── cpp-memory-safety/           ← valgrind, ASAN, UBSAN discipline
```

**Target**: ~6–8 skills per new language. Shared skills carry the heavy conceptual load.

---

## 4. How TPRD §Skills-Manifest Becomes the Router

The human authors the TPRD and declares exactly which skills the run needs:

```markdown
## §Skills-Manifest

### Required
- rust-build-test >= 1.0.0
- rust-ownership-patterns >= 1.0.0
- rust-async-tokio >= 1.0.0
- tdd-patterns >= 1.0.0
- circuit-breaker-policy >= 1.0.0
- review-fix-protocol >= 1.1.0

### Optional
- rust-otel-instrumentation >= 1.0.0
```

`sdk-intake-agent` validates all declared skills exist and are at required versions. If `rust-build-test` is declared, every downstream agent that needs to build/test reads that skill — no language detection needed.

---

## 5. Guardrail Strategy (Same Gate IDs, Language-Specific Implementation)

Guardrail IDs are **language-agnostic contracts** ("≥90% branch coverage"), not tool invocations:

```
scripts/guardrails/
├── shared/          ← decision-log format (G01), marker protocol (G05), target-dir (G07)
├── go/G60.sh        ← go test -coverprofile; fail if < 90%
├── rust/G60.sh      ← cargo tarpaulin --min-coverage 90
├── java/G60.sh      ← mvn verify + jacoco:check
└── cpp/G60.sh       ← gcov + lcov; fail if < 90%
```

`guardrail-validator` detects which language guardrail folder to use from the `§Skills-Manifest` (if `rust-build-test` is listed, load `rust/` guardrails). Same gate IDs, transparent to all agents.

---

## 6. Performance Impact of Many Skills

### Token budget (most important)

Agents only load skills declared in `§Skills-Manifest`. With 4 languages × 8 skills = 32 language skills in the index, but only 8–12 are loaded per run:

| Scenario | Skills loaded | Context size |
|---|---:|---:|
| Go run today | ~15 language + ~10 shared | ~50 KB |
| Rust run (proposed) | ~8 language + ~10 shared | ~36 KB |
| Java run (proposed) | ~8 language + ~10 shared | ~36 KB |
| All 4 langs in index, only 1 runs | same as single-lang | no change |

**Adding more languages to the index does not increase per-run token cost.** Cost is determined solely by what `§Skills-Manifest` declares.

### Code quality impact

| Scenario | Effect |
|---|---|
| Skills scoped to declared language | 🟢 Better — tighter, expert context |
| Shared skills loaded for all agents | 🟢 Fine — small, always relevant |
| TPRD author declares wrong-language skills | 🔴 Degrades — caught by `sdk-intake-agent` at Phase 0 |

The Phase 0 validation is the quality gate: `sdk-intake-agent` checks that all declared skills are internally consistent (same `language` tag, no mixing).

### Wall-clock impact

- Agent count: unchanged (zero new agents)
- Guardrail count per run: same as today (~15 scripts); only the correct language folder runs
- Skill authoring overhead: one-time ~1 week per new language, then zero ongoing cost

---

## 7. Phased Rollout

### Phase R1 — Make agents generic (no new language yet)
1. Strip Go-specific toolchain references from agent prompts → replace with "follow `<lang>-build-test` skill"
2. Create `go/go-build-test/SKILL.md` that captures all current Go toolchain rules (this just moves existing knowledge, not loses it)
3. Restructure [skill-index.json](file:///home/meet-dadhania/Documents/motadata-ai-pipeline/go-sdk-pipeline/.claude/skills/skill-index.json) → `schema_version: 2.0.0` with `language` tag on each skill
4. Update `sdk-intake-agent` to validate skill language consistency at Phase 0
5. **Verification**: Run existing Go TPRD. Output identical to v0.2.0 (determinism rule 25).

### Phase R2 — Rust adapter (skills + guardrails only)
1. Author via human PR: `rust-build-test`, `rust-ownership-patterns`, `rust-async-tokio`, `rust-error-handling` (~4 skills)
2. Author via human PR: `scripts/guardrails/rust/G10.sh`, `G32.sh`, `G60.sh` (~3 scripts)
3. **No agent changes needed** — agents are already generic after R1

### Phase R3/R4 — Java / C++ (same pattern as R2)

---

## 8. Summary Rules

| Rule | Detail |
|---|---|
| **Agents never branch on language** | No `if lang == rust` in any agent prompt |
| **Skills are self-contained** | Each language skill has build, test, lint, audit, docs, perf sections |
| **§Skills-Manifest is the router** | Human declares skills → pipeline follows them |
| **Shared skills carry the concepts** | ~10 shared skills; language skills are thin (~1–2 pages) |
| **Gate IDs are language-agnostic** | G60 = "≥90% coverage"; implementation varies per `lang/` folder |
| **Learning-engine respects language tag** | Never cross-applies patches across language boundaries |
| **Skill authorship is human-PR-only** | Per CLAUDE.md rule 23 — no exceptions |

> [!IMPORTANT]
> The **single change that unlocks multi-language** is making agents read "follow the build-and-test skill" instead of hard-coding `go build`. Everything else (skills, guardrails) is additive and can land incrementally without touching agents again.

---

## 3. Skill Taxonomy Restructuring

### Current structure (Go-only, flat)
```
.claude/skills/
├── go-concurrency-patterns/SKILL.md        ← Go-specific
├── go-error-handling-patterns/SKILL.md     ← Go-specific
├── tdd-patterns/SKILL.md                   ← Generic
├── otel-instrumentation/SKILL.md           ← Generic concept, Go impl
└── circuit-breaker-policy/SKILL.md         ← Generic pattern
```

### Proposed multi-language structure
```
.claude/skills/
├── _shared/                                ← Language-agnostic (no change to concepts)
│   ├── tdd-patterns/SKILL.md
│   ├── circuit-breaker-policy/SKILL.md
│   ├── review-fix-protocol/SKILL.md
│   ├── decision-logging/SKILL.md
│   ├── otel-instrumentation/SKILL.md       ← concept only; impl in each adapter
│   └── api-ergonomics-audit/SKILL.md
│
├── go/                                     ← renamed from current root Go skills
│   ├── go-concurrency-patterns/SKILL.md
│   ├── go-error-handling-patterns/SKILL.md
│   ├── goroutine-leak-prevention/SKILL.md
│   ├── go-hexagonal-architecture/SKILL.md
│   └── ...
│
├── rust/
│   ├── rust-ownership-patterns/SKILL.md    ← borrow checker, lifetimes
│   ├── rust-async-tokio/SKILL.md           ← tokio, async/await idioms
│   ├── rust-error-handling/SKILL.md        ← Result<T,E>, thiserror, anyhow
│   ├── rust-trait-design/SKILL.md          ← trait objects, generics, Send+Sync
│   ├── rust-ffi-safety/SKILL.md            ← unsafe blocks, FFI discipline
│   └── rust-dependency-vetting/SKILL.md    ← cargo audit, deny.toml
│
├── java/
│   ├── java-concurrency-patterns/SKILL.md  ← CompletableFuture, virtual threads
│   ├── java-error-handling/SKILL.md        ← checked vs unchecked exceptions
│   ├── java-interface-design/SKILL.md      ← Builder pattern, fluent API
│   ├── java-dependency-vetting/SKILL.md    ← OWASP dependency-check, Maven BOM
│   └── java-otel-instrumentation/SKILL.md  ← opentelemetry-java SDK specifics
│
└── cpp/
    ├── cpp-raii-patterns/SKILL.md          ← RAII, smart pointers
    ├── cpp-concurrency-patterns/SKILL.md   ← std::thread, std::atomic
    ├── cpp-error-handling/SKILL.md         ← exceptions vs error codes vs std::expected
    ├── cpp-memory-safety/SKILL.md          ← AddressSanitizer, valgrind discipline
    └── cpp-build-system/SKILL.md           ← CMake, Conan, vcpkg patterns
```

### Skill-index.json evolution

The current flat [skill-index.json](file:///home/meet-dadhania/Documents/motadata-ai-pipeline/go-sdk-pipeline/.claude/skills/skill-index.json) gains a `language` dimension:

```jsonc
{
  "schema_version": "2.0.0",
  "skills": {
    "shared": [
      { "name": "tdd-patterns", "version": "1.0.0", "path": "_shared/tdd-patterns/SKILL.md" },
      { "name": "circuit-breaker-policy", "version": "1.0.0", "path": "_shared/circuit-breaker-policy/SKILL.md" }
    ],
    "go": [
      { "name": "go-concurrency-patterns", "version": "1.0.0", "path": "go/go-concurrency-patterns/SKILL.md" }
    ],
    "rust": [
      { "name": "rust-ownership-patterns", "version": "1.0.0", "path": "rust/rust-ownership-patterns/SKILL.md" }
    ],
    "java": [
      { "name": "java-concurrency-patterns", "version": "1.0.0", "path": "java/java-concurrency-patterns/SKILL.md" }
    ]
  }
}
```

---

## 4. Agent Changes Required

### Agents with NO change needed (language-agnostic core)
| Agent | Why no change |
|---|---|
| `metrics-collector` | Works on JSONL metrics, not code |
| `phase-retrospector` | Operates on run artifacts |
| `root-cause-tracer` | Runs on decision-log entries |
| `improvement-planner` | Categorical reasoning, not language-specific |
| `learning-engine` | Skill patch logic is general |
| `baseline-manager` | Stores numeric quality scores |
| `decision-logging` (skill) | Meta skill, format only |
| `review-fix-protocol` (skill) | Logic-agnostic |

### Agents that need **language-aware forking**

```
sdk-impl-lead          → LANG_ADAPTER switches toolchain commands:
                          go: go build, go test -race, goleak
                          rust: cargo build, cargo test, cargo clippy, cargo audit
                          java: mvn verify / gradle build, spotbugs, OWASP dep-check
                          cpp: cmake --build, ctest, AddressSanitizer, valgrind

sdk-convention-devil   → per-language idiom rules (goroutine leak → Rust must use
                          Arc/Mutex safely; Java must avoid raw threads without executor)

sdk-dep-vet-devil      → per-language package ecosystem:
                          go: govulncheck + osv-scanner
                          rust: cargo audit + cargo deny
                          java: OWASP dependency-check + Maven BOM check
                          cpp: vcpkg audit + CVE scan

sdk-leak-hunter        → goroutine-specific today → must fork:
                          rust: no goroutine leaks, but unsafe/FFI boundary leaks
                          java: thread pool leaks, DirectByteBuffer leaks
                          cpp: valgrind memcheck / AddressSanitizer

guardrail-validator    → guardrail scripts vary per language (G01-G103 are Go-specific)
sdk-profile-auditor    → pprof is Go-specific; perf/flamegraphs for cpp; async-profiler for Java
sdk-complexity-devil   → big-O analysis logic is the same; benchmarking tool differs
```

### Implementation pattern for language-adaptive agents

Each language-aware agent reads a small **toolchain manifest** at startup:

```markdown
# runs/<run-id>/context/toolchain.md   (written by sdk-intake-agent at Phase 0)

language: rust
build_cmd: cargo build --release
test_cmd: cargo test
lint_cmd: cargo clippy -- -D warnings
audit_cmd: cargo audit
bench_tool: criterion
leak_tool: valgrind / cargo-sanitize
coverage_tool: cargo-tarpaulin
otel_package: opentelemetry-rust
```

No agent hard-codes language checks. Every agent reads `toolchain.md` and branches.

---

## 5. Guardrail Strategy

### Problem
Current 103 guardrail scripts (G01–G103) are Go-specific shell scripts (`go build`, `go vet`, `goleak`, `govulncheck`, etc.).

### Solution: Guardrail namespacing

```
scripts/guardrails/
├── shared/              ← language-agnostic (decision-log format, marker protocol)
│   ├── G01.sh           ← decision-log schema
│   ├── G05.sh           ← marker byte-hash verification
│   └── G07.sh           ← target-dir discipline
│
├── go/                  ← current G01-G103 (mostly Go toolchain)
│   ├── G10.sh           ← go build
│   ├── G11.sh           ← go vet
│   └── ...
│
├── rust/
│   ├── G10.sh           ← cargo build
│   ├── G11.sh           ← cargo clippy
│   ├── G32.sh           ← cargo audit (maps to go govulncheck role)
│   └── G60.sh           ← cargo-tarpaulin ≥90% coverage
│
├── java/
│   ├── G10.sh           ← mvn verify / gradle build
│   ├── G32.sh           ← OWASP dependency-check
│   └── G60.sh           ← JaCoCo ≥90%
│
└── cpp/
    ├── G10.sh           ← cmake + make
    ├── G32.sh           ← CVE scan
    └── G60.sh           ← gcov/llvm-cov ≥90%
```

`guardrail-validator` reads `LANG_ADAPTER` → runs `shared/G*.sh` + `<lang>/G*.sh`. Same gate IDs, different implementations — all agents continue to reference e.g. "G60 coverage gate" without knowing the underlying tool.

---

## 6. How Many Skills is "Too Many"? — Performance Impact Analysis

### What "performance" means here
In an LLM-based pipeline, "performance" has **three dimensions**:

| Dimension | What it means in this pipeline |
|---|---|
| **Token budget** | More skills loaded = more tokens per agent context |
| **Code quality** | More targeted skills = better output; too many = dilution |
| **Pipeline wall-clock** | More agents/guardrails = longer run time |

### 6.1 Token budget impact (quantified)

Current single-language load: ~40 skills × ~2 KB average SKILL.md = **~80 KB** loaded per run.

With 4 languages — naive "load everything" approach:
- 40 shared + 20 Go + 15 Rust + 15 Java + 15 C++ = **105 skills × 2 KB = ~210 KB**

But agents **only need the skills relevant to their phase and the selected language**. With lazy/selective loading:

```
Agent reads toolchain.md → LANG=rust
Loads: _shared/* (20 skills × 2KB = 40KB)
     + rust/* (15 skills × 2KB = 30KB)
Total: 70KB ← LESS than the current Go-only load of 80KB
```

**Key principle**: skill growth does NOT degrade performance when loading is selective.

### 6.2 Code quality impact

| Scenario | Effect on quality |
|---|---|
| All language skills loaded into every agent | 🔴 DEGRADES — agent dilutes attention across irrelevant idioms |
| Correct language skills loaded, nothing extra | 🟢 SAME or BETTER — tighter context |
| Shared skills loaded for all agents | 🟢 FINE — they are small, concept-only, always relevant |
| Too many skills for one language (>25 per lang) | 🟡 WATCH — same dilution risk as loading wrong-lang skills |

**The right number per language**: 15–25 skills. Current Go has 40 total (19 SDK-native + 21 generic), but ~15 are truly Go-specific. Target ~15 language-specific skills per new language.

### 6.3 Wall-clock / guardrail runtime impact

| Factor | Go (baseline) | +Rust | +Java | +Cpp |
|---|---|---|---|---|
| Additional guardrail scripts to author | 0 | ~12 new | ~10 new | ~10 new |
| Scripts run per run | 103 | 103 (only one lang runs) | 103 | 103 |
| Agents run per run | 35 | 35 (adapters, not new agents) | 35 | 35 |
| Per-run wall-clock impact | baseline | ~0 | ~0 | ~0 |

**Wall-clock does not grow linearly** with language count because only one language adapter activates per run.

---

## 7. The Specific Risks and How to Handle Them

### Risk 1: Skill dilution (most important)
**Problem**: If `sdk-impl-lead` has both `rust-async-tokio` and `go-concurrency-patterns` in context, it produces confused code.

**Mitigation**: Enforce skill routing in `sdk-intake-agent`. It writes a `skills-manifest.json` to `runs/<run-id>/context/` listing **only** skills for the selected language. Agents read this, not the full [skill-index.json](file:///home/meet-dadhania/Documents/motadata-ai-pipeline/go-sdk-pipeline/.claude/skills/skill-index.json).

```jsonc
// runs/abc123/context/skills-manifest.json (auto-generated by intake)
{
  "language": "rust",
  "loaded_skills": [
    "tdd-patterns",
    "circuit-breaker-policy",
    "rust-ownership-patterns",
    "rust-async-tokio",
    "rust-error-handling"
  ]
}
```

### Risk 2: Guardrail gate ID collision
**Problem**: If `G60` means "tarpaulin coverage" for Rust and "go test -cover" for Go, the same TPRD `§Guardrails-Manifest: [G60]` must mean different things.

**Mitigation**: Gate IDs are **language-agnostic contracts** ("≥90% branch coverage"), not tool invocations. The per-language script fulfills the contract. `guardrail-validator` loads the right implementation transparently.

### Risk 3: Learning-engine patches wrong language's skill
**Problem**: `learning-engine` patches `rust-ownership-patterns` based on a Go run pattern.

**Mitigation**: `learning-engine` stamps the `language` field on every patch. It MUST NOT cross-apply patches across language boundaries. Guardrail G85 extended to verify `patch.language == run.language`.

### Risk 4: Skill count explosion → maintenance hell
**Problem**: 4 languages × 20 skills = 80 skill files to maintain.

**Mitigation**:
1. **Shared skills are the primary investment** — put 70% of knowledge there
2. Language-specific skills are thin adapters over shared concepts (1–2 page docs, not 10-page tomes)
3. `sdk-skill-coverage-reporter` tracks which skills are actually cited in TPRDs; unused skills flagged for deprecation
4. `sdk-skill-drift-detector` catches when a skill's prescriptions no longer match real code

### Risk 5: Devil agents produce wrong verdicts
**Problem**: `sdk-convention-devil` checks Go `Config struct + New()` convention on a Rust codebase.

**Mitigation**: Each devil agent has a **language guard** at the top of its prompt:

```markdown
## Language Guard
Read `runs/<run-id>/context/toolchain.md`.
If LANG != go: skip Go-specific checks (Config struct, functional options, godoc).
Apply the LANG-specific convention list from `<lang>/<lang>-convention-checklist.md`.
```

This is a 3-line addition to each devil agent, not a rewrite.

---

## 8. Phased Rollout Plan

> **Principle**: Never break Go support while adding language support. Each phase ships independently.

### Phase R1 — Infrastructure (no new language yet)
1. Restructure [skill-index.json](file:///home/meet-dadhania/Documents/motadata-ai-pipeline/go-sdk-pipeline/.claude/skills/skill-index.json) to `schema_version: 2.0.0` with `shared`/`go` split
2. Move existing Go skills into `go/` subdirectory (backwards-compatible; `archive_source` path updated)
3. Add `§Target-Language` field to TPRD schema; default = `go` (existing TPRDs work unchanged)
4. `sdk-intake-agent` writes `toolchain.md` + scoped `skills-manifest.json`
5. Add language guard stubs to devil agents

**Verification**: Run existing Go TPRD. Output identical to v0.2.0 run (determinism rule 25).

### Phase R2 — Rust adapter
1. Author: `rust-ownership-patterns`, `rust-async-tokio`, `rust-error-handling`, `rust-trait-design` (4 skills via human PR)
2. Author guardrails in `rust/`: G10 (cargo build), G11 (clippy), G32 (cargo audit), G60 (tarpaulin)
3. Update `sdk-impl-lead`, `sdk-leak-hunter`, `sdk-dep-vet-devil` with `LANG=rust` branches
4. Author Rust toolchain.md template

**Verification**: Run a minimal Rust SDK TPRD (Mode A, trivial HTTP client). Passes all gates.

### Phase R3 — Java adapter (same approach)
### Phase R4 — C++ adapter (same approach)

---

## 9. Summary: How Multi-Language Affects Pipeline Performance

| Concern | Impact | Mitigation |
|---|---|---|
| **Token cost per run** | Neutral (selective loading keeps context ≤80KB) | Scoped `skills-manifest.json` per run |
| **Code quality** | Better (tighter, language-specific context) | Skill routing; language guard on devil agents |
| **Wall-clock per run** | ~0 (only one adapter runs per run) | Adapter-per-language, not additional serial phases |
| **Maintenance overhead** | Medium (4× skill authorship surface) | Maximize shared skills; thin lang-specific adapters |
| **Learning-engine safety** | Medium risk of cross-language patch | `language` field on every patch; G85 extended |
| **Guardrail correctness** | Risk of wrong-language script | Namespaced guardrails; adapter-scoped loading |
| **Skill count in index** | Grows from 40 → ~105 | Lazy loading + coverage-reporter pruning |

### The one non-negotiable rule

> **Every language adapter is fully isolated at runtime. Zero cross-language context pollution during a run.**

This is enforced by:
- `skills-manifest.json` (skill routing)
- `toolchain.md` (toolchain routing)
- Language guard in every devil agent
- `learning-engine` `language` field on patches

If you maintain this invariant, adding 10 languages has exactly the same per-run performance as adding 1.

---

## 10. New Files to Create (Human-PR-Only)

| File | Purpose |
|---|---|
| `.claude/skills/rust/rust-ownership-patterns/SKILL.md` | Borrow checker, lifetimes, Send+Sync |
| `.claude/skills/rust/rust-async-tokio/SKILL.md` | tokio runtime, async SDK patterns |
| `scripts/guardrails/rust/G10.sh` | cargo build gate |
| `scripts/guardrails/rust/G32.sh` | cargo audit gate |
| `docs/MULTI-LANG-TPRD-SCHEMA.md` | `§Target-Language` field spec |
| `docs/LANG-ADAPTER-AUTHORING-GUIDE.md` | How to add a new language adapter |
| [SKILL-CREATION-GUIDE.md](file:///home/meet-dadhania/Documents/motadata-ai-pipeline/go-sdk-pipeline/SKILL-CREATION-GUIDE.md) | Update: add language scoping section |

> [!IMPORTANT]
> Per [CLAUDE.md](file:///home/meet-dadhania/Documents/motadata-ai-pipeline/go-sdk-pipeline/CLAUDE.md) rule 23 and [AGENTS.md](file:///home/meet-dadhania/Documents/motadata-ai-pipeline/go-sdk-pipeline/AGENTS.md), **all new skill files are human-PR-only**. The pipeline never creates new SKILL.md files. New-skill proposals go to [docs/PROPOSED-SKILLS.md](file:///home/meet-dadhania/Documents/motadata-ai-pipeline/go-sdk-pipeline/docs/PROPOSED-SKILLS.md).

> [!WARNING]
> Migrating existing Go skills from the flat `.claude/skills/` root to `.claude/skills/go/` must be done atomically in a single PR that also updates `skill-index.json`. Any partial migration breaks the `sdk-intake-agent` skill resolution.
