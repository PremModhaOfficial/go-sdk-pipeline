# P0 Dry-Run — File-Move Manifest

> **Purpose**: enumerate every file move required to extract the invariant core from the flat pipeline layout into `core/ + packs/go/`. **No files are moved by this document** — it is a review artifact. Approval steps at the bottom.
>
> **Scope**: phases, agents, skills, guardrails, commands, CLAUDE.md, settings.json, AGENTS.md, LIFECYCLE.md, transitional P1/P2 artifacts.
>
> **Out of scope**: `runs/`, `baselines/`, `evolution/`, `docs/`, `.git/`, `.omc/`, `.serena/`, `.mcp.json`, `pipeline-map.html` — these stay at root.

---

## Summary counts

| Bucket | Files |
|---|---:|
| `core/` — language-invariant | 55 |
| `packs/go/` — Go-specialized | 58 |
| `split` — content divided between core + pack | 3 |
| Stays at root (orchestration) | 5 |
| Transitional artifacts (move from P1/P2 staging) | 8 |
| **Total classified** | **129** |

> **REVISION (2026-04-24, post-Stage-9.1)**: Per user feedback, ALL 38 agents
> now live in `core/agents/` (not 16). The 22 agents originally classified as
> `packs/go/agents/` have been moved to `core/agents/`, and the Go-specific
> content they embed will be extracted into `packs/go/agent-bindings/<agent>.yaml`
> during Stage 9.4. The rationale: agents are roles (general); Go-specific
> heuristics are pack-supplied bindings. See Section 2 below for the corrected
> classification.

Flagged for your review: see *Review checklist* at the bottom.

---

## 1. Target directory structure

```
motadata-sdk-pipeline/
├── core/
│   ├── agents/                 (14 invariant agents)
│   ├── skills/                 (12 invariant/meta skills)
│   ├── phases/                 (5 phase contracts)
│   ├── scripts/
│   │   ├── guardrails/         (29 pack-neutral or pack-aware-via-dispatcher guardrails)
│   │   ├── ast-hash/           (dispatcher — symbols.sh + ast-hash.sh)
│   │   └── perf/               (perf-config.yaml — folds into pack-manifest at P3)
│   ├── CORE-CLAUDE.md          (invariant rules 1-5, 7-13, 17-18, 21-28, 30, 31)
│   └── pack-manifest-schema.json  (P3 deliverable; contract for packs)
│
├── packs/
│   └── go/
│       ├── agents/             (24 Go-specialized leads + devils + tooling)
│       ├── skills/             (29 Go-idiom skills)
│       ├── guardrails/         (13 Go-tool-specific guardrails)
│       ├── ast-hash-backend.go, ast-hash-backend, go-symbols.go, go-symbols  (from P1)
│       ├── quality-standards.md   (from CLAUDE.md §6 + rule 14 + rule 19)
│       └── pack-manifest.yaml  (P3 deliverable)
│
├── commands/                   (stays — orchestration; internally rewritten to load pack manifest)
├── runs/, baselines/, evolution/, docs/   (stays — unchanged)
├── CLAUDE.md                   (replaced by a stub pointing to core/CORE-CLAUDE.md + packs/go/quality-standards.md)
├── AGENTS.md, LIFECYCLE.md, PIPELINE-OVERVIEW.md   (stays — content updated)
└── settings.json, .mcp.json    (stays — unchanged)
```

---

## 2. Agents — 38 files

### → `core/agents/` (14)

