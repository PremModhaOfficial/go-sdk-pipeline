# Pipeline v0.4.0 — Evolution Report

**Released**: 2026-04-27
**Branch**: `pkg-layer-v0.4` (cut from `mcp-enhanced-graph` after v0.3.0)
**Predecessor**: v0.3.0 (2026-04-24)

---

## What v0.4.0 includes

A **package layer** — manifest-only, no file moves — that scopes which agents / skills / guardrails are active per run. Sets the stage for a second-language adapter (Python or Rust) to land in v0.5.0 without forking the agent fleet.

This release is **structural, not behavioral** for Go-only runs. A v0.3.0 Go TPRD running through v0.4.0 should produce identical generated code, identical decision-log shape, identical guardrail pass/fail set — the only delta is two new artifacts under `runs/<id>/context/` (`active-packages.json`, `toolchain.md`) and one new intake-phase guardrail run (`G05`).

### 1. Package manifests (commit `59157c3`, scaffolding)

Two JSON manifests under `.claude/package-manifests/`:

- `shared-core.json` — language-agnostic orchestration, meta-skills, governance. 22 agents, 16 skills, 22 guardrails.
- `go.json` — Go SDK language adapter. 16 agents, 25 skills, 31 guardrails. Carries `toolchain` block (build/test/lint/coverage/bench/supply-chain commands), `file_extensions`, `marker_comment_syntax`, `module_file`.

Every on-disk artifact (38 agents, 41 skills, 53 guardrails) is in exactly one manifest. **`scripts/validate-packages.sh`** enforces; runs on demand and exits non-zero on orphan / duplicate / dangling reference.

Each manifest also carries a `generalization_debt` array — artifacts whose role is language-neutral but whose body still cites Go idioms. That list is the v0.5.0 second-language-pilot backlog; no action required in this release.

### 2. TPRD schema extension (`phases/INTAKE-PHASE.md`)

Three new optional TPRD preamble fields, all backwards-compatible:

| Field | Default | Purpose |
|---|---|---|
| `§Target-Language` | `go` | Primary language adapter package; must match a manifest. |
| `§Target-Tier` | `T1` | `T1` = full perf gates; `T2` = build/test/lint/supply-chain only; `T3` = out-of-scope. |
| `§Required-Packages` | derived | Override list. Rare. |

TPRDs without these fields default to `go T1` — identical to pre-v0.4.0 behavior.

### 3. Per-run package resolution (`sdk-intake-agent` Wave I5.5)

New wave between Mode Detection (I5) and Completeness Check (I6):

