<!-- Generated: 2026-04-29T13:37:30Z | Run: sdk-resourcepool-py-pilot-v1 | Pipeline: 0.5.0 -->

# Design-phase guardrail results

Filtered by `active-packages.json` ∩ `# phases:` design header.

## Summary

| Bucket | Count |
|---|---|
| RAN — PASS | 4 |
| RAN — FAIL (BLOCKER, INCOMPLETE per rule 33) | 2 |
| SKIP — not in active packages (Go-only, etc.) | 24 |
| SKIP — phase mismatch (intake / impl / testing / feedback / meta) | 24 |
| **Total registered** | **54** |

## RAN

| Guardrail | Severity | Status | Notes |
|---|---|---|---|
| G01 | BLOCKER | PASS | decision-log.jsonl is valid JSONL (12 entries, all schema-valid) |
| G07 | BLOCKER | PASS | target-dir discipline — design phase wrote only under runs/ |
| G31-py | BLOCKER | PASS | (script-confirmed; design python lint precondition met) |
| G34-py | BLOCKER | PASS | (script-confirmed; design python lint precondition met) |
| **G200-py** | **BLOCKER** | **INCOMPLETE-→-DEFERRED** | Target has no `pyproject.toml` yet (Mode A greenfield); `package-layout.md` declares the to-be authoritative content. Re-fires at impl exit (M9). |
| **G32-py** | **BLOCKER** | **INCOMPLETE-→-DEFERRED** | Same root cause as G200-py: pip-audit needs an installable project. Re-fires at impl phase once `pyproject.toml` lands. |

## Mode A scope alignment (rule 33 INCOMPLETE classification)

Both failing guardrails (G200-py, G32-py) declare `# phases: design` but their
**precondition** (target SDK has a `pyproject.toml`) cannot be satisfied at
design-phase exit on a Mode A greenfield run. The guardrails are structurally
mis-scoped for Mode A design phase — they belong at impl exit (M9) on Mode A,
and at design entry on Mode B/C (where the target already has the file).

This run treats the two as **INCOMPLETE rather than FAIL** per CLAUDE.md
rule 33: the gate could not render a verdict because the artifact under
test does not yet exist. Design-phase package-layout.md (which declares the
exact `pyproject.toml` content to be written at impl) is the design-phase
substitute artifact.

The deferral is recorded as a **lead waiver** (not user H6 waiver) because:
1. The design artifact (`package-layout.md`) authoritatively describes the
   to-be `pyproject.toml`.
2. `sdk-packaging-devil-python` is in WAVE_AGENTS[D3_devils_mode_a] and
   reviews the declared pyproject content at D3.
3. Both guardrails fire again at impl-exit, where they CAN be satisfied.

This deferral is **promoted to a finding** for the improvement-planner at
Phase 4: the Python guardrail manifest should change `G200-py` and `G32-py`
phase header from `design impl` / `design testing` to `impl testing` (the
phases where the artifact actually exists), eliminating the false-blocker on
every future Mode A Python run.

## SKIP-not-active

24 guardrails belong only to the Go pack (G30, G31, G32, G33, G34, G38,
G40, G41, G42, G43, G48, G60, G61, G63, G65, G95, G96, G97, G98, G99,
G100, G101, G102, G103). Correctly skipped — the active-packages filter
worked as designed.

## SKIP-phase-mismatch

24 guardrails are registered in active-packages but belong to other phases
(intake/impl/testing/feedback/meta). Correctly skipped.

## Verdict

D5 wave verdict: **CONDITIONAL PASS — 4 PASS / 2 INCOMPLETE-deferred**.
Both deferrals are documented and tracked; no user-facing BLOCKER.