| Current path | New path | Reason |
|---|---|---|
| `.claude/agents/baseline-manager.md` | `core/agents/baseline-manager.md` | Tracks per-run quality metrics; no language dependency |
| `.claude/agents/defect-analyzer.md` | `core/agents/defect-analyzer.md` | Root-cause analysis; invariant |
| `.claude/agents/guardrail-validator.md` | `core/agents/guardrail-validator.md` | Runs guardrails; invariant |
| `.claude/agents/improvement-planner.md` | `core/agents/improvement-planner.md` | Feedback synthesis; invariant |
| `.claude/agents/learning-engine.md` | `core/agents/learning-engine.md` | Applies patches; invariant |
| `.claude/agents/metrics-collector.md` | `core/agents/metrics-collector.md` | Per-agent quality_score formula; invariant |
| `.claude/agents/phase-retrospector.md` | `core/agents/phase-retrospector.md` | Per-phase debrief; invariant |
| `.claude/agents/root-cause-tracer.md` | `core/agents/root-cause-tracer.md` | Defect-to-phase mapping; invariant |
| `.claude/agents/sdk-drift-detector.md` | `core/agents/sdk-drift-detector.md` | Curve-fit drift on soak signals; schema invariant |
| `.claude/agents/sdk-intake-agent.md` | `core/agents/sdk-intake-agent.md` | TPRD structural validation + manifest checks; invariant |
| `.claude/agents/sdk-marker-scanner.md` | `core/agents/sdk-marker-scanner.md` | Now pack-aware via ast-hash dispatcher (P1) |
| `.claude/agents/sdk-perf-architect.md` | `core/agents/sdk-perf-architect.md` | Now pack-aware via perf-config (P2) |
| `.claude/agents/sdk-profile-auditor.md` | `core/agents/sdk-profile-auditor.md` | Pack-aware profiler invocation |
| `.claude/agents/sdk-skill-coverage-reporter.md` | `core/agents/sdk-skill-coverage-reporter.md` | Invariant (scopes to TPRD manifest) |
| `.claude/agents/sdk-skill-drift-detector.md` | `core/agents/sdk-skill-drift-detector.md` | Invariant (scopes to invoked skills) |
| `.claude/agents/sdk-soak-runner.md` | `core/agents/sdk-soak-runner.md` | Pack-aware soak backend |

### → `packs/go/agents/` (24)

| Current path | New path | Reason |
|---|---|---|
| `.claude/agents/code-reviewer.md` | `packs/go/agents/code-reviewer.md` | Reviews Go idioms, error handling, concurrency |
| `.claude/agents/documentation-agent.md` | `packs/go/agents/documentation-agent.md` | Generates godoc + Example_* — Go-specific |
| `.claude/agents/refactoring-agent.md` | `packs/go/agents/refactoring-agent.md` | Go-idiom refactorings (dedup, error wrapping) |
| `.claude/agents/sdk-api-ergonomics-devil.md` | `packs/go/agents/sdk-api-ergonomics-devil.md` | godoc + Config+New ergonomics |
| `.claude/agents/sdk-benchmark-devil.md` | `packs/go/agents/sdk-benchmark-devil.md` | Invokes `go test -bench` |
| `.claude/agents/sdk-breaking-change-devil.md` | `packs/go/agents/sdk-breaking-change-devil.md` | Go public API diff |
| `.claude/agents/sdk-complexity-devil.md` | `packs/go/agents/sdk-complexity-devil.md` | Invokes Go benches for scaling sweep (G107 itself is pack-neutral) |
| `.claude/agents/sdk-constraint-devil.md` | `packs/go/agents/sdk-constraint-devil.md` | Runs Go `BenchmarkXxx` functions |
| `.claude/agents/sdk-convention-devil.md` | `packs/go/agents/sdk-convention-devil.md` | Config+New, no init(), package naming |
| `.claude/agents/sdk-dep-vet-devil.md` | `packs/go/agents/sdk-dep-vet-devil.md` | govulncheck + osv-scanner + license |
| `.claude/agents/sdk-design-devil.md` | `packs/go/agents/sdk-design-devil.md` | Go API design review heuristics |
| `.claude/agents/sdk-design-lead.md` | `packs/go/agents/sdk-design-lead.md` | Hardcoded Go skill list in prompt |
| `.claude/agents/sdk-existing-api-analyzer.md` | `packs/go/agents/sdk-existing-api-analyzer.md` | Reads Go source tree for Mode B/C baseline |
| `.claude/agents/sdk-impl-lead.md` | `packs/go/agents/sdk-impl-lead.md` | Hardcoded Go skill list, Go TDD wave plan |
| `.claude/agents/sdk-integration-flake-hunter.md` | `packs/go/agents/sdk-integration-flake-hunter.md` | Runs `go test -count=3` |
| `.claude/agents/sdk-leak-hunter.md` | `packs/go/agents/sdk-leak-hunter.md` | goleak-specific |
| `.claude/agents/sdk-marker-hygiene-devil.md` | `packs/go/agents/sdk-marker-hygiene-devil.md` | Validates Go comment marker formatting |
| `.claude/agents/sdk-merge-planner.md` | `packs/go/agents/sdk-merge-planner.md` | Go-AST-coupled 3-way merge for Mode C |
| `.claude/agents/sdk-overengineering-critic.md` | `packs/go/agents/sdk-overengineering-critic.md` | Detects unused Go interfaces + premature abstraction |
| `.claude/agents/sdk-security-devil.md` | `packs/go/agents/sdk-security-devil.md` | Go TLS defaults, credential-handling idioms |
| `.claude/agents/sdk-semver-devil.md` | `packs/go/agents/sdk-semver-devil.md` | Go public-API diff for semver |
| `.claude/agents/sdk-testing-lead.md` | `packs/go/agents/sdk-testing-lead.md` | Hardcoded Go skill list (testcontainers, fuzz-patterns, …) |

