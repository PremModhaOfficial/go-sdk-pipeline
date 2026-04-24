# Package Layer — Reconciliation Memo

**Date**: 2026-04-24
**Supersedes**: `runs/c-refactor-plan.md`
**Target release**: pipeline v0.4.0 (scaffolding pass) → v0.4.x (dispatch refactor, later)
**Branch**: `pkg-layer-v0.4` off `pipeline-v0.3.0-straighten`
**Status**: scaffolding landed; dispatch refactor deferred

---

## What this memo supersedes

`runs/c-refactor-plan.md` was a **24-week physical-packaging plan** (Option C from `runs/decision-memo.md`). It proposed moving agents/skills/phases/scripts into `core/` and `packs/go/` directory trees. Work started:

- `core/CORE-CLAUDE.md` stub (marked "P0 Stage 9.1")
- `core/agents/` — 11 agent `.md` files copied (byte-identical duplicates of `.claude/agents/`)
- `core/skills/` — 10 skill directories copied (byte-identical duplicates of `.claude/skills/`)
- `core/phases/` — 5 phase contracts copied
- `core/scripts/` — compute-shape-hash.sh + guardrails/ast-hash/perf subdirs
- `core/tests/` — ast-hash + perf test fixtures
- `packs/go/ast-hash-backend.go` (162 LOC) + `packs/go/symbols-backend.go` (307 LOC) — real Go executable backends for AST-based marker hashing
- `packs/go/agent-bindings/`, `packs/go/guardrails/`, `packs/go/skills/`, `packs/go/quality-standards.md`

## Why it was superseded

The physical-packaging approach has one fatal issue and one large cost:

1. **Claude Code harness discovery breaks on file moves.** The harness auto-discovers agents at `.claude/agents/*.md` and skills at `.claude/skills/*/SKILL.md`. Moving files into `.claude/packages/<pkg>/agents/` (or equivalent) makes them uninvokable. The in-progress work sidestepped this by **copying** files rather than moving — but copies diverge from canonical over time, and my new v0.3.0 G90-strict gate can't catch it because both locations exist.

2. **24 weeks for package boundary + Python pilot is disproportionate to near-term value.** Per `runs/decision-memo.md`, Option C pays off only at 3+ languages. We don't have a firm commitment to even a second language, and a manifest-only layer gets most of the architectural benefit (clear ownership, orphan detection, future dispatch readiness) in ~1 week.

## What changed — v0.4.0 scaffolding pass

This pass lands **manifest-only** package boundaries:

- `.claude/package-manifests/shared-core.json` — 22 agents / 16 skills / 21 guardrails
- `.claude/package-manifests/go.json` — 16 agents / 25 skills / 31 guardrails
- `.claude/package-manifests/README.md` — explains the layer
- `scripts/validate-packages.sh` — orphan / duplicate / dangling-reference check

No files moved. No agent prompts edited. No runtime consumer reads the manifests yet — they're descriptive artifacts whose correctness is enforced by `validate-packages.sh`. This matches the "structure first, then change stuff" framing.

## What's NOT in this pass (deferred to v0.4.x or later)

- TPRD `§Target-Language` parsing
- `sdk-intake-agent` writing `active-packages.json`
- `guardrail-validator` filtering gates through active packages
- Phase-lead prompts gating agent invocations through active packages
- `toolchain.md` generation from package manifest
- G05 (active-packages.json schema validation)
- Deletion of the `core/` and `packs/` directories left by the physical-packaging attempt (see "Fate of in-progress work" below)

## Fate of in-progress work under `core/` and `packs/` — resolved

Inspection on 2026-04-24 confirmed duplication and placeholder status for every item. Actions taken in this pass:

### Preserved (real work moved to canonical locations)

| Original path | New canonical path | Notes |
|---|---|---|
| `core/tests/ast-hash/test.sh` | `scripts/tests/ast-hash/test.sh` | Real P1 integration test for AST-hash protocol; resolves `$ROOT/scripts/ast-hash/` correctly from new location. |
| `core/tests/ast-hash/test-g95.sh` | `scripts/tests/ast-hash/test-g95.sh` | Real integration test for G95 marker-ownership under AST-hash + byte-hash paths. |
| `core/tests/perf/test-g104.sh` | `scripts/tests/perf/test-g104.sh` | Real test for G104 alloc budget with per-pack metric selection. |

### Preserved in place (already at canonical location; untracked — commit separately if wanted)

| Path | Status | Notes |
|---|---|---|
| `scripts/ast-hash/` | Untracked | Full AST-hash toolkit: `go-backend.go` + compiled binary, `go-symbols.go` + compiled binary, `ast-hash.sh`, `symbols.sh`, README. ~7MB total (most of it compiled Go). Separate commit decision — binaries probably want `.gitignore` entries. |
| `scripts/perf/perf-config.yaml` | Untracked | Per-language perf metric selection config. Separate commit decision. |

