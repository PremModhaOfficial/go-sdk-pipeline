<!-- Generated: 2026-04-18T05:53:17Z | Run: sdk-dragonfly-s2 -->
# §Guardrails-Manifest Validation — sdk-dragonfly-s2

**Guardrail:** G24 (BLOCKER severity)
**Verdict:** PASS
**Source:** `runs/sdk-dragonfly-s2/tprd.md` §Guardrails-Manifest (38 declared entries)
**Script dir:** `scripts/guardrails/`

## Summary

| Status | Count |
|---|---:|
| PASS (executable `.sh` exists) | 38 |
| FAIL (missing)                 | 0 |
| Total declared                 | 38 |

## Detailed check

Every guardrail id declared in TPRD §Guardrails-Manifest has an executable script in `scripts/guardrails/<Gid>.sh`.

| Guardrail | Phase | Severity | Script present |
|---|---|---|---|
| G01 | all | BLOCKER | yes |
| G02 | all | BLOCKER | yes |
| G03 | all | BLOCKER | yes |
| G07 | impl | BLOCKER | yes |
| G20 | intake | BLOCKER | yes |
| G21 | intake | BLOCKER | yes |
| G22 | intake | INFO | yes |
| G23 | intake | WARN | yes |
| G24 | intake | BLOCKER | yes |
| G30 | design | BLOCKER | yes |
| G31 | design | BLOCKER | yes |
| G32 | design | BLOCKER | yes |
| G33 | design | BLOCKER | yes |
| G34 | design | BLOCKER | yes |
| G38 | design | BLOCKER | yes |
| G40 | impl | BLOCKER | yes |
| G41 | impl | BLOCKER | yes |
| G42 | impl | BLOCKER | yes |
| G43 | impl | BLOCKER | yes |
| G48 | impl | BLOCKER | yes |
| G60 | testing | BLOCKER | yes |
| G61 | testing | BLOCKER | yes |
| G63 | testing | BLOCKER | yes |
| G65 | testing | BLOCKER | yes |
| G69 | testing | BLOCKER | yes |
| G80 | feedback | BLOCKER | yes |
| G82 | feedback | BLOCKER | yes |
| G90 | meta | BLOCKER | yes |
| G93 | meta | BLOCKER | yes |
| G95 | impl | BLOCKER | yes |
| G96 | impl | BLOCKER | yes |
| G97 | impl | BLOCKER | yes |
| G98 | impl | BLOCKER | yes |
| G99 | impl | BLOCKER | yes |
| G100 | impl | BLOCKER | yes |
| G101 | impl | BLOCKER | yes |
| G102 | impl | BLOCKER | yes |
| G103 | impl | BLOCKER | yes |

## Mode-A interaction notes

Even though Mode A voids the `[owned-by: MANUAL]` preservation invariant, the marker guardrails (G95, G96, G100, G101, G103) still execute — they will be trivially satisfied because no MANUAL markers are emitted in this run. G98 + G99 remain fully active and enforce `[traces-to: TPRD-*]` on every pipeline-authored symbol.

## Verdict

**PASS** — all 38 declared guardrails have executable scripts. Proceeding to I4 clarification loop.
