<!-- Generated: 2026-04-22T18:16:40Z | Run: sdk-dragonfly-p1-v1 -->
# H1 Gate — NOT ASKED (BLOCKED)

**Phase:** Intake · **Verdict:** **BLOCKED** · **Exit code:** 6

H1 (TPRD acceptance) is not put to the user because Wave I3 (§Guardrails-Manifest validation, G24) BLOCKER-failed. Per `phases/INTAKE-PHASE.md` and `commands/run-sdk-addition.md §Exit codes`, a missing-guardrail BLOCKER halts the pipeline before the H1 question is asked. H4..H10 are not reached.

## Intake wave verdicts

| Wave | Check | Severity | Verdict | Notes |
|---|---|---|---|---|
| I1 | TPRD ingest (copy to run dir) | — | OK | 41,807 bytes copied from `runs/sdk-dragonfly-p1-tprd.md` |
| I6 | G20 — required topic areas | BLOCKER | **PASS** | all 14 headers present (Purpose, Goals, Non-Goals, Compat Matrix, API Surface, Config, Error Model, Observability, Security, Perf Targets, Test Strategy, Breaking-Change, Milestones, Risks + both manifests) |
| I6 | G21 — §Non-Goals populated | BLOCKER | **PASS** | 11 bullets (threshold ≥3) |
| I2 | G23 — §Skills-Manifest | WARN | **WARN** | 32 declared · 28 present · 4 missing (all flagged WARN-expected in TPRD) |
| I3 | G24 — §Guardrails-Manifest | BLOCKER | **FAIL** | 50 declared · 40 present · **10 missing** |
| I4 | Clarifications | — | skipped | blocker halted intake before clarification loop |
| I5 | Mode detection | — | skipped | blocker halted before mode stamp (TPRD declares Mode B — extension) |
| I7 | H1 gate | — | **not asked** | per intake contract |

## G24 BLOCKER — 10 missing guardrail scripts

| Guardrail | Phase referenced | Purpose (from CLAUDE.md) | Pipeline rule |
|---|---|---|---|
| **G81** | Feedback | Baselines updated or rationale | Rule 28 (compensating baselines 1, 2, 4) |
| **G83** | Feedback | Every patch logged in skill evolution-log.md | Rule 23 (versioning & human-only authorship) |
| **G84** | Feedback | Per-run safety caps respected | Rule 22 / `settings.json § safety_caps` |
| **G104** | Impl (M3.5) | Alloc-budget per declared `allocs_per_op` | Rule 32 axis 3 (allocation) |
| **G105** | Testing (T-SOAK) | Soak-MMD (minimum measurable duration) | Rule 32 axis 6 + Rule 33 (INCOMPLETE ≠ PASS) |
| **G106** | Testing (T-SOAK) | Soak-drift statistically significant trend check | Rule 32 axis 6 |
| **G107** | Testing (T5) | Complexity scaling sweep | Rule 32 axis 4 |
| **G108** | Testing (T5) | Oracle-margin vs reference impl | Rule 32 axis 5 (not waivable via `--accept-perf-regression`) |
| **G109** | Impl (M3.5) | Profile-no-surprise hotspot check | Rule 32 axis 2 |
| **G110** | Impl (M7+M9) | `[perf-exception:]` marker ↔ `perf-exceptions.md` pairing | Rule 32 axis 7 + Rule 29 |

All 10 filed to `docs/PROPOSED-GUARDRAILS.md` with motivation, phase, severity, and rationale.

## G23 WARN — 4 missing skills (non-blocking)

| Skill | Declared in TPRD | Status | Filed to |
|---|---|---|---|
| `redis-pipeline-tx-patterns` | §5.1 — KeyPrefix inside Pipeline() callback | WARN-expected | `docs/PROPOSED-SKILLS.md` |
| `go-iter-seq-patterns` | §5.4 — Go 1.23+ range-over-func iterators | WARN-expected | `docs/PROPOSED-SKILLS.md` |
| `redis-set-sortedset-semantics` | §5.5 + §5.6 — member encoding, score semantics | WARN-expected | `docs/PROPOSED-SKILLS.md` |
| `generic-codec-helper-design` | §5.2 — package-level generics over non-generic receiver | WARN-expected | `docs/PROPOSED-SKILLS.md` |

Per TPRD §Skills-Manifest footnote and Rule 23, these would not have blocked the run. Pipeline would have proceeded using in-library generic skills (`go-concurrency-patterns`, `testing-patterns`, etc.) plus TPRD §5 prescriptions.

## H0 (target-dir preflight) — PASS

- `$SDK_TARGET_DIR` resolved to `/home/prem-modha/projects/nextgen/motadata-go-sdk/src/motadatagosdk`
- git repo: **yes** (remote `git@ssh.dev.azure.com:v3/Motadata/NextGen/motadata-go-sdk`)
- current branch: `sdk-pipeline/sdk-dragonfly-s2` (P0 branch; up-to-date with origin)
- planned branch: `sdk-pipeline/sdk-dragonfly-p1-v1` — **not created** (deferred until H1 approval to avoid leaving an orphan branch on this halt)
- target dir untouched

## Mode detection (deferred)

TPRD §1 declares **Mode B — extension** of P0 Dragonfly client. Mode stamp not written to `state/run-manifest.json` because I5 wave did not run. Mode B gates Phase 0.5 extension-analyze, which also did not run.

## Resume path

This halt is recoverable without re-parsing the TPRD. Two options:

### Option 1 (recommended): author the 10 missing guardrail scripts

Per `docs/PROPOSED-GUARDRAILS.md` workflow:

1. Human authors `scripts/guardrails/G{81,83,84,104,105,106,107,108,109,110}.sh`
2. Each follows existing convention: `exit 0 = PASS`, `exit 1 = FAIL`, `exit 2 = WARN`
3. `chmod +x` on each
4. Update `docs/PROPOSED-GUARDRAILS.md` row `status: proposed → promoted` with commit SHA
5. Re-run: `/run-sdk-addition --spec runs/sdk-dragonfly-p1-tprd.md`

The existing G20/G21/G23 PASS/WARN verdicts carry over mechanically (deterministic checks, TPRD unchanged).

### Option 2 (discouraged): TPRD revision

Remove the 10 IDs from §Guardrails-Manifest. **Not recommended** — Rule 32 axes 2–7 (G104–G110) are load-bearing for the TPRD's declared §10 perf targets (oracle margins, alloc budgets, complexity, profile discipline). Dropping them gives perf-confidence that the TPRD does not actually possess. G81/G83/G84 are feedback-phase safeguards for the learning-engine's runtime power (Rule 23/28); dropping them removes the only per-run check that the evolution pipeline respected its declared safety caps.

## What the user should see

- **No code changed in `$SDK_TARGET_DIR`.** No files written to target, no branch cut, no commits.
- **Run artifacts all under `motadata-sdk-pipeline/runs/sdk-dragonfly-p1-v1/`.**
- **Next action is on the human**: either author the 10 scripts (recommended) or revise the TPRD.

## Invariants honored on halt

- Rule 17 — target-dir discipline (pipeline wrote only to `runs/`)
- Rule 21 — never commits, never pushes
- Rule 22 — budget tracking (~0.1% of intake token budget used)
- Rule 31 — no MCP dependency for halt verdict (all checks ran from local scripts + static index)
- `settings.json § safety_caps.new_guardrails_per_run = 0` — runtime did not author any scripts