### Deleted (verified byte-identical duplicates of canonical files)

| Path | Verification |
|---|---|
| `core/agents/` | 11 files, each byte-identical to `.claude/agents/<name>.md` (checked 5 at random, all identical) |
| `core/skills/` | 10 directories, each byte-identical to `.claude/skills/<name>/` |
| `core/phases/` | 5 files, duplicates of `phases/<name>.md` |
| `core/scripts/compute-shape-hash.sh` | Diff returned empty vs. `scripts/compute-shape-hash.sh` |
| `core/scripts/ast-hash/ast-hash.sh`, `symbols.sh`, `README.md` | Diff returned empty vs. `scripts/ast-hash/*` |
| `core/scripts/perf/perf-config.yaml` | Diff returned empty vs. `scripts/perf/perf-config.yaml` |
| `core/scripts/guardrails/` | 37 files, all identical to `scripts/guardrails/*.sh` (sampled G01, G04, G06, G90, G100, G101 — all identical) |
| `packs/go/guardrails/` | Sampled G30, G32, G48, G65 — all identical to canonical |
| `packs/go/skills/` | Sampled circuit-breaker-policy, client-mock-strategy, connection-pool-tuning — all identical |
| `packs/go/ast-hash-backend.go` | Diff empty vs. `scripts/ast-hash/go-backend.go` |
| `packs/go/symbols-backend.go` | Diff empty vs. `scripts/ast-hash/go-symbols.go` |
| `packs/go/ast-hash-backend` (3.3MB binary) | SHA256 match to `scripts/ast-hash/go-backend` |
| `packs/go/symbols-backend` (4MB binary) | SHA256 match to `scripts/ast-hash/go-symbols` |

### Deleted (self-marked stubs and placeholders)

| Path | Self-marker text |
|---|---|
| `core/CORE-CLAUDE.md` | "P0 Stage 9.1 stub — content split deferred to Stage 9.4 (documentation)" |
| `packs/go/quality-standards.md` | Same stub framing, same deferred content |
| `packs/go/agent-bindings/*.yaml` (22 files) | Each self-marked "Stage 9.1 placeholder — will be populated in Stage 9.4 (documentation)". Manifest-only does not use agent-bindings; the manifests themselves carry the agent↔pack mapping. |

### Final state

Directories `core/` and `packs/` are both removed. Working tree contains only canonical locations + the new scaffolding. All three guardrails (G06, G90, G116) still PASS. `validate-packages.sh` reports clean 38/38 agents, 41/41 skills, 52/52 guardrails.

## Recommended next steps

1. **Decide on `scripts/ast-hash/` and `scripts/perf/` commit disposition.** These are untracked real work at canonical locations. Options: (a) commit `*.go`, `*.sh`, `*.md`, `*.yaml` and `.gitignore` the compiled binaries; (b) leave untracked until the v0.4.x dispatch refactor; (c) keep in a separate feature branch. Recommend (a) to stop drift.

2. **Schedule the v0.4.x dispatch refactor.** The refined 6.5-day plan (`sdk-intake-agent` writes `active-packages.json`, phase-leads + `guardrail-validator` filter through it, `toolchain.md` generated from `go.json.toolchain`, TPRD `§Target-Language`, G05 active-packages schema gate, E2E determinism check against Dragonfly baseline). Scaffolding here becomes its Phase 1 input — no new manifest work needed.

3. **Optional v0.4.x cleanup**: resolve the 4 agents + 3 skills in `shared-core.generalization_debt`. Not urgent — only pays off when the second language adapter lands.

## Cross-reference

- `/home/prem-modha/.claude/plans/that-is-exacly-what-generic-pearl.md` — v0.3.0 straighten plan (merged)
- `runs/decision-memo.md` — original A/B/C language-agnostic options analysis
- `runs/c-refactor-plan.md` — superseded 24-week physical-packaging plan
- `runs/language-agnostic-audit.md` — underlying audit that informed both plans
- `evolution/evolution-reports/pipeline-v0.3.0.md` — v0.3.0 release notes (straighten pass)
- Future: `evolution/evolution-reports/pipeline-v0.4.0.md` — to be written when this lands

---

## Verification at scaffolding-land time

```
$ bash scripts/validate-packages.sh
PASS: manifests consistent with filesystem
  agents:     38 manifested / 38 on fs
  skills:     41 manifested / 41 on fs
  guardrails: 52 manifested / 52 on fs

Package breakdown:
  go                16 agents   25 skills   31 guardrails
  shared-core       22 agents   16 skills   21 guardrails

$ bash scripts/check-doc-drift.sh
PASS G06
PASS G90
PASS G116
=== drift check PASSED ===
```