### Sub-designers (from DESIGN-PHASE.md) — `packs/go/agents/` or inline

`sdk-designer`, `interface-designer`, `algorithm-designer`, `concurrency-designer`, `pattern-advisor` — these have **no `.md` files** in `.claude/agents/`. They are spawned by `sdk-design-lead.md` via the Agent tool with runtime-constructed prompts. No files to move; the *design-lead* moves into the pack and carries the sub-agent logic with it.

---

## 3. Skills — 41 directories

### → `core/skills/` (12 — meta-tagged + language-neutral infrastructure)

- `decision-logging/`
- `review-fix-protocol/`
- `lifecycle-events/`
- `context-summary-writing/`
- `conflict-resolution/`
- `feedback-analysis/`
- `guardrail-validation/`
- `spec-driven-development/`
- `environment-prerequisites-check/`
- `api-ergonomics-audit/`
- `mcp-knowledge-graph/`
- `sdk-marker-protocol/`   *(now pack-neutral post-P1)*

### → `packs/go/skills/` (29)

- `backpressure-flow-control/`, `circuit-breaker-policy/`, `client-mock-strategy/`, `client-rate-limiting/`, `client-shutdown-lifecycle/`, `client-tls-configuration/`, `connection-pool-tuning/`, `context-deadline-patterns/`, `credential-provider-pattern/`, `fuzz-patterns/`, `go-concurrency-patterns/`, `go-dependency-vetting/`, `go-error-handling-patterns/`, `go-example-function-patterns/`, `go-hexagonal-architecture/`, `go-module-paths/`, `go-struct-interface-design/`, `goroutine-leak-prevention/`, `idempotent-retry-safety/`, `mock-patterns/`, `network-error-classification/`, `otel-instrumentation/`, `sdk-config-struct-pattern/`, `sdk-otel-hook-integration/`, `sdk-semver-governance/`, `table-driven-tests/`, `tdd-patterns/`, `testcontainers-setup/`, `testing-patterns/`

### skill-index.json → split

- `core/skills/skill-index.json` — catalog of the 12 core skills
- `packs/go/skills/skill-index.json` — catalog of the 29 Go skills + pack tag

---

## 4. Phases — 5 files

All → `core/phases/*.md`. The phase contracts are structural (wave definitions, HITL gates, agent rosters-by-role). Go-specific tooling references stay in the pack-agent prompts they orchestrate.

| Current | New |
|---|---|
| `phases/DESIGN-PHASE.md` | `core/phases/DESIGN-PHASE.md` |
| `phases/FEEDBACK-PHASE.md` | `core/phases/FEEDBACK-PHASE.md` |
| `phases/IMPLEMENTATION-PHASE.md` | `core/phases/IMPLEMENTATION-PHASE.md` |
| `phases/INTAKE-PHASE.md` | `core/phases/INTAKE-PHASE.md` |
| `phases/TESTING-PHASE.md` | `core/phases/TESTING-PHASE.md` |

Each file needs minor edits at move time to replace `.go`-specific examples with pack-parameterized phrasing.

---

## 5. Commands — 2 files (stay at root)

| Current | New | Change needed |
|---|---|---|
| `commands/run-sdk-addition.md` | `commands/run-sdk-addition.md` | Updated to accept `--pack <lang>` flag; defaults to `go` |
| `commands/preflight-tprd.md` | `commands/preflight-tprd.md` | Updated to read pack manifest for skill/guardrail lookups |

---

## 6. Guardrails — 53 scripts

### → `core/scripts/guardrails/` (29)

Language-invariant OR pack-parameterized (read `PACK` env / dispatcher).

