# motadata-sdk-pipeline — Agent Fleet Rules

Multi-agent pipeline targeting the external Go SDK at `$SDK_TARGET_DIR` (typically `motadata-go-sdk/src/motadatagosdk/`). Purpose: take a TPRD for adding / extending / incrementally updating a client in that SDK and produce production-quality code + tests + benchmarks.

**Inspired by and ports machinery from** motadata-ai-pipeline (archived). All ported content is inlined; this pipeline has no runtime dependency on the archive. See `PROVENANCE.md` for origin commit SHA and per-file mapping.

---

## Project Context

- **Target SDK**: Go 1.26, module `motadatagosdk`, dirs `config/ events/ core/ otel/ utils/ cmd/`
- **Convention**: primary `Config struct + New(cfg)`, functional options only where target SDK already uses them
- **No multi-tenancy** — SDK is a library, tenant context is caller-supplied (not pipeline concern)
- **No inter-service NATS/HTTP** — SDK may EXPOSE NATS capability (events/), but pipeline itself does not enforce NATS patterns on non-events clients
- **OTel required** — all clients wire into `motadatagosdk/otel` package
- **Resilience toolkit** — clients reuse `core/circuitbreaker/`, `core/pool/`, existing middleware

## Agent Fleet Rules (all agents follow)

### 1. Observability Logging — MANDATORY
Every agent MUST append to `runs/<run-id>/decision-log.jsonl`. Entry types: `decision`, `lifecycle`, `communication`, `event`, `failure`, `refactor`, `skill-evolution`, `budget`. Full schema in plan §Decision Log; validator guardrail G01.

### 2. Context Sharing
- BEFORE starting: read all files in `runs/<run-id>/<phase>/context/`
- AFTER completing: write summary to `runs/<run-id>/<phase>/context/<agent-name>-summary.md` (≤200 lines)
- Summaries must be self-contained for downstream agents

### 3. Output Ownership
- Each agent writes ONLY to its designated output dir
- Never modify another agent's outputs
- Phase lead is the only writer of the phase's final report

### 4. Communication Protocol
- Use Teammate messages for urgent cross-agent coordination
- Use filesystem (context dir) for artifacts
- Prefix urgent with `ESCALATION:` or `BLOCKER:`
- Log every meaningful communication in decision log (`type: communication`)

### 5. Review Agents Are READ-ONLY
All devil / critic / reviewer / validator agents never modify source. Output only to `runs/<run-id>/<phase>/reviews/`.

### 6. Quality Standards
- Godoc on every exported symbol (first word = symbol name)
- Table-driven tests, table-driven benchmarks
- No `init()` functions
- No global mutable state
- `context.Context` first param on every I/O method
- `Config struct + New(cfg)` OR functional options — match target SDK convention
- OTel via `motadatagosdk/otel` (NOT raw OTel API)
- Interface-first for testability; compile-time interface assertions (`var _ Interface = (*Impl)(nil)`)

### 7. Ownership Matrix — single owner per domain
See `AGENTS.md` for full matrix. Key: skill bootstrap = `sdk-bootstrap-lead`; API design = `sdk-design-lead`; code = `sdk-impl-lead`; tests = `sdk-testing-lead`; patches = `learning-engine`.

### 8. Conflict Resolution
Agent discovering conflict sends `ESCALATION: CONFLICT` to phase lead; lead decides per ownership matrix; logs with `tags: ["conflict-resolution"]`.

### 9. State Management & Checkpointing
Phase lead maintains `runs/<run-id>/state/run-manifest.json`. Checkpoint after every wave. On restart, read manifest; `in-progress` → resume, `completed` → start fresh.

### 10. Error Recovery
Agent failure → `lifecycle: failed` entry + assess retry-vs-proceed. Max 1 retry per agent per wave. Second failure = degraded; proceed with warning.

### 11. Resource Limits
- Context summary ≤200 lines
- Schema/spec files ≤500 lines/service
- Decision log ≤15 entries per agent per run
- Review-fix loop: 5 retries per finding, stuck detection at 2 non-improving iterations, global 10-iter cap

### 12. Observability & Run Isolation
Every run has `run_id` (UUID v4). Every log entry stamps `run_id` + `pipeline_version`. Context summaries timestamp with `<!-- Generated: ISO-8601 | Run: run_id -->`.

### 13. Post-Iteration Review Re-Run — MANDATORY
After ANY rework iteration, phase lead re-runs ALL review/devil agents. No exceptions. Ported from archive.

### 14. Implementation Completeness
- Zero `ErrNotImplemented` / `TODO` in generated code
- Every interface has real impl
- Tests cover real behavior (not mocked away)
- Coverage ≥90% on new package
- Benchmarks recorded for hot paths
- `goleak.VerifyTestMain` clean
- `govulncheck` + `osv-scanner` clean
- Every exported func has at least one `Example_*` where applicable

### 16. Story → Feature-Level Completeness
For each symbol declared in TPRD §7 API: (a) impl exists, (b) test exists, (c) godoc exists, (d) benchmark if hot path, (e) `Example_*` where applicable, (f) `[traces-to: TPRD-<section>-<id>]` marker on generated symbols.

### 17. Target-dir Discipline
Writes ONLY to `$SDK_TARGET_DIR` and `runs/`. Guardrail G07 enforces.

