# Pipeline v0.3.0 — Evolution Report

**Released**: 2026-04-24
**Branch**: `pipeline-v0.3.0-straighten` (cut from `mcp-enhanced-graph`)
**Predecessor**: v0.2.0 (2026-04-18)

---

## What v0.3.0 includes

Five substantive changes merged on `mcp-enhanced-graph` between the v0.2.0 cut and this release. Each is a numeric/structural gate change, not just doc.

### 1. MCP-enhanced cross-run knowledge graph (commit `7e646b0`)

Cross-run state (defects, patterns, baselines, agent performance, patches) migrates from flat JSONL under `evolution/knowledge-base/` to Neo4j via `mcp__neo4j-memory__*`.

- **New skill**: `mcp-knowledge-graph/SKILL.md` (v1.0.0) — canonical read/write + fallback pattern for MCP-aware agents.
- **Updated skill**: `environment-prerequisites-check/SKILL.md` (v1.0.0 → v1.1.0) — adds MCP reachability probe.
- **5 agents updated** with MCP-aware sections (JSONL fallback preserved): `learning-engine`, `improvement-planner`, `root-cause-tracer`, `metrics-collector`, `baseline-manager`.
- **New guardrail G04**: MCP health check at phase start; WARN-only; writes `runs/<id>/<phase>/mcp-health.md`.
- **New CLAUDE.md rule 31**: MCP Fallback Policy. Every MCP is an enhancement, never a correctness dependency.
- **New docs**: `docs/MCP-INTEGRATION-PROPOSAL.md`, `docs/NEO4J-KNOWLEDGE-GRAPH.md`.
- **New script**: `scripts/migrate-jsonl-to-neo4j.py` — backfills graph from JSONL on next healthy run.

### 2. Performance-confidence regime (commit `91d9c37`)

Seven falsification axes; rule 32 lists them, rule 33 formalizes PASS/FAIL/INCOMPLETE verdict taxonomy.

- **New agents** (5): `sdk-perf-architect` (authors `design/perf-budget.md`), `sdk-profile-auditor` (pprof shape + alloc budget), `sdk-complexity-devil` (big-O scaling sweep), `sdk-soak-runner` (background soak + drift polling), `sdk-drift-detector` (fast-fail on positive drift trend).
- **New guardrails** (7): G104 alloc budget, G105 MMD soak duration, G106 drift detection, G107 complexity/big-O, G108 oracle margin, G109 profile shape, G110 perf-exception ↔ design-entry pairing.
- **New CLAUDE.md rules 32 + 33**.
- **New marker**: `[perf-exception: <reason> bench/BenchmarkX]` paired with `runs/<run-id>/design/perf-exceptions.md`.

### 3. Golden-corpus regression retirement (commits `f809317`, `69751a2`)

Full-replay regression was dominant Phase 4 cost (~1.5–3M tokens, 30+ min) and caught almost nothing the devil fleet wasn't already catching on the live run.

Replaced by:
- **Four compensating baselines**: `output-shape-history.jsonl` (SHA256 of sorted exported-symbol signatures), `devil-verdict-history.jsonl` (per-skill `devil_fix_rate` + `devil_block_rate`), tightened quality regression threshold (10% → 5%, enforced by **G86**), `Example_*` count per package in `coverage-baselines.json`.
- **G85**: enforces `learning-notifications.md` is written whenever any patch is applied.
- **G86**: quality regression BLOCKER at 5% once ≥3 prior runs exist.
- **CLAUDE.md rule 28** fully rewritten around the notification + 4-baseline safety net.

### 4. Deterministic-first reviewer gate (commit `edacb87`)

`review-fix-protocol` bumped to v1.1.0. After any rework iteration, phase lead re-runs ALL reviewers **only if** the deterministic-first gate (build/vet/fmt/staticcheck, `-race`, goleak, govulncheck/osv-scanner, marker byte-hash, constraint bench, license allowlist) is green. Iterations failing BLOCKER-level guardrails loop back to fix agents without spawning the reviewer fleet.

- Avoids wasted reviewer tokens on iterations a reviewer couldn't meaningfully evaluate.
- CLAUDE.md rule 13 updated with the gate semantics.

### 5. Drift-prevention gates (this release, pipeline-v0.3.0-straighten)

New structural gates introduced in this straighten pass to stop the "changes propagate to some files and not others" failure mode:

- **G06**: `pipeline_version` consistency across repo.
- **G90 (tightened)**: `skill-index.json` ↔ filesystem strict equality (was subset).
- **G116**: retired-term scanner — fails if `DEPRECATED.md` entries appear in non-deprecated docs.
- **`scripts/check-doc-drift.sh`**: orchestrator wired into intake phase.
- **`docs/DEPRECATED.md`**: retirement registry for concepts + commit-sha + replacement.
- **`.claude/settings.json:pipeline_version`**: declared as authoritative single source of truth per CLAUDE.md rule update.

---

## Upgrade notes

### For agents/skills reading `pipeline_version`

Read from `.claude/settings.json` at invocation time. Do not hardcode the version string in skill bodies or agent prompts. Example stamps in `decision-logging/SKILL.md` now show `sdk-pipeline@0.3.0`.

### For historical runs

Run artifacts under `runs/sdk-dragonfly-s2/` and `runs/sdk-dragonfly-p1-v1/` retain their original `pipeline_version` stamps (0.1.0 and 0.2.0 respectively). These are immutable provenance. The `evolution/knowledge-base/neo4j-seed.json` Run observations were corrected to drop a retcon'd `pipeline_version=0.2.0` observation on the sdk-dragonfly-s2 Run entity; the historical fact is 0.1.0.

### Baselines

All `baselines/*.json` files now stamp `sdk-pipeline@0.3.0`. `performance-baselines.json` moved from 0.1.0; the others from 0.2.0. The `captured_at` and `baseline_run` fields are unchanged — the baseline data itself is unchanged, only the owning-version field was bumped to match the current authoritative version.

### Settings.json changes

- `pipeline_version`: `0.1.0` → `0.3.0`. No other field changed in this release.

---

## What's next (v0.4.0 targets)

Per `PIPELINE-OVERVIEW.md` §11 rollout plan:
- **Serena** integration for Phase 0.5 (marker-scanner) + Phase 2 (impl).
- **code-graph** for blast-radius queries on Mode B/C edits.

Per `docs/MCP-INTEGRATION-PROPOSAL.md`:
- **context7** at Intake + Design for current library docs (v0.5.0).

---

## Commit reference

| Commit | Subject |
|---|---|
| `7e646b0` | feat(mcp): neo4j-memory cross-run knowledge graph + Serena/code-graph/context7 integration scaffolding (v0.3.0) |
| `91d9c37` | feat(perf-confidence): add rules 32/33 + gates G104-G110 + 5 new agents |
| `f809317` | refactor(pipeline): retire golden-corpus full-replay regression |
| `69751a2` | feat(feedback): four compensating baselines + G86 for retired golden-corpus |
| `edacb87` | feat(pipeline): deterministic-first gate for reviewer fleet (review-fix-protocol v1.1.0) |
| (this PR) | chore(pipeline): v0.3.0 straighten — version propagation + drift-prevention gates |