- `G01.sh` (decision-log schema), `G02.sh` (communication entries), `G03.sh` (lifecycle matched)
- `G04.sh` (MCP health), `G06.sh` (pipeline_version consistency), `G07.sh` (target-dir discipline)
- `G20.sh`–`G24.sh` (TPRD structural + manifests)
- `G38.sh` (no tenant_id — universal SDK invariant)
- `G69.sh` (credential hygiene — pattern scan for creds in source; language-neutral regex)
- `G80.sh`–`G86.sh` (learning-engine metadata + safety caps)
- `G90.sh`, `G93.sh` (skill-index consistency, CLAUDE.md rule contiguity)
- `G95.sh`, `G96.sh`, `G99.sh`, `G101.sh`, `G103.sh` (pack-aware via ast-hash / symbols dispatchers — **this session**)
- `G100.sh` (do-not-regenerate file-level hash — language-neutral file lock)
- `G102.sh` (marker syntax validity — pack-neutral marker grammar)
- `G104.sh` (alloc budget — pack-aware via perf-config — **this session**)
- `G105.sh`, `G106.sh` (soak MMD + drift — structural)
- `G107.sh` (complexity scaling — schema language-agnostic)
- `G108.sh` (oracle margin — structural)
- `G109.sh` (profile no-surprise — schema language-agnostic)
- `G110.sh` (perf-exception pairing — structural)
- `G116.sh` (retired-term scanner — docs linter)
- `run-all.sh` (dispatcher)

### → `packs/go/guardrails/` (24)

Invoke Go-specific tooling directly.

- `G30.sh`, `G31.sh` (api.go.stub compiles + stub schema)
- `G32.sh` (govulncheck), `G33.sh` (osv-scanner), `G34.sh` (license allowlist — Go dep licenses)
- `G40.sh` (no TODO/ErrNotImplemented — Go text patterns)
- `G41.sh` (go build), `G42.sh` (go vet), `G43.sh` (gofmt -l)
- `G48.sh` (no init() — Go-specific)
- `G60.sh`, `G61.sh`, `G63.sh` (go test coverage + flake)
- `G65.sh` (Go bench regression via benchstat)
- `G97.sh` (constraint bench — Go `BenchmarkXxx` naming; will become pack-aware later)
- `G98.sh` (required markers on .go files — file-extension Go-specific)

Note: G97 and G98 are listed here because they currently use Go-specific patterns; they should be migrated to `core/` with pack-supplied file-ext + bench-pattern in a future P1 follow-up (tracked).

---

## 7. Root-level files — split / stays / rewritten

| File | Action | Detail |
|---|---|---|
| `CLAUDE.md` | **split** | Content moves: rules 1–5, 7–13, 17–18, 21–28, 30, 31 → `core/CORE-CLAUDE.md`. Rule 6 (quality standards), rule 14 (impl completeness Go specifics like goleak/govulncheck), rule 19 (dep vetting) → `packs/go/quality-standards.md`. Root `CLAUDE.md` becomes a stub linking both. |
| `AGENTS.md` | stays, rewritten | Update ownership matrix to reflect core/pack structure |
| `LIFECYCLE.md` | stays, rewritten | Document pack selection + the new ops |
| `PIPELINE-OVERVIEW.md` | stays, rewritten | CXO-facing; update diagrams + architecture section |
| `README.md` | stays, rewritten | Point to pack layout |
| `settings.json` | stays | Add `packs_dir: "packs"` key; runtime reads active pack |
| `.mcp.json` | stays | Unchanged |
| `SKILL-CREATION-GUIDE.md` | stays, rewritten | Guide applies to both core and pack skills |
| `AGENT-CREATION-GUIDE.md` | stays, rewritten | Same |
| `send.md`, `improvements.md`, `pipeline-map.html` | stays | Reference/docs |

---

## 8. Transitional artifacts from this session (8 files)

These currently live at flat-layout paths. They move at P0:

| Current (flat) | New (core/pack) |
|---|---|
| `scripts/ast-hash/ast-hash.sh` | `core/scripts/ast-hash/ast-hash.sh` |
| `scripts/ast-hash/symbols.sh` | `core/scripts/ast-hash/symbols.sh` |
| `scripts/ast-hash/README.md` | `core/scripts/ast-hash/README.md` |
| `scripts/ast-hash/go-backend.go` | `packs/go/ast-hash-backend.go` |
| `scripts/ast-hash/go-backend` | `packs/go/ast-hash-backend` (compiled binary) |
| `scripts/ast-hash/go-symbols.go` | `packs/go/symbols-backend.go` |
| `scripts/ast-hash/go-symbols` | `packs/go/symbols-backend` (compiled binary) |
| `scripts/perf/perf-config.yaml` | `core/scripts/perf/perf-config.yaml` (P3 folds into pack-manifest.yaml) |
| `scripts/compute-shape-hash.sh` | `core/scripts/compute-shape-hash.sh` |
| `tests/ast-hash/*` | `core/tests/ast-hash/*` |
| `tests/perf/*` | `core/tests/perf/*` |