### 18. Target SDK Convention Respect
Agents MUST read target SDK tree before designing. No contradicting existing patterns (e.g., if target uses `Config struct + New()`, don't default to functional options without justification).

### 19. Dependency Justification
Every new `go get` requires `runs/<run-id>/design/dependencies.md` entry: name, version, license, size, `govulncheck`, `osv-scanner`, last-commit-age, transitive-count. `sdk-dep-vet-devil` verdict required. License allowlist: MIT / Apache-2.0 / BSD / ISC / 0BSD / MPL-2.0.

### 20. Benchmark Regression Gate
>10% regression on shared paths OR >5% on new-package hot path = BLOCKER unless `--accept-perf-regression <pct>`.

### 21. Git-Based Safety
`$SDK_TARGET_DIR` MUST be a git repo. Pipeline works on dedicated branch `sdk-pipeline/<run-id>`. Final diff shown to user before merge recommendation. No force-push. No direct main commit.

### 22. Budget Tracking
`manifest.json` tracks per-phase token + wall-clock. Soft caps → warn. Hard caps → user confirm-to-continue.

### 23. Skill Versioning
Every skill MUST have `version: X.Y.Z` frontmatter + adjacent `evolution-log.md`. Patches bump version; major changes require user approval + golden-corpus regression.

### 24. Supply Chain
`govulncheck` + `osv-scanner` MUST be green on all new deps.

### 25. Determinism
Same TPRD + same pipeline version + same seed MUST converge on equivalent output (modulo comments/formatting). Variance is a learning-engine signal.

### 26. Dry-Run Honored
`--dry-run` halts before any target-dir write; produces `runs/<run-id>/preview.md`.

### 27. Credential Hygiene
Integration tests read creds from `.env.example` (committed, fake) and `.env` (gitignored). No creds in spec/design/test source. Guardrail G69.

### 28. Golden Regression
Changes to any skill version MUST pass `golden-corpus` regression before auto-application by `learning-engine`.

### 29. Code Provenance Markers
Markers (`[traces-to:]`, `[constraint:]`, `[stable-since:]`, `[deprecated-in:]`, `[do-not-regenerate]`, `[owned-by:]`) are machine-read by `sdk-marker-scanner`. Marker rules:

- MANUAL-marked symbols NEVER modified by pipeline (guardrail G96, byte-hash match)
- `[constraint: ... bench/BenchmarkX]` triggers automatic bench proof (guardrail G97)
- `[do-not-regenerate]` = hard lock (G100)
- `[stable-since: vX]` signature changes require major semver + TPRD §12 declaration (G101)
- Pipeline-authored symbols MUST have `[traces-to: TPRD-<section>-<id>]` marker (G99)
- Pipeline NEVER forges `[traces-to: MANUAL-*]` (G103)

### 30. Incremental Update Support
Pipeline supports three request modes: A (new package), B (extension), C (incremental update). Mode C uses marker-aware 3-way merge via `sdk-merge-planner`. Existing tests + bench MUST continue passing post-update (G95).

---

## Phase Flow

```
Phase -1 Bootstrap   → create/evolve skills (if gaps)
Phase 0   Intake     → TPRD canonicalization + clarifications
Phase 0.5 Analyze    → (Mode B/C only) snapshot existing API + tests + bench
Phase 1   Design     → API design + devil review
Phase 2   Impl       → TDD red/green/refactor/docs (marker-aware)
Phase 3   Testing    → unit + integration + bench + leak
Phase 4   Feedback   → metrics + drift + golden + learning-engine
```

HITL gates H0 through H10 + H7b control phase transitions. See plan §HITL Gates.

## Pipeline Versioning

`settings.json` declares `pipeline_version: "0.1.0"`. Every log entry stamps it. Upgrade path: bump semver, run `scripts/verify-provenance.sh` to diff against archive, update `PROVENANCE.md`.

## Directory Reference

```
docs/                       — Pipeline docs, missing-skills-backlog
phases/                     — Phase contracts
commands/                   — Slash commands
.claude/agents/             — Agent prompts
.claude/skills/<n>/SKILL.md — Skills (versioned)
runs/<run-id>/              — Per-run state
  decision-log.jsonl        — All agent entries
  state/run-manifest.json   — Wave / agent status
  bootstrap/                — Phase -1 outputs
  intake/                   — TPRD + clarifications
  extension/                — Phase 0.5 outputs (Mode B/C)
  design/                   — Phase 1 outputs
  impl/                     — Phase 2 outputs (ownership-map, merge plan)
  testing/                  — Phase 3 outputs
  feedback/                 — Phase 4 outputs
baselines/                  — Persistent quality/coverage/perf/skill-health
golden-corpus/<n>/          — Canonical fixtures
evolution/                  — Learning-engine state
state/ownership-cache.json  — Target-SDK-wide marker ownership map
```

## Meta: this file's delta vs. archive

- Rules 1–13 ported verbatim (paths rebased)
- Rule 6 rewritten (SDK conventions, not microservice)
- Rule 14 adapted (no NATS handler requirement, adds goleak + govulncheck)
- Rule 15 DROPPED (no full-stack/frontend)
- Rule 16 rewritten (feature-level, symbol-traceability)
- Rules 17–30 NEW (SDK-mode: target-dir discipline, markers, modes, HITL, golden, supply chain)

See `PROVENANCE.md` for full change log.