1. Parse `§Target-Language` / `§Target-Tier` / `§Required-Packages`.
2. Verify each package's manifest exists; verify `pipeline_version_compat` satisfied; recursively resolve `depends`.
3. Compute the union of `agents` / `skills` / `guardrails` arrays → write `runs/<run-id>/context/active-packages.json`.
4. Write `runs/<run-id>/context/toolchain.md` (informational digest of the language adapter's toolchain block).

### 4. New guardrail G05 — `active-packages.json` valid + resolves

`scripts/guardrails/G05.sh`. Phase=intake, severity=BLOCKER. Verifies:

- File exists.
- JSON shape (`run_id`, `resolved_at`, `target_language`, `target_tier`, `packages[]`).
- Every referenced package's manifest exists on disk.
- No circular `depends` (depth-32 ceiling).
- Manifests are well-formed (`name`/`version`/`agents`/`skills`/`guardrails` present).
- Drift cross-check: `agents`/`skills`/`guardrails` arrays in `active-packages.json` equal the union derived from on-disk manifests (sorted, unique). Any drift = BLOCKER.

Added to `shared-core.json`'s guardrails list (G05 is language-neutral).

### 5. Package-scoped dispatch — guardrail-validator + 3 phase leads

`guardrail-validator` Delta 6 (new): reads `active-packages.json`, computes `ACTIVE_GATES = union of .packages[].guardrails`, filters by phase header, runs only the filtered set. Reports `gates_active` / `gates_run` / `gates_skipped` with package attribution.

`sdk-design-lead`, `sdk-impl-lead`, `sdk-testing-lead` each gain an "Active Package Awareness" section. Per-invocation gate: agents not in the active set are skipped + logged as `event: agent-not-in-active-packages`. Tier-critical agents (per-lead table) being absent = BLOCKER.

T1 = today's full-fat behavior. T2 skips the perf-confidence wave entirely. T3 is out-of-scope.

### 6. CLAUDE.md rule 34 — Package Layer

New rule documenting the manifest-only invariant, per-run resolution flow, tier semantics, and v0.5.0 backwards-compat plan. The "Directory Reference" section gains entries for `.claude/package-manifests/`, `scripts/validate-packages.sh`, `runs/<id>/context/active-packages.json`, `runs/<id>/context/toolchain.md`.

### 7. New doc — `docs/PACKAGE-AUTHORING-GUIDE.md`

Walks through how a future contributor authors a second-language adapter package: manifest schema, toolchain block, depends syntax, generalization-debt convention, validator workflow, where adapter scripts will live in v0.5.0+ (currently inline in the manifest's `toolchain` block; externalized later).

### 8. Pipeline version 0.3.0 → 0.4.0

`.claude/settings.json` bumped. All live consumers (`improvements.md`, `decision-logging/SKILL.md`, `mcp-knowledge-graph/SKILL.md`, `skill-index.json`, 5× `baselines/*.json`, `CLAUDE.md`) updated to match. G06 PASS post-bump.

### 9. Baseline partitioning — Decision D1=B (per-language subdirectory) shipped

Per Decision D1=B (recorded in `docs/LANGUAGE-AGNOSTIC-DECISIONS.md`), all baseline files moved into per-scope subdirectories AND every consumer was refactored to read the new paths in the same PR. This is the load-bearing piece that makes the v0.5.0 Python pilot mechanical:

**Files moved**:
- 7 per-language baselines (perf, coverage, output-shape jsonl, devil-verdict jsonl, do-not-regenerate, stable-signatures, regression-report) → `baselines/go/`
- 4 shared baselines (quality, skill-health, skill-health-baselines, baseline-history jsonl) → `baselines/shared/`

**Manifests declare paths**:
- `go.json` carries `baselines.owns_per_language_paths: [baselines/go/...]`
- `shared-core.json` carries `baselines.owns_shared_paths: [baselines/shared/...]`

**Consumer path-refactor (~70 substitutions across 21 files)**:
- Agents: `baseline-manager`, `learning-engine`, `metrics-collector`, `sdk-benchmark-devil`, `sdk-intake-agent`, `sdk-skill-coverage-reporter`, `sdk-testing-lead`
- Skills: `mcp-knowledge-graph`, `sdk-marker-protocol`, `sdk-semver-governance`
- Guardrails: `G81.sh`, `G86.sh`, `G101.sh`
- Governance docs: `CLAUDE.md`, `LIFECYCLE.md`, `phases/FEEDBACK-PHASE.md`, `phases/TESTING-PHASE.md`, `improvements.md`, `docs/PROPOSED-GUARDRAILS.md`
- Scope-stamping: every JSON baseline carries `scope: per-language|shared|shared-stub` + `language: go` (where applicable) + `scope_note` linking to LANGUAGE-AGNOSTIC-DECISIONS.md

**Deferred for v0.5.0** (decisions D2 + D6, research spikes R1 + R2):
- D2: cross-language fairness for shared-core agents/skills with `generalization_debt` (data-dependent — needs Python pilot to measure)
- D6: generalization-debt rewrite timing (Eager vs Lazy vs Split; pair with R2 spike)
- R1: cross-language oracle calibration study
- R2: debt-rewrite feasibility study
- Python adapter scaffold itself (`python.json`, Python skills, `baselines/python/` partition)

### 10. New doc — `docs/LANGUAGE-AGNOSTIC-DECISIONS.md`

Living decision register. Contains: decisions taken (D1, D3, D4, D5), decisions deferred (D2, D6), Tier-2/Tier-3 open questions surfaced for the Python pilot, the per-touchpoint handling table, R1+R2 research spike specs, v0.5.0 execution checklist. Designed for next-version pickup.

---

## Upgrade notes

### For TPRD authors

If you're writing a TPRD for a Go SDK addition: nothing changes. The new fields default to `go T1`. Don't add them.

If you're (eventually) writing a TPRD for a non-Go target: declare `§Target-Language: <lang>` near the top of the TPRD. Intake will resolve `<lang>.json` from `.claude/package-manifests/`. If the manifest doesn't exist yet, that's a BLOCKER — file under `docs/PROPOSED-PACKAGES.md` for human authoring.

### For agent / skill / guardrail authors

Every NEW artifact must be added to exactly one package manifest in the same PR that introduces it. `scripts/validate-packages.sh` is your CI check. Existing artifacts have already been classified into `shared-core` (role is language-neutral) or `go` (role is Go-specific).

If an artifact is `shared-core` but its body cites Go idioms (e.g. `tdd-patterns` skill, `sdk-design-devil` agent), add an entry to that manifest's `generalization_debt` array with name + reason. v0.5.0 will work through that list when the second adapter lands.

### For run-replay / determinism (rule 25)

A v0.3.0 Go-only TPRD replayed under v0.4.0 will produce:

- ✅ Identical generated code (no agent prompt edited its core responsibilities; only added a startup-protocol read-step + dispatch gate that no-ops on Go T1 because the active set covers everything)
- ✅ Identical decision-log entry types + counts, plus one new `event: package-resolution` entry from intake
- ✅ Identical guardrail pass/fail set, plus G05 PASS
- ✅ Two new artifacts: `context/active-packages.json`, `context/toolchain.md`

Determinism (rule 25) is preserved.

### Settings.json changes

- `pipeline_version`: `0.3.0` → `0.4.0`. No other field changed.

### Baselines

All `baselines/*.json` files now stamp `sdk-pipeline@0.4.0`. The baseline data itself is unchanged.

---

## Rollback path

The package layer is **inert until intake/validator/leads read it**. Rollback strategies:

1. **Soft rollback**: revert the agent prompt edits in `sdk-intake-agent`, `guardrail-validator`, `sdk-design-lead`, `sdk-impl-lead`, `sdk-testing-lead`. Manifests stay on disk as inert metadata; `validate-packages.sh` continues to enforce orphan-free discipline. Pipeline behavior reverts to v0.3.0.
2. **Hard rollback**: `git revert` the v0.4.0 PR. No file moves were performed, so nothing needs to be moved back. `pipeline_version` returns to `0.3.0`.

No baselines or generated code on a target SDK depend on the package layer; rollback is local to this repo only.

---

## What's NOT in this pass (deferred to v0.5.0+)

- ❌ Authoring a second-language manifest (Python / Rust / TypeScript / Java).
- ❌ Externalizing adapter scripts. The current `toolchain` block in `go.json` carries inline shell-command strings (`go build ./...`, etc.). v0.5.0 will move these into `.claude/package-manifests/<lang>/adapters/*.sh` referenced by manifest path.
- ❌ Working through the `generalization_debt` lists. Each entry will get either (a) a language-neutral rewrite, (b) move to the `<lang>` package if role turns out language-specific, or (c) split into shared + per-language parts.
- ❌ Output-artifact normalization. Bench output, profile output, coverage output today are Go-tool-native (`benchstat`, `pprof`, `go tool cover`). v0.5.0 introduces normalized JSON schemas that adapter scripts emit; agents consume schemas, not raw tool output.
- ❌ Per-tier guardrail-validator filtering. Today, T2 dispatch is enforced at phase leads (skip waves) but `guardrail-validator` still runs every gate the active set declares. T2 should also skip perf-confidence guardrails (G104-G110); deferred until a real T2 TPRD exists.
- ❌ Removing the legacy fallback in `guardrail-validator` and the three phase leads ("if `active-packages.json` absent, run everything"). Fallback stays in v0.4.0 for safety on replay; removed in v0.5.0.

---

## Commit reference

| Commit | Subject |
|---|---|
| `59157c3` | chore(pipeline): v0.4.0 scaffolding — package-manifest layer (structure only) |
| `7020748` | feat(ast-hash): commit language-pluggable AST hasher toolkit + perf-config |
| `8c67c91` | docs(roadmap): add pendingList.md — production-readiness + multi-language roadmap |
| (this PR) | feat(package-layer): v0.4.0 — TPRD §Target-Language/Tier/Required-Packages, intake Wave I5.5, G05, dispatch deltas, CLAUDE.md rule 34, authoring guide |

---

## What's next (v0.5.0 targets)

- Second-language adapter pilot (likely Python — `python.json` manifest + adapter scripts).
- Externalize adapter scripts under `.claude/package-manifests/<lang>/adapters/`.
- Normalized output-artifact schemas (bench / profile / coverage) consumed by agents.
- Walk through `generalization_debt` lists in `shared-core.json`.
- Remove legacy fallback in dispatch logic.
