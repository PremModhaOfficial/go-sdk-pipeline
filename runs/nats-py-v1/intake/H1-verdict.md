# HITL H1 — Verdict (run `nats-py-v1`)

**Decided by**: user (sahil.thadani@motadata.com), 2026-05-02
**Verdict**: **APPROVED — proceed to Phase 1 Design**

## Decisions recorded

| # | Question | Choice | Rationale |
|---|---|---|---|
| Q1 | Run scope | **A — Full** | User: "ok lest do A goooooooo …". All 5 modules + consolidated OTel + config in a single `nats-py-v1` run. Estimated 8–12M tokens across phases. |
| Q2 | Skills-Manifest | **accept (augmented: 31 + 3 = 34)** | 3 Python-specific skills authored under user direction during intake (see `H1-augmentation-note.md`). |
| Q3 | Guardrails-Manifest | **accept (augmented: 53 + 5 = 58) with 5 informational exclusions for Mode A** | 5 Python-aware guardrails authored under user direction (G120–G124). G95/G96/G100/G101/G103 remain informationally excluded for Mode A (no preserved symbols). |
| Q4 | Constraint advisories | **noted** | 3 advisory floors recorded for `sdk-perf-architect` D1 (nats-py 50–200µs publish floor; codec ≤30 allocs/op; asyncio dispatch 10–30µs). |
| Q5 | Marker-protocol Phase B plan | **acknowledge** | G95–G103 lift-plan documented in `python.json::notes.marker_protocol_note` for the first Mode B/C extension run. |

## Gate disposition

- `phases.intake.status` → `completed`
- `hitl_gates.H1_tprd.status` → `approved`
- Next phase: **Phase 1 Design** (Mode A — `sdk-existing-api-analyzer` is NOT invoked; `sdk-design-lead` is the entry point per `commands/run-sdk-addition.md` flow).
- Branch creation deferred to Phase 2 Implementation per pipeline contract — no target-dir writes during Design.

## Risk acknowledgements (logged for H10 reviewer)

1. **Token budget**: Option A is 5–10× a typical SDK addition. The user accepted explicitly. `learning-engine` should record per-phase token spend against `.claude/settings.json::phase_budgets` and warn at 80% of any per-phase cap.
2. **Aspirational perf-budget propagation**: TPRD has no `[constraint:]` markers. `sdk-perf-architect` at D1 must consult `intake/H1-summary.md §4` advisory floors — do NOT mirror Go SDK numbers.
3. **Marker-protocol Python-side debt**: deferred to first Mode B/C run. For this Mode A run, G95–G103 are informationally excluded; pipeline-authored symbols still get `[traces-to: TPRD-<section>-<id>]` markers (Python `# `-comment syntax per `python.json::marker_comment_syntax`), and `sdk-marker-scanner` must learn the Python comment shape to scan them at run end.
4. **Single-run scope**: failure in any one of the 5 modules halts the whole pipeline at the failing wave. The intake-recommended decomposition (Option B) was explicitly rejected by user; this is logged.

## Active package set (regenerated)

`runs/nats-py-v1/context/active-packages.json` regenerated to pick up the augmented `python` pack (v1.0.0 → v1.1.0, +3 skills, +5 guardrails). G05 + `validate-packages.sh` PASS.

| Pack | v | Agents | Skills | Guardrails |
|---|---|---|---|---|
| `shared-core` | 1.0.0 | 22 | 16 | 22 |
| `python` | 1.1.0 | 0 | 7 (was 4) | 5 (was 0) |
| **Active union** | — | **22** | **23** | **27** |

## Handoff

`sdk-design-lead` invoked next with full briefing:
- canonical TPRD: `runs/nats-py-v1/tprd.md`
- mode: A (greenfield)
- target dir: `/home/prem-modha/projects/nextgen/motadata-py-sdk` (no writes during design)
- target package root: `motadata_py_sdk.events` (plus codec, otel, config siblings per TPRD §12)
- active packages: `runs/nats-py-v1/context/active-packages.json`
- Python research digests: `runs/nats-py-v1/intake/research/{nats-py.md, otel-python.md}`
- 3 advisory perf-floors: see this file's "Risk acknowledgements" §2 + `intake/H1-summary.md §4`
