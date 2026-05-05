# Evolution Log — decision-logging

## 1.1.0 — bootstrap-seed — 2026-04-17
Added `skill-evolution` and `budget` entry types. Envelope required new fields `pipeline_version` + `skill_version_snapshot`. Wired into baseline-manager + improvement-planner + sdk-skill-drift-detector.

6-type schema: decision, lifecycle, communication, event, failure, refactor.

## v1.1.1 — run sdk-resourcepool-py-pilot-v1, 2026-04-28 (pipeline v0.5.0)

PATCH bump — appended "Rework waves — per-wave cap reset" section. Documents two compliant patterns for rework waves (M10/M11/etc.): Pattern A = per-wave cap reset (preferred); Pattern B = wave-level meta-entry rollup with `consolidated` tag. Updates G01 + downstream consumer (baseline-manager, improvement-planner) reading rules to count `decision` entries per-wave, not per-run. Resolves the impl-lead 23-vs-15 cap question without retroactively penalizing the M10/M11 rework. Description tightened. Source: improvement-plan A3; skill-drift §SKD-003 MODERATE. Applied by: learning-engine.