The dispatcher scripts (`ast-hash.sh`, `symbols.sh`) were **already written pack-aware** and will work correctly once the Go backend moves — the dispatchers already prefer `$ROOT/packs/go/<backend>` over `$ROOT/scripts/ast-hash/<backend>`.

---

## 9. Migration strategy (when you approve)

Four phases of P0 execution, each with a verification gate:

### Stage 9.1 — Parallel copy (week 3, day 1–2)
- Create `core/` and `packs/go/` directories with subdir skeleton
- `cp -r` every file above to its new location
- Leave originals in place — nothing is removed yet
- **Verify**: diff every copied file against original (must be byte-identical)

### Stage 9.2 — Wire-up (week 3, day 3–4)
- Update `commands/run-sdk-addition.md` and `commands/preflight-tprd.md` to read pack
- Update `scripts/guardrails/run-all.sh` to route to `core/` or `packs/go/` scripts based on guardrail ID
- Update every moved script's `REPO_ROOT` calculation if path depth changed
- **Verify**: run G04 (MCP health) + G01 (decision-log schema) against `runs/sdk-dragonfly-s2/` — both pass exit 0

### Stage 9.3 — Cutover (week 3, day 5)
- Delete original flat-layout files (but NOT via `rm -rf` — explicit file list, reviewed before removal)
- Run Dragonfly TPRD end-to-end via `/run-sdk-addition`
- **Verify**: byte-equivalent output vs. the pre-cutover `sdk-dragonfly-s2` artifacts

### Stage 9.4 — Documentation (week 4)
- Rewrite AGENTS.md, LIFECYCLE.md, PIPELINE-OVERVIEW.md
- Update `docs/` if any reference the old layout
- **Verify**: `preflight-tprd` on any existing TPRD still passes

---

## 10. Review checklist (your sign-off before Stage 9.1)

Please confirm or comment:

1. **Top-level structure**: `core/ + packs/go/ + commands/ + runs/ + baselines/ + evolution/ + docs/` — does this match the architecture you pictured?
2. **Pack naming**: `packs/go/` (not `go-pack/` or `motadata-sdk-go/`) — sound?
3. **Core package identity**: does `core/` stay a directory, or do you want it as a separable subrepo (`motadata-sdk-pipeline-core/`)?
4. **Git strategy**: one PR per stage (9.1, 9.2, 9.3, 9.4) on branch `c-refactor/p0`, OR four separate PRs? (Recommend one branch, four commits.)
5. **Specific agent classifications I'd like you to confirm**:
    - `code-reviewer`, `documentation-agent`, `refactoring-agent` → `packs/go/` (generic names but Go-content)
    - `sdk-overengineering-critic` → `packs/go/` (could arguably be core; core rule "no unused abstractions" + pack implementation)
6. **Specific guardrails I'd like you to confirm**:
    - `G69` credential hygiene → `core/` (I chose core because the regex is language-neutral; but it may have Go-specific patterns I didn't re-read)
    - `G38` no tenant_id → `core/` (SDK-discipline invariant)
    - `G97`, `G98` → `packs/go/` for now; eventual migration to core + pack-parameterized file-ext/bench-pattern
7. **`CLAUDE.md` split boundaries**: does the proposed rule-number split match your mental model?
8. **Freeze policy during P0**: can we freeze new-feature merges on the pipeline repo for the ~1 week of P0? Strongly recommended — makes Stage 9.3 byte-diff reliable.

---

## 11. After P0 completes

Natural next steps (covered by `runs/c-refactor-plan.md`):

- **P3** (week 6–7): author `pack-manifest.yaml` + `pack-manifest-schema.json`, have `core/` load it at run start. Fold `perf-config.yaml` into the manifest.
- **P4** (weeks 8–17): author `packs/python/` — skills (~20), devils (~10), leads (3), guardrails (~10), quality-standards.md, ast-hash-backend.py, symbols-backend.py. Pilot TPRD for redis-py.

Everything before P4 is one-time infrastructure. P4 is the per-language pattern you'll repeat for every new language.
