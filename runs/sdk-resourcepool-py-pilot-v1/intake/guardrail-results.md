# Intake-phase guardrail results

Run-id: `sdk-resourcepool-py-pilot-v1` · pipeline 0.5.0 · target-language python · target-tier T1
Dispatcher: `scripts/run-guardrails.sh intake <run-dir> <target-dir>`
Filter: active-packages union (shared-core ∪ python) ∩ `# phases:` header includes `intake`

## Summary

| Metric | Count |
|---|---|
| RAN + PASS | **12** |
| RAN + WARN-FAIL | 0 |
| RAN + BLOCKER-FAIL | 0 |
| Skipped (not in active packages) | 24 |
| Skipped (phase mismatch) | 18 |

## Ran (12) — all PASS

| ID | Severity | Notes |
|---|---|---|
| G01  | BLOCKER | decision-log JSONL valid |
| G04  | WARN    | MCP health (graceful-degrade) |
| G05  | BLOCKER | active-packages.json resolves cleanly (target-language `python`, target-tier `T1`, packages [shared-core python], 39 agents · 36 skills · 30 guardrails) |
| G06  | BLOCKER | pipeline_version drift = none (all consumers see 0.5.0) |
| G07  | BLOCKER | target-dir discipline |
| G20  | BLOCKER | TPRD all-section completeness (16/16) |
| G21  | BLOCKER | §Non-Goals populated (TPRD has 13 bullets) |
| G22  | INFO    | clarifications ≤3 (this run: 0) |
| G23  | WARN    | §Skills-Manifest 22/22 present at version |
| G24  | BLOCKER | §Guardrails-Manifest 19/19 present + executable |
| G90  | BLOCKER | skill-index ↔ filesystem strict-equality |
| G116 | BLOCKER | retired-concept catalog (DEPRECATED.md) clean |

## Skipped — not in active packages (24, expected)

Go-only guardrails (G30–G65 set, G95–G99 marker-byte-hash) belong to the `go` package manifest, which is NOT in this run's active set. `python.json` declares 11 Python-specific guardrails; intake-phase only invokes 0 of them (all `-py` guardrails are design/impl/testing-phase). Skipped: G30, G31, G31-py, G32, G32-py, G33, G34, G34-py, G38, G40, G40-py, G41, G41-py, G42, G42-py, G43, G43-py, G48, G60, G60-py, G61, G61-py, G63, G63-py, G65, G95, G96, G97, G98, G99.

## Skipped — phase mismatch (18, expected)

Active-set guardrails whose `# phases:` header excludes `intake`: G02 (feedback), G03 (meta — schema/reset), G69 (testing), G80 (feedback), G85 (feedback), G86 (feedback), G93 (meta), G100 (impl), G101 (impl), G102 (impl), G103 (impl), and the 7 -py guardrails (design/impl/testing only). These will fire in their respective phases.

## Verdict

**PASS** — every BLOCKER and WARN guardrail required for intake ran and returned PASS. Pipeline cleared to advance to H1.

Report-machine-readable: `intake/guardrail-report.json`
